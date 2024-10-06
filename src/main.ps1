. "$PSScriptRoot\util.ps1"

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

function Clear-PwrPackageScript {
	Remove-Item Function:\Install-PwrPackage -Force -ErrorAction SilentlyContinue
	Remove-Item Function:\Test-PwrPackageInstall -Force -ErrorAction SilentlyContinue
	Clear-Variable 'PwrPackageConfig' -Force -ErrorAction SilentlyContinue
}

function Test-PwrPackageScript {
	Get-Item Function:\Install-PwrPackage | Out-Null
	Get-Item Function:\Test-PwrPackageInstall | Out-Null
	Get-Variable 'PwrPackageConfig' | Out-Null
	if (-not $PwrPackageConfig.Name) {
		Write-Error "shipyard: PwrPackageConfig missing name property"
	}
	if ($PwrPackageConfig.Nonce -and (-not $PwrPackageConfig.Version)) {
		Write-Error "shipyard: PwrPackageConfig missing version property"
	}
}

function Invoke-PwrPackageScan {
	Set-Service -Name wuauserv -StartupType Manual -Status Running
	(Get-Service wuauserv).WaitForStatus('Running')
	Update-MpSignature
	Start-MpScan -ScanType CustomScan -ScanPath (Resolve-Path '\pkg').Path
	Get-MpThreatDetection
}

function Invoke-DockerBuild($tag) {
	if (Get-Command 'Invoke-CustomDockerBuild' -ErrorAction SilentlyContinue) {
		Write-Host 'Using custom docker build'
		Invoke-CustomDockerBuild $tag
	} else {
		& docker build -f Dockerfile -t $tag \pkg
	}
}

function Invoke-DockerPush($name, $version) {
	$tag = "airpower/shipyard:$name-$($version.Replace('+', '_'))"
	Invoke-DockerBuild $tag
	& docker image push $tag
}

function Invoke-PwrInit {
	if (-not $PwrPackageConfig.Nonce) {
		$tagList = Get-DockerTags 'airpower/shipyard'
		$latest = [SemanticVersion]::new()
		$namePart = "$($PwrPackageConfig.Name)-"
		$matcher = if ($PwrPackageConfig.Matcher) { $PwrPackageConfig.Matcher } else { "^$namePart" }
		$PwrPackageConfig.Tags = @()
		foreach ($item in $tagList.tags) {
			if ($item -match $matcher) {
				$v = [SemanticVersion]::new($item.Substring($namePart.length).Replace('_', '+'))
				$PwrPackageConfig.Tags += $v
				if ($v.LaterThan($latest)) {
					$latest = $v
				}
			}
		}
		$PwrPackageConfig.Latest = $latest
	}
}

function Invoke-PwrScript($pkg) {
	$ProgressPreference = 'SilentlyContinue'
	& $pkg
	Invoke-PwrInit
	Install-PwrPackage
	if ($LASTEXITCODE -ne 0) {
		throw "install package completed with exit code $LASTEXITCODE"
	}
	Write-Output "shipyard: $($PwrPackageConfig.Name) v$($PwrPackageConfig.Version) is $(if ($PwrPackageConfig.UpToDate) { 'UP-TO-DATE' } else { 'OUT-OF-DATE' })"
	if (-not $PwrPackageConfig.UpToDate) {
		Test-PwrPackageInstall
		if ($LASTEXITCODE -ne 0) {
			throw "test package completed with exit code $LASTEXITCODE"
		}
		tar.exe -czf 'pkg.tar.gz' '\pkg'
		(Get-Item 'pkg.tar.gz').Length / 1MB
	}
}

function Save-WorkflowMatrix {
	$tagList = Get-DockerTags 'airpower/shipyard'
	$pkgs = @()
	$scripts = Get-ChildItem . -Include '*.ps1' -Recurse | Where-Object { $_.FullName -match [Regex]::Escape('\pkgs\') }
	foreach ($script in $scripts) {
		Write-Output "shipyard: analyzing $($script.Name)"
		Clear-PwrPackageScript
		& $script.FullName
		Test-PwrPackageScript
		if ("$($env:GITHUB_REF_NAME -replace '^.*/').ps1" -eq $script.Name -or ($env:GITHUB_REF_NAME -replace '^.*/').StartsWith("$($script.BaseName)-")) {
			$pkgs = ,$script.FullName.Replace((Get-Location), '.')
			break
		} elseif ((-not $PwrPackageConfig.Nonce) -or ("$($PwrPackageConfig.Name)-$($PwrPackageConfig.Version)" -notin $tagList.tags)) {
			$pkgs += ,$script.FullName.Replace((Get-Location), '.')
		}
	}
	Clear-PwrPackageScript
	[IO.File]::WriteAllText('.matrix', (ConvertTo-Json @{ package = $pkgs } -Depth 50 -Compress))
}