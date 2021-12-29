$global:PwrPackageConfig = @{
	Name = 'nasm'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'netwide-assembler'
		Repo = 'nasm'
		TagPattern = '^.*([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Version = $Tag.SubString(5)
	$AssetName = "nasm-$Version-win64.zip"
	$Params = @{
		AssetName = $AssetName
		AssetIdentifier = $Tag
		AssetURL = "https://www.nasm.us/pub/nasm/releasebuilds/$Version/win64/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'nasm.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}