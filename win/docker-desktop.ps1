# Docker Desktop
winget install Docker.DockerDesktop

# WSL2 Setup

## Check if WSL 2 is already installed
$wsl_version = (wsl.exe -l -v | Select-String -Pattern "WSL 2" -Quiet)
if ($wsl_version) {
    Write-Host "WSL 2 is already installed."
    return
}

## Enable the Windows Subsystem for Linux feature
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

## Enable the Virtual Machine Platform feature
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

## Download and install the WSL 2 Linux kernel update package
$wsl_update_url = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
$wsl_update_path = "$env:TEMP\wsl_update_x64.msi"
Invoke-WebRequest -Uri $wsl_update_url -OutFile $wsl_update_path
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $wsl_update_path /quiet" -Wait

## Set WSL 2 as the default version
wsl --set-default-version 2

Write-Host "WSL 2 has been installed."