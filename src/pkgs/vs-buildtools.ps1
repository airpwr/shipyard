$global:PwrPackageConfig = @{
	Name = 'vs-buildtools'
}

$global:MSVCVersions = @(
	@{Name = 'msvc143'; Archs = @('x86', 'x64', 'amd64', 'arm', 'arm64')},
	@{Name = 'msvc142'; Ver = '14.29'; Archs = @('x86', 'x64', 'amd64')},
	@{Name = 'msvc141'; Ver = '14.16'; Archs = @('x86', 'x64', 'amd64')},
	@{Name = 'msvc140'; Ver = '14.0';  Archs = @('x86', 'x64', 'amd64', 'arm')}
)

function global:Install-PwrPackage {
	$OldPath = $env:Path
	$VSInfo = $null
	# See https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history
	(Invoke-WebRequest 'https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-history').Content -split '</tr>' | ForEach-Object {
		if ($_ -match '(?s)<tr\b.+\bLTSC\b.+>([0-9]+\.[0-9]+\.[0-9]+)</.+ href="([^"]+/vs_BuildTools\.exe)"') {
			$NewVersion = [SemanticVersion]::new($Matches[1])
			if (-not $VSInfo -or $NewVersion.LaterThan($VSInfo.Version)) {
				$VSInfo = @{Version = $NewVersion; URI = $Matches[2]}
			}
		}
	}
	if (-not $VSInfo) {
		Write-Error 'No Visual Studio Build Tools found on website'
	}
	$PwrPackageConfig.Version = $VSInfo.Version.ToString()
	$PwrPackageConfig.UpToDate = -not $VSInfo.Version.LaterThan($PwrPackageConfig.Latest)
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	Write-Output "Installing Visual Studio Build Tools v$($PwrPackageConfig.Version)..."
	Invoke-WebRequest -UseBasicParsing $VSInfo.URI -OutFile 'vs_buildtools.exe'
	$Options = @(
		"--add Microsoft.VisualStudio.Workload.VCTools",
		"--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
		"--add Microsoft.VisualStudio.Component.VC.Tools.ARM",
		"--add Microsoft.VisualStudio.Component.VC.Tools.ARM64",
		"--add Microsoft.VisualStudio.Component.VC.Tools.ARM64EC",
		"--add Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64",
		"--add Microsoft.VisualStudio.Component.VC.v141.x86.x64",
		"--add Microsoft.VisualStudio.Component.VC.140"
	)
	$setup = Start-Process ./vs_buildtools.exe "--quiet --wait --norestart --nocache --installPath `"%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools`" $($Options -join ' ')" -Wait -PassThru
	if ($setup.ExitCode -NotIn @(0, 3010)) {
		Write-Error "Visual Studio Build Tools setup failed with error code $($setup.ExitCode)"
	}
	Write-Output 'Done Installing'
	mkdir "${env:ProgramFiles(x86)}\pkg" -Force | Out-Null
	New-Item -Type Junction -Target "${env:ProgramFiles(x86)}\pkg" -Path '\pkg'
	Move-Item "${env:ProgramFiles(x86)}\Microsoft Visual Studio*", "${env:ProgramFiles(x86)}\Windows Kits" "${env:ProgramFiles(x86)}\pkg\"
	[System.IO.File]::WriteAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\core\winsdk.bat',
		[System.IO.File]::ReadAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\core\winsdk.bat').
		Replace('reg query "%1\Microsoft\Microsoft SDKs\Windows\v10.0" /v "InstallationFolder"', 'echo InstallationFolder X %~dp0..\..\..\..\..\..\..\Windows Kits\10\').
		Replace('reg query "%1\Microsoft\Microsoft SDKs\Windows\v8.1" /v "InstallationFolder"', 'echo InstallationFolder X %~dp0..\..\..\..\..\..\..\Windows Kits\8.1\').
		Replace('reg query "%1\Microsoft\Windows Kits\Installed Roots" /v "KitsRoot10"', 'echo KitsRoot10 X %~dp0..\..\..\..\..\..\..\Windows Kits\10\'))
	[System.IO.File]::WriteAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\ext\vcvars\vcvars140.bat',
		[System.IO.File]::ReadAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\ext\vcvars\vcvars140.bat').
		Replace('reg query "%1\Microsoft\VisualStudio\SxS\VC7" /v "14.0"', 'echo 14.0 X %~dp0..\..\..\..\..\..\..\..\Microsoft Visual Studio 14.0\VC\'))
	Write-Output 'Done Hacking'
	$PwrPackageVars = @{}
	foreach ($msvc in $MSVCVersions) {
		foreach ($arch in $msvc.Archs) {
			Write-Output "Evaluating variables for configuration $($msvc.name) on arch $arch"
			$vars = 'WindowsSdkBinPath', 'WindowsSdkVerBinPath', 'WindowsSDKVersion', 'VCToolsRedistDir', 'VSCMD_ARG_VCVARS_VER', 'UniversalCRTSdkDir', 'WindowsSdkDir', 'VCIDEInstallDir', 'VSCMD_ARG_HOST_ARCH', 'VSCMD_ARG_app_plat', 'VCToolsVersion', 'INCLUDE', 'EXTERNAL_INCLUDE', 'WindowsLibPath', 'VCToolsInstallDir', 'VCINSTALLDIR', 'VS170COMNTOOLS', 'LIBPATH', 'path', 'UCRTVersion', 'DevEnvDir', 'WindowsSDKLibVersion', 'LIB', 'VSCMD_VER', 'VSINSTALLDIR', 'VSCMD_ARG_TGT_ARCH', 'VisualStudioVersion'
			foreach ($v in $vars) {
				Clear-Item "env:$v" -Force -ErrorAction SilentlyContinue
			}
			Write-Output 'Env Cleared'
			$path = 'C:\windows;C:\windows\system32;C:\windows\system32\WindowsPowerShell\v1.0'
			$env:path = $path
			$vsSetup = "`"$((Get-ChildItem -Path '\pkg' -Recurse -Include 'VsDevCmd.bat' | Select-Object -First 1).FullName)`" $(if ($msvc.Ver) { "-vcvars_ver=$($msvc.Ver)" }) -arch=$arch -host_arch=amd64"
			Write-Output 'Starting Dev Setup'
			$vsenv = cmd /S /C "$vsSetup && set"
			$vsenv.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $s = $_.Split('='); if ($s.count -eq 2) { Set-Item "env:$($s[0])" $s[1]; if ($s[1].Length -gt 2000) { Write-Warning "Long environment variable detected: $($s[0])" } } }
			$map = @{}
			foreach ($var in $vars) {
				$map.$var = Get-Item "env:$var" -ErrorAction SilentlyContinue | ForEach-Object { $_.value.Replace("${env:ProgramFiles(x86)}", '\pkg') }
				Write-Output "  $var=$($map.$var)"
			}
			$map.path = $map.path.Replace($path, '')
			if ($MSVCVersions.IndexOf($msvc) -eq 0) {
				$PwrPackageVars.$arch = @{env = $map}
				if ($msvc.Archs.IndexOf($arch) -eq 0) {
					$PwrPackageVars.env = $map
				}
			} elseif ($msvc.Archs.IndexOf($arch) -eq 0) {
				$PwrPackageVars."$($msvc.name)" = @{env = $map}
			}
			$PwrPackageVars."$($msvc.name)-$arch" = @{env = $map}
		}
	}
	Get-ChildItem '\pkg\Windows Kits' '10.0.*' -Recurse -Exclude $PwrPackageVars.env.UCRTVersion | Remove-Item -Recurse -Force
	Write-PackageVars $PwrPackageVars
	$env:path = $oldPath
}

function global:Test-PwrPackageInstall {
	Write-Host '--- Testing config default ---'
	pwr sh 'file:///\pkg'
	cl
	pwr exit
	foreach ($msvc in $MSVCVersions) {
		foreach ($arch in $msvc.Archs) {
			Write-Host "--- Testing config $($msvc.name)-$arch ---"
			pwr sh "file:///\pkg < $($msvc.name)-$arch"
			cl
			pwr exit
		}
	}
}

function global:Invoke-DockerBuild($tag) {
	Copy-Item Dockerfile -Destination "${env:ProgramFiles(x86)}\Dockerfile.vs-buildtools"
	& docker build -f "${env:ProgramFiles(x86)}\Dockerfile.vs-buildtools" -t $tag "${env:ProgramFiles(x86)}\pkg"
}