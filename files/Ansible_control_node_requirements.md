# Requirements for the control node running Ansible on Rocky Linux 9.2

> **Quick start (automated)**: instead of running the steps below one by one, you can bootstrap the whole control node with the provided script, which installs the system (dnf) packages, the Python (pip) dependencies (`files/pip-requirements.txt`) and the Ansible collections (`files/requirements.yml`) in one go. From the project root:
>
> ```
> ./files/setup-control-node.sh
> ```
>
> The script is idempotent (safe to re-run). The manual sections below remain the reference explanation for each dependency and are still useful if you prefer to install only what a specific OS provisioning flow requires, or to understand what the script does. After running it, complete the manual, environment-specific steps (hostname, SSH key pair, and — for ESXi — the VMware vSphere automation SDK).


## Tested with

The playbooks in this repository were last validated end-to-end (HVM provisioning incl. 2-NIC management-link redundancy, cluster create; ESXi/RHEL/Windows provisioning) on the following control-node software stack (v1.0.3):

| Component | Version |
|-----------|---------|
| OS | Rocky Linux 9.2 |
| Python | 3.11.13 (in a virtualenv) |
| ansible-core | 2.19.11 |
| community.general | 13.2.0 |
| community.vmware | 6.2.1 |
| vmware.vmware | 2.9.0 |
| ansible.windows | 3.7.0 |
| microsoft.ad | 1.12.0 |
| pyVmomi | 8.0.3 |
| vsphere-automation-sdk | 1.87.0 |
| jmespath | 1.1.0 |
| passlib | 1.7.4 |
| pywinrm | 0.5.0 |
| requests | 2.34.2 |
| pip | 26.1.2 |

> **Note**: As of v1.0.3 the control node runs **Python 3.11 in a virtualenv** with **ansible-core 2.19** and the **latest** collection releases (community.general 13.x, community.vmware 6.x). The previous stack (Python 3.9.16 / ansible-core 2.15.13, the last ansible-core supporting Python 3.9) reached community EOL, so the node was moved to a newer, supported line. The deprecated `community.vmware` cluster/host/maintenance-mode modules were migrated to the `vmware.vmware` collection as part of this move; `community.vmware` is retained for the modules that have no `vmware.vmware` equivalent yet (e.g. `vmware_host_facts`, `vmware_vmkernel`, `vmware_vswitch`, `vmware_portgroup`). Because Python 3.11+ removes the built-in `crypt` module, `passlib` is now the mandatory `password_hash` backend (see the passlib note below for the ESXi-specific `rounds=5000` requirement).

## Update the System

Ensure that all packages are up to date with the latest security patches and bug fixes.

```
sudo dnf -y update
```


## Set hostname

To ensure proper functionality of the Ansible playbooks, it is important to use a Fully Qualified Domain Name (FQDN) hostname for the control node running Ansible.

```
sudo hostnamectl set-hostname <hostname>.<your-domain>
```


## Clone the Github repository

```
sudo dnf -y install git
mkdir ~/Projects
cd ~/Projects
git clone https://github.com/jullienl/HPE-COM-baremetal
```


## Generate an SSH RSA key pair without a passphrase for the Ansible control node

SSH public key authentication is mandatory for Ansible to control hosts as it allows Ansible to authenticate with the managed nodes without manually entering passwords, which is essential for automation.

Openssh is installed by default on Rocky Linux so it is not necessary to install it. 
To generate an SSH RSA key pair without a passphrase:

```
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
``` 

> `-N ""` indicates that the passphrase is an empty string i.e., no passphrase. This is to prevent Ansible from asking for the passphrase when running a playbook.

> **Caution**: Always be cautious with the handling of SSH private keys. Without a passphrase, ensure that they are kept in very   secure storage and that permissions are set correctly to prevent unauthorized access (chmod 600 ~/.ssh/id_rsa).

> **Note**: When you use an SSH private key that is protected by a passphrase, you need to provide a way for Ansible to use that passphrase when it connects to managed nodes. A common method to handle this situation is by using `ssh-agent`


## ISO creation tools required

```
# mkisofs
sudo dnf -y install epel-release
sudo dnf -y install mkisofs

# isoinfo (used for RHEL only)
sudo dnf -y install genisoimage

# isohybrid (used for RHEL only)
sudo dnf -y install syslinux

# implantisomd5 (used for RHEL only)
sudo dnf -y install isomd5sum
```


