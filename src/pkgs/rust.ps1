$global:PwrPackageConfig = @{
	Name = 'rust'
}

function global:Install-PwrPackage {
	$params = @{
		Owner = 'rust-lang'
		Repo = 'rust'
		TagPattern = '^([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$latest = Get-GitHubTag @params
	$global:PwrPackageConfig.UpToDate = -not $latest.Version.LaterThan($global:PwrPackageConfig.Latest)
	$global:PwrPackageConfig.Version = $latest.Version.ToString()
	if ($global:PwrPackageConfig.UpToDate) {
		return
	}
	$msi = "$env:Temp\rust.msi"
	Invoke-WebRequest "https://static.rust-lang.org/dist/rust-$($latest.Version)-x86_64-pc-windows-msvc.msi" -OutFile $msi -UseBasicParsing
	msiexec.exe /i $msi /qn /norestart
	if ($LASTEXITCODE -ne 0) {
		throw "msiexec exit code $LASTEXITCODE"
	}
	robocopy.exe "$env:USERPROFILE\.cargo\bin" '\pkg' /MIR
	if ($LASTEXITCODE -ne 1) {
		throw "robocopy exit code $LASTEXITCODE"
	}
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'rustc.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	rustc --version
	pwr exit
}
