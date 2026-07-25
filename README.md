```text
  ___  ____  _____ _   _ __     ___    ____ 
 / _ \|  _ \| ____| \ | |\ \   / / \  / ___|
| | | | |_) |  _| |  \| | \ \ / / _ \ \___ \
| |_| |  __/| |___| |\  |  \ V / ___ \ ___) |
 \___/|_|   |_____|_| \_|   \_/_/   \_\____/
       M A N A G E M E N T   T O O L        

===============================================
 OpenVAS Management Tool v1.0.1 (Windows x64/ARM64) 
===============================================
 Community Edition (immauss/openvas) 
===============================================
 Web UI URL: http://localhost:9392
 Credentials: admin / admin
===============================================
```

# OpenVAS Management Tool (WSL Containers)

This repository contains a PowerShell script for managing a containerized instance of Greenbone OpenVAS (Community Edition) using native Windows Subsystem for Linux (WSL) containers (`wslc.exe`). 

It deploys the community-maintained `immauss/openvas` all-in-one image, which bypasses complex networking requirements and makes it highly suitable for standard WSL container environments.

## 📋 Prerequisites

Before running this script, ensure your system meets the following requirements:
* **Operating System**: Windows 10/11 (x64 or ARM64)
* **Virtualization**: Hardware virtualization must be enabled in your BIOS/UEFI.
* **Administrator Privileges**: You may need to run your terminal as an Administrator for WSL installations and configuration updates.

## 🚀 Easy Installation Steps

Follow these simple steps to get your OpenVAS instance up and running:

1. **Open PowerShell**: Launch a PowerShell session (preferably as Administrator).
2. **Bypass Execution Policy**: Because the script is not digitally signed, temporarily bypass the execution policy for your session by running: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
3. **Execute the Script**: Run `.\Manage-OpenVAS.ps1`.
4. **Install and Deploy (Option I)**: Select **Option I** from the interactive menu. The script will handle the rest:
    * Install/Update WSL to support native containers (if needed).
    * Provision persistent volumes and deploy the `immauss/openvas:latest` container.
    * *Note: If the WSLC engine was just installed, you will need to close and reopen your PowerShell terminal to reload environment variables, then relaunch the script and select Option I again.*
5. **Start/Restart Services (Option S)**: Select **Option S** to start the container and wait for the Web UI to come online.
6. **Access the Web UI**: Once started successfully, access the Greenbone Security Assistant UI by navigating to `http://localhost:9392` in your web browser.
    * **Default Credentials**: `admin` / `admin`

## 🔄 Updating the Management Tool

To update the management tool to the latest version:

1. **Fetch Latest Source Code**: Pull the latest changes from the repository:
   ```powershell
   git pull origin main
   ```
2. **Update Globally Installed PowerShell Module**: Run the local module installer to overwrite the installed module files in your user PowerShell module path:
   ```powershell
   .\Install-ModuleLocal.ps1
   ```
3. **Update OpenVAS Container Images (Optional)**: Relaunch the management tool and choose **Option U** from the menu to pull the latest `immauss/openvas` container images without losing your database or vulnerability data.
   ```powershell
   Manage-OpenVAS
   ```

## 📌 Versioning & Version History

The management tool follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`). 

- **Module Version Manifest**: Declared in [`OpenVASWSLC.psd1`](file:///c:/Users/carlo/OneDrive/Private/Stuff/Scripts/openvas-wslc/OpenVASWSLC/OpenVASWSLC.psd1) (`ModuleVersion = '1.0.1'`).
- **Runtime Display**: Displayed dynamically in the menu header banner when invoking `Manage-OpenVAS`.

### Version History
* **v1.0.1**: Cleaned up ASCII banner spelling (`OPENVAS`) and alignment, added `OpenVAS Management Tool` labeling, standardized function approved verbs (`Invoke-OpenVAS`, `Set-OpenVASLimits`, `Confirm-OpenVASInstalled`), eliminated unused variable warnings, and established module versioning.
* **v1.0.0**: Initial release with native WSL container (`wslc.exe`) orchestration, interactive lifecycle menu, dynamic hardware detection (x64/ARM64), auto `.wslconfig` optimization, and feed sync capabilities.

## 🛠️ Troubleshooting

* **Missing Environment Variables / Engine Not Found**: Ensure you completely closed and reopened your terminal after selecting Option 1.
* **Container Crash on Startup**: Ensure you have enough system memory allocated to WSL. The script automatically tries to provision 8GB.
* **Network Errors**: Ensure WSL is allowed through your Windows Firewall, or temporarily disable it for troubleshooting.

