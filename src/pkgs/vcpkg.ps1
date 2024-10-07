$global:PwrPackageConfig = @{
	Name = 'vcpkg'
}

function global:Install-PwrPackage {
	$params = @{
		Owner = 'Microsoft'
		Repo = 'vcpkg'
		TagPattern = '^([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$latest = Get-GitHubTag @params
	$global:PwrPackageConfig.UpToDate = -not $latest.Version.LaterThan($global:PwrPackageConfig.Latest)
	$global:PwrPackageConfig.Version = $latest.Version.ToString()
	if ($global:PwrPackageConfig.UpToDate) {
		return
	}
	$url = "https://github.com/microsoft/vcpkg.git"
	$v = "{0:D4}.{1:D2}.{2:D2}" -f $latest.Version.Major, $latest.Version.Minor, $latest.Version.Patch
	git.exe clone --separate-git-dir '.git.vcpkg' --depth 1 --branch $v $url '\pkg'
	if ($LASTEXITCODE -ne 0) {
		throw "git clone --separate-git-dir '.git.vcpkg' --depth 1 --branch $v $url '\pkg' exit code $LASTEXITCODE"
	}
	Write-Host "installing vcpkg $v"
	Push-Location '\pkg'
	.\bootstrap-vcpkg.bat -disableMetrics
	Get-ChildItem .
	Pop-Location
	Write-PackageVars @{
		env = @{
			vcpkg_root = '\pkg'
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'vcpkg.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		vcpkg.exe --version
	}
}
