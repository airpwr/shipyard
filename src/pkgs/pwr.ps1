$global:PwrPackageConfig = @{
	Name = 'pwr'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'airpwr'
		Repo = 'airpwr'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	mkdir '\pkg'
	Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/airpwr/airpwr/$Tag/src/pwr.ps1" -OutFile '\pkg\pwr.ps1'
	Write-PackageVars @{
		env = @{
			path = '\pkg'
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr exec 'file:///\pkg' {
		if ((Get-Command pwr).Path -ne (Resolve-Path '\pkg\pwr.ps1').Path) {
			Write-Error (Get-Command pwr).Path
		}
	}
}