$global:PwrPackageConfig = @{
	Name = 'conan'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'conan-io'
		Repo = 'conan'
		AssetPattern = '^conan-.+?-windows-x86_64.zip$'
		TagPattern = '^([0-9]+)\.([0-9]+)\.([0-9]+)$'
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
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'conan.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		conan --version
		conan --help
	}
}
