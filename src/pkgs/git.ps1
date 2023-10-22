$global:PwrPackageConfig = @{
	Name = 'git'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'git-for-windows'
		Repo = 'git'
		AssetPattern = 'PortableGit-.+?64-bit\.7z\.exe'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)\.windows(\.[0-9]+)$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$git = "$env:Temp\$($Asset.Name)"
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile $git
	Invoke-WebRequest -UseBasicParsing 'https://www.7-zip.org/a/7za920.zip' -OutFile "$env:temp\7z.zip"
	Expand-Archive "$env:temp\7z.zip" "$env:temp\7z"
	& "$env:temp\7z\7za.exe" x -o'\pkg' $git | Out-Null
	& (Get-ChildItem -Path '\pkg' -Recurse -Include 'git.exe' | Select-Object -First 1) config --system --unset credential.helper
	Write-PackageVars @{
		env = @{
			path = (@(
				(Get-ChildItem -Path '\pkg' -Recurse -Include 'gitk.exe' | Select-Object -First 1).DirectoryName,
				(Get-ChildItem -Path '\pkg' -Recurse -Include 'sed.exe' | Select-Object -First 1).DirectoryName,
				(Get-ChildItem -Path '\pkg' -Recurse -Include 'curl.exe' | Select-Object -First 1).DirectoryName
			) -join ';')
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		git --version
		curl.exe --version
		sed --version
	}
}