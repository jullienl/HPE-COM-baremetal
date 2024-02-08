#version=RHEL9.2


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

nicbonding="{{enable_nic_bonding}}"

ip addr | grep -m 2 -i "state up" | awk '{ print $2 }' > /tmp/interface
# Remove colon
sed -i 's/:/\ /g' /tmp/interface
# Merge the lines into a single line separated by a comma then remove spaces
interface=`cat /tmp/interface | paste -sd ',' | tr -d ' '`

if [[ "$nicbonding" == "true" ]]; then
    # With bonding:
    #  Create a team with the first two connected nics if any, 
    #  If only one nic is connected, use only one nic in the team
    echo "Network interfaces found: $interface"
    echo "network --device=team0 --bondslaves=$interface --bootproto=static --ip={{os_ip_address}} --activate --onboot yes --noipv6 --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --bondopts=mode=active-backup" >/tmp/network.ks

else
    # With no bonding:
    #  Take only the first nic found
    firstnic=$(echo "$interface" | cut -d ',' -f1)
    echo "Network interface found: $firstnic"
    echo "network --bootproto=static --ip={{os_ip_address}} --activate --onboot yes --noipv6 --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --device=$firstnic" >/tmp/network.ks
fi

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

[RHEL-9.2_appstream]
name=RHEL-9.2_appstream
baseurl={{RHEL_repo_url}}/AppStream
enabled=1
gpgcheck=1
gpgkey={{RHEL_repo_url}}/RPM-GPG-KEY-redhat-release
sslverify=0
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
