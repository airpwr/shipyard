Class SemanticVersion : System.IComparable {

	[int]$Major = 0
	[int]$Minor = 0
	[int]$Patch = 0
	[int]$Build = 0

	hidden init([string]$tag, [string]$pattern) {
		if ($tag -match $pattern) {
			$this.Major = if ($Matches[1]) { $Matches[1] } else { 0 }
			$this.Minor = if ($Matches[2]) { $Matches[2] } else { 0 }
			$this.Patch = if ($Matches[3]) { $Matches[3] } else { 0 }
			$this.Build = if ($Matches[4]) { "$($Matches[4])".Substring(1) } else { 0 }
		}
	}

	SemanticVersion([string]$tag, [string]$pattern) {
		$this.init($tag, $pattern)
	}

	SemanticVersion([string]$version) {
		$this.init($version, '^([0-9]+)\.([0-9]+)\.([0-9]+)(\+[0-9]+)?$')
	}

	SemanticVersion() { }

	[bool] LaterThan([object]$Obj) {
		return $this.CompareTo($obj) -lt 0
	}

	[int] CompareTo([object]$Obj) {
		if ($Obj -isnot $this.GetType()) {
			throw "cannot compare types $($Obj.GetType()) and $($this.GetType())"
		} elseif ($this.Major -ne $Obj.Major) {
			return $Obj.Major - $this.Major
		} elseif ($this.Minor -ne $Obj.Minor) {
			return $Obj.Minor - $this.Minor
		} elseif ($this.Patch -ne $Obj.Patch) {
			return $Obj.Patch - $this.Patch
		} else {
			return $Obj.Build - $this.Build
		}
	}

	[string] ToString() {
		return "$($this.Major).$($this.Minor).$($this.Patch)$(if ($this.Build) {"+$($this.Build)"})"
	}

}

function Get-DockerToken($scope) {
	$resp = Invoke-WebRequest "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${scope}:pull"
	return ($resp.content | ConvertFrom-Json).token
}

function Get-DockerTags($scope) {
	$token = Get-DockerToken $scope
	$headers = @{
		"Authorization" = "Bearer $token"
	}
	$resp = Invoke-WebRequest "https://index.docker.io/v2/$scope/tags/list" -Headers $headers -UseBasicParsing
	return [string]$resp | ConvertFrom-Json
}

function Write-PackageVars($vars) {
	$text = $vars | ConvertTo-Json -Depth 50 -Compress
	$text = $text.Replace((Resolve-Path '\pkg').Path.Replace('\', '\\'), '${.}').Replace('\\pkg', '${.}')
	[IO.File]::WriteAllText('\pkg\.pwr', $text)
}

function Set-RegistryKey($path, $name, $value) {
	if (!(Test-Path $path)) {
		New-Item -Path $path -Force | Out-Null
	}
	New-ItemProperty -Path $path -Name $name -Value $value -Force | Out-Null
}

function Find-LatestTag([object[]]$List, [string]$TagProperty, [string]$TagPattern) {
	$LatestAsset = $List[0]
	$LatestVersion = [SemanticVersion]::new($LatestAsset.$TagProperty, $TagPattern)
	for ($i = 1; $i -lt $List.Count; $i += 1) {
		$version = [SemanticVersion]::new($List[$i].$TagProperty, $TagPattern)
		if ($LatestVersion.CompareTo($version) -gt 0) {
			$LatestAsset = $List[$i]
			$LatestVersion = $version
		}
	}
	return @{
		Item = $LatestAsset
		Version = $LatestVersion
	}
}

function Get-GitHubRelease {
	param (
		[Parameter(Mandatory=$true)][string]$Owner,
		[Parameter(Mandatory=$true)][string]$Repo,
		[Parameter(Mandatory=$true)][string]$AssetPattern,
		[Parameter(Mandatory=$true)][string]$TagPattern
	)
	$Releases = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/$Owner/$Repo/releases?per_page=100").Content | ConvertFrom-Json
	$Latest = Find-LatestTag $Releases 'tag_name' $TagPattern
	if ($Latest) {
		foreach ($Asset in $Latest.item.assets) {
			if ($Asset.name -match $AssetPattern) {
				return @{
					URL = $Asset.browser_download_url
					Name = $Asset.name
					Identifier = $Latest.item.tag_name
					Version = $Latest.version
				}
			}
		}
	}
	Write-Error "Failed to find a GitHub Release for $Owner $Repo"
}

function Get-GitHubTag {
	param (
		[Parameter(Mandatory=$true)][string]$Owner,
		[Parameter(Mandatory=$true)][string]$Repo,
		[Parameter(Mandatory=$true)][string]$TagPattern
	)
	$i = 1
	$Tags = @()
	do {
		Write-Output "page=$i"
		$Page = (Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/$Owner/$Repo/tags?per_page=100&page=$i").Content | ConvertFrom-Json
		$Tags += $Page
		$i++
	} while ($Page.Count -gt 0)
	$Latest = Find-LatestTag $Tags 'name' $TagPattern
	if ($Latest) {
		return @{
			Name = $Latest.item.name
			Version = $Latest.version
		}
	}
	Write-Error "Failed to find a GitHub Tag for $Owner $Repo"
}

function Install-BuildTool {
	param (
		[Parameter(Mandatory=$true)][string]$AssetName,
		[Parameter(Mandatory=$true)][string]$AssetURL,
		[string]$ToolDir = '\pkg'
	)
	$Asset = "$env:Temp/$AssetName"
	Invoke-WebRequest -UseBasicParsing $AssetURL -OutFile $Asset
	Expand-Archive $Asset $ToolDir
}