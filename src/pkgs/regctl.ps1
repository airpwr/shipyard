$global:PwrPackageConfig = @{
	Name = 'regctl'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'regclient'
		Repo = 'regclient'
		AssetPattern = 'regctl-windows-amd64.exe'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.?([0-9]+)?$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	New-Item -Path '\pkg' -ItemType Directory -Force -ErrorAction Ignore | Out-Null
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile '\pkg\regctl.exe'
	Invoke-WebRequest -UseBasicParsing $Asset.URL.Replace('regctl-', 'regbot-') -OutFile '\pkg\regbot.exe'
	Invoke-WebRequest -UseBasicParsing $Asset.URL.Replace('regctl-', 'regsync-') -OutFile '\pkg\regsync.exe'
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'regctl.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		regctl version
		regbot version
		regsync version
	}
}