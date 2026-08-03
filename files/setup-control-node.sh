#!/usr/bin/env bash
# =====================================================================================================================
# Control-node bootstrap for the HPE Compute Ops Management bare metal provisioning project.
#
# One command sets up the whole Ansible control node (Rocky Linux 9.x). It installs, in order:
#   0. Python virtualenv     : creates/activates ~/.venvs/ansible (Python 3.11) unless already inside one
#   1. System (dnf) packages : ISO tooling, nginx, rsync, unzip, wimlib, pykickstart, git, python3-pip
#   2. Python (pip) packages : from files/pip-requirements.txt (ansible-core, jmespath, passlib, pywinrm, ...)
#   3. Ansible collections   : from files/requirements.yml (community.general/vmware/windows, microsoft.ad)
#
# This wires together the three package managers this project relies on (dnf + pip + ansible-galaxy), which cannot be
# combined into a single requirements file. It is idempotent: re-running it is safe.
#
# Usage (from the project root):
#   ./files/setup-control-node.sh
#
# Notes:
#   - Uses 'sudo' for the dnf steps; you will be prompted for your password.
#   - You do NOT need to create a virtualenv first: if you are not already inside one, the script creates and uses
#     ~/.venvs/ansible automatically. Override the location with VENV_DIR=/path ./files/setup-control-node.sh.
#     After it finishes, run 'source ~/.venvs/ansible/bin/activate' in each new shell before running playbooks.
#   - Optional tools (ansible-lint) are left commented in files/pip-requirements.txt.
#   - See files/Ansible_control_node_requirements.md for the detailed, per-dependency explanation.
# =====================================================================================================================

set -euo pipefail

# Resolve the project root (the parent of this script's 'files/' directory) so the script works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "==> Project root: ${PROJECT_ROOT}"

# --- 0. Python virtual environment -----------------------------------------------------------------------------------
# This project requires Python 3.11 in a virtualenv (see files/Ansible_control_node_requirements.md). If the script is
# run against the system Python instead, the pip and OpenSSL-workaround steps below try to write into the system
# site-packages (e.g. /usr/lib/python3.9/site-packages) and fail with "Permission denied" for a non-root user - and
# running them as root would pollute the OS Python. To make the script robust regardless of how it is launched: if we
# are not already inside a virtualenv, create/activate the project one at ~/.venvs/ansible and use it for every
# python/pip step that follows. (Rocky/RHEL 9's default Python is 3.9, so python3.11 is installed first if missing.)
VENV_DIR="${VENV_DIR:-${HOME}/.venvs/ansible}"

if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "==> [0/3] No active virtualenv detected; preparing ${VENV_DIR} ..."
  if ! command -v python3.11 >/dev/null 2>&1; then
    echo "    Installing python3.11 (Rocky/RHEL 9 default Python is 3.9) ..."
    sudo dnf -y install python3.11
  fi
  if [ ! -d "${VENV_DIR}" ]; then
    echo "    Creating virtualenv with python3.11 at ${VENV_DIR} ..."
    python3.11 -m venv "${VENV_DIR}"
  fi
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"
  echo "    Activated virtualenv: ${VIRTUAL_ENV}"
else
  echo "==> [0/3] Using the already-active virtualenv: ${VIRTUAL_ENV}"
fi

# --- 1. System (dnf) packages ----------------------------------------------------------------------------------------
echo "==> [1/3] Installing system packages with dnf ..."
sudo dnf -y install epel-release
sudo dnf -y install \
  git \
  python3-pip \
  mkisofs \
  genisoimage \
  syslinux \
  isomd5sum \
  pykickstart \
  nginx \
  unzip \
  wimlib-utils \
  rsync

# --- Keep openssh in lockstep with the system OpenSSL ----------------------------------------------------------------
# On RHEL/Rocky/Alma 9.8+ the system OpenSSL is 3.5.x. If openssl-libs was updated to 3.5.x but openssh was left at an
# older build (compiled against OpenSSL 3.0.x), ssh-keygen fails at runtime with
# "OpenSSL version mismatch. Built against 30000070, you have 30500050", which breaks the known_hosts module used by
# the unprovisioning playbooks (and every ssh-keygen call). Updating openssh so it matches the current OpenSSL fixes it.
echo "==> Ensuring openssh matches the system OpenSSL (avoids ssh-keygen ABI mismatch) ..."
sudo dnf -y update openssh openssh-clients openssh-server

# --- Enable and start nginx (used to host the generated ISOs) --------------------------------------------------------
echo "==> Enabling nginx and opening the firewall for HTTP ..."
sudo systemctl enable --now nginx
sudo firewall-cmd --permanent --add-service=http || true
sudo firewall-cmd --reload || true

# --- 2. Python (pip) packages ----------------------------------------------------------------------------------------
echo "==> [2/3] Installing Python packages from files/pip-requirements.txt ..."
pip3 install --upgrade pip setuptools wheel
pip3 install -r files/pip-requirements.txt

# --- 2b. OpenSSL 3.5.x DER-cadata workaround -------------------------------------------------------------------------
# RHEL/Rocky/Alma 9.8+ ship OpenSSL 3.5.x, on which Python's
# ssl.load_verify_locations(cadata=<DER bytes>) wrongly rejects valid certificates with
# "[ASN1: NOT_ENOUGH_DATA]". ansible-core feeds the system trust store to that call as DER, so every
# HTTPS request with validate_certs:true fails (COM OAuth2 session in all playbooks, and ansible-galaxy).
# We install a small module into the active Python's site-packages and trigger it at interpreter start
# via a .pth file. The module SELF-DETECTS the defect and is a complete no-op on healthy OpenSSL, and it
# preserves full certificate validation (it is NOT validate_certs:false). See the module header and
# files/Ansible_control_node_requirements.md for details.
echo "==> [2b] Installing the OpenSSL 3.5.x DER-cadata workaround (auto-detecting, venv-local) ..."
SITE_PACKAGES="$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')"
if [ -n "${SITE_PACKAGES}" ] && [ -d "${SITE_PACKAGES}" ]; then
  install -m 0644 "files/hpe_openssl35_der_cadata_fix.py" "${SITE_PACKAGES}/hpe_openssl35_der_cadata_fix.py"
  # A .pth file with an 'import' line is executed at interpreter startup; unlike sitecustomize.py it does
  # not clobber any existing customer hook (multiple .pth files coexist).
  printf 'import hpe_openssl35_der_cadata_fix\n' > "${SITE_PACKAGES}/hpe_openssl35_der_cadata_fix.pth"
  echo "    Installed into: ${SITE_PACKAGES}"
else
  echo "    WARNING: could not resolve site-packages; skipping the OpenSSL workaround install." >&2
fi

# --- 3. Ansible collections ------------------------------------------------------------------------------------------
echo "==> [3/3] Installing Ansible collections from files/requirements.yml ..."
ansible-galaxy collection install -r files/requirements.yml --force

echo ""
echo "==> Control node setup complete."
echo "    Everything above was installed into the virtualenv: ${VIRTUAL_ENV:-${VENV_DIR}}"
echo "    Activate it in each new shell before running playbooks:"
echo "      source ${VENV_DIR}/bin/activate"
echo "    Next steps (see files/Ansible_control_node_requirements.md):"
echo "      - Generate the SSH key pair:  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N \"\""
echo "      - Enable nginx directory browsing (autoindex) if desired."
echo "      - For ESXi provisioning, install the VMware vSphere automation SDK requirements."
