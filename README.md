```text
  ____ ___  ____  _   _ _____ ___ _____ ___  
 / ___/ _ \|  _ \| \ | | ____/ __|_   _/ _ \ 
| |  | | | | |_) |  \| |  _| \__ \ | || | | |
| |__| |_| |  _ <| |\  | |___ ___) || || |_| |
 \____\___/|_| \_\_| \_|_____|____/ |_| \___/ 
                 IT & Security                 

===============================================
 OpenVAS WSLC Orchestrator v1.0 (Windows x64/ARM64) 
===============================================
 All-In-One Edition (immauss/openvas) 
===============================================
 Web UI URL: http://localhost:9392
 Credentials: admin / admin
===============================================
```

# OpenVAS WSL Containers Orchestrator

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

## 🛠️ Troubleshooting

* **Missing Environment Variables / Engine Not Found**: Ensure you completely closed and reopened your terminal after selecting Option 1.
* **Container Crash on Startup**: Ensure you have enough system memory allocated to WSL. The script automatically tries to provision 8GB.
* **Network Errors**: Ensure WSL is allowed through your Windows Firewall, or temporarily disable it for troubleshooting.
