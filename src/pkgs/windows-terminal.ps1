$global:PwrPackageConfig = @{
	Name = 'windows-terminal'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'microsoft'
		Repo = 'terminal'
		AssetPattern = 'Microsoft\.WindowsTerminal(Preview)?_Win10_.+\.msixbundle'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+).*$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$bundle = "$env:Temp\$($Asset.Name)"
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile $bundle
	Expand-Archive $bundle "$env:temp\bundle"
	Expand-Archive "$env:temp\bundle\CascadiaPackage_$($Asset.Identifier.Substring(1))_x64.msix" "\pkg"
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'wt.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	Get-Command wt
	pwr exit
}