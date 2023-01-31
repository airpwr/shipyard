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
	$cargohome = "$env:USERPROFILE\.cargo\bin" # Cargo installed by default
	if ([IO.Directory]::Exists($cargohome)) {
		Write-Host "removing default rust installation at $cargohome"
		[IO.Directory]::Delete($cargohome, $true)
	}
	$idx = $env:Path.IndexOf($cargohome)
	if ($idx -ge 0) {
		$env:Path = $env:Path.Remove($idx, $cargohome.Length)
	}
	$env:CARGO_HOME = '\pkg'
	Write-Host 'downloading rustup'
	$rustup = "$env:Temp\rustup-init.exe"
	Invoke-WebRequest 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' -OutFile $rustup -UseBasicParsing
	Write-Host "installing rust $($latest.Version)"
	& $rustup -v -y --no-update-default-toolchain
	if ($LASTEXITCODE -ne 0) {
		throw "rustup-init exit code $LASTEXITCODE"
	}
	& "$env:CARGO_HOME\bin\rustup.exe" toolchain install $latest.Version
	if ($LASTEXITCODE -ne 0) {
		throw "rustup exit code $LASTEXITCODE"
	}
	& "\pkg\bin\rustc.exe" --version
	Write-PackageVars @{
		env = @{
			cargo_home = (Split-Path (Get-ChildItem -Path '\pkg' -Recurse -Include 'bin' | Select-Object -First 1).FullName -Parent)
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'rustc.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	if (-not $global:PwrPackageConfig.Version) {
		throw 'missing package version'
	}
	$wantver = "rustc $($global:PwrPackageConfig.Version)"
	$env:Path = "$env:AppData\pwr\cmd" # TODO: Remove when pwr version >= 0.6.0
	pwr sh 'file:///\pkg'
	$rustver = & rustc.exe --version
	if (-not $rustver.ToString().StartsWith($wantver)) {
		& "\pkg\bin\rustc.exe" --version
		throw "wrong version $rustver (want $wantver)"
	}
	pwr exit
	Write-Host $rustver
}
