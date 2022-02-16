$PathConfig = $PSCommandPath + '.action.config.json'
$Config = Get-Content -Path $PathConfig | ConvertFrom-Json
Write-Host $PathConfig
Write-Host $Config.name2