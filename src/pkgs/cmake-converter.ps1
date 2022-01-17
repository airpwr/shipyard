$global:PwrPackageConfig = @{
	Name = 'cmake-converter'
}

function global:Install-PwrPackage {
	$Params = @{
		Owner = 'pavelliavonau'
		Repo = 'cmakeconverter'
		TagPattern = '^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
	}
	$Latest = Get-GitHubTag @Params
	$PwrPackageConfig.UpToDate = -not $Latest.Version.LaterThan($PwrPackageConfig.Latest)
	$PwrPackageConfig.Version = $Latest.Version.ToString()
	if ($PwrPackageConfig.UpToDate) {
		return
	}
	# Download src
	Invoke-WebRequest -UseBasicParsing "https://api.github.com/repos/$($Params.Owner)/$($Params.Repo)/zipball/$($Latest.Name)" -OutFile "$env:Temp\repo.zip"
	Expand-Archive "$env:Temp\repo.zip" '\repo'
	$env:repo = (Get-ChildItem -Path '\repo' -Recurse -Include 'setup.py' | Select-Object -First 1).DirectoryName
	# Install python
	$PythonVersion = "3.10.1"
	$PythonAsset = "$env:Temp/python.zip"
	Invoke-WebRequest -UseBasicParsing "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip" -OutFile $PythonAsset
	Expand-Archive $PythonAsset '\python'
	Remove-Item '\python\*._pth'
	# Install pip
	Invoke-WebRequest -UseBasicParsing 'https://bootstrap.pypa.io/get-pip.py' -OutFile '\python\get-pip.py'
	& '\python\python.exe' '\python\get-pip.py' --no-warn-script-location
	& '\python\python.exe' -m pip install '--target' '\pkg' $env:repo
	# Fix python path in exe
	$ExeDirectory = (Get-ChildItem -Path '\pkg' -Recurse -Include 'cmake-converter.exe' | Select-Object -First 1).DirectoryName
	$ExeData = Get-Content -Raw -AsByteStream "$ExeDirectory\cmake-converter.exe"
	$FixedData = (-split (($ExeData.ForEach('ToString', 'X') -join ' ') -replace '\b23 21( [2-7].)+ 5C 70 79 74 68 6F 6E 2E 65 78 65', '23 21 70 79 74 68 6F 6E 2E 65 78 65') -replace '^', '0x') -as [byte[]]
	Set-Content -Value $FixedData -AsByteStream "$ExeDirectory\cmake-converter.exe"
	Write-PackageVars @{
		env = @{
			path = $ExeDirectory
			pythonpath = '\pkg'
		}
	}
}

function global:Test-PwrPackageInstall {
	pwr sh 'file:///\pkg'
	$env:Path = "\python;$env:Path"
	cmake-converter -s "$env:repo\test\datatest\sln\cpp.sln"
	pwr exit
}