# Automatic bare metal provisioning with HPE Compute Ops Management and Ansible

Automatic bare metal provisioning refers to the process of automatically deploying and configuring physical servers or bare metal machines using automated tools such as Ansible in this project.

The goal is to enable quick and easy provisioning of servers managed by HPE Compute Ops Management and enable the long list of benefits of automatic bare metal provisioning.

In this project, automating the provisioning of operating systems on bare metal servers is made simple and accessible to anyone with basic knowledge of Ansible, HPE Compute Ops Management, and kickstart techniques. While it is generally a complex process that requires a wide range of skills, this project simplifies it with the use of auto-customized kickstarts, auto-generated ISO files and by exploiting the very interesting functions of HPE Compute Ops Management server groups.

One of the benefit of Ansible is parallel execution that allows the simultaneous execution of tasks on multiple hosts. In other words, with one playbook execution, you can provision a customized OS on multiple servers (5 by default). This can significantly speed up the execution time of playbooks, especially when managing large environments with a large number of hosts. Parallel execution enables faster infrastructure provisioning, configuration management, and application deployment across multiple hosts, improving overall efficiency and reducing the time required for administrative tasks.


## Main benefits

Here are some benefits of automatic bare metal provisioning:

- **Time-saving**: Automating the provisioning process eliminates the need for manual, repetitive tasks involved in setting up and configuring servers. This saves considerable time and effort, enabling teams to focus on more strategic and value-added activities.

- **Consistency**: With automatic bare metal provisioning, server configurations are standardized and consistent across the infrastructure. This reduces the chance of human error and ensures that all servers adhere to a predefined configuration, leading to improved stability and reliability.

- **Efficiency**: Automated provisioning allows for faster and more efficient deployment of bare metal machines. It streamlines the process by eliminating manual intervention and reducing the potential for errors. This results in quicker turnaround times, enabling teams to respond rapidly to changing business needs.

- **Scalability**: Automatic bare metal provisioning provides the ability to scale up or down the infrastructure as required. By automating the deployment of new servers, organizations can easily add or remove resources based on demand, ensuring optimal performance and resource utilization.

- **Standardization**: Automated provisioning enables organizations to enforce standardized practices and configurations across different environments. This promotes consistency and simplifies troubleshooting and maintenance, as all servers are provisioned using the same set of tools and configurations.

- **Reduced costs**: By automating the provisioning process, organizations can reduce operational costs associated with manual provisioning. It eliminates the need for manual labor, minimizes human error, and reduces the time required for server setup, resulting in cost savings over time.

- **Integration with DevOps practices**: Automated bare metal provisioning integrates well with other DevOps practices, such as infrastructure as code (IaC) and configuration management. It enables organizations to manage infrastructure as code, version control server configurations, and easily replicate environments, thus facilitating collaboration and improving overall agility.


## Supported operating systems

For automating the provisioning of operating systems, three main playbooks are available, one for each type of operating system:
- VMware ESXi 7 and 8
- Red Hat Enterprise Linux and equivalent (soon to come)
- Windows Server 2022 and equivalent (soon to comne)

Note that UEFI secure boot is not supported, but can be enabled at a later date once the operating system has been installed.

## Supported storage configuration

