$global:PwrPackageConfig = @{
	Name = 'zarf'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'zarf-dev'
		Repo = 'zarf'
		AssetPattern = 'zarf_v.+_Windows_amd64.exe'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	New-Item -Path '\pkg' -ItemType "Directory"
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile '\pkg\zarf.exe'
	Write-PackageVars @{
		env = @{
			path = '\pkg'
		}
	}
}

function global:Test-PwrPackageInstall {
	airpower exec 'file:///\pkg' {
		zarf version
	}
}
