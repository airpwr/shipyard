$global:PwrPackageConfig = @{
	Name = 'buf'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'bufbuild'
		Repo = 'buf'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$AssetName = 'buf-Windows-x86_64.zip'
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://github.com/bufbuild/buf/releases/download/$Tag/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'buf.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		buf --version
	}
}
