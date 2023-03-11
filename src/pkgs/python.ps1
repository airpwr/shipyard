$global:PwrPackageConfig = @{
	Name = 'python'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'python'
		Repo = 'cpython'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Tag = $Latest.name
	$Version = $Tag.SubString(1)
	$Installer = 'python-installer.exe'
	Invoke-WebRequest -UseBasicParsing "https://www.python.org/ftp/python/$Version/python-$Version-amd64.exe" -OutFile $Installer
	mkdir '\pkg'
	$InstallDir = (Resolve-Path '\pkg').Path
	Start-Process -Wait -PassThru ".\$Installer" "/quiet AssociateFiles=0 Shortcuts=0 Include_launcher=0 InstallLauncherAllUsers=0 InstallAllUsers=0 TargetDir=$InstallDir DefaultJustForMeTargetDir=$InstallDir DefaultAllUsersTargetDir=$InstallDir"
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'python.exe' | Select-Object -Last 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr exec 'file:///\pkg' {
		python --version
	}
}