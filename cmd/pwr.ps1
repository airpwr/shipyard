<#
.SYNOPSIS
	pwr is a package manager for Windows
.DESCRIPTION
	TODO
.LINK
	https://github.com/airpwr/shipyard
.PARAMETER Command
	The main command.
	list
	fetch
	shell
	help
	version
#>
param (
	[Parameter(Position=0)]
	[string]$Command,
	[Parameter(Position=1)]
	[ValidatePattern('^[a-zA-Z0-9_-]+(:([0-9]+\.){0,2}[0-9]*)?$')]
	[string[]]$Packages,
	[switch]$Fetch
)

Class SemanticVersion : System.IComparable {

	[int]$Major = 0
	[int]$Minor = 0
	[int]$Patch = 0

	hidden init([string]$tag, [string]$pattern) {
		if ($tag -match $pattern) {
			$this.Major = if ($Matches.1) { $Matches.1 } else { 0 }
			$this.Minor = if ($Matches.2) { $Matches.2 } else { 0 }
			$this.Patch = if ($Matches.3) { $Matches.3 } else { 0 }
		}
	}

	SemanticVersion([string]$tag, [string]$pattern) {
		$this.init($tag, $pattern)
	}

	SemanticVersion([string]$version) {
		$this.init($version, '^([0-9]+)\.([0-9]+)\.([0-9]+)$')
	}

	SemanticVersion() { }

	[bool] LaterThan([object]$Obj) {
		return $this.CompareTo($obj) -lt 0
	}

	[int] CompareTo([object]$Obj) {
		if ($Obj -isnot [SemanticVersion]) {
			return 1
		} elseif (!($this.Major -eq $Obj.Major)) {
			return $Obj.Major - $this.Major
		} elseif (!($this.Minor -eq $Obj.Minor)) {
			return $Obj.Minor - $this.Minor
		} else {
			return $Obj.Patch - $this.Patch
		}
	}

	[string] ToString() {
		return "$($this.Major).$($this.Minor).$($this.Patch)"
	}

}

function AsHashTable {
	param (
		[Parameter(ValueFromPipeline)][PSCustomObject]$Object
	)
	$Table = @{}
	$Object.PSObject.Properties | Foreach-Object {
		$V = $_.Value
		if ($V -is [array]) {
			$V = [System.Collections.ArrayList]$V
		} elseif ($V -is [PSCustomObject]) {
			$V = ($V | AsHashTable)
		}
		$Table.($_.Name) = $V
	}
	return $Table
}