## Ansible installation and requirements

```
sudo dnf -y install python3-pip
pip3 install setuptools-rust wheel
pip3 install ansible-core
```


## Install all Python (pip) dependencies at once (optional shortcut)

Rather than running the individual `pip3 install ...` commands documented in the sections below (jmespath, passlib, pywinrm, requests, the VMware SDK, etc.), you can install every Python dependency used by these playbooks in a single command with the provided pip requirements file:

```
pip3 install -r files/pip-requirements.txt
```

> **Note**: This is the pip/Python package list. It is different from `files/requirements.yml`, which is the ansible-galaxy file used to install the Ansible *collections* (see "Installation of the Ansible Collections used in these playbooks" below). You still need both.

> **Note**: The individual sections below explain what each dependency is for and remain valid if you prefer to install only what a specific OS provisioning flow requires.


## Installation of Ansible lint (optional, useful to identify problems in playbooks)

```
pip install ansible-lint
```


## Installation of ksvalidator (optional, useful to validate kickstart file modifications)

```
sudo dnf -y install pykickstart
```


## Installation of the Ansible Collections used in these playbooks 

``` 
ansible-galaxy collection install -r files/requirements.yml --force 
```
`--force` is required if you need to upgrade the collections to the latest available versions from the Galaxy server. 


## VMware collection requirements (used for ESX provisioning only)

```
pip3 install --upgrade pip setuptools
pip3 install --upgrade git+https://github.com/vmware/vsphere-automation-sdk-python.git
pip3 install -r ~/.ansible/collections/ansible_collections/community/vmware/requirements.txt
pip3 install requests # (Should be already installed)
```


## Windows collection requirements 

An important task to ensure the smooth operation of this project is the pre-creation of DNS records for all hosts that will be provisioned. For this reason, each playbook includes a task to create a DNS record on a Windows DNS server defined in the \vars folder. 
For this Windows DNS server to be managed by Ansible, a Windows Remote Management (WinRM) listener should be created and activated. And for Ansible to execute commands remotely on this Windows server, the pywinrm library must be installed. 

```
pip3 install pywinrm
```
pywinrm is the Python library that allows Ansible to interact with the WinRM service running on the Windows DNS server to perform the DNS record operations. 


## Installation of json_query filter used in the playbooks

The `json_query` filter enables the filtration and transformation of JSON data within Ansible playbooks. This particular filter isn't bundled with the core Ansible package; rather, it comes with the community.general collection that has been added through the `requirements.yml` file earlier. However, to function correctly, `json_query` relies on the jmespath Python library—an additional dependency that must be installed separately. 

```
pip3 install jmespath
```


## Installation of passlib for password hashing (used for ESXi, RHEL and HVM provisioning)

The playbooks hash the OS root/admin password with Ansible's `password_hash('sha512')` filter (for example `hashed_root_password` in `vars/HVM_vars.yml`). By default this filter relies on Python's built-in `crypt` module, which is deprecated and removed in Python 3.13. Without `passlib` you get the warning:

```
[DEPRECATION WARNING]: Encryption using the Python crypt module is deprecated. ... Install the passlib library for continued encryption functionality.
```

Installing the `passlib` Python library makes Ansible use it instead of the `crypt` module, which removes the warning and keeps password hashing working on Python 3.13+:

```
pip3 install passlib
```

> **ESXi note (`rounds=5000` required)**: once `passlib` is the backend, `password_hash('sha512')` emits the extended `$6$rounds=656000$...` crypt form. The ESXi kickstart installer (weasel) rejects it with *"crypted password is not valid"* while parsing the kickstart. The ESXi vars therefore hash with `password_hash('sha512', rounds=5000)`, which forces the classic `$6$salt$hash` form ESXi accepts. RHEL uses a static pre-computed hash and HVM (Ubuntu) accepts the extended form, so only ESXi needs `rounds=5000`.


## OpenSSL 3.5.x workaround (RHEL/Rocky/Alma 9.8+)

On control nodes whose **system OpenSSL is 3.5.x** (shipped by RHEL/Rocky/Alma **9.8 and later**), Python's `ssl.load_verify_locations(cadata=<DER bytes>)` incorrectly rejects valid certificates with:

```
ssl.SSLError: [ASN1: NOT_ENOUGH_DATA] not enough data (_ssl.c:...)
```

