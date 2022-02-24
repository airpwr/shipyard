$global:PwrPackageConfig = @{
	Name = 'doxygen'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'doxygen'
		Repo = 'doxygen'
		TagPattern = '^Release_([0-9]+)_([0-9]+)_([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Version = $Latest.version.ToString()
	$AssetName = "doxygen-$Version.windows.x64.bin.zip"
	$Params = @{
		AssetName = $AssetName
		AssetIdentifier = $Tag
		AssetURL = "https://www.doxygen.nl/files/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'doxygen.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	doxygen --version
	pwr exit
}