$global:PwrPackageConfig = @{
	Name = 'vscode'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'microsoft'
		Repo = 'vscode'
		TagPattern = '^([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Params = @{
		AssetName = 'vscode.zip'
		AssetIdentifier = $Tag
		AssetURL = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'code.cmd' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	code --version
	pwr exit
}