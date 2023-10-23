$global:PwrPackageConfig = @{
	Name = 'vscode'
}

function global:Install-PwrPackage {
	$AssetURL = 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive'
	$Response = Invoke-WebRequest $AssetURL -Method 'HEAD'
	$Version = [SemanticVersion]::new($Response.Headers.'Content-Disposition', '^.*filename="VSCode-win32-x64-([0-9]+)\.([0-9]+)\.([0-9]+)\.zip"$')
	$PwrPackageConfig.UpToDate = -not $Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Params = @{
		AssetName = 'vscode.zip'
		AssetURL = $AssetURL
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'code.cmd' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		code --version
	}
}