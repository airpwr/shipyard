$global:PwrPackageConfig = @{
	Name = 'sonar-scanner'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'SonarSource'
		Repo = 'sonar-scanner-cli'
		TagPattern = '^([0-9]+)\.([0-9]+)\.?([0-9]+)?(\.[0-9]+)?$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Params = @{
		AssetName = 'sonar-scanner.zip'
		AssetURL = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$Tag.zip"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'sonar-scanner' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec jre, 'file:///\pkg' {
		sonar-scanner --version
	}
}