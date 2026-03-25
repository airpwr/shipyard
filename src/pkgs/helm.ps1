$global:PwrPackageConfig = @{
	Name = 'helm'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'helm'
		Repo = 'helm'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Version = $Latest.version.ToString()
	$AssetName = "helm-v$Version-windows-amd64.zip"
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://get.helm.sh/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'helm.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	airpower exec 'file:///\pkg' {
		helm version
	}
}
