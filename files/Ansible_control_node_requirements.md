# Requirements for the control node running Ansible on Rocky Linux 9.2

To ensure proper functionality of the Ansible playbooks, it is important to use a Fully Qualified Domain Name (FQDN) hostname for the control node running Ansible.
```
hostnamectl set-hostname <hostname>.<your-domain>
```

## Clone the Github project
```
sudo dnf install git
mkdir ~/Projects
cd ~/Projects
git clone https://github.com/jullienl/HPE-COM-baremetal
```

## openssh installation

openssh should be installed by default.

## Generate an SSH RSA key pair without a passphrase for the Ansible control node
```
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ""
``` 

## ISO creation tools required
```
# isoinfo
sudo dnf install epel-release
sudo dnf install genisoimage
# mkisofs
sudo dnf install mkisofs
# isohybrid
sudo dnf install syslinux
# implantisomd5
sudo dnf install isomd5sum
```

## Ansible installation and requirements
```
sudo dnf install python3-pip
pip3 install setuptools-rust wheel
pip3 install ansible-core
```

## Installation of ksvalidator (optional, useful to validate kickstart file modifications)
```
sudo dnf install pykickstart
```
## Installation of the Ansible Collections used in these playbooks 
``` 
ansible-galaxy collection install -r files/requirements.yml --force 
```
`--force` is required if you need to upgrade the collections to the latest available versions from the Galaxy server. 


## VMware collection requirements
```
pip3 install --upgrade pip setuptools
pip3 install --upgrade git+https://github.com/vmware/vsphere-automation-sdk-python.git
pip3 install -r ~/.ansible/collections/ansible_collections/community/vmware/requirements.txt
pip3 install requests # (Should be already installed)
```

## Windows collection requirements
```
pip3 install pywinrm
```
## Installation of json_query filter used in the playbooks
```
pip3 install jmespath
```

## ngnix web service
ngnix is used to host the OS ISOs from which provisioned servers will boot using iLO virtual media.
```
sudo dnf install nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
``` 

## Enabling ngnix directory browsing
``` 
sudo sed -i '0,/server {/s//&\n        autoindex on;/' /etc/nginx/nginx.conf
sudo systemctl restart nginx
``` 


## unzip

unzip is used to extract HPE Package to get product id information.

```
sudo dnf install unzip #(should be already installed)
```