function Invoke-PackageVariables($PkgPath) {
	$vars = (Get-Content -Path "$PkgPath\.pwr").Replace('${.}', (Resolve-Path $PkgPath).Path.Replace('\', '\\')) | ConvertFrom-Json | AsHashTable
	# Vars
	foreach ($k in $vars.var.keys) {
		Set-Variable -Name $k -Value $vars.var.$k
	}
	# Env
	foreach ($k in $vars.env.keys) {
		Set-Item "env:$k" $vars.env.$k
	}
	# Run
	foreach ($line in $vars.run) {
		Invoke-Expression $line
	}
}

function Get-DockerToken($scope) {
	$resp = Invoke-WebRequest "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${scope}:pull"
	return ($resp.content | ConvertFrom-Json).token
}

function Get-DockerManifest($token, $scope, $tag) {
	$headers = @{
		"Authorization" = "Bearer $token"
		"Accept" = "application/vnd.docker.distribution.manifest.v2+json"
	}
	$resp = Invoke-WebRequest "https://index.docker.io/v2/$scope/manifests/$tag" -Headers $headers -UseBasicParsing
	return [string]$resp | ConvertFrom-Json
}

function Invoke-PullDockerLayer($out, $token, $scope, $digest) {
	$tmp = "$env:temp/$($digest.Replace(':', '_')).tgz"
	$headers = @{
		"Authorization" = "Bearer $token"
	}
	Invoke-WebRequest "https://index.docker.io/v2/$scope/blobs/$digest" -OutFile $tmp -Headers $headers
	tar -xzf $tmp -C $out --exclude 'Hives/*' --strip-components 1
	Remove-Item $tmp
}

function Get-DockerTags($scope) {
	$token = Get-DockerToken $scope
	$headers = @{
		"Authorization" = "Bearer $token"
	}
	$resp = Invoke-WebRequest "https://index.docker.io/v2/$scope/tags/list" -Headers $headers -UseBasicParsing
	return [string]$resp | ConvertFrom-Json
}

function Set-RegistryKey($path, $name, $value) {
	if (!(Test-Path $path)) {
		New-Item -Path $path -Force | Out-Null
	}
	New-ItemProperty -Path $path -Name $name -Value $value -Force | Out-Null
}

function Resolve-PwrPackge($pkg) {
	return "$PwrPath\pkg\$pkg"
}

function Split-Package($pkg) {
	$split = $pkg.Split(':')
	switch ($split.count) {
		2 {
			return @{
				Name = $split[0]
				Version = $split[1]
			}
		}
		Default {
			return @{
				Name = $pkg
				Version = 'latest'
			}
		}
	}
}

function Get-LatestVersion($name, $matcher) {
	$latest = $null
	foreach ($v in $Pkgs.$name) {
		$ver = [SemanticVersion]::new($v, '([0-9]+)\.([0-9]+)\.([0-9]+)')
		if (($null -eq $latest) -or ($ver.CompareTo($latest) -lt 0)) {
			if ($matcher -and ($v -notmatch $matcher)) {
				continue
			}
			$latest = $ver
		}
	}
	if (-not $latest) {
		Write-Error "pwr: no package named $name$(if ($matcher) { " matching $matcher"} else { '' })"
	}
	return $latest.ToString()
}

function Assert-Package($pkg) {
	$p = Split-Package $pkg
	$name = $p.name
	$version = $p.version
	if (-not $pkgs.$name) {
		Write-Error "pwr: no package named '${name}'"
	} elseif ($version -eq 'latest') {
		return "$name-$(Get-LatestVersion $name)"
	} elseif ($version -match '^([0-9]+\.){2}[0-9]+$' -and ($version -in $Pkgs.$name)) {
		return "$name-$version"
	} elseif ($version -match '^[0-9]+(\.[0-9]+)?$') {
		return "$name-$(Get-LatestVersion $name $version)"
	} else {
		Write-Error "pwr: no package for ${name}:$version"
	}
}

function Get-Packages {
	$pkgFile = "$PwrPath\pkgs.pwr"
	$exists = Test-Path $pkgFile
	if ($exists) {
		$LastWrite = [DateTime]::Parse((Get-Item $pkgFile).LastWriteTime)
		$OutOfDate = [DateTime]::Compare((Get-Date), $LastWrite + (New-TimeSpan -Days 1)) -gt 0
	}
	if (!$exists -or $OutOfDate -or $Fetch) {
		Write-Output 'pwr: fetching package list'
		$tagList = Get-DockerTags $PwrScope
		$pkgs = @{}
		$names = @{}
		foreach ($tag in $tagList.tags) {
			$tag -match '([^-]+)-(.+)' | Out-Null
			if ($Matches) {
				$pkg = $Matches[1]
				$ver = $Matches[2]
				$names.$pkg = $null
				$pkgs.$pkg = @($pkgs.$pkg) + @([SemanticVersion]::new($ver)) | Sort-Object
			}
		}
		foreach ($name in $names.keys) {
			$pkgs.$name = $pkgs.$name | ForEach-Object { $_.ToString() }
		}
		$pkgs | ConvertTo-Json -Depth 50 -Compress | Out-File $pkgFile -Encoding 'utf8' -Force
	}
	return Get-Content $pkgFile | ConvertFrom-Json
}

function Test-Package($pkg) {
	$PkgPath = Resolve-PwrPackge $pkg
	return Test-Path "$PkgPath\.pwr"
}

function Invoke-PackagePull($pkg) {
	$p = $pkg.Replace('-', ':')
	if (Test-Package $pkg) {
		Write-Output "pwr: $p already exists"
	} else {
		Write-Host "pwr: fetching ${p} ... " -NoNewline
		$token = Get-DockerToken $PwrScope
		$manifest = Get-DockerManifest $token $PwrScope $pkg
		$PkgPath = Resolve-PwrPackge $pkg
		mkdir $PkgPath -Force | Out-Null
		foreach ($layer in $manifest.layers) {
			if ($layer.mediaType -eq "application/vnd.docker.image.rootfs.diff.tar.gzip") {
				Invoke-PullDockerLayer $PkgPath $token $PwrScope $layer.digest
			}
		}
		Write-Host 'done.'
	}
}


function Invoke-PackageShell($pkg) {
	$PkgPath = Resolve-PwrPackge $pkg
	$vars = (Get-Content -Path "$PkgPath\.pwr").Replace('${.}', (Resolve-Path $PkgPath).Path.Replace('\', '\\')) | ConvertFrom-Json | AsHashTable
	#Reg
	foreach ($k in $vars.reg.keys) {
		foreach ($j in $vars.reg.$k.keys) {
			Set-RegistryKey $k $j $vars.reg.$k.$j
		}
	}
	# Vars
	foreach ($k in $vars.var.keys) {
		Set-Variable -Name $k -Value $vars.var.$k -Scope 'global'
	}
	# Env
	foreach ($k in $vars.env.keys) {
		$prefix = ''
		if ($k -eq 'path') {
			$prefix += "${env:path};"
		}
		Set-Item "env:$k" "$prefix$($vars.env.$k)"
	}
	# Run
	foreach ($line in $vars.run) {
		Invoke-Expression $line
	}
}

function Assert-NonEmptyPackages {
	if ($Packages.Count -eq 0) {
		if (Test-Path '.pwr') {
			$ps = @()
			foreach($line in [IO.File]::ReadLines('.pwr')) {
				$p = $line.Trim()
				if (-not [String]::IsNullOrWhiteSpace($p)) {
					$ps += ,$p
				}
			}
			$script:Packages = $ps
		}
	}
	if ($Packages.Count -eq 0) {
		Write-Error 'no packages provided'
	}
}

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$PwrScope = 'airpower/shipyard'
$PwrPath = "$env:appdata\pwr"
$Pkgs = Get-Packages
mkdir $PwrPath -Force | Out-Null
switch ($Command) {
	{$_ -in 'v', 'version'} {
		Write-Host 'pwr 0.0.0'
	}
	'fetch' {
		Assert-NonEmptyPackages
		foreach ($p in $Packages) {
			$pkg = Assert-Package $p
			Invoke-PackagePull $pkg
		}
	}
	{$_ -in 'sh', 'shell'} {
		Assert-NonEmptyPackages
		foreach ($key in [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::User).keys) {
			if (($key -ne 'tmp') -and ($key -ne 'temp')) {
				Clear-Item "env:$key" -Force -ErrorAction SilentlyContinue
			}
		}
		$s = Split-Path $MyInvocation.MyCommand.Path -Parent
		$env:path = "\windows;\windows\system32;$s"
		foreach ($p in $Packages) {
			$pkg = Assert-Package $p
			if (!(Test-Package $pkg)) {
				Invoke-PackagePull $pkg
			}
			Invoke-PackageShell $pkg
			Write-Output "pwr: using $pkg"
		}
	}
	{$_ -in 'ls', 'list'} {
		if (($Packages.count -eq 1) -and ($Packages[0] -match '[^:]+')) {
			$pkg = $Matches[0]
			Write-Output $pkgs.$pkg | Format-List
		} else {
			Write-Output $pkgs | Format-List
		}
	}
	{$_ -in 'rm', 'remove'} {
		Assert-NonEmptyPackages
		$name = [IO.Path]::GetRandomFileName()
		$empty = "$env:Temp\$name"
		mkdir $empty | Out-Null
		foreach ($p in $Packages) {
			$pkg = Assert-Package $p
			if (Test-Package $pkg) {
				Write-Host "pwr: removing $pkg ... " -NoNewline
				$path = Resolve-PwrPackge $pkg
				robocopy $empty $path /purge | Out-Null
				Remove-Item $path
				Write-Host 'done.'
			} else {
				Write-Output "pwr: $pkg not found"
			}
		}
		Remove-Item $empty
	}
	{$_ -in 'h', 'help'} {
		Get-Help pwr -detailed
	}
	Default {
		Write-Host -ForegroundColor Red "pwr: no such command '$Command'"
		Write-Host -ForegroundColor Red "     use 'pwr help' for a list of commands"
	}
}