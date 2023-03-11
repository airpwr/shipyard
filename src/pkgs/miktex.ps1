$global:PwrPackageConfig = @{
	Name = 'MiKTeX'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'MiKTeX'
		Repo = 'miktex'
		TagPattern = '^([0-9]+)\.([0-9]+)\.?([0-9]+)?$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$AssetName = 'miktexsetup-x64.zip'
	$PackageSet = 'basic' # 'basic' (~850MB), 'advanced' (~1.5GB), 'complete' (~8GB)
	$ToolDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("\pkg")
	$Asset = "$env:Temp/$AssetName"
	# Those turdcicles don't have the installer tied to the version
	Invoke-WebRequest -UseBasicParsing "https://miktex.org/download/win/$AssetName" -OutFile $Asset
	Expand-Archive $Asset 'miktexsetup'
	& 'miktexsetup\miktexsetup_standalone.exe' --verbose "--package-set=$PackageSet" download
	& 'miktexsetup\miktexsetup_standalone.exe' --verbose "--package-set=$PackageSet" "--portable=$ToolDir" install
	[System.IO.File]::WriteAllText("$ToolDir\texmfs\config\miktex\config\issues.json", '[]')
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path $ToolDir -Recurse -Include 'latex.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr exec 'file:///\pkg' {
		latex -version
	}
}