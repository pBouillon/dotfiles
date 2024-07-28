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
        Set-Location "~/Dev"
        return
    }

    $projectPath = "~/Dev/Projects/$ProjectName"

    if (Test-Path $projectPath) {
        Set-Location $projectPath
    } else {
        Write-Host "No project named '$ProjectName' found." -ForegroundColor DarkYellow
    }
}

Set-Alias dev Set-DevLocation

# Utility - Touch alias
function Create-File {
    param(
        [String]$FilePath
    )
    if (Test-Path -Path $FilePath) {
        Write-Host "File already exists at '$FilePath'." -ForegroundColor DarkYellow
    }
    else{
        New-Item $FilePath
    }
}

Set-Alias touch Create-File

# Autocompletion - Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion - Show previous commands with same prefix
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
