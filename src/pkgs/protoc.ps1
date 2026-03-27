$global:PwrPackageConfig = @{
	Name = 'protoc'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'protocolbuffers'
		Repo = 'protobuf'
		TagPattern = '^v([0-9]+)\.([0-9]+)(?:\.([0-9]+))?$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$AssetName = "protoc-$($Tag.Substring(1))-win64.zip"
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://github.com/protocolbuffers/protobuf/releases/download/$Tag/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'protoc.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		protoc --version
	}
}
