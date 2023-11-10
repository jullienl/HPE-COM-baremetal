vmaccepteula

rootpw --iscrypted {{encrypted_root_password}}

%include /tmp/DiskConfig

network --device=vmnic0 --bootproto=static --addvmportgroup=1 --ip={{os_ip_address}} --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --hostname={{inventory_hostname}}   
reboot   

%pre --interpreter=busybox


# Finding boot volume for the OS installation
# Using minimum size difference between the server resource size and the list of disks to identify the correct one
SIZEinBytes={{boot_drive_bytes_size}}
CONTROLLER="{{Controller_type}}"

if [ "$CONTROLLER" == "NS204i" ]; then
    echo "The controller is a 'NS204i'"
    INDEX="t*"
fi

if [ "$CONTROLLER" == "SR/MR controller" ]; then
    echo "The controller is a 'SR/MR controller'"
    INDEX="n*"
fi

SIZEinGB=$((SIZEinBytes / (1024 * 1024 * 1024)))

MINDELTA=100
DRIVESIZE=""

for DISK in `ls /vmfs/devices/disks/$INDEX | grep -v ":"`; do
    VML=$(echo $DISK | awk '{ print substr ($0, 21 ) }')
    VSIZE=$(localcli storage core device list -d $VML  | sed -n 5p |  awk '{ print substr ($0, 10 ) }')
    # If $VSIZE is not null and not equal to zero
    if [[ -n $VSIZE && $VSIZE -ne 0 ]]; then
        DETAIL=$(esxcli storage core device list -d $VML)
        GB=$(($VSIZE/1024))
        echo "Size = $GB GB"
        DELTA=$(( $GB - $SIZEinGB ))
        if [ "$DELTA" -lt 0 ]; then
            DELTA=$((-DELTA))
        fi
        if [ $DELTA -lt $MINDELTA ]; then
            MINDELTA=$DELTA
            DRIVE=$DISK
            DRIVESIZE=$GB
        fi
        echo "Diff is $DELTA GB with `echo $DEV | awk '{ print substr ($0, 12 ) }'` $GB GB"
        echo "Matching Drive: $DRIVESIZE GB"
    fi
done

echo "BOOTDRIVE is $DRIVE with $DRIVESIZE GB"
echo "clearpart --drives=$DRIVE --overwritevmfs">/tmp/DiskConfig
echo "install --disk=$DRIVE --overwritevmfs --novmfsondisk">>/tmp/DiskConfig
   

%firstboot --interpreter=busybox

# Hostname and domain settings
esxcli system hostname set --host="{{inventory_hostname}}"
esxcli system hostname set --fqdn="{{inventory_hostname}}.{{domain}}"
esxcli network ip dns search add --domain="{{domain}}"

# Adding Ansible control node SSH public key to host authorized_keys 
echo "Installing Ansible SSH public key"
cat <<EOF >/etc/ssh/keys-root/authorized_keys
{{ansible_ssh_public_key}}
EOF
