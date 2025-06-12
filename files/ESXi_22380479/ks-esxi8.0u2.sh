vmaccepteula

rootpw --iscrypted {{hashed_root_password}}

%include /tmp/DiskConfig


# Network configuration 

network --device=vmnic0 --bootproto=static --addvmportgroup=1 --ip={{os_ip_address}} --netmask={{netmask}} --gateway={{gateway}} --nameserver={{nameserver}} --hostname={{inventory_hostname}}   
reboot   

%pre --interpreter=busybox 

# Redirect output to a log file 
LOGFILE="/tmp/Pre_install.log"

echo "Starting pre-installation script" > "${LOGFILE}" 2>&1

# Storage configuration - Drive selection and clearing existing partitions using drive size and storage controller type

# Finding boot volume for the OS installation
# Using minimum size difference between the server resource size and the list of disks to identify the correct one
SIZEinBytes={{boot_drive_bytes_size}}
CONTROLLER="{{Controller_type}}"

echo "CONTROLLER=$CONTROLLER" >> "${LOGFILE}" 2>&1

if echo "$CONTROLLER" | grep -q "NS204i"; then
    # echo "The controller is an 'NS204i'" >> "${LOGFILE}" 2>&1
    INDEX="t*"  # an NVMe or SATA disk is detected as t10.nvme or t10.ATA vmfs disk by ESXi
fi

if echo "$CONTROLLER" | grep -q "SR"; then
    # echo "The controller is an 'SR controller'" >> "${LOGFILE}" 2>&1
    INDEX="n*"
fi 

if echo "$CONTROLLER" | grep -q "MR"; then
    # echo "The controller is an 'MR controller'" >> "${LOGFILE}" 2>&1
    INDEX="n*"
fi 


# if SIZEinBytes exists then run the disk detection process
if [ "$SIZEinBytes" != "0" ]; then 

        echo "INDEX=$INDEX" >> "${LOGFILE}" 2>&1

        echo "SIZEinBytes=$SIZEinBytes" >> "${LOGFILE}" 2>&1

        SIZEinGigaBytes=$(($SIZEinBytes >> 30))

        echo "SIZEinGB=$SIZEinGigaBytes" >> "${LOGFILE}" 2>&1

        # Minimum delta between COM value and volume found in bytes
        MINDELTA=1000000  # 1MB
        DRIVESIZE=""

        for DISK in $(ls /vmfs/devices/disks/$INDEX | grep -v ":"); do
            echo "" >> "${LOGFILE}" 2>&1
            VML=$(echo $DISK | awk '{ print substr ($0, 21 ) }')
            VSIZE=$(localcli storage core device list -d $VML  | sed -n 5p |  awk '{ print substr ($0, 10 ) }')
            echo "VML = $VML" >> "${LOGFILE}" 2>&1
            # echo "VSIZE = $VSIZE" >> "${LOGFILE}" 2>&1

            VSIZEinBytes=$(($VSIZE * 1024 * 1024))
            echo "VSIZEinBytes = $VSIZEinBytes" >> "${LOGFILE}" 2>&1
            
            # If $VSIZE is not null and not equal to zero
            if [[ -n $VSIZE && $VSIZE -ne 0 ]]; then

                GB=$(($VSIZE/1024))
                echo "VSIZEinGB = $GB" >> "${LOGFILE}" 2>&1

                DELTA=$(( $VSIZEinBytes - $SIZEinBytes ))
                echo "DELTA = $DELTA" >> "${LOGFILE}" 2>&1

                if [[ $DELTA -lt 0 ]]; then
                    echo "" >> "${LOGFILE}" 2>&1
                    DELTA=$((-DELTA))
                    echo "DELTA is less than 0=$DELTA" >> "${LOGFILE}" 2>&1
                fi

                if [[ $DELTA -lt $MINDELTA ]]; then
                    MINDELTA=$DELTA
                    echo "DELTA is less than MINDELTA-$MINDELTA" >> "${LOGFILE}" 2>&1
                    TARGET_DISK=$DISK
                    DRIVESIZE=$GB
                fi

                echo "Diff is $DELTA with $VML $GB GB" >> "${LOGFILE}" 2>&1
                echo "Matching Drive: $DRIVESIZE GB" >> "${LOGFILE}" 2>&1
            fi
        done

        echo "Target disk is $TARGET_DISK with $DRIVESIZE GB" >> "${LOGFILE}" 2>&1

        # Clearing partitions on target disk found
        echo "clearpart --drives=$TARGET_DISK --overwritevmfs" >/tmp/DiskConfig

        # Starting the ESXi installation on the target disk found
        echo "install --disk=$TARGET_DISK --overwritevmfs --novmfsondisk" >>/tmp/DiskConfig

else
# if SIZE does not exist then use local disk for the OS installation
    echo "Target disk is local" >> "${LOGFILE}" 2>&1
    echo "clearpart --firstdisk=local --overwritevmfs" >/tmp/DiskConfig
    echo "install --firstdisk=local --overwritevmfs --novmfsondisk" >>/tmp/DiskConfig
fi            

# Error handling: Check if TARGET_DISK was found
if [ -z "$TARGET_DISK" ]; then
    echo "ERROR: No suitable target disk found for installation." >> "${LOGFILE}" 2>&1
    echo "ERROR: No suitable target disk found for installation." > /tmp/disk_detection_error
    # Exit with error code to halt installation
    exit 1
fi




###############################################################################
# Post-Installation Scripts
###############################################################################

%firstboot --interpreter=busybox

# Hostname and domain settings
esxcli system hostname set --host="{{inventory_hostname}}"
esxcli system hostname set --fqdn="{{inventory_hostname}}.{{domain}}"
esxcli network ip dns search add --domain="{{domain}}"
esxcli system time set --day="{{ ansible_date_time.day }}" --month="{{ ansible_date_time.month }}" --year="{{ ansible_date_time.year }}" --hour="{{ ansible_date_time.hour }}" --min="{{ ansible_date_time.minute }}" --sec="{{ ansible_date_time.second }}"

# Adding Ansible control node SSH public key to host authorized_keys 
echo "Installing Ansible SSH public key"
cat <<EOF >/etc/ssh/keys-root/authorized_keys
{{ansible_ssh_public_key}}
EOF
