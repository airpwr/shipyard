$global:PwrPackageConfig = @{
	Name = 'vs-buildtools'
	Version = '17.142.2'
	Nonce = $true
}

function global:Install-PwrPackage {
	$oldPath = $env:Path
	mkdir '\vs' -Force | Out-Null
	[Environment]::SetEnvironmentVariable("ProgramFiles(x86)", "\vs", "User")
	Invoke-WebRequest -UseBasicParsing 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile 'vs_buildtools.exe'
	cmd /S /C 'start /w vs_buildtools.exe --quiet --wait --norestart --nocache --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64 --add Microsoft.VisualStudio.Component.VC.v141.x86.x64 --add Microsoft.VisualStudio.Component.VC.140 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --remove Microsoft.VisualStudio.Component.Windows10SDK.10240 --remove Microsoft.VisualStudio.Component.Windows10SDK.10586 --remove Microsoft.VisualStudio.Component.Windows10SDK.14393 --remove Microsoft.VisualStudio.Component.Windows81SDK || IF "%ERRORLEVEL%"=="3010" EXIT 0'
	Write-Output 'Done Installing'
	New-Item -Type Junction -Target "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Path "\pkg\Microsoft Visual Studio"
	New-Item -Type Junction -Target "${env:ProgramFiles(x86)}\Windows Kits" -Path "\pkg\Windows Kits"
	New-Item -Type Junction -Target "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0" -Path "\pkg\Microsoft Visual Studio 14.0"
	[System.IO.File]::WriteAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\core\winsdk.bat',
		[System.IO.File]::ReadAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\core\winsdk.bat').
			Replace('reg query "%1\Microsoft\Microsoft SDKs\Windows\v10.0" /v "InstallationFolder"', 'echo InstallationFolder X %~dp0..\..\..\..\..\..\..\Windows Kits\10\').
			Replace('reg query "%1\Microsoft\Microsoft SDKs\Windows\v8.1" /v "InstallationFolder"', 'echo InstallationFolder X %~dp0..\..\..\..\..\..\..\Windows Kits\8.1\').
			Replace('reg query "%1\Microsoft\Windows Kits\Installed Roots" /v "KitsRoot10"', 'echo KitsRoot10 X %~dp0..\..\..\..\..\..\..\Windows Kits\10\'))
	[System.IO.File]::WriteAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\ext\vcvars\vcvars140.bat',
		[System.IO.File]::ReadAllText('\pkg\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\vsdevcmd\ext\vcvars\vcvars140.bat').
			Replace('reg query "%1\Microsoft\VisualStudio\SxS\VC7" /v "14.0"', 'echo 14.0 X %~dp0..\..\..\..\..\..\..\..\Microsoft Visual Studio 14.0\VC\'))
	Write-Output 'Done Hacking'
	$vars = 'WindowsSdkVerBinPath', 'VCToolsRedistDir', 'VSCMD_ARG_VCVARS_VER', 'UniversalCRTSdkDir', 'WindowsSdkDir', 'VCIDEInstallDir', 'VSCMD_ARG_HOST_ARCH', 'VCToolsVersion', 'INCLUDE', 'WindowsLibPath', 'VCToolsInstallDir', 'VCINSTALLDIR', 'VS170COMNTOOLS', 'LIBPATH', 'path', 'UCRTVersion', 'DevEnvDir', 'WindowsSDKLibVersion', 'LIB', 'VSCMD_VER', 'VSINSTALLDIR', 'VSCMD_ARG_TGT_ARCH'
	foreach ($v in $vars) {
		Clear-Item "env:$v" -Force -ErrorAction SilentlyContinue
	}
	Write-Output 'Env Cleared'
	$path = "C:\windows;C:\windows\system32;C:\windows\system32\WindowsPowerShell\v1.0"
	$env:path = $path
	$vsSetup = "`"$((Get-ChildItem -Path '\pkg' -Recurse -Include 'VsDevCmd.bat' | Select-Object -First 1).FullName)`" -arch=x64 -host_arch=x64"
	Write-Output 'Starting Dev Setup'
	$vsenv = cmd /S /C "$vsSetup && set"
	Write-Output $vsenv
	$vsenv.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $s = $_.Split("="); if ($s.count -eq 2) { Set-Item "env:$($s[0])" $s[1] } }
	$map = @{}
	foreach ($var in $vars) {
		$map.$var = (get-item "env:$var" -ErrorAction SilentlyContinue).value
	}
	$map.path = $map.path.Replace($path, '')
	Write-PackageVars @{ env = $map }
	$env:path = $oldPath
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	cl
	& $env:ComSpec /c 'VsDevCmd -vcvars_ver=14.0 -arch=x64 -host_arch=x64 && cl'
	pwr exit
}