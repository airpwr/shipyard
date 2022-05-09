$global:PwrPackageConfig = @{
	Name = 'pandoc'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'jgm'
		Repo = 'pandoc'
		AssetPattern = '^pandoc-.+-windows-x86_64\.zip$'
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
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'pandoc.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	pandoc -v
	pwr exit
}