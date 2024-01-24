# Steps to create a WinPE image for Windows server deployment


Creating a Windows Preinstallation Environment (WinPE) image is an essential part of deploying Windows servers, especially for custom or automated installations. Below are the steps to follow to create a WinPE image suited to the Ansible playbook of this project for the deployment of Windows Server:

**Prerequisites**:
- A Windows machine to install the Windows Assessment and Deployment Kit (Windows ADK) 
- Adequate permissions to execute commands on your machine

## Step 1: Install Windows ADK

1. Download the **Windows ADK**  and the **Windows WinPE add-on for the ADK** from the official Microsoft website for the version of Windows you are supporting. See https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install

2. Run both installers. For creating WinPE media, make sure to include the **Deployment Tools** component.

## Step 2: Create a Working Copy of WinPE

Open an elevated Command Prompt (or PowerShell) window and use the `copype` command to create a working copy of the WinPE files.

```cmd
copype amd64 D:\WinPE_AMD64
```

## Step 3: Customize WinPE

1. Mount the image

   ```powershell
   Mount-WindowsImage -ImagePath D:\WinPE_AMD64\media\sources\boot.wim -Index 1 -path D:\Mount\
   ```

   > **Note**: If you get an error saying the Windows image is already mounted, enter: `Get-WindowsImage -Mounted | Dismount-WindowsImage -Discard`

2. Add the following packages that are needed:

   By default, WinPE does not support PowerShell and advanced scripting functionalities so it is necessary to add a few packages.

   ```powershell
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WMI.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-WMI_en-us.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-NetFX.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-NetFX_en-us.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-PowerShell.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-StorageWMI.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-DismCmdlets.cab"
   Dism /Add-Package /Image:"D:\Mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab"
   ```



## Step 4: Edit the startnet.cmd script to launch the PowerShell script for the preliminary tasks

`startnet.cmd` is a command script that runs by default when WinPE boots. This file is part of the WinPE boot image and is responsible for initializing the network connections and starting the Command Prompt window. By default, it includes a single command, `wpeinit`, which is responsible for activating WinPE's networking features upon boot and for this project, two additional commands must be added.

Open `startnet.cmd` located in `D:\NMount\NWindows\Nsystem32\` and edit it as follows:

```cmd
REM Default command to initialize networking
wpeinit

REM Define a high-performance power plan to speed up Windows installation
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

REM Run the batch file 'Run_Pre_installation_script.cmd' created by the playbook to launch `Pre_installation_script.ps1`
X:\Run_Pre_installation_script.cmd

```

The `powercfg` command is used to activate the high-performance power plan, enhancing the speed of the Windows setup process. The `Run_Pre_installation_script.cmd` command is a batch file generated by the Ansible playbook responsible for Windows provisioning; its execution is necessary to trigger `Pre_installation_script.ps1`, an associated PowerShell script that performs multiple preliminary tasks prior to initiating the automated setup for Windows Server.

`Pre_installation_script.ps1` is automatically generated by the playbook and has the following functions:
- Identify the OS boot Volume DiskID using the volume size and storage controller type provided by HPE Compute Ops Management
- Set DiskID in the autounattend.xml file to define the OS installation target disk 
- Create `Post_installation_script.ps1` in `%OEM%` that will run at OS startup to clean temporary files, install iLO CHIF driver, the HPE Agentless Management Service (AMS) and set IP parameters with or without NIC teaming
- Create the different disk partitions required by Windows
- Mount the Windows Server DVD ISO from a network share and copy its content to the Windows partition 
- Create the recovery partition content from the mounted Windows Server DVD ISO
- Save the pre-installation script logs to the Windows drive
- Start the unattend installation setup of Windows Server

## Step 5: Commit Changes and Unmount the WinPE Image

After this modification, commit all changes and unmount the image:

```powershell
Dismount-WindowsImage -Path D:\Mount\ -save
```

## Step 6: Create the Bootable Media

Back to the elevated Command Prompt of **ADK Deployment and Imaging Tools Environment** enter:

```cmd
MakeWinPEMedia /ISO D:\WinPE_AMD64 D:\WinPEx64.iso
```

## Step 7: Copy the new WinPE ISO to the web server

The newly generated WinPE file `D:\WinPEx64.iso` is now ready and customized and can be copied to the web server defined by the `winpe_iso_url` and `winpe_iso_file` variables in `group_vars/WIN2022/Windows_vars.yml`.



## Step 8: (Optional) Check content of startnet.cmd

To check the content of `startnet.cmd`, you can mount the WinPE image then go to `\sources` and open `boot.wim` with 7-Zip.

Then open `startnet.cmd` located in `\Windows\System32\`.
