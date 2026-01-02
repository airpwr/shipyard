$global:PwrPackageConfig = @{
	Name = 'dotnet-sdk'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'dotnet'
		Repo = 'sdk'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)(?:-rtm.*)?$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Version = $PwrPackageConfig.Version
	$Params = @{
		AssetName = "dotnet-sdk-$Version.zip"
		AssetURL = "https://builds.dotnet.microsoft.com/dotnet/Sdk/$Version/dotnet-sdk-$Version-win-x64.zip"
	}

	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'dotnet.exe' | Select-Object -First 1).DirectoryName
			dotnet_root = '\pkg'
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		dotnet --list-sdks
	}
}