$global:PwrPackageConfig = @{
	Name = 'maven'
}

function global:Install-PwrPackage {
	$Version = $null
	$PkgInfo = $null
	(Invoke-WebRequest 'https://maven.apache.org/download.html').Content -split '<a ' | ForEach-Object {
		if ($_ -match '(?s)(?<=\bhref=")([^"]+/apache-maven-([0-9]+(?:\.[0-9]+){0,3})-bin.zip)(?=")') {
			$Version = [SemanticVersion]::new($Matches[2])
			if ($Version -notin $PwrPackageConfig.Tags -and (-not $PkgInfo -or $Version.LaterThan($PkgInfo.Version))) {
				$PkgInfo = @{Version = $Version; URI = $Matches[1]}
			}
		}
	}
	if (-not $Version) {
		Write-Error 'No maven release found on website'
	}
	if (-not $PkgInfo) {
		$PwrPackageConfig.Version = $Version.ToString()
		$PwrPackageConfig.UpToDate = $true
		return
	}
	$PwrPackageConfig.Version = $PkgInfo.Version.ToString()
	Write-Output "Installing maven v$($PwrPackageConfig.Version)..."
	Install-BuildTool 'maven.zip' $PkgInfo.URI "$env:Temp\maven-unzip"
	Move-Item (Get-Item "$env:Temp\maven-unzip\*") '\pkg'
	Write-PackageVars @{
		env = @{
			path = (Get-ChildItem -Path '\pkg' -Recurse -Include 'mvn.cmd' | Select-Object -First 1).DirectoryName
		}
	}
}

function global:Test-PwrPackageInstall {
	Airpower exec 'file:///\pkg' {
		mvn -version
	}
}
