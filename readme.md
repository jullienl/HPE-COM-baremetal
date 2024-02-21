# Automatic bare metal provisioning with HPE Compute Ops Management and Ansible

Automatic bare metal provisioning refers to the process of automatically deploying and configuring physical servers or bare metal machines using automated tools such as Ansible in this project.

The goal is to enable quick and easy provisioning of servers managed by HPE Compute Ops Management and enable the long list of benefits of automatic bare metal provisioning.

In this project, automating the provisioning of operating systems on bare metal servers is made simple and accessible to anyone with basic knowledge of Ansible, HPE Compute Ops Management, and kickstart techniques. While it is generally a complex process that requires a wide range of skills, this project simplifies it with the use of auto-customized kickstarts, auto-generated ISO files and by exploiting the very interesting functions of HPE Compute Ops Management server groups.

One of the benefits of Ansible is parallel execution that allows the simultaneous execution of tasks on multiple hosts. In other words, with one playbook execution, you can provision a customized OS on multiple servers (5 by default). This can significantly speed up the execution time of playbooks, especially when managing large environments with a large number of hosts. Parallel execution enables faster infrastructure provisioning, configuration management, and application deployment across multiple hosts, improving overall efficiency and reducing the time required for administrative tasks.


## Main benefits

Here are some benefits of automatic bare metal provisioning:

- **Time-saving**: Automating the provisioning process eliminates the need for manual, repetitive tasks involved in setting up and configuring servers. This saves considerable time and effort, enabling teams to focus on more strategic and value-added activities.

- **Consistency**: With automatic bare metal provisioning, server configurations are standardized and consistent across the infrastructure. This reduces the chance of human error and ensures that all servers adhere to a predefined configuration, leading to improved stability and reliability.

- **Efficiency**: Automated provisioning allows for faster and more efficient deployment of bare metal machines. It streamlines the process by eliminating manual intervention and reducing the potential for errors. This results in quicker turnaround times, enabling teams to respond rapidly to changing business needs.

- **Scalability**: Automatic bare metal provisioning provides the ability to scale up or down the infrastructure as required. By automating the deployment of new servers, organizations can easily add or remove resources based on demand, ensuring optimal performance and resource utilization.

- **Standardization**: Automated provisioning enables organizations to enforce standardized practices and configurations across different environments. This promotes consistency and simplifies troubleshooting and maintenance, as all servers are provisioned using the same set of tools and configurations.

- **Reduced costs**: By automating the provisioning process, organizations can reduce operational costs associated with manual provisioning. It eliminates the need for manual labor, minimizes human error, and reduces the time required for server setup, resulting in cost savings over time.

- **Integration with DevOps practices**: Automated bare metal provisioning integrates well with other DevOps practices, such as infrastructure as code (IaC) and configuration management. It enables organizations to manage infrastructure as code, version control server configurations, and easily replicate environments, thus facilitating collaboration and improving overall agility.


## Demo videos

For a concise understanding of the possibilities offered by this bare metal provisioning project with HPE Compute Ops Management and Ansible, you can watch the following videos:

**Efficient Bare Metal Provisioning for Windows Server with HPE Compute Ops Management and Ansible**:  

