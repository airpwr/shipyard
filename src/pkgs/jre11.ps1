$global:PwrPackageConfig = @{
	Name = 'jre'
	Matcher = '^jre-11\.'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'adoptium'
		Repo = 'temurin11-binaries'
		AssetPattern = '^.*jre_x64_windows_hotspot_.+?\.zip$'
		TagPattern = "^jdk-([0-9]+)\.([0-9]+)\.([0-9]+)[^']+$"
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
	}
	Install-BuildTool @Params
	$Params_x86 = @{
		AssetName = $Asset.Name.Replace('_x64_', '_x86-32_')
		AssetURL = $Asset.URL.Replace('_x64_', '_x86-32_')
		ToolDir = '\pkg\x86'
	}
	Install-BuildTool @Params_x86
	Write-PackageVars @{
		env = @{
			java_home = (Split-Path (Get-ChildItem -Path '\pkg' -Exclude 'x86' -Recurse -Include 'bin' | Select-Object -First 1).FullName -Parent)
			path = (Get-ChildItem -Path '\pkg' -Exclude 'x86' -Recurse -Include 'java.exe' | Select-Object -First 1).DirectoryName
		}
		amd64 = @{
			env = @{
				java_home = (Split-Path (Get-ChildItem -Path '\pkg' -Exclude 'x86' -Recurse -Include 'bin' | Select-Object -First 1).FullName -Parent)
				path = (Get-ChildItem -Path '\pkg' -Exclude 'x86' -Recurse -Include 'java.exe' | Select-Object -First 1).DirectoryName
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
	pwr sh 'file:///\pkg'
	java -version
	pwr exit
	pwr sh 'file:///\pkg<x86'
	java -version
	pwr exit
}