$global:PwrPackageConfig = @{
	Name = 'vs'
	Version = '17.142.0'
	Nonce = $true
}

function global:Install-PwrPackage {
	mkdir '\vs' -Force | Out-Null
	[Environment]::SetEnvironmentVariable("ProgramFiles(x86)", "\vs", "User")
	Invoke-WebRequest -UseBasicParsing 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile 'vs_buildtools.exe'
	cmd /S /C 'start /w vs_buildtools.exe --quiet --wait --norestart --nocache --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --remove Microsoft.VisualStudio.Component.Windows10SDK.10240 --remove Microsoft.VisualStudio.Component.Windows10SDK.10586 --remove Microsoft.VisualStudio.Component.Windows10SDK.14393 --remove Microsoft.VisualStudio.Component.Windows81SDK || IF "%ERRORLEVEL%"=="3010" EXIT 0'
	robocopy /MIR "${env:ProgramFiles(x86)}\Microsoft Visual Studio" "\pkg\Microsoft Visual Studio" | Out-Null
	robocopy /MIR "${env:ProgramFiles(x86)}\Windows Kits" "\pkg\Windows Kits" | Out-Null
	$winSdk = '\pkg\Windows Kits\10\'
	Write-PackageVars @{
		reg = @{
			'HKCU:\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0' = @{
				InstallationFolder = $winSdk
			}
			'HKCU:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' = @{
				KitsRoot10 = $winSdk
			}
		}
		var = @{
			vsSetup = "`"$((Get-ChildItem -Path '\pkg' -Recurse -Include 'VsDevCmd.bat' | Select-Object -First 1).FullName)`" -vcvars_ver=14.29 -arch=x64 -host_arch=x64"
		}
		run = @(
			'$vsenv = cmd /S /C "$vsSetup && set"',
			'$vsenv.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $s = $_.Split("="); if ($s.count -eq 2) { Set-Item "env:$($s[0])" $s[1] } }'
		)
	}
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
	(Get-ChildItem -Path '\pkg' -Recurse -Include 'VsDevCmd.bat' | Select-Object -First 1).FullName
	Get-ChildItem '\pkg'
}