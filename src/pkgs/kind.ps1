$global:PwrPackageConfig = @{
	Name = 'kind'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'kubernetes-sigs'
		Repo = 'kind'
		AssetPattern = 'kind-windows-amd64'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	New-Item -Path '\pkg' -ItemType 'Directory'
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile '\pkg\kind.exe'
	Write-PackageVars @{
		env = @{
			path = '\pkg'
		}
	}
}

function global:Test-PwrPackageInstall {
	airpower exec 'file:///\pkg' {
		kind version
	}
}
