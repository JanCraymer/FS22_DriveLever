@echo off
del FS22_DriveLever.zip
"%programfiles%\7-Zip\7z.exe" a -tzip FS22_DriveLever.zip modDesc.xml icon.dds src/*
pause