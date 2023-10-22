$global:PwrPackageConfig = @{
	Name = 'dotnet-sdk'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'dotnet'
		Repo = 'sdk'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)(?:-rtm.*)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Version = $PwrPackageConfig.Version
	$AssetName = "dotnet-$Version.zip"
	$Resp = Invoke-WebRequest "https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/sdk-$Version-windows-x64-binaries"
	if (-not ($Resp.Content -match '.*"(https://download\..*?)".*')) {
		Write-Error "failed to match the url pattern"
		return
	}
	$Params = @{
		AssetName = $AssetName
		AssetURL = $Matches[1]
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