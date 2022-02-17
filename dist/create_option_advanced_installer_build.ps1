$ErrorActionPreference = 'Stop'
$PathConfig = $PSCommandPath + '.action.config.json'
$Config = Get-Content -Path $PathConfig | ConvertFrom-Json
$Config.PathExecuteVersion = (Join-Path -Path $PSScriptRoot -ChildPath $Config.PathExecuteVersion -Resolve)
return
#Resolve Path file in Config
try {
    $Config.PathAdvancedInstallerCommandFile = (Join-Path -Path $PSScriptRoot -ChildPath $Config.PathAdvancedInstallerCommandFile -Resolve)
}
catch {
    Write-Host ('File not found Advanced Installer CommandFile: {0}' -f $_.TargetObject)
    $Config.PathAdvancedInstallerCommandFile = $_.TargetObject
}
try {
    $Config.PathAdvancedInstallerProjectFile = (Join-Path -Path $PSScriptRoot -ChildPath $Config.PathAdvancedInstallerProjectFile -Resolve)
}
catch {
    Write-Host ('File not found Advanced Installer Project (.aip): {0}' -f $_.TargetObject)
    Write-Host ('Config Option [PathAdvancedInstallerProjectFile]: {0}' -f $Config.PathAdvancedInstallerProjectFile)
    return
}
try {
    $Config.PathAdvancedInstallerOutputFolder = (Join-Path -Path $PSScriptRoot -ChildPath $Config.PathAdvancedInstallerOutputFolder -Resolve) 
}
catch {
    Write-Host ('Directory not found Advanced Installer Output: {0}' -f $_.TargetObject)
    Write-Host ('Create auto Advanced Installer Output: {0}....' -f $_.TargetObject)
    [System.IO.Directory]::CreateDirectory($_.TargetObject)
    $Config.PathAdvancedInstallerOutputFolder = $_.TargetObject
}
#Find version Execute Application in Config
$fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Config.PathExecuteVersion)
$advVersion = '{0}.{1}.{2}{3}.{3}' -f $fileVersion.FileMajorPart, $fileVersion.FileMinorPart, $fileVersion.FileBuildPart.toString().PadLeft(4, '0'), $fileVersion.FilePrivatePart
$Config | Add-Member -NotePropertyName Version -NotePropertyValue $advVersion
$Config | Add-Member -NotePropertyName PathAdvancedInstallerOutputFile -NotePropertyValue (join-Path -Path $Config.PathAdvancedInstallerOutputFolder -ChildPath $Config.OutputPackageName)
$Config | Add-Member -NotePropertyName PathAdvancedInstallerOutputFileZip -NotePropertyValue ((join-Path -Path $Config.PathAdvancedInstallerOutputFolder -ChildPath $Config.OutputPackageName.Replace('.exe', '')) + '.v{0}.zip' -f $fileVersion.FileVersion)

#Write to AdvancedInstaller commandFile
$saveFile = @(';aic', `
    ('SetVersion ' + $Config.Version), `
    ('SetProperty ExecuteVersion="{0}"' -f $fileVersion.FileVersion), `
    ('SetOutputLocation -buildname DefaultBuild -path {0}' -f $Config.PathAdvancedInstallerOutputFolder), `
    ('SetPackageName {0} -buildname DefaultBuild' -f $Config.OutputPackageName), `
        'Save', `
        'Rebuild')
$saveFile | Out-File -FilePath $Config.PathAdvancedInstallerCommandFile
Write-Host $Config

&AdvancedInstaller.com /execute $Config.PathAdvancedInstallerProjectFile $Config.PathAdvancedInstallerCommandFile 
compress-archive -path $Config.PathAdvancedInstallerOutputFile -destinationpath ($Config.PathAdvancedInstallerOutputFileZip) -Force