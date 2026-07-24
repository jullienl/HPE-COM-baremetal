#version=RHEL9.2
# ---------------------------------------------------------------------------------------------------------------------
# RHEL 9.3 (and equivalents: Rocky / AlmaLinux) - Anaconda kickstart seed
#
# This file is the Anaconda kickstart used to perform a fully unattended installation of RHEL on HPE Compute Ops
# Management servers. It is rendered by Ansible (Jinja2) from 'RHEL9.3_provisioning.yml' and shipped in a small
# per-host seed ISO labelled 'OEMDRV' (Anaconda auto-discovers the kickstart on an OEMDRV volume).
#
# WHAT THIS SEED CONFIGURES (item by item, top to bottom):
#   1. Install mode/source - text install; installer + packages pulled from the network repo ('RHEL_repo_url').
#   2. Network (%pre)     - configures a static IP on a SINGLE management NIC for the install (selected by the
#                           COM-derived 'primary_nic_mac', falling back to the first carrier-up NIC). NIC bonding
#                           is NOT done during the install; when 'enable_nic_bonding' is true the playbook builds
#                           an active-backup 'team0' bond AFTER the install, over SSH (the HVM model), so a bond
#                           can never stall Anaconda's network-repo fetch on non-LAG switch fabrics.
#   3. System settings    - firewall (ssh), reboot after install, keyboard/language, root password (crypted),
#                           sha512 shadow passwords, first-boot setup agent, no X, chronyd time sync (timezone/NTP).
#   4. Storage (%pre)     - identifies the OS boot disk by controller type ('Controller_type') and the COM-detected
#                           size ('boot_drive_bytes_size'), then writes /tmp/storage.ks with 'ignoredisk --only-use' +
#                           'clearpart' + 'autopart --type=lvm' pinned to that disk (falls back to 'sda').
#   5. Bootloader/packages - kernel append line, base package set, and emergency kdump.
#   6. Post nochroot (%post) - copies the bundled HPE RPMs (incl. AMS) from the media to /root/rpms, configures the
#                           BaseOS/AppStream + EPEL yum repos, and sets the hostname. When 'proxy_url' is set, routes
#                           external access (EPEL) through the corporate proxy and persists it for dnf/yum (internal
#                           repos + local domain bypass it).
#   7. Post (%post)       - installs the bundled RPMs (HPE AMS, etc.) offline and authorizes the Ansible control
#                           node SSH public key so the post-install play can connect over SSH.
# ---------------------------------------------------------------------------------------------------------------------


# Installation mode
text
# graphical


# To be used with DVD ISO (named rhel-xxx-dvd.iso)
# (contains the installer as well as a set of all packages)
# cdrom

# To be used with Boot ISO (named rhel-xxx-boot.iso)
# (contains only the installer, but not any installable packages)
url --url={{RHEL_repo_url}} --noverifyssl
# repo --name=BaseOS --baseurl={{RHEL_repo_url}}/BaseOS --noverifyssl
# repo --name=AppStream  --baseurl={{RHEL_repo_url}}/AppStream  --noverifyssl


# Network configuration 
%include /tmp/network.ks
 
%pre --interpreter=/usr/bin/bash --log=/tmp/kickstart_network_configuration.log

echo "Network configuration: /tmp/network.ks or /var/log/network.ks"

# --- SINGLE-NIC install (matches the HVM provisioning model) ------------------------------------------------
# The OS install ALWAYS runs over a single management NIC, even when NIC bonding is requested. Bonding is
# created AFTER the install (on the running system, by the playbook over SSH). Installing over a single NIC
# avoids a 2-port active-backup bond stalling Anaconda's early network-repo fetch on switch fabrics without
# a LAG (a link-up-but-wrong port silently black-holes the bond, which then fails "Error setting up software
# source"). We pick the primary NIC by its MAC address (derived from the COM inventory, so it is
# generation-independent). If no MAC was provided, we fall back to the first carrier-up interface.

PRIMARY_MAC="{{ primary_nic_mac | default('') | lower }}"
DEV=""

