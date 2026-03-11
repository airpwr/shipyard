$global:PwrPackageConfig = @{
    Name = 'ruby'
}

function global:Install-PwrPackage {
    $Params = @{
        Owner        = 'oneclick'
        Repo         = 'rubyinstaller2'
        AssetPattern = '^rubyinstaller-([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)\-x64\.7z$'
        TagPattern   = '^rubyinstaller-([0-9]+)\.([0-9]+)\.([0-9]+)$'
    }

    $Asset = Get-GitHubRelease @Params
    $global:PwrPackageConfig.UpToDate = -not $Asset.Version.LaterThan($global:PwrPackageConfig.Latest)
    $global:PwrPackageConfig.Version = $Asset.Version.ToString()

    if ($global:PwrPackageConfig.UpToDate) {
        Write-Debug "Ruby is up to date (version $($global:PwrPackageConfig.Version)), skipping packaging"
        return
    }

    Install-BuildTool -AssetName $Asset.Name -AssetURL $Asset.URL

    $RubyExe = Get-ChildItem -Path '\pkg' -Recurse -Include 'ruby.exe' | Select-Object -First 1
    if (-not $RubyExe) {
        throw 'Failed to find ruby.exe after installation'
    }
    $PathEntries = @($RubyExe.DirectoryName)

    $GemCmd = Get-ChildItem -Path '\pkg' -Recurse -Include 'gem.cmd' | Select-Object -First 1
    if (-not $GemCmd) {
        throw 'Failed to find ruby.exe after installation'
    }

    if ($GemCmd) {
        $PathEntries += $GemCmd.DirectoryName
    }

    Write-PackageVars @{
        env = @{
            path = ($PathEntries | Select-Object -Unique) -join ';'
        }
    }
}

function global:Test-PwrPackageInstall {
    Airpower exec 'file:///\pkg' {
        ruby --version
        gem --version
        gem env home
    }
}