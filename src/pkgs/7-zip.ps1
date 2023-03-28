$global:PwrPackageConfig = @{
	Name = '7-zip'
	Version = '22.1.0'
	Nonce = $true
}

function global:Install-PwrPackage {
	$z = "$env:Temp\7zInstall.exe"
	Invoke-WebRequest -UseBasicParsing 'https://www.7-zip.org/a/7z2201-x64.exe' -OutFile $z
	Invoke-WebRequest -UseBasicParsing 'https://www.7-zip.org/a/7za920.zip' -OutFile "$env:temp\7z.zip"
	Expand-Archive "$env:temp\7z.zip" "$env:temp\7z"
	& "$env:temp\7z\7za.exe" x -o'\pkg' $z | Out-Null
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include '7z.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr exec 'file:///\pkg' {
		7z
	}
}
