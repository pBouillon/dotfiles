$DEV_BASE_DIR = "D:/Dev"

# Starship - Initialize
Invoke-Expression (&starship init powershell)

# fnm - Change environment on directory changed
fnm env --use-on-cd | Out-String | Invoke-Expression

# Utility - Set Dev Location
function Set-DevLocation {
    param(
        [string]$ProjectName
    )

    if (-not $ProjectName) {
        Set-Location "$DEV_BASE_DIR"
        return
    }

    $projectPath = "$DEV_BASE_DIR/Projects/$ProjectName"

    if (Test-Path $projectPath) {
        Set-Location $projectPath
    } else {
        Write-Host "No project named '$ProjectName' found." -ForegroundColor DarkYellow
    }
}

Set-Alias dev Set-DevLocation

function Create-File {
    param(
        [String]$FilePath
    )

    if ([string]::IsNullOrEmpty($FilePath)) {
        Write-Host "Error: No path specified." -ForegroundColor Red
        return
    }

    $pathEndsWithSeparator = $FilePath.EndsWith('\') -or $FilePath.EndsWith('/')

    if ($pathEndsWithSeparator) {
        if (Test-Path -Path $FilePath) {
            Write-Host "Directory already exists at '$FilePath'." -ForegroundColor DarkYellow
        }
        else {
            Write-Host "Error: Directory does not exist. Use 'mkdir' to create directories." -ForegroundColor Red
        }
    }
    else {
        if (Test-Path -Path $FilePath) {
            Write-Host "File already exists at '$FilePath'." -ForegroundColor DarkYellow
        }
        else {
            New-Item -ItemType File -Path $FilePath -Force | Out-Null
        }
    }
}

Set-Alias touch Create-File

# Utility - Local PocketBase Versions Launcher
function Get-PocketBaseVersions {
    $basePath = "$DEV_BASE_DIR/Tools/PocketBase"
    if (Test-Path $basePath) {
        Get-ChildItem -Path $basePath -Directory | Where-Object { $_.Name -match '^v\d+\.\d+\.\d+$' } | ForEach-Object { $_.Name.Substring(1) }
    } else {
        Write-Host "PocketBase directory not found at $basePath" -ForegroundColor Red
        return @()
    }
}

function Invoke-PocketBase {
    param(
        [string]$Version = 'latest'
    )

    $versions = Get-PocketBaseVersions
    if ($versions.Count -eq 0) {
        Write-Host "No PocketBase versions found." -ForegroundColor Red
        return
    }

    if ($Version -eq 'latest') {
        # Find the highest version
        $latestVersion = $versions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
        $Version = $latestVersion
    }

    if ($Version -ne 'latest' -and $Version -notin $versions) {
        Write-Host "Version '$Version' not found."
        Write-Host "Available versions:" -ForegroundColor Red
        $versions | ForEach-Object { Write-Host "- $_" }
        return
    }

    $basePath = "$DEV_BASE_DIR/Tools/PocketBase"
    $exePath = Join-Path -Path $basePath -ChildPath "v$Version/pocketbase.exe"

    if (Test-Path $exePath) {
        Write-Host "Running PocketBase v$Version" -ForegroundColor DarkGray
        & $exePath serve
    } else {
        Write-Host "PocketBase executable not found at $exePath" -ForegroundColor Red
    }
}

Set-Alias pb Invoke-PocketBase


# Autocompletion - Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion - Show previous commands with same prefix
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
