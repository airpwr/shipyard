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
	Write-Host 'removing existing rust installation'
	$cargohome = "$env:USERPROFILE\.cargo"
	[IO.Directory]::Delete($cargohome, $true)
	Write-Host 'downloading rustup-init'
	$init = "$env:Temp\rustup-init.exe"
	Invoke-WebRequest 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe' -OutFile $init -UseBasicParsing
	Write-Host "installing rust $($latest.Version)"
	& $init --version
	if ($LASTEXITCODE -ne 0) {
		throw "rustup-init version exit code $LASTEXITCODE"
	}
	& $init -v -y --no-update-default-toolchain
	if ($LASTEXITCODE -ne 0) {
		throw "rustup-init exit code $LASTEXITCODE"
	}
	foreach ($target in @('x86_64-pc-windows-msvc', 'x86_64-pc-windows-gnu', 'i686-pc-windows-msvc', 'i686-pc-windows-gnu')) {
		rustup.exe target add $target
		if ($LASTEXITCODE -ne 0) {
			throw "rustup target add $target exit code $LASTEXITCODE"
		}
	}
	rustup.exe toolchain install $latest.Version
	if ($LASTEXITCODE -ne 0) {
		throw "rustup toolchain install $($latest.Version) exit code $LASTEXITCODE"
	}
	Get-ChildItem $cargohome -Recurse
	robocopy.exe $cargohome '\pkg\.cargo' /np /nfl /ndl /ns /nc /mir
	if ($LASTEXITCODE -ne 1) { # https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy#exit-return-codes
		throw "robocopy exit code $LASTEXITCODE"
	}
	$global:LASTEXITCODE = 0 # Reset robocopy's exit code
	Write-PackageVars @{
		env = @{
			cargo_home = (Split-Path (Get-ChildItem -Path '\pkg' | Select-Object -First 1).FullName -Parent)
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'rustc.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	if (-not $global:PwrPackageConfig.Version) {
		throw 'missing package version'
	}
	$wantver = "rustc $($global:PwrPackageConfig.Version) "
	[IO.Directory]::Delete("$env:USERPROFILE\.cargo", $true)
	Airpower exec 'file:///\pkg' {
		Get-ChildItem $env:CARGO_HOME -Recurse
		$rustver = & rustc.exe --version
		Write-Host "test rust version $rustver"
		if (-not $rustver.ToString().StartsWith($wantver)) {
			throw "wrong version $rustver (want $wantver)"
		}
		"fn main() { println!(`"Hello world`"); }" | Out-File -FilePath main.rs -Encoding utf8
		rustc.exe main.rs
		if ($LASTEXITCODE -ne 0) {
			throw "rustc exit code $LASTEXITCODE"
		}
		$out = & .\main.exe
		if ($out -ne "Hello world") {
			throw "bad program output ``$out``"
		}
	}
}
