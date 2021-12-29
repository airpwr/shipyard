$global:PwrPackageConfig = @{
	Name = 'python'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'python'
		Repo = 'cpython'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Version = $Tag.SubString(1)
	$AssetName = "python-$Version-embed-amd64.zip"
	$Params = @{
		AssetName = $AssetName
		AssetIdentifier = $Tag
		AssetURL = "https://www.python.org/ftp/python/$Version/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'python.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}