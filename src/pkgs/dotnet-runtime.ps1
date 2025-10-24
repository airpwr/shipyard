$global:PwrPackageConfig = @{
	Name = 'dotnet-runtime'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'dotnet'
		Repo = 'runtime'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Version = $Tag.SubString(1)
	$Params = @{
		AssetName = "dotnet-$Version.zip"
		AssetURL = "https://builds.dotnet.microsoft.com/dotnet/Runtime/$Version/dotnet-runtime-$Version-win-x64.zip"
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
		dotnet --info
	}
}