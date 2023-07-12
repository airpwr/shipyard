$global:PwrPackageConfig = @{
	Name = 'obsidian'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner        = 'obsidianmd'
		Repo         = 'obsidian-releases'
		AssetPattern = '^Obsidian\.([0-9]+)\.([0-9]+)\.([0-9]+)\.exe$'
		TagPattern   = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Params = @{
		AssetName = $Asset.Name
		AssetURL  = $Asset.URL
	}
	Invoke-WebRequest -URL $Asset.URL -OutFile "obsidian.exe"
	& "obsidian.exe"
	# Install-BuildTool @Params
	# Write-PackageVars @{
	# 	env = @{
	# 		path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'obsidian.exe' | Select-Object -First 1).DirectoryName
	# 	}
	# }
}

function global:Test-PwrPackageInstall {
	pwr exec 'file:///\pkg' {
		pwsh -v
	}
}