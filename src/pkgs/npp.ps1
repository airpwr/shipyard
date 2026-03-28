$global:PwrPackageConfig = @{
	Name = 'npp'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'notepad-plus-plus'
		Repo = 'notepad-plus-plus'
		AssetPattern = '^npp[.][0-9]+[.][0-9]+([.][0-9]+)?[.]portable[.]zip$'
        TagPattern = '^v([0-9]+)\.([0-9]+)(\.[0-9]+)?$'
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
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'notepad++.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		notepad++ --help
	}
}
