$global:PwrPackageConfig = @{
	Name = 'powershell'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'PowerShell'
		Repo = 'PowerShell'
		AssetPattern = '^PowerShell-.+-win-x64\.zip$'
		TagPattern = "^v([0-9]+)\.([0-9]+)\.([0-9]+)$"
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Params = @{
		AssetName = $Asset.Name
		AssetIdentifier = $Asset.Identifier
		AssetURL = $Asset.URL
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'pwsh.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	pwsh -v
	pwr exit
}