$global:PwrPackageConfig = @{
	Name = 'chromium'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'ungoogled-software'
		Repo = 'ungoogled-chromium-windows'
		AssetPattern = 'ungoogled-chromium_.*_windows_x64\.zip$'
		TagPattern = '^([0-9]+)\.([0-9]+)\.([0-9]+)(\.[0-9]+)(-.+)?$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Params = @{
		AssetName = $Asset.Name
		AssetURL = $Asset.URL
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'chrome.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		chrome --headless --disable-gpu --dump-dom https://github.com/ungoogled-software/ungoogled-chromium-windows/releases/latest | tee -Variable ChromeStatus
	}
}
