$global:PwrPackageConfig = @{
	Name = 'go'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'golang'
		Repo = 'go'
		TagPattern = '^go([0-9]+)\.([0-9]+)\.?([0-9]+)?$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$AssetName = "$Tag.windows-amd64.zip"
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://go.dev/dl/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'go.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr exec 'file:///\pkg' {
		go version
	}
}