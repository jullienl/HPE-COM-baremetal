# Requirements for the control node running Ansible on Rocky Linux 9.2


## Update the System

Ensure that all packages are up to date with the latest security patches and bug fixes.

```
sudo dnf update -y
```


## Set hostname

To ensure proper functionality of the Ansible playbooks, it is important to use a Fully Qualified Domain Name (FQDN) hostname for the control node running Ansible.

```
sudo hostnamectl set-hostname <hostname>.<your-domain>
```


## Clone the Github repository

```
sudo dnf install git
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
sudo dnf install epel-release
sudo dnf install mkisofs

# isoinfo (used for RHEL only)
sudo dnf install genisoimage

# isohybrid (used for RHEL only)
sudo dnf install syslinux

# implantisomd5 (used for RHEL only)
sudo dnf install isomd5sum
```


## Ansible installation and requirements

```
sudo dnf install python3-pip
pip3 install setuptools-rust wheel
pip3 install ansible-core
```


## Installation of Ansible lint (optional, useful to identify problems in playbooks)

```
pip install ansible-lint
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


## Ngnix web service

Ngnix is used to host the custom OS ISO images that will be generated, and from which provisioned servers will boot from.

```
sudo dnf install nginx
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
sudo dnf install unzip 
```


## Wimlib (used for Windows provisioning only)

Wimlib is used to inject scripts into the WinPE image.

```
sudo dnf install wimlib-utils
```



## Rsync

rsync is used to copy ISO image files.

```
sudo dnf install rsync
```