The operating system boot volume is only supported when configured with internal local storage using either an HPE NS204i-x NVMe Boot Controller or HPE MegaRAID (MR) or SmartRaid (SR) Storage Controller.

 > **Note**: Internal storage policies are used to create the RAID configuration for the OS volume. This requires storage controllers with firmware that support DMTF Redfish storage APIs. Refer to the [storage controller firmware requirements](https://internal.support.hpe.com/hpesc/docDisplay?docId=a00115739en_us&docLocale=en_US&page=GUID-91880D5C-C0CD-421F-B5E7-C474CD9BA017.html) 

Booting from a SAN (Storage Area Network) is currently not supported by this project.

### Storage Controller selection: 

During the installation process, the selection of the disk to install the operating system is determined by the following conditions:

1. If an HPE NS204i-x NVMe Boot Controller is detected, the automatic RAID1 volume associated with it will be used for installing the OS.
2. If there is no HPE NS204i-x NVMe Boot Controller found, the first available HPE MegaRAID (MR) or SmartRaid (SR) Storage Controller with disks will be utilized for the OS installation.

### OS boot volume RAID type and size

When an HPE NS204i-x NVMe Boot Controller is used, a mirror between the two NVMe drives is automatically created (RAID1) for the operating system boot volume using the entire disk. 

With MR/SR Storage controller, you can define the operating system boot volume settings in the OS variable file located in /vars:
- RAID level (RAID0, RAID1 or RAID5) using the variable `raid_type`
- The size of volume (a number >0 or -1, where -1 indicates to use the entire disk) using the variable `volume_size_in_GB`

During the installation process, it is possible to present SAN volumes to the servers (such as vmfs datastore volumes/cluster volumes, etc.), as the installation process looks for the internal logical drive to install the operating system, and will under no circumstances install the OS, nor destroy the data on the presented SAN volumes.


## Process flow

The following diagrams describe the overall process flow that is used for ESXi:

**Provisioning**:   

![image](https://github.com/jullienl/HPE-COM-baremetal/assets/13134334/f30c7618-0ac3-486f-804e-73fce2a8df07)


**Unprovsioning**:   

![image](https://github.com/jullienl/HPE-COM-baremetal/assets/13134334/decc72b3-4a79-429d-b888-e98032aa5ef6)


A more detailed process flow is avalable at https://miro.com/app/board/uXjVNZ9eH-w=/?share_link_id=812370641566 



## Pre-requisites

- An Ansible control node running Ansible:
  - With an access to the internet to access the HPE GreenLake platform and to the management network where the servers to be provisioned reside.

  - With a storage volume large enough to host a copy of the ISO files, and the temporary extraction of an ISO and the new generated ISO with the customized kickstart for each server being provisioned 

    > **Note**: 1TB+ is recommended if you plan to provision several servers in parallel. 

  - At the right date and time to support the various time-dependent playbook operations. 

- A web server containing ISO images of the different operating systems to be provisioned. 

- A network location containing an installation source for each Linux version to be provisioned. 

  > To reduce the process of creating Red Hat (and community Enterprise Linux: CentOS, Alma Linux, Rocky Linux) customized ISO images, this projet uses BOOT ISO images (~700MB) instead of traditional DVD ISOs (~8GB). The BOOT ISO does not contain any installable packages. It is therefore necessary to set up an installation source that stores a copy of the DVD ISO image contents, so that the BOOT ISO image installer can access the software packages and start the installation.

  > To learn how to prepare an installation source using HTTP/HTTPS, see [Creating an installation source using HTTP or HTTPS](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_a_standard_rhel_8_installation/prepare-installation-source_installing-rhel#creating-an-installation-source-on-http_prepare-installation-source)

  > The installation source URL which points to the extracted contents of the DVD ISO image is defined by the variable `<OS>_repo_url` in /vars.  
  

- HPE Compute Ops Management API Client Credentials with the Compute Ops Management Administrator role.

  > **Note**: To learn more about how to set up the API client credentials, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us 

  > **Note**: There is no need for a predefined server group in HPE Compute Ops Management. Each playbook is designed to handle the creation of a temporary server group, specifically for server BIOS, storage, and operating system configuration.

- To utilize the servers in HPE Compute Ops Management, certain steps need to be followed. Each server should be onboarded to the HPE GreenLake platform, properly licensed, and assigned to the COM application instance. Additionally, it is important to ensure that the iLO (Integrated Lights-Out) of each server is connected to the HPE GreenLake platform.

  > To learn more, see [Configuring Compute Ops Management direct management](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00001293en_us&page=GUID-8F12FE6C-DC13-44DC-921B-041E8DC628DB.html)

- The `Hosts` inventory file needs to be updated. Each server should be listed in the corresponding inventory group along with its serial number and the IP address that should be assigned to the operating system.

- A Windows DNS server configured to be managed by Ansible. See below for more information.



## Ansible control node information

- It runs Ansible
- It can be a physical server or a Virtual Machine
- It is used as the temporary destination for the preparation of ISO files.
- It runs `nginx` web services to host the created ISO files from which the bare metal servers will boot from using iLO virtual media.
- It must have enough disk space to host all ISOs and generated ISOs.
- It must be at the right time and date.

### Ansible control node configuration

To configure the Ansible control node, see [Ansible_control_node_requirements.md](https://github.com/jullienl/HPE-COM-baremetal/blob/main/files/Ansible_control_node_requirements.md) in `/files`

By default, Ansible executes tasks on a maximum of 5 hosts in parallel. If you want to increase the parallelism and have the provisioning tasks executed on more hosts simultaneously, you can modify this value directly in the playbooks using the `ansible_forks` variable.

  > It's important to note that while parallel execution can significantly improve performance, it also increases resource consumption on the Ansible control machine. Therefore, it's recommended to test and tune the value of `ansible_forks` based on your specific environment to find the optimal balance between performance and resource usage.

## Windows DNS Server configuration

The Windows DNS Server to be managed by Ansible should meet below requirements:
- PowerShell 3.0 or newer
- .NET 4.0 to be installed
- A WinRM listener should be created and activated

To configure WinRM, you can simply run [ConfigureRemotingForAnsible.ps1](https://github.com/jullienl/HPE-COM-baremetal/blob/main/files/ConfigureRemotingForAnsible.ps1) on the Windows Server to set up the basics. 

> **Note**: The purpose of this script is solely for training and development, and it is strongly advised against using it in a production environment since it enables both HTTP and HTTPS listeners with a self-signed certificate and enables Basic authentication that can be inherently insecure.

To learn more about **Setting up Windows host**, see [https://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html#winrm-setup](https://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html#winrm-setup)

## Preparation to run the playbooks

1. Clone or download this repository on your Ansible control node   
   
2. Update all variables located in `/vars` 

3. Copy the operating system ISOs to a web server defined by the variables `src_iso_url` and `src_iso_file` 

4. Secure your HPE Compute Ops Management credentials, using Ansible vault to encrypt them. From the root of this Ansible project on the Ansible control node, run:   
    ```
    ansible-vault create vars/GLCP_US_West_credentials_encrypted.yml
    ```   
    Once the password is entered, type the following content using your own API client credentials and connectivity endpoint:
     ```
     ---
     ClientID: "xxxxxxxx-xxxx-xxx-xxx-xxxxxxxxx"
     ClientSecret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
     ConnectivityEndpoint: "https://<connectivity_endpoint>-api.compute.cloud.hpe.com"
     ```
    > **Note**: To learn more about Ansible vault, see https://docs.ansible.com/ansible/latest/user_guide/vault.html
    
    > **Note**: To access the HPE Compute Ops Management API, you need to create your client credentials on the HPE GreenLake platform. To learn more, see [https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us) 


5. Secure your VMware vCenter credentials using:   
    ```
    ansible-vault create vars/VMware_vCenter_vars_encrypted.yml
    ```   
    And copy/paste the content of `/vars/VMware_vCenter_vars_clear.yml` example in the editor using your own information.

6. Secure your Windows credentials, using:   
    ```
    ansible-vault create vars/Windows_DNS_vars_encrypted.yml
    ```   
    And copy/paste the content of `/vars/Windows_DNS_vars_clear.yml` example in the editor using your own information.

7. Secure your WinRM variables for the Windows hosts, using:   
    ```
    ansible-vault create vars/WinRM_vars_encrypted.yml
    ```   
    And copy/paste the content of `/vars/WinRM_vars_clear.yml` example in the editor using your own information.

8. Update the `hosts` Ansible inventory file with the list of servers to provision. 

   Each server should be listed using a hostname in the corresponding inventory group along with its serial number and the IP address that should be assigned to the operating system.
   
   You can use the `hosts` file example:
      ```
      [ESX]
      ESX-1 os_ip_address=192.168.3.171 serial_number=CZJ3100GDB 
      ESX-2 os_ip_address=192.168.3.172 serial_number=CZ2311004G 
      ESX-3 os_ip_address=192.168.3.173 serial_number=CZ2311004H 
      
      [RHEL]
      RHEL-1 os_ip_address=192.168.3.174 serial_number=CZJ4100GDF 
      RHEL-2 os_ip_address=192.168.3.175 serial_number=CZJ3200ERF 
      ```

    > **Note**: Groups are defined by [...] like [ESX] in the example above. This group defines the list of ESX hosts that will be provisioned using the `ESXi_provisioning.yml` playbook. All hosts defined in this group will be provisioned in parallel by Ansible when the playbook is executed.

9. To provision all hosts present in the corresponding inventory group, run the following command to have Ansible prompt you for the vault and sudo passwords:    
   ```
   ansible-playbook <ESXi|RHEL|WIN>_provisioning.yml> -i hosts --ask-vault-pass --ask-become-pass
   ```
  
   For example, running `ansible-playbook ESXi_provisioning.yml` will provision all servers listed above in the [ESX] inventory group, i.e. ESX-1, ESX-2 and ESX-3.


## Provisioning playbook output samples 

Output samples generated by the provisioning playbooks can be found in `/files/output_samples`

## Unrovisioning playbook output samples 

Output samples generated by the unprovisioning playbooks can be found in `/files/output_samples`

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


## License

This project is licensed under the MIT License - see the LICENSE file for details
