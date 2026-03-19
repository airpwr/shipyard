$global:PwrPackageConfig = @{
	Name = 'hugo'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'gohugoio'
		Repo = 'hugo'
		AssetPattern = '^hugo_extended_[0-9]+\.[0-9]+\.[0-9]+_windows-amd64\.zip$'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}

  $Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = $False
	if ($PwrPackageConfig.Latest) {
		$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	}
  $global:PwrPackageConfig.Version = $Asset.Version.ToString()

  if ($global:PwrPackageConfig.UpToDate) {
      Write-Debug "$($global:PwrPackageConfig.Name) is up to date (version $($global:PwrPackageConfig.Version)), skipping packaging"
      return
  }

	$Params = @{
		AssetName = $Asset.Name
		AssetURL  = $Asset.URL
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'hugo.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		hugo version
	}
}