if [ -n "$PRIMARY_MAC" ]; then
    # Find the interface whose permanent/current MAC matches the COM-derived primary MAC.
    for n in $(ls /sys/class/net | grep -v '^lo$'); do
        m=$(cat /sys/class/net/$n/address 2>/dev/null | tr 'A-Z' 'a-z')
        if [ "$m" == "$PRIMARY_MAC" ]; then DEV="$n"; break; fi
    done
    echo "Primary NIC MAC '$PRIMARY_MAC' -> device '${DEV:-<not found>}'"
fi

if [ -z "$DEV" ]; then
    # Fallback: first interface reporting carrier/up (skips NO-CARRIER ports).
    DEV=$(ip -o link show up 2>/dev/null | awk -F': ' '$2 != "lo" {print $2}' | head -n 1)
    # Last-resort fallback: first "state up" from ip addr (legacy behaviour).
    [ -z "$DEV" ] && DEV=$(ip addr | grep -m 1 -i "state up" | awk '{ print $2 }' | sed 's/://')
    echo "Falling back to first carrier-up NIC: '${DEV}'"
fi

echo "Network device selected for install: '$DEV'"
echo "network --bootproto=static --ip={{os_ip_address}} --activate --onboot yes --noipv6 --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --device=$DEV" >/tmp/network.ks

echo "Command set: $(</tmp/network.ks)" 
%end

# Firewall configuration
firewall --enabled --service ssh

# Reboot after installation
reboot

# Keyboard layouts
keyboard --xlayouts={{keyboard}}

# System language
lang {{language}}

# Installation logging level
# logging --level=info

# Root password 
rootpw --iscrypted {{hashed_root_password}}

# System authorization information
authselect --enableshadow --passalgo=sha512

# SELinux configuration
# The default SELinux policy is enforcing

# Run the Setup Agent on first boot
firstboot --enable

# Do not configure the X Window System
skipx

# System services - Enable time synchronisation daemon 
services --enabled="chronyd"

# System timezone
timezone --utc {{timezone}} 
timesource --ntp-server {{ntp_server}} 


# Storage configuration - Drive selection and partitionning using drive size and storage controller type
%include /tmp/storage.ks

%pre --interpreter=/usr/bin/bash --log=/tmp/kickstart_storage_configuration.log

echo "Storage configuration: /tmp/storage.ks or /var/log/storage.ks"

# Finding boot volume for the OS installation
SIZEinBytes={{boot_drive_bytes_size}}

CONTROLLER="{{Controller_type}}"


if echo "$CONTROLLER" | grep -q "NS204i"; then
    echo "The controller is a 'NS204i'"
    INDEX="nvme"
fi

if echo "$CONTROLLER" | grep -q "SR"; then
    echo "The controller is a 'SR controller'"
    INDEX="sd"

fi 

if echo "$CONTROLLER" | grep -q "MR"; then
    echo "The controller is a 'MR controller'"
    INDEX="sd"
fi 

# Handle the case when local disks are used (no controller string matches)
if [ -z "$INDEX" ]; then
    echo "No known controller detected, assuming local disks (e.g., sda, nvme0n1)"
    # Try to detect if nvme or sd disks are present
    if lsblk -dno NAME | grep -q "^nvme"; then
        INDEX="nvme"
    else
        INDEX="sd"
    fi
fi

# if SIZEinBytes exists then run the disk detection process
if [ "$SIZEinBytes" != "0" ]; then 

    echo "Detecting boot drive for OS installation..."

    # Get the first disk from the disk list with the size defined:
    BOOTDRIVE=`lsblk -dbo NAME,SIZE | grep "^$INDEX" | awk '$2 == "'"$SIZEinBytes"'" {print $1}' | head -n 1` # => usually returns sdb or nvme0n1 

    if [ -z "$BOOTDRIVE" ]
    then
        echo "ERROR: BOOTDRIVE is undefined"
    else
        echo "BOOTDRIVE detected is $BOOTDRIVE"
        cat << EOF > /tmp/storage.ks
        zerombr
        ignoredisk --only-use=$BOOTDRIVE
        clearpart  --all --initlabel --drives=$BOOTDRIVE
        autopart --type=lvm
EOF
    fi

