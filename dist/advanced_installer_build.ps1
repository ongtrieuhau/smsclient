$ErrorActionPreference = 'Stop'
$PathConfig = $PSCommandPath + '.action.config.json'
$Config = Get-Content -Path $PathConfig | ConvertFrom-Json
$Config.PathExecuteVersion = (Join-Path -Path $PSScriptRoot -ChildPath $Config.PathExecuteVersion -Resolve)
$Config.PathRcloneZip = (Join-Path -Path $PSScriptRoot -ChildPath $Config.PathRcloneZip -Resolve)
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
$Config | Add-Member -NotePropertyName GITHUBREPOSITORYSECRETSDEFAULTRTDB -NotePropertyValue ($env:GITHUBREPOSITORYSECRETSDEFAULTRTDB)
$Config | Add-Member -NotePropertyName PathRcloneConfig -NotePropertyValue ($PSScriptRoot + '\rclone.conf')
$Config | Add-Member -NotePropertyName PathRclone -NotePropertyValue ($PSScriptRoot + '\rclone.exe')
$Config | Add-Member -NotePropertyName PathRcloneFolder -NotePropertyValue ($PSScriptRoot + '\')

if ([string]::IsNullOrEmpty($Config.GITHUBREPOSITORYSECRETSDEFAULTRTDB)) {
    $Config.GITHUBREPOSITORYSECRETSDEFAULTRTDB = (Get-Content -Path ($PSScriptRoot + '\' + 'GITHUBREPOSITORYSECRETSDEFAULTRTDB.githubignore'))
}
$Config | Add-Member -NotePropertyName GITHUBREPOSITORYSECRETSDEFAULTRTDB_DECODE -NotePropertyValue ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Config.GITHUBREPOSITORYSECRETSDEFAULTRTDB)))
#$Config.GITHUBREPOSITORYSECRETSDEFAULTRTDB_DECODE | Out-File -FilePath $Config.PathRcloneConfig
[System.IO.File]::WriteAllLines($Config.PathRcloneConfig, $Config.GITHUBREPOSITORYSECRETSDEFAULTRTDB_DECODE, (New-Object System.Text.UTF8Encoding $False))
#Write to AdvancedInstaller commandFile
$saveFile = @(';aic', `
    ('SetVersion ' + $Config.Version), `
    ('SetProperty ExecuteVersion="{0}"' -f $fileVersion.FileVersion), `
    ('SetOutputLocation -buildname DefaultBuild -path {0}' -f $Config.PathAdvancedInstallerOutputFolder), `
    ('SetPackageName {0} -buildname DefaultBuild' -f $Config.OutputPackageName), `
        'Save', `
        'Rebuild')
$saveFile | Out-File -FilePath $Config.PathAdvancedInstallerCommandFile
&AdvancedInstaller.com /execute $Config.PathAdvancedInstallerProjectFile $Config.PathAdvancedInstallerCommandFile 
Write-Host ('CompressZip {0}=>{1}' -f $Config.PathAdvancedInstallerOutputFile, $Config.PathAdvancedInstallerOutputFileZip)
compress-archive -path $Config.PathAdvancedInstallerOutputFile -destinationpath ($Config.PathAdvancedInstallerOutputFileZip) -Force
if ([System.IO.File]::Exists($Config.PathRclone)) { [System.IO.File]::Delete($Config.PathRclone) }
expand-archive -path $Config.PathRcloneZip -destinationpath $Config.PathRcloneFolder
if ([System.IO.File]::Exists($Config.PathRclone) -and 
    [System.IO.File]::Exists($Config.PathRcloneConfig)) {
    $Config | Add-Member -NotePropertyName RcloneArgumentList -NotePropertyValue ('')
             
    while ($Config.RcloneCloudPath.StartsWith('\')) { $Config.RcloneCloudPath = $Config.RcloneCloudPath.TrimStart('\') }      
    while ($Config.RcloneCloudPath.EndsWith('\')) { $Config.RcloneCloudPath = $Config.RcloneCloudPath.TrimEnd('\') }    
    Get-Content $Config.PathRcloneConfig | ForEach-Object {
        if ($_.StartsWith('[') -and $_.EndsWith(']')) {
            $uploadName = $_.Replace('[', '').Replace(']', '')
            $Config.RcloneArgumentList = '' 
            $Config.RcloneArgumentList += 'copy "' + $Config.PathAdvancedInstallerOutputFileZip + '" ' + $uploadName + ':"' + $Config.RcloneCloudPath + '"'
            $Config.RcloneArgumentList += ' --config "' + $Config.PathRcloneConfig + '"'
            $Config.RcloneArgumentList += ' --auto-confirm'
            Write-Host ('Rclone upload: {0}=>{1}' -f $Config.PathAdvancedInstallerOutputFileZip, $uploadName)
            Start-Process -WindowStyle Hidden -Wait -FilePath $Config.PathRclone -ArgumentList $Config.RcloneArgumentList
        }
    }  
}
if ([System.IO.File]::Exists($Config.PathRclone)) { [System.IO.File]::Delete($Config.PathRclone) }
if ([System.IO.File]::Exists($Config.PathRcloneConfig)) { [System.IO.File]::Delete($Config.PathRcloneConfig) }
Write-Host $Config