ansible-core reads the system trust store, converts it to DER and passes it to that call, so on an affected node **every HTTPS request made with `validate_certs: true` fails** — including the HPE Compute Ops Management OAuth2 session in [Create_COM_session.yml](Create_COM_session.yml) used by all playbooks (symptom: *"Status code was -1 ... Connection failure: [ASN1: NOT_ENOUGH_DATA]"* against `https://sso.common.cloud.hpe.com/as/token.oauth2`), and `ansible-galaxy` collection installs.

The affected OpenSSL is the current, official, distribution-signed build (e.g. `openssl-libs-3.5.5-*.el9_8`), not a broken one, and the enabled repositories offer no alternative version. Downgrading the system crypto library is unsupported and system-wide (dnf, rpm, sshd, curl all link it) and would forgo security patches, so this project ships a small, **venv-local, self-detecting** workaround instead.

`setup-control-node.sh` installs [hpe_openssl35_der_cadata_fix.py](hpe_openssl35_der_cadata_fix.py) into the active Python's `site-packages` and adds a companion `.pth` file so it loads at interpreter start (covering `ansible-playbook`, `ansible`, and `ansible-galaxy`). Key properties:

- **Preserves certificate validation** — it converts the trust store from DER to PEM (the code path OpenSSL 3.5.x handles correctly) before verification. This is **not** `validate_certs: false`.
- **Auto-detecting / safe everywhere** — on import it probes whether this interpreter's OpenSSL rejects DER `cadata`; the fix is applied **only** on affected hosts and is a complete **no-op** on healthy OpenSSL (3.0.x, 3.2.x, or a future fixed 3.5.x).
- **Isolated & reversible** — it affects only the virtualenv it is installed in; delete `hpe_openssl35_der_cadata_fix.py` and `hpe_openssl35_der_cadata_fix.pth` from `site-packages` to remove it.

If you set up the control node manually (without the script), install it into your active environment with:

```
SITE=$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
install -m 0644 files/hpe_openssl35_der_cadata_fix.py "$SITE/"
printf 'import hpe_openssl35_der_cadata_fix\n' > "$SITE/hpe_openssl35_der_cadata_fix.pth"
```

> **Long-term**: when the distribution ships an OpenSSL build where DER `cadata` works again, the self-test stops matching and the module becomes an automatic no-op; it can then be removed.


## OpenSSH must match the system OpenSSL (RHEL/Rocky/Alma 9.8+)

Related to the OpenSSL 3.5.x update above: if the system `openssl-libs` package is upgraded to 3.5.x but `openssh` is left at an older release that was built against OpenSSL 3.0.x, `ssh-keygen` (and other openssh tools) fail at runtime with an ABI mismatch:

```
ssh-keygen failed (rc=255, stderr='OpenSSL version mismatch. Built against 30000070, you have 30500050')
```

This breaks the `known_hosts` module used by the unprovisioning playbooks (which shells out to `ssh-keygen`) — and in fact **every** `ssh-keygen` call on the node. The fix is to update openssh so it matches the current OpenSSL:

```
sudo dnf -y update openssh openssh-clients openssh-server
```

> **Note**: This is why "Update the System" (`sudo dnf -y update`) is listed as a prerequisite — a full update keeps openssh and openssl in lockstep. The problem only appears when the two are updated out of sync (e.g. openssl patched but openssh held back). Updating openssh restarts `sshd`, which does **not** drop existing SSH sessions.


## Ngnix web service

Ngnix is used to host the custom OS ISO images that will be generated, and from which provisioned servers will boot from.

```
sudo dnf -y install nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
``` 

Enabling ngnix directory browsing:

``` 
sudo sed -i '0,/server {/s//&\n        autoindex on;/' /etc/nginx/nginx.conf
sudo systemctl restart nginx
``` 


## Unzip (should already be installed)

Unzip is used to extract HPE Package to get product id information that is required when the package is installed.

```
sudo dnf -y install unzip 
```


## Wimlib (used for Windows provisioning only)

Wimlib is used to inject scripts into the WinPE image.

```
sudo dnf -y install wimlib-utils
```



## Rsync

rsync is a utility for efficiently transferring and synchronizing files across computer systems, by using differential data transfer to minimize network usage. It is used in this project to copy ISO image files.

```
sudo dnf -y install rsync
```