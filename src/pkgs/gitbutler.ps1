$global:PwrPackageConfig = @{
	Name = 'gitbutler'
}

function global:Install-PwrPackage {
	$AssetURL = 'https://app.gitbutler.com/downloads/release/windows/x86_64/msi'
	$Response = Invoke-WebRequest $AssetURL -Method 'HEAD'
	$Version = [SemanticVersion]::new($Response.Headers.'Content-Disposition', 'filename=GitButler_([0-9]+)\.([0-9]+)\.([0-9]+)_x64_en-US.msi')
	Write-Host "GitButler $Version"
	$PwrPackageConfig.UpToDate = -not $Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	$Asset = "$env:Temp\GitButler.msi" /quiet /qn
	Invoke-WebRequest -UseBasicParsing $AssetURL -OutFile $Asset
	& $Asset
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'GitButler.exe' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		gitbutler --version
	}
}