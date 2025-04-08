$global:PwrPackageConfig = @{
	Name = 'jdk'
	Matcher = '^jdk-11\.'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'adoptium'
		Repo = 'temurin11-binaries'
		AssetPattern = '^.*jdk_x64_windows_hotspot_.+?\.zip$'
		TagPattern = "^jdk-(11)\.([0-9]+)\.([0-9]+)((\.[0-9]+)?(\+[0-9]+)?)$"
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
	$Params_x86 = @{
		AssetName = $Asset.Name.Replace('_x64_', '_x86-32_')
		AssetURL = $Asset.URL.Replace('_x64_', '_x86-32_')
		ToolDir = '\pkg-preinstall\x86'
	}
	Install-BuildTool @Params_x86
	New-Item -Path '\pkg\x86' -ItemType Directory -Force -ErrorAction Ignore | Out-Null
	Move-Item "$(Get-ChildItem -Path '\pkg-preinstall\x86' -Recurse -Include 'bin' | Select-Object -First 1 | ForEach-Object { Split-Path $_ })\*" '\pkg\x86'
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
		x86 = @{
			env = @{
				java_home = (Split-Path (Get-ChildItem -Path '\pkg\x86' -Recurse -Include 'bin' | Select-Object -First 1).FullName -Parent)
				path = (Get-ChildItem -Path '\pkg\x86' -Recurse -Include 'java.exe' | Select-Object -First 1).DirectoryName
			}
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		java -version
		javac -version
	}
	Airpower exec 'file:///\pkg<x86' {
		java -version
		javac -version
	}
}