# if SIZE does not exist then use sda disk for the OS installation
else
    echo "BOOTDRIVE detected is sda"
    
    cat << EOF > /tmp/storage.ks
    zerombr
    ignoredisk --only-use=sda
    clearpart  --all --initlabel --drives=sda
    autopart --type=lvm
EOF
fi  

%end

# bootloader --append="rhgb novga console=ttyS0,115200 console=tty0 panic=1" --location=mbr --boot-drive=$BOOTDRIVE
bootloader --append="rhgb quiet crashkernel=auto"

%packages
yum-utils
tar
nano
glibc-langpack-en
glibc-minimal-langpack
bash-completion
bind-utils
# @^Virtualization Host
# @system-tools
# kexec-tools
# curl
%end



# ENABLE EMERGENCY KERNEL DUMPS FOR DEBUGGING
%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

###############################################################################
# Post-Installation Scripts (nochroot)
###############################################################################

%post --nochroot --log=/mnt/sysimage/var/log/kickstart_post_nochroot.log
#!/bin/bash

echo "Post configuration in nochroot"

{% if proxy_url is defined and (proxy_url | length) > 0 %}
# --- Corporate proxy -------------------------------------------------------------------------------
# Route EXTERNAL package access (e.g. the EPEL release rpm from dl.fedoraproject.org) through the
# corporate proxy during %post, and persist it for dnf/yum on the installed system. Internal traffic
# (the RHEL repo and the local '{{ domain }}' domain) BYPASSES the proxy (see 'proxy=_none_' on the
# internal repos below and 'no_proxy' here).
export http_proxy="{{ proxy_url }}"
export https_proxy="{{ proxy_url }}"
export no_proxy="localhost,127.0.0.1,{{ domain }}"
echo 'proxy={{ proxy_url }}' >> /mnt/sysimage/etc/dnf/dnf.conf
{% endif %}

# Create Directory
mkdir -p /mnt/sysimage/root/rpms

# Copy RPMs from Install media to root
cp /run/install/repo/rpms/*rpm /mnt/sysimage/root/rpms/


echo "Copying %pre stage log files in /var/log folder"
/usr/bin/cp -rv /tmp/*.* /mnt/sysimage/var/log/
echo "=============================="
echo "Currently mounted partitions"
df -Th

# Set up the yum repositories for RHEL.
echo "Adding repos BaseOS and AppStream from web server"

configure_yum_repos()
{
# Enable internal RHEL repos (BaseOS + Appstream).
    cat >> /mnt/sysimage/etc/yum.repos.d/rhel_web_repo.repo << EOF
[RHEL-9.2_baseos]
name=RHEL-9.2_baseos
baseurl={{RHEL_repo_url}}/BaseOS
enabled=1
gpgcheck=1
gpgkey={{RHEL_repo_url}}/RPM-GPG-KEY-redhat-release
sslverify=0
{% if proxy_url is defined and (proxy_url | length) > 0 %}
proxy=_none_
{% endif %}

[RHEL-9.2_appstream]
name=RHEL-9.2_appstream
baseurl={{RHEL_repo_url}}/AppStream
enabled=1
gpgcheck=1
gpgkey={{RHEL_repo_url}}/RPM-GPG-KEY-redhat-release
sslverify=0
{% if proxy_url is defined and (proxy_url | length) > 0 %}
proxy=_none_
{% endif %}
EOF

# Enable the EPEL
rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

}

configure_yum_repos

echo "Renaming host"
hostnamectl set-hostname {{inventory_hostname}}.{{domain}}
hostnamectl --pretty set-hostname {{inventory_hostname}}
cp /etc/hostname /mnt/sysimage/etc/hostname
cp /etc/machine-info /mnt/sysimage/etc/machine-info

%end

###############################################################################
# Post-Installation Scripts
###############################################################################

%post --interpreter=/bin/bash --log=/var/log/kickstart_post.log
#!/bin/bash

# Install all RPMs available in /rpms
yum localinstall -y /root/rpms/*.rpm

# Add Ansible SSH public key to authorized_keys
echo "Installing Ansible SSH public key"
mkdir -m0700 /root/.ssh/
cat <<EOF >/root/.ssh/authorized_keys
{{ansible_ssh_public_key}}
EOF
chmod 0600 /root/.ssh/authorized_keys
%end
