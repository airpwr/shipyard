$global:PwrPackageConfig = @{
	Name = 'vs'
	Version = '17.142.1'
	Nonce = $true
}

function global:Install-PwrPackage {
	$comspec = (get-command cmd).path
	& $comspec /S /C "echo test 123"
	mkdir '\vs' -Force | Out-Null
	[Environment]::SetEnvironmentVariable("ProgramFiles(x86)", "\vs", "User")
	Invoke-WebRequest -UseBasicParsing 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile 'vs_buildtools.exe'
	cmd /S /C 'start /w vs_buildtools.exe --quiet --wait --norestart --nocache --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --remove Microsoft.VisualStudio.Component.Windows10SDK.10240 --remove Microsoft.VisualStudio.Component.Windows10SDK.10586 --remove Microsoft.VisualStudio.Component.Windows10SDK.14393 --remove Microsoft.VisualStudio.Component.Windows81SDK || IF "%ERRORLEVEL%"=="3010" EXIT 0'
	robocopy /MIR "${env:ProgramFiles(x86)}\Microsoft Visual Studio" "\pkg\Microsoft Visual Studio" | Out-Null
	robocopy /MIR "${env:ProgramFiles(x86)}\Windows Kits" "\pkg\Windows Kits" | Out-Null
	$winSdk = '\pkg\Windows Kits\10\'
	Set-RegistryKey 'HKCU:\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0' 'InstallationFolder' $winSdk
	Set-RegistryKey 'HKCU:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' 'KitsRoot10' $winSdk
	Clear-Item "env:$key" -Force -ErrorAction SilentlyContinue
	$comspec = (get-command cmd).path
	$env:path = "\windows;\windows\system32"
	$vsSetup = "`"$((Get-ChildItem -Path '\pkg' -Recurse -Include 'VsDevCmd.bat' | Select-Object -First 1).FullName)`" -vcvars_ver=14.29 -arch=x64 -host_arch=x64"
	$vsenv = & $comspec /S /C "$vsSetup && set"
	$vsenv.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $s = $_.Split("="); if ($s.count -eq 2) { Set-Item "env:$($s[0])" $s[1] } }
	$vars = 'WindowsSdkVerBinPath', 'VCToolsRedistDir', 'VSCMD_ARG_VCVARS_VER', 'UniversalCRTSdkDir', 'WindowsSdkDir', 'VCIDEInstallDir', 'VSCMD_ARG_HOST_ARCH', 'VCToolsVersion', 'INCLUDE', 'WindowsLibPath', 'VCToolsInstallDir', 'VCINSTALLDIR', 'VS170COMNTOOLS', 'LIBPATH', 'path', 'UCRTVersion21', 'DevEnvDir', 'WindowsSDKLibVersion', 'LIB', 'VSCMD_VER', 'VSINSTALLDIR', 'VSCMD_ARG_TGT_ARCH'
	$map = @{}
	foreach ($var in $vars) {
		$map.$var = (get-item "env:$var").value
	}
	Write-PackageVars $map
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}