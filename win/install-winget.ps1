# Install Windows Package Manager (winget)
Invoke-WebRequest -Uri https://aka.ms/winget-cli -OutFile winget-cli.msixbundle
Add-AppxPackage .\winget-cli.msixbundle
winget --version
Set-ExecutionPolicy -Scope CurrentUser Unrestricted