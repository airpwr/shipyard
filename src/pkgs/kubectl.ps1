$global:PwrPackageConfig = @{
	Name = 'kubectl'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'kubernetes'
		Repo = 'kubernetes'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Version = $Latest.version.ToString()
	$AssetName = 'kubectl.exe'
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://dl.k8s.io/release/v$Version/bin/windows/amd64/$AssetName"
	}
	Install-BuildTool @Params
	New-Item -Path '\pkg' -ItemType 'Directory'
	Move-Item -Path "$env:TEMP\$AssetName" -Destination '\pkg'
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include $AssetName | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	airpower exec 'file:///\pkg' {
		kubectl version --client
	}
}
