$global:PwrPackageConfig = @{
	Name = 'jre'
	Matcher = '^jre-25\.'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'adoptium'
		Repo = 'temurin25-binaries'
		AssetPattern = '^.*jre_x64_windows_hotspot_.+?\.zip$'
		TagPattern = "^jdk-(25)(?:\.([0-9]+)(?:\.([0-9]+))?)?(\+[0-9]+)?$"
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Params = @{
		AssetName = $Asset.Name
		AssetURL = $Asset.URL
		ToolDir = '\pkg-preinstall\x64'
	}
	Install-BuildTool @Params
	New-Item -Path '\pkg\x64' -ItemType Directory -Force -ErrorAction Ignore | Out-Null
	Move-Item "$(Get-ChildItem -Path '\pkg-preinstall\x64' -Recurse -Include 'bin' | Select-Object -First 1 | ForEach-Object { Split-Path $_ })\*" '\pkg\x64'
	Write-PackageVars @{
		env = @{
			java_home = (Split-Path (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'bin' | Select-Object -First 1).FullName -Parent)
			path = (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'java.exe' | Select-Object -First 1).DirectoryName
		}
		amd64 = @{
			env = @{
				java_home = (Split-Path (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'bin' | Select-Object -First 1).FullName -Parent)
				path = (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'java.exe' | Select-Object -First 1).DirectoryName
			}
		}
		x64 = @{
			env = @{
				java_home = (Split-Path (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'bin' | Select-Object -First 1).FullName -Parent)
				path = (Get-ChildItem -Path '\pkg\x64' -Recurse -Include 'java.exe' | Select-Object -First 1).DirectoryName
			}
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		java -version
	}
}
