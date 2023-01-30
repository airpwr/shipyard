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
	$installdir = "$env:USERPROFILE\.cargo\bin"
	# $env:Path
	[IO.Directory]::Delete($installdir, $true)
	Write-Host "downloading rust $($latest.Version)"
	Invoke-WebRequest "https://static.rust-lang.org/dist/rust-$($latest.Version)-x86_64-pc-windows-msvc.msi" -OutFile $msi -UseBasicParsing
	Write-Host "installing $msi"
	# icacls.exe "C:\Windows\Temp" /q /c /t /grant Users:F /T
	# icacls.exe "$env:Temp" /q /c /t /grant Users:F /T
	msiexec.exe /i $msi /quiet /passive /qn # /norestart
	if ($LASTEXITCODE -ne 0) {
		throw "msiexec exit code $LASTEXITCODE"
	}
	# while (-not [IO.File]::Exists("$installdir\rustc.exe")) {
	# 	Start-Sleep -Seconds 2
	# }
	robocopy.exe $installdir '\pkg' /MIR
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
	pwr exit
	$rustver = & '\pkg\rustc.exe' --version
	Write-Host $rustver
	$wantver = "rustc $($global:PwrPackageConfig.Version)"
	if (-not $rustver.ToString().StartsWith($wantver)) {
		throw "wrong version $rustver (want $wantver)"
	}
	# Write-Host $rustver
}
