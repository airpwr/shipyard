$global:PwrPackageConfig = @{
	Name = 'cmake-converter'
}

function global:Install-PwrPackage {
	$BatFile = "\pkg\cmake-converter.bat"
	New-Item -Type Directory -Force (Split-Path $BatFile) | Out-Null
	Set-Content $BatFile @"
	@echo off

	python -c "import cmake_converter" 2> NUL || python -m pip install --trusted-host pypi.org cmake_converter --quiet --exists-action i
	python -m cmake_converter.main %*
"@

	# Check version
	Airpower exec python {
		&$BatFile --help
		$script:Version = [SemanticVersion]::new((python -m pip list | Select-String -Pattern '(?<=cmake-converter\s+)[0-9.]+').Matches[0].Value)
	}
	$PwrPackageConfig.UpToDate = -not $Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	Write-PackageVars @{
		env = @{
			path = (Split-Path $BatFile)
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec python, 'file:///\pkg' {
		# Run a test from the repo
		Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/pavelliavonau/cmakeconverter/zipball/v2.2.0" -OutFile "$env:Temp\repo.zip"
		Expand-Archive "$env:Temp\repo.zip" '\repo'
		cmake-converter -s "$((Get-ChildItem -Path '\repo' -Recurse -Include 'setup.py' | Select-Object -First 1).DirectoryName)\test\datatest\sln\cpp.sln"
	}
}
