$global:PwrPackageConfig = @{
	Name = 'zig'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'ziglang'
		Repo = 'zig'
		TagPattern = '^([0-9]+)\.([0-9]+)\.?([0-9]+)?$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$AssetName = "zig-windows-x86_64-$Tag.zip"
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://ziglang.org/download/$Tag/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'zig.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr exec 'file:///\pkg' {
		zig version
	}
}
