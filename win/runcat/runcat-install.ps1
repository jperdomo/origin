# RunCat
## Broken
Invoke-WebRequest https://github.com/Kyome22/RunCat_for_windows/releases/download/2.0/RunCat-x64.zip -OutFile runcat.zip
Expand-Archive runcat.zip
del runcat.zip
runcat\RunCat.exe /s /v