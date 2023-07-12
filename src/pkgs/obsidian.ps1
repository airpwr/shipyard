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
	Write-Host "URL = $($Asset.URL)"
	$obby = "obsidian.exe"
	Invoke-WebRequest -UseBasicParsing "$($Asset.URL)" -OutFile $obby
	airpower exec 7-zip {
		mkdir '\app'
		mkdir '\pkg'
		7z x -o'\app' $obby | Out-Null
		7z x -o'\pkg' '\app\$PLUGINSDIR\app-64.7z' | Out-Null
	}
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'obsidian.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	airpower exec 'file:///\pkg' {
		Get-Command obsidian
	}
}