[![Efficient Bare Metal Provisioning for Windows Server with HPE Compute Ops Management and Ansible](https://img.youtube.com/vi/A6RD6nIAFmw/0.jpg)](https://www.youtube.com/watch?v=A6RD6nIAFmw)


**Efficient Bare Metal Provisioning for RHEL 9.3 with HPE Compute Ops Management and Ansible**: 

[![Efficient Bare Metal Provisioning for RHEL 9.3 with HPE Compute Ops Management and Ansible](https://img.youtube.com/vi/6_o8yB4cvag/0.jpg)](https://www.youtube.com/watch?v=6_o8yB4cvag)


**Efficient Bare Metal Provisioning for ESXi with HPE Compute Ops Management and Ansible**: 

[![Efficient Bare Metal Provisioning for ESXi with HPE Compute Ops Management and Ansible](https://img.youtube.com/vi/_ySgROdd_Bw/0.jpg)](https://www.youtube.com/watch?v=_ySgROdd_Bw)


## Supported operating systems

For automating the provisioning of operating systems, three main playbooks are available, one for each type of operating system:
- VMware ESXi 7 and 8
- Red Hat Enterprise Linux and equivalent 
- Windows Server 2022 and equivalent

> **Note**: UEFI secure boot is not supported but can be enabled at a later date once the operating system has been installed.

> **Note**: iLO Security in FIPS or CAC mode is not supported.

## Supported storage configuration

The operating system boot volume is only supported when configured with internal local storage using either an HPE NS204i-x NVMe Boot Controller or HPE MegaRAID (MR) or SmartRaid (SR) Storage Controller.

 > **Note**: Internal storage policies are used to create the RAID configuration for the OS volume. This requires storage controllers with firmware that support DMTF Redfish storage APIs. Refer to the [storage controller firmware requirements](https://internal.support.hpe.com/hpesc/docDisplay?docId=a00115739en_us&docLocale=en_US&page=GUID-91880D5C-C0CD-421F-B5E7-C474CD9BA017.html) (access requires authentication with your HPE GreenLake account)

Booting from a SAN (Storage Area Network) is currently not supported by this project.

### Storage Controller selection 

To avoid data loss or other issues, the playbooks include some logic to ensure that the target disk for OS installation is correctly identified. To do this, the size of the volume detected by Compute Ops Management and presented by the internal local storage (NS204i or MR or SR controller) is used to make this selection. In addition, when multiple controllers are detected, disk selection is determined by the following conditions:

1. If an HPE NS204i-x NVMe Boot Controller is detected, the automatic RAID1 volume associated with it will be used for installing the OS.
2. If there is no HPE NS204i-x NVMe Boot Controller found, the first available HPE MegaRAID (MR) or SmartRaid (SR) Storage Controller with disks will be utilized for the OS installation.


### OS boot volume RAID type and size

- When an HPE NS204i-x NVMe Boot Controller is used, a mirror (RAID1) between the two NVMe drives is by design automatically created and the whole disk is used to create the operating system volume. In this case, the playbooks in this project simply skip the task of creating the operating system boot volume, as it is automatically managed by the NS204i. 

- With MR/SR Storage controller, the creation of the operating system boot volume is managed by the playbooks of this project and in this case, you can define the volume settings in the OS variable file located in /vars using:
  - `raid_type`: Defines the RAID level (RAID0, RAID1 or RAID5) 
  - `volume_size_in_GB`: Defines the OS volume size. It must be a number greater than 0 or equal to -1 to indicate that the entire disk should be used.

During the installation process, it is possible to present SAN volumes to the servers (such as vmfs datastore volumes/cluster volumes, etc.), as the installation process looks for the internal logical drive to install the operating system, and will not install the OS, nor destroy the data on the presented SAN volumes.

### Network configuration

- For ESXi, the network configuration during the OS installation starts by using the first available nic (vmnic0). Once the OS is installed, additional tasks take place to add the second nic (vmnic1) to the standard vSwitch0.

- For RHEL, the kickstart file plays a crucial role during OS installation. It contains a script that is executed during the installation process. The configuration for NIC bonding is controlled by the `enable_nic_bonding` variable, which can be found in `vars/<Linux_OS>_vars.yml`.

- For Windows Server, a `Post_installation_script.ps1` script located in `c:\Windows\Setup\Scripts` is executed when the OS installation is complete. This PowerShell script among other things, sets IP parameters and NIC teaming. The configuration for NIC teaming is controlled by the `enable_nic_bonding` variable, which can be found in `group_vars/<WINxxxx>/Windows_vars.yml`.

With Linux and Windows:
  - When `enable_nic_bonding` is set to `true`, NIC teaming will be established using the first two connected NICs. However, if only one NIC is connected, the bond will be created with just that single NIC.

  - When `enable_nic_bonding` is set to `false`, no NIC teaming will be created. In this case, the network settings will be configured on the first connected NIC that is detected.

## Process flow

The following diagrams describe the overall process flows:

**RHEL Provisioning**:  

![image](https://github.com/jullienl/HPE-COM-baremetal/assets/13134334/0cf77db0-dc3a-4fa7-a82b-2734e25a2dd9)
 
**Windows Server Provisioning**:  
 
![image](https://github.com/jullienl/HPE-COM-baremetal/assets/13134334/a7c2d4e5-c564-455a-b784-ba05de4a13b8)
 
**RHEL and Windows Server Unprovisioning**:   
 
![image](https://github.com/jullienl/HPE-COM-baremetal/assets/13134334/4b53cb2e-57d4-48f4-a912-7dd577b363ea)
 
**ESXi Provisioning**:   
  
![image](https://github.com/jullienl/HPE-COM-baremetal/assets/13134334/9a31b6f4-2583-4688-a828-a468619ef221)
   
**ESXi Unprovisioning**:   
   
![image](https://github.com/jullienl/HPE-COM-baremetal/assets/13134334/20234a57-95c1-4563-b399-b16ef2f259c1)


## Prerequisites

- An Ansible control node running Ansible:
  - Meets Ansible system requirements, see https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform/2.3/html/red_hat_ansible_automation_platform_planning_guide/platform-system-requirements#ref-controller-system-requirements
  - With internet connectivity to interface with the HPE GreenLake platform and must also be connected to the management network where the servers will be deployed.
  - With a storage volume large enough to host a copy of the ISO files, and the temporary extraction of an ISO and the new generated ISO with the customized kickstart for each server being provisioned 

    > **Note**: 1TB+ is recommended if you plan to provision several servers in parallel. 

  - At the right date and time to support the various time-dependent playbook operations. 

- A web server containing ISO images of the various operating systems to be provisioned. For Windows provisioning, a custom WinPE image must be created and supplied. See below for more details.

- For Linux provisioning, a network location (http/https) containing an installation source for each Linux version to be provisioned. 

  > **Note**: The installation source URL which points to the extracted contents of the DVD ISO image is defined by the variable `<OS>_repo_url` in `<OS>_vars.yml` in the `vars` folder. 

  > **Note**: To reduce the process of creating Red Hat (and community Enterprise Linux: CentOS, Alma Linux, Rocky Linux) customized ISO images, this project uses BOOT ISO images (~700MB) instead of traditional DVD ISOs (~8GB). The BOOT ISO does not contain any installable packages. It is therefore necessary to set up an installation source that stores a copy of the DVD ISO image contents, so that the BOOT ISO image installer can access the software packages and start the installation.

  > **Note**: To learn how to prepare an installation source using HTTP/HTTPS, see [Creating an installation source using HTTP or HTTPS](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_a_standard_rhel_8_installation/prepare-installation-source_installing-rhel#creating-an-installation-source-on-http_prepare-installation-source)

- For Windows provisioning, a network location containing the Windows Server ISO image must be provided as an UNC path (\\server\share).

  > **Note**: The network location which points to the DVD ISO image is defined by the variable `src_iso_network_share` in `Windows_vars.yml` in the `group_vars` folder. The `src_iso_file_path` defines the Windows Server ISO image location in the network share.
  
- HPE Compute Ops Management API Client Credentials with the Compute Ops Management Administrator role.

  > **Note**: To learn more about how to set up the API client credentials, see [Configuring API client credentials](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-23E6EE78-AAB7-472C-8D16-7169938BE628.html) 

  > **Note**: There is no need for any predefined server groups or server settings in HPE Compute Ops Management. Each playbook is written to handle the creation of temporary server groups and server settings for the server BIOS, storage, and operating system configuration.

- All HPE servers to be provisioned must be onboarded to the HPE GreenLake platform and their iLO must be correctly configured (with an IP address and connected to the cloud platform). 

  > **Note**: To utilize the servers in HPE Compute Ops Management, certain steps need to be followed. Each server should be onboarded to the HPE GreenLake platform, properly licensed, and assigned to the COM application instance. Additionally, it is important to ensure that the iLO of each server is connected to the HPE GreenLake platform. To learn more, see [Configuring Compute Ops Management direct management](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00001293en_us&page=GUID-8F12FE6C-DC13-44DC-921B-041E8DC628DB.html)

- The Ansible inventory files for each operating system (i.e. [hosts_ESX](https://github.com/jullienl/HPE-COM-baremetal/blob/main/hosts_ESX)) must be updated. Each server should be listed in the corresponding inventory file along with its serial number and the IP address that should be assigned to the operating system.

- A Windows DNS server configured to be managed by Ansible. See below for more details.

  > **Note**: To ensure the smooth operation of this project, it is essential that a DNS record exists for each provisioned server. For this reason, each playbook includes a task to create a DNS record on the Windows DNS server defined in `vars` folder. 

  > **Note**: For this project, I'm using a Windows DNS server because my lab is managed by Microsoft Active Directory. If you want to use a Linux DNS server instead, you will need to modify the "Creating a DNS record for the bare metal server" task in each playbook to be compatible with a Unix-like operating systems. You can use the [community.general.nsupdate](https://docs.ansible.com/ansible/latest/collections/community/general/nsupdate_module.html) module to perform dynamic DNS updates when using a Linux DNS server.

  > **Note**: If in your environment, DNS records for servers to be provisioned are created in advance, you can remove the "Create DNS record for bare metal server" task from the playbooks.

- For Windows server provisioning, a custom WinPE image is required.

  > **Note**: When using a Windows Server ISO for installation, you cannot execute a script prior to the initiation of the setup process. Additionally, PowerShell is inaccessible during the Panther phase of the installation. Although you can trigger a script execution via the unattend file, this approach does not support the dynamic use of variables to populate other sections within the unattend file for particular requirements, such as specifying the disk on which to install. Therefore, the only viable method to pre-configure the unattend file with the appropriate target disk information is by utilizing Windows Preinstallation Environment (WinPE) to run the necessary PowerShell commands.

  > **Note**: To create the WinPE image needed to provision the Windows host, refer to [WinPE_image_creation.md](https://github.com/jullienl/HPE-COM-baremetal/blob/main/files/WinPE_image_creation.md) in the `files` folder.

> **Note**: This project utilizes the HPE iLO virtual media feature to mount ISO files for operating system installation. The capability known as "script/URL-based virtual media" is unique to the HPE iLO Advanced license. However, this specific license is not necessary when you are using HPE Compute Ops Management.


## Ansible control node information

- It runs Ansible
- It can be a physical server or a Virtual Machine
- It is used as the temporary destination for the preparation of ISO files.
- It runs `nginx` web services to host the created ISO files from which the bare metal servers will boot from using iLO virtual media.
- It must have enough disk space to host all ISOs and generated ISOs.
- It must be at the right time and date.

### Ansible control node configuration

To configure the Ansible control node, see [Ansible_control_node_requirements.md](https://github.com/jullienl/HPE-COM-baremetal/blob/main/files/Ansible_control_node_requirements.md) in the `files` folder.

By default, Ansible executes tasks on a maximum of 5 hosts in parallel. If you want to increase the parallelism and have the provisioning tasks executed on more hosts simultaneously, you can modify this value directly in the playbooks using the `ansible_forks` variable.

  > **Note**: It's important to note that while parallel execution can significantly improve performance, it also increases resource consumption on the Ansible control machine. Therefore, it's recommended to test and tune the value of `ansible_forks` based on your specific environment to find the optimal balance between performance and resource usage.

## Windows DNS Server configuration

The Windows DNS Server to be managed by Ansible should meet below requirements:
- A WinRM listener should be created and activated. 
- A Windows user with administrative privileges or member of the **Remote Management Users** security group (allows connection to remote Windows DNS server via WinRM)
- A Windows user with administrative privileges or member of the **DNSAdmins** security group (allows DNS records to be updated)

> **Note**: Since Windows Server 2012, WinRM is enabled by default.

> **Note**: Find out more about how Ansible manages Microsoft Windows hosts, see [Windows Remote Management](https://docs.ansible.com/ansible/latest/os_guide/windows_winrm.html)


## Preparation to run the playbooks

1. Clone or download this repository on your Ansible control node.   
   
2. Update all variables located in `vars` and `group_vars` folders.

   > `group_vars` is a feature in Ansible that allows you to define variables that will be applied to groups of hosts. For instance, `group_vars/WIN2022` folder is specifically used for setting variables applicable to the Windows hosts that are part of the [WIN2022] group defined in the inventory file (i.e. `hosts`). So, it's essential to retain the name of the `WIN2022` folder so that Ansible can correctly associate the variables within this folder with the hosts in the [WIN2022] group. When Ansible runs, it will look for a directory matching the group name inside `group_vars` and apply any variables it finds there to the hosts in that group.

   > For ESXi and RHEL variables, the root password is hashed in the kickstart using the variable `hashed_root_password` to maintain the confidentiality of the root password. See the kickstart files for more information on how to hash your password from the Ansible control node.

3. For ESXi and Linux, copy the operating system ISOs to a web server as defined in the variables `src_iso_url` and `src_iso_file`. For Windows, copy the WinPE image you created as described in [WinPE_image_creation.md](https://github.com/jullienl/HPE-COM-baremetal/blob/main/files/WinPE_image_creation.md) onto the web server and as defined in the variables `winpe_iso_url` and `winpe_iso_file`.

4. Secure your HPE Compute Ops Management credentials, using Ansible vault to encrypt them. From the root of this Ansible project on the Ansible control node, run:   
    ```
    ansible-vault create vars/GLP_COM_API_credentials_encrypted.yml
    ```   
    Once the password is entered, type the following content using your own API client credentials and connectivity endpoint:
     ```
     ---
     ClientID: "xxxxxxxx-xxxx-xxx-xxx-xxxxxxxxx"
     ClientSecret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
     ConnectivityEndpoint: "https://<connectivity_endpoint>-api.compute.cloud.hpe.com"
     ```
    
    > **Note**: The `GLP_COM_API_credentials_clear.yml` file illustrates the contents of the encrypted file to be supplied.

    > **Note**: To learn more, see [Protecting sensitive data with Ansible vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
    
    > **Note**: To access the HPE Compute Ops Management API, you need to create your client credentials on the HPE GreenLake platform, see [Configuring API client credentials](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-23E6EE78-AAB7-472C-8D16-7169938BE628.html) 

5. Secure your VMware vCenter credentials using:   
    ```
    ansible-vault create vars/VMware_vCenter_vars_encrypted.yml
    ```   
    And copy/paste the content of `vars/VMware_vCenter_vars_clear.yml` example in the editor using your data.

6. Secure your Windows DNS credentials, using:   
    ```
    ansible-vault create vars/Windows_DNS_vars_encrypted.yml
    ```   
    And copy/paste the content of `vars/Windows_DNS_vars_clear.yml` example in the editor using your data.

7. Secure your sensitive variables for the Windows hosts in the `group_vars/WIN2022`, using:   
    ```
    ansible-vault create group_vars/WIN2022/Windows_sensitive_vars_encrypted.yml
    ```   
    And copy/paste the content of `group_vars/WIN2022/Windows_sensitive_vars_clear.yml` example in the editor using your data.
    

8. Update the different Ansible inventory files (`hosts_ESX`, `hosts_RHEL` and `hosts_WIN`) with the list of servers to provision. 

   Each server should be listed using a hostname in the corresponding inventory group along with its serial number and the IP address that should be assigned to the operating system.
   
   You can use the inventory files as examples, such as `hosts_ESX`:
      ```
      localhost ansible_python_interpreter=/usr/bin/python3 ansible_connection=local 

      [All:vars]
      ansible_ssh_common_args='-o StrictHostKeyChecking=no'

      [All]
      ESX-1 os_ip_address=192.168.3.174 serial_number=CZ2311004H            
      ESX-2 os_ip_address=192.168.3.175 serial_number=CZ2311004G            

      ```

   For Windows, it is necessary to use the group named [WIN2022] for WinRM to function correctly, as illustrated in `hosts_WIN` :
      ```
      localhost ansible_python_interpreter=/usr/bin/python3 ansible_connection=local 

      [WIN2022:vars]
      ansible_ssh_common_args='-o StrictHostKeyChecking=no'

      [WIN2022]
      WIN-1 os_ip_address=192.168.3.178 serial_number=CZ2311004H       # DL360 Gen10 Plus (MR active - NS204i disabled)     [iLO: 192.168.0.20]
      WIN-2 os_ip_address=192.168.3.179 serial_number=CZ2311004G       # DL360 Gen10 Plus (MR disabled - NS204i active)     [iLO: 192.168.0.21]

      ```

    > **Note**: This list must be built using the hostname, not the FQDN. FQDNs are defined in playbooks using the `domain` variable defined in the variable files. 
    
    > **Note**: Groups are defined by [...] like [All] and [WIN2022] in the examples above. These groups define the list of hosts that will be provisioned using the `<ESXi|RHEL|WIN>_provisioning.yml>` playbooks. All hosts defined in the group will be provisioned in parallel by Ansible when the playbook is executed.


## How to run a playbook

A single command is required to provision all hosts listed in an inventory file: 
```
ansible-playbook <provisioning_file>.yml -i <inventory_file> --ask-vault-pass --ask-become-pass
```


Where `<provisioning_file>` should be replaced with `ESXi80_provisioning`, `RHEL_provisioning`, or `WIN_provisioning` depending on the target operating system. Similarly, replace `<inventory_file>` with the appropriate inventory filename such as `hosts_ESXi`, `hosts_RHEL`, or `hosts_WIN`.

Upon running this command, Ansible will prompt you to enter the vault password and the sudo password to proceed with the provisioning process.
  
For example, running `ansible-playbook ESXi80_provisioning.yml -i hosts_ESX --ask-vault-pass --ask-become-pass` will provision all servers listed in `hosts_ESX` in the [All] inventory group, i.e. ESX-1 and ESX-2.


## Provisioning playbook output samples 

Output samples generated by the provisioning playbooks can be found in `files/output_samples`

## Unrovisioning playbook output samples 

Output samples generated by the unprovisioning playbooks can be found in `files/output_samples`

## Built and tested with

The resources in this repository have been tested with Ansible control node running on a Rocky Linux 9.2 VM with:
  - Ansible core 2.15.4
  - Python 3.9.16
  - Community.general 3.8.0
  - Community.windows 1.7.0
  - Community.vmware 1.15.0

The provisioned OS tested successfully are:
  - VMware-ESXi-7.0.3-21930508-HPE-703.0.0.11.4.0.5-Sep2023.iso
  - VMware-ESXi-8.0.2-22380479-HPE-802.0.0.11.4.0.14-Sep2023.iso
  - rhel-9.3-x86_64-boot.iso
  - Windows Server 2022 using a custom WinPE image.


## License

This project is licensed under the MIT License - see the LICENSE file for details.
