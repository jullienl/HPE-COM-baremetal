"""
Workaround for an OpenSSL 3.5.x defect that breaks Ansible's HTTPS requests.

WHAT THIS FIXES
---------------
On control nodes whose system OpenSSL is 3.5.x (shipped by RHEL/Rocky/Alma 9.8+),
Python's ``ssl.SSLContext.load_verify_locations(cadata=<DER bytes>)`` raises

    ssl.SSLError: [ASN1: NOT_ENOUGH_DATA] not enough data (_ssl.c:...)

for certificates that are perfectly valid (the SAME certificates load fine when
passed as a PEM *string*, and ``cryptography``/``openssl x509`` parse them without
complaint). ansible-core's HTTP stack (``ansible.module_utils.urls.get_ca_certs``)
reads the system trust store, converts every certificate to DER, concatenates it,
and calls ``load_verify_locations(cadata=<DER blob>)`` -- so on an affected system
EVERY HTTPS request made with ``validate_certs: true`` fails. In this project that
breaks the HPE Compute Ops Management OAuth2 session (``files/Create_COM_session.yml``)
used by all playbooks, as well as ``ansible-galaxy`` collection installs.

HOW IT FIXES IT
---------------
It wraps ``ssl.SSLContext.load_verify_locations`` so that when it is called with
*bytes* ``cadata`` (DER), the blob is split into individual DER certificates and
converted to a PEM string before being passed to the real method. The PEM ``cadata``
path is unaffected by the OpenSSL defect, so **certificate validation is fully
preserved** -- this is NOT the same as ``validate_certs: false``.

SAFE ON UNAFFECTED SYSTEMS
--------------------------
On import the module runs a tiny self-test (it tries to load an embedded throwaway
certificate as DER ``cadata``). The wrapper is installed **only if that self-test
reproduces the defect**. On a control node with a healthy OpenSSL (3.0.x, 3.2.x, or
a future fixed 3.5.x), this module does nothing at all and Ansible uses its normal
code path untouched.

SCOPE / REVERSIBILITY
---------------------
* It is loaded only by the Python interpreter of the virtualenv it is installed in
  (via a ``.pth`` file in that venv's site-packages), so it never affects the system
  Python, the system OpenSSL, or any other software on the host.
* To remove it, delete this file and the companion ``.pth`` file from site-packages
  (see files/setup-control-node.sh, which installs both).

LONG-TERM FIX
-------------
When the distribution ships an OpenSSL build where ``load_verify_locations(cadata=<DER>)``
works again, the self-test stops matching and this module automatically becomes a
no-op; it can then be removed entirely.
"""

import base64
import ssl

# A tiny self-signed throwaway certificate (ECDSA P-256), used ONLY as a local
# probe to detect whether this interpreter's OpenSSL rejects DER `cadata`.
# It is never trusted or added to any real verification store.
_PROBE_DER_B64 = (
    "MIIBKDCBz6ADAgECAgEBMAoGCCqGSM49BAMCMB0xGzAZBgNVBAMMEm9wZW5zc2wzNS1zZWxmdGVzdDAg"
    "Fw0yMDAxMDEwMDAwMDBaGA8yMDUwMDEwMTAwMDAwMFowHTEbMBkGA1UEAwwSb3BlbnNzbDM1LXNlbGZ0"
    "ZXN0MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEzRgns6IPfixNgeC9hmvvKJwuQUP2faZMp0zd2V1C"
    "Hlay9tNPwyvcyfXhlu9R7Uu03zo9KSCRILyKadYHkcofSTAKBggqhkjOPQQDAgNIADBFAiEA9ddjZzG9"
    "KH03Cygzi3Pvt7gZQ3anPKaFKcUU+lmDA74CIBXgI8xByBY9rqe1oLbV1ZXsMjrjfeWg3f898UGbUdw2"
)


def _split_der_blob(data):
    """Split a concatenation of DER certificates using ASN.1 TLV lengths."""
    certs = []
    i = 0
    n = len(data)
    while i < n and data[i] == 0x30:  # ASN.1 SEQUENCE
        j = i + 1
        if j >= n:
            break
        length_byte = data[j]
        j += 1
        if length_byte & 0x80:
            num = length_byte & 0x7F
            if num == 0 or j + num > n:
                break
            length = int.from_bytes(data[j:j + num], "big")
            j += num
        else:
            length = length_byte
        end = j + length
        if end > n:
            break
        certs.append(data[i:end])
        i = end
    return certs


def _der_blob_to_pems(data):
    pems = []
    for der in _split_der_blob(data):
        try:
            pems.append(ssl.DER_cert_to_PEM_cert(der))
        except Exception:
            # Skip anything that is not a clean single DER cert; the rest still load.
            continue
    return pems


def _openssl_rejects_der_cadata():
    """Return True if this interpreter's OpenSSL wrongly rejects valid DER cadata."""
    try:
        probe = base64.b64decode(_PROBE_DER_B64)
    except Exception:
        return False
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        ctx.load_verify_locations(cadata=probe)
        return False  # DER cadata works -> healthy OpenSSL, nothing to do
    except ssl.SSLError:
        return True   # DER cadata rejected -> affected OpenSSL, install workaround
    except Exception:
        return False


def install():
    """Install the DER->PEM cadata workaround if (and only if) this host is affected."""
    if getattr(ssl.SSLContext.load_verify_locations, "_der_cadata_workaround", False):
        return  # already installed
    if not _openssl_rejects_der_cadata():
        return  # healthy OpenSSL: leave Ansible's normal code path untouched

    _orig = ssl.SSLContext.load_verify_locations

    def load_verify_locations(self, cafile=None, capath=None, cadata=None):
        if isinstance(cadata, (bytes, bytearray)):
            pems = _der_blob_to_pems(bytes(cadata))
            if pems:
                return _orig(self, cafile=cafile, capath=capath, cadata="".join(pems))
        return _orig(self, cafile=cafile, capath=capath, cadata=cadata)

    load_verify_locations._der_cadata_workaround = True
    ssl.SSLContext.load_verify_locations = load_verify_locations


try:
    install()
except Exception:
    # Never let the workaround break interpreter startup.
    pass
