$global:PwrPackageConfig = @{
	Name = 'gradle'
	Matcher = '^gradle-6\.'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'gradle'
		Repo = 'gradle'
		TagPattern = '^v(6)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Version = $Tag.SubString(1)
	if ($Version.EndsWith('.0')) {
		$Version = $Version.SubString(0, $Version.Length - 2)
	}
	$AssetName = "gradle-$Version-bin.zip"
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://services.gradle.org/distributions/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'gradle.bat' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}