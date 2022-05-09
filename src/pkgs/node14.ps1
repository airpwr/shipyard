# End-of-Life is 2023-04-30. See https://nodejs.org/en/about/releases/
$global:PwrPackageConfig = @{
	Name = 'node'
	Matcher = '^node-14\.'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'nodejs'
		Repo = 'node'
		TagPattern = '^v(14)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$AssetName = "node-$Tag-win-x64.zip"
	$Params = @{
		AssetName = $AssetName
		AssetURL = "https://nodejs.org/dist/$Tag/$AssetName"
	}
	Install-BuildTool @Params
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'node.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	node --version
	pwr exit
}