if (Test-Path ".\Release") {
    RmDir .\Release -Recurse -Force
}
if (Test-Path ".\OofhoursMediaTool.zip") {
    Remove-Item ".\OofhoursMediaTool.zip"    
}
MkDir .\Release
Copy-Item .\MediaToolApp\bin\debug\MediaToolApp.exe .\Release
Copy-Item .\MediaToolApp\bin\debug\MediaToolApp.exe.config .\Release
Copy-Item .\LICENSE .\Release
Copy-Item .\Modules .\Release -Recurse
Compress-Archive -Path .\Release -DestinationPath OofhoursMediaTool.zip
