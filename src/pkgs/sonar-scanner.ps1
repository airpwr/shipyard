$global:PwrPackageConfig = @{
	Name = 'sonar-scanner'
}

function global:Install-PwrPackage {
	$Releases = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/SonarSource/sonar-scanner-cli/releases?per_page=100").Content | ConvertFrom-Json
	$Latest = Find-LatestTag $Releases 'tag_name' '^([0-9]+)\.([0-9]+)\.?([0-9]+)?(\.[0-9]+)?$'
	if (!$Latest) {
		Write-Error "Failed to find a GitHub Release for SonarSource sonar-scanner-cli"
	}
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Params = @{
		AssetName = 'sonar-scanner.zip'
		AssetURL = "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$($Latest.Item.tag_name).zip"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'sonar-scanner' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh jre:11, 'file:///\pkg'
	sonar-scanner --version
	pwr exit
}