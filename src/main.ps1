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
	Remove-MpPreference -ExclusionPath (Get-MpPreference).ExclusionPath
	Update-MpSignature
	try {
		Start-MpScan -ScanPath '\pkg' -ScanType CustomScan
	} catch {
		$Error[0] | Format-List -Property * -Force
		Write-Error $Error[0]
	}
	Get-MpThreatDetection
}

function Invoke-DockerPush($name, $version) {
	$tag = "airpower/shipyard:$name-$version"
	& docker build -f Dockerfile -t $tag \pkg
	& docker image push $tag
}

function Invoke-PwrInit {
	if (-not $PwrPackageConfig.Nonce) {
		$tagList = Get-DockerTags 'airpower/shipyard'
		$latest = [SemanticVersion]::new()
		$matcher = if ($PwrPackageConfig.Matcher) { $PwrPackageConfig.Matcher } else { "^$($PwrPackageConfig.Name)-" }
		foreach ($item in $tagList.tags) {
			if ($item -match $matcher) {
				$v = [SemanticVersion]::new($item.Substring($item.IndexOf('-') + 1))
				if ($v.LaterThan($latest)) {
					$latest = $v
				}
			}
		}
		$PwrPackageConfig.Latest = $latest
	}
}

function Invoke-PwrScript($pkg) {
	& $pkg
	Invoke-PwrInit
	Install-PwrPackage
	# pwr shell $name-$version
	Write-Output "shipyard: $($PwrPackageConfig.Name) v$($PwrPackageConfig.Version) is $(if ($PwrPackageConfig.UpToDate) { 'UP-TO-DATE' } else { 'OUT-OF-DATE' })"
	if (-not $PwrPackageConfig.UpToDate) {
		Test-PwrPackageInstall
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
		if ("${env:GITHUB_REF_NAME}.ps1" -eq $script.Name) {
			$pkgs = ,$script.FullName.Replace((Get-Location), '.')
			break
		} elseif ((-not $PwrPackageConfig.Nonce) -or ("$($PwrPackageConfig.Name)-$($PwrPackageConfig.Version)" -notin $tagList.tags)) {
			$pkgs += ,$script.FullName.Replace((Get-Location), '.')
		}
	}
	Clear-PwrPackageScript
	[IO.File]::WriteAllText('.matrix', (ConvertTo-Json @{ package = $pkgs } -Depth 50 -Compress))
}