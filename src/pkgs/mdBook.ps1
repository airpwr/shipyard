$global:PwrPackageConfig = @{
	Name = 'mdbook'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'rust-lang'
		Repo = 'mdbook'
		AssetPattern = '^mdbook-v[0-9]+[.][0-9]+[.][0-9]+-x86_64-pc-windows-msvc[.]zip$'
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
		AssetURL  = $Asset.URL
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'mdbook.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		mdbook help
	}
}
