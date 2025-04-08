$global:PwrPackageConfig = @{
	Name = 'mingw'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'niXman'
		Repo = 'mingw-builds-binaries'
		AssetPattern = 'x86_64-.+-win32(?:-.+)?-ucrt-.+\.7z'
		TagPattern = '^([0-9]+)\.([0-9]+)\.([0-9]+)-[^-]+(?:-rev([0-9]+))?$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$mingw = "$env:Temp\$($Asset.Name)"
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile $mingw
	Airpower load 7-zip
	& "7z.exe" x -o'\pkg\x64' $mingw | Out-Null
	$Params.AssetPattern = 'i686-.+-win32(?:-.+)?-ucrt-.+\.7z'
	$Asset = Get-GitHubRelease @Params
	$mingw = "$env:Temp\$($Asset.Name)"
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile $mingw
	& "7z.exe" x -o'\pkg\x86' $mingw | Out-Null
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'gcc.exe' | Select-Object -First 1).DirectoryName
		}
		amd64 = @{
			env = @{
				path = (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'gcc.exe' | Select-Object -First 1).DirectoryName
			}
		}
		x64 = @{
			env = @{
				path = (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'gcc.exe' | Select-Object -First 1).DirectoryName
			}
		}
		x86 = @{
			env = @{
				path = (Get-ChildItem -Path '\pkg\x86' -Recurse -Include 'gcc.exe' | Select-Object -First 1).DirectoryName
			}
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		gcc --version
	}
}