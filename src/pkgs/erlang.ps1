$global:PwrPackageConfig = @{
	Name = 'erlang'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'erlang'
		Repo = 'otp'
		AssetPattern = 'otp_win64_.+\.exe'
		TagPattern = '^OTP-([0-9]+)\.([0-9]+)\.([0-9]+)\.?([0-9]+)?$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$erlang = "$env:Temp\$($Asset.Name)"
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile $erlang
	Airpower load 7-zip
	& "7z.exe" x -o'\pkg' $erlang | Out-Null
	$start = (Get-ChildItem -Path '\pkg' -Recurse -Include 'start.boot' | Select-Object -First 1).DirectoryName
	New-Item -Path '\pkg\bin' -ItemType Directory -Force -ErrorAction Ignore | Out-Null
	robocopy $start '\pkg\bin' /mir | Out-Null
	if ($LASTEXITCODE -eq 1) {
		$global:LASTEXITCODE = 0
	}
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'erl.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
	}
}