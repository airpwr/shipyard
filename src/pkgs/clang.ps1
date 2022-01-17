$global:PwrPackageConfig = @{
	Name = 'clang'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'llvm'
		Repo = 'llvm-project'
		AssetPattern = '^LLVM-.+-win64\.exe$'
		TagPattern = '^llvmorg-([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Asset = Get-GitHubRelease @Params
	$PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Asset.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	# Install 7zip
	Invoke-WebRequest -UseBasicParsing 'https://www.7-zip.org/a/7za920.zip' -OutFile "$env:temp\7z.zip"
	Expand-Archive "$env:temp\7z.zip" "$env:temp\7z"
	$llvm = "$env:Temp\$($Asset.Name)"
	# Download llvm
	Invoke-WebRequest -UseBasicParsing $Asset.URL -OutFile $llvm
	# Unpack llvm
	& "$env:temp\7z\7za.exe" x -o'\pkg' $llvm
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'clang.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	clang --version
	pwr exit
}