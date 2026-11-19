$global:PwrPackageConfig = @{
	Name = 'flatc'
}

function global:Install-PwrPackage {
	$AssetName = 'Windows.flatc.binary.zip'
	$Params = @{
		Owner = 'google'
		Repo = 'flatbuffers'
		AssetPattern = $AssetName
		TagPattern = '^v([0-9]+)\.([0-9]+)(?:\.([0-9]+))?.*$'
	}
	$Latest = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	Install-BuildTool -AssetName $Latest.Name -AssetURL $Latest.URL
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'flatc.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		flatc --version
	}
}
