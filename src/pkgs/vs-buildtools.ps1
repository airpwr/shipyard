$global:PwrPackageConfig = @{
	Name    = 'vs-buildtools'
	Version = '17.2.3' # see https://docs.microsoft.com/en-us/visualstudio/releases/2022/release-history
	Nonce   = $true
}

function global:Install-PwrPackage {
	$oldPath = $env:Path
	Invoke-WebRequest -UseBasicParsing 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile 'vs_buildtools.exe'
	cmd /S /C 'start /w vs_buildtools.exe --quiet --wait --norestart --nocache --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64 --add Microsoft.VisualStudio.Component.VC.v141.x86.x64 --add Microsoft.VisualStudio.Component.VC.140 --remove Microsoft.VisualStudio.Component.Windows10SDK.10240 --remove Microsoft.VisualStudio.Component.Windows10SDK.10586 --remove Microsoft.VisualStudio.Component.Windows10SDK.14393  --remove Microsoft.VisualStudio.Component.Windows10SDK.19041 || IF "%ERRORLEVEL%"=="3010" EXIT 0'
	Write-Output 'Done Installing'
	mkdir "${env:ProgramFiles(x86)}\pkg" -Force | Out-Null
	New-Item -Type Junction -Target "${env:ProgramFiles(x86)}\pkg" -Path '\pkg'
	Move-Item -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Destination "${env:ProgramFiles(x86)}\pkg\Microsoft Visual Studio"
	Move-Item -Path "${env:ProgramFiles(x86)}\Windows Kits" -Destination "${env:ProgramFiles(x86)}\pkg\Windows Kits"
	Move-Item -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0" -Destination "${env:ProgramFiles(x86)}\pkg\Microsoft Visual Studio 14.0"
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
	foreach ($msvc in @(@{Name = 'msvc143'; Ver = '14.32'}, @{Name = 'msvc140'; Ver = '14.0'}, @{Name = 'msvc141'; Ver = '14.16'}, @{Name = 'msvc142'; Ver = '14.29'})) {
		foreach ($arch in @('x86', 'amd64', 'arm', 'arm64')) {
			if (($msvc.name -eq 'msvc140') -and ($arch -eq 'arm64')) {
				continue # not supported
			}
			Write-Output "Evaluating variables for configuration $($msvc.name) on arch $arch"
			$vars = 'WindowsSdkBinPath', 'WindowsSdkVerBinPath', 'WindowsSDKVersion', 'VCToolsRedistDir', 'VSCMD_ARG_VCVARS_VER', 'UniversalCRTSdkDir', 'WindowsSdkDir', 'VCIDEInstallDir', 'VSCMD_ARG_HOST_ARCH', 'VSCMD_ARG_app_plat', 'VCToolsVersion', 'INCLUDE', 'WindowsLibPath', 'VCToolsInstallDir', 'VCINSTALLDIR', 'VS170COMNTOOLS', 'LIBPATH', 'path', 'UCRTVersion', 'DevEnvDir', 'WindowsSDKLibVersion', 'LIB', 'VSCMD_VER', 'VSINSTALLDIR', 'VSCMD_ARG_TGT_ARCH', 'VisualStudioVersion'
			foreach ($v in $vars) {
				Clear-Item "env:$v" -Force -ErrorAction SilentlyContinue
			}
			Write-Output 'Env Cleared'
			$path = 'C:\windows;C:\windows\system32;C:\windows\system32\WindowsPowerShell\v1.0'
			$env:path = $path
			$vsSetup = "`"$((Get-ChildItem -Path '\pkg' -Recurse -Include 'VsDevCmd.bat' | Select-Object -First 1).FullName)`" -vcvars_ver=$($msvc.ver) -arch=$arch -host_arch=amd64"
			Write-Output 'Starting Dev Setup'
			$vsenv = cmd /S /C "$vsSetup && set"
			$vsenv.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $s = $_.Split('='); if ($s.count -eq 2) { Set-Item "env:$($s[0])" $s[1] } }
			$map = @{}
			foreach ($var in $vars) {
				$map.$var = Get-Item "env:$var" -ErrorAction SilentlyContinue | ForEach-Object { $_.value.Replace("${env:ProgramFiles(x86)}", '\pkg') }
				Write-Output "  $var=$($map.$var)"
			}
			$map.path = $map.path.Replace($path, '')
			if (($msvc.name -eq 'msvc143') -and ($arch -eq 'x86')) {
				$PwrPackageVars.env = $map
			}
			$PwrPackageVars."$($msvc.name)-$arch" = @{env = $map}
		}
	}
	Write-PackageVars $PwrPackageVars
	$env:path = $oldPath
}

function global:Test-PwrPackageInstall {
	Write-Host '--- Testing config default ---'
	pwr sh 'file:///\pkg'
	cl
	pwr exit
	foreach ($msvc in @('msvc143', 'msvc140', 'msvc141', 'msvc142')) {
		foreach ($arch in @('x86', 'amd64', 'arm', 'arm64')) {
			if (($msvc -eq 'msvc140') -and ($arch -eq 'arm64')) {
				continue # not supported
			}
			Write-Host "--- Testing config $msvc-$arch ---"
			pwr sh "file:///\pkg < $msvc-$arch"
			cl
			pwr exit
		}
	}
}

function global:Invoke-DockerBuild($tag) {
	Copy-Item Dockerfile.vs-buildtools -Destination "${env:ProgramFiles(x86)}\pkg\Dockerfile"
	& docker build -t $tag "${env:ProgramFiles(x86)}\pkg"
}