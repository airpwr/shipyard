$global:PwrPackageConfig = @{
	Name = '7-zip'
	Version = '21.7.0'
	Nonce = $true
}

function global:Install-PwrPackage {
	$z = "$env:Temp\7z2107.exe"
	Invoke-WebRequest -UseBasicParsing 'https://www.7-zip.org/a/7z2107-x64.exe' -OutFile $z
	Invoke-WebRequest -UseBasicParsing 'https://www.7-zip.org/a/7za920.zip' -OutFile "$env:temp\7z.zip"
	Expand-Archive "$env:temp\7z.zip" "$env:temp\7z"
	& "$env:temp\7z\7za.exe" x -o'\pkg' $z
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include '7z.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	7z
	pwr exit
}