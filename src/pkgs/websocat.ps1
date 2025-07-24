$global:PwrPackageConfig = @{
	Name = 'websocat'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'vi'
		Repo = 'websocat'
		AssetPattern = '^websocat\.x86_64.*-windows.*\.exe$'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)[^-]*$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	New-Item -Path "\pkg" -ItemType Directory -Force -ErrorAction Ignore | Out-Null
	$AssetFile = "\pkg\websocat.exe"
	Write-Output "downloading $($Asset.URL) to $AssetFile"
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile $AssetFile
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'websocat.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}