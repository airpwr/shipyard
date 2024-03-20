$global:PwrPackageConfig = @{
	Name = 'zstd'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'facebook'
		Repo = 'zstd'
		AssetPattern = 'zstd-v.+-win64.zip'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Params = @{
		AssetName = $Asset.Name
		AssetURL = $Asset.URL
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'zstd.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	airpower exec 'file:///\pkg' {
		zstd --version
	}
}