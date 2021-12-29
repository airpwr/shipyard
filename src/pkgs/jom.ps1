$global:PwrPackageConfig = @{
	Name = 'jom'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'qt-labs'
		Repo = 'jom'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Version = $Tag.SubString(1).replace('.', '_')
	$AssetName = "jom_$Version.zip"
	$Params = @{
		AssetName = $AssetName
		AssetIdentifier = $Tag
		AssetURL = "http://qt.mirror.constant.com/official_releases/jom/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'jom.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}