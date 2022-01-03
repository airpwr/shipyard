$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PwrCmd = "$env:appdata\pwr\cmd"
mkdir $PwrCmd -Force | Out-Null
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/airpwr/shipyard/main/cmd/pwr.ps1' -OutFile "$PwrCmd\pwr.ps1"
$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $UserPath.Contains($PwrCmd)) {
	[Environment]::SetEnvironmentVariable('Path', "$UserPath;$PwrCmd", 'User')
}
pwr version