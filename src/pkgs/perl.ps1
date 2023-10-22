$global:PwrPackageConfig = @{
	Name = 'perl'
}

function global:Install-PwrPackage {
	$List = (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/StrawberryPerl/strawberryperl.com/gh-pages/releases.json').Content | ConvertFrom-Json
	foreach ($Item in $List) {
		if ($Item.archname -eq 'MSWin32-x64-multi-thread') {
			$Version = $Item.version
			$AssetName = "strawberry-perl-$Version.zip"
			$Params = @{
				AssetName = $AssetName
				AssetURL = $Item.edition.portable.url
			}
			$v = [SemanticVersion]::new($Version, '^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)')
			$PwrPackageConfig.UpToDate = -not $v.LaterThan($PwrPackageConfig.Latest)
			$PwrPackageConfig.Version = $v.ToString()
			if ($PwrPackageConfig.UpToDate) {
				return
			}
			Install-BuildTool @Params
			$MakeDirectory = (Get-ChildItem -Path '\pkg' -Recurse -Include 'gmake.exe' | Select-Object -First 1).DirectoryName
			if (-not (Test-Path $MakeDirectory\make.exe)) {
				New-Item -ItemType HardLink $MakeDirectory\make.exe -Target $MakeDirectory\gmake.exe
			}
			Write-PackageVars @{
				env = @{
					path = (@(
						(Get-ChildItem -Path '\pkg' -Recurse -Include 'perl.exe' | Select-Object -First 1).DirectoryName,
						$MakeDirectory
					) -join ';')
				}
			}
			return
		}
	}
	Write-Error "Failed to find an x64 build for StrawberryPerl"
}

function global:Test-PwrPackageInstall {
	Get-Content '\pkg\.pwr'
}