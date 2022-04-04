$global:PwrPackageConfig = @{
	Name = 'python'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'MiKTeX'
		Repo = 'miktex'
		TagPattern = '^([0-9]+)(\.([0-9]+)(\.([0-9]+)(\.([0-9]+))?)?)?$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Version = $Latest.name
	$AssetName = "basic-miktex-$Version-x64.exe"
	$ToolDir = "\pkg"
	$Asset = "$env:Temp/$AssetName"
	Invoke-WebRequest -UseBasicParsing "https://miktex.org/download/ctan/systems/win32/miktex/setup/windows-x64/$AssetName" -OutFile $Asset
	Start-Process $Asset -ArgumentList "--auto-install=yes --unattended --private --user-install=$ToolDir --no-registry" -Wait
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'latex.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}