$DEV_BASE_DIR = "D:/Dev"

# Logging Utility
function Log {
    param(
        [String]$Level = 'Info',
        [String]$Message
    )

    $levelColors = @{
        'Success' = [System.ConsoleColor]::Green
        'Verbose' = [System.ConsoleColor]::DarkGray
        'Debug'   = [System.ConsoleColor]::Cyan
        'Info'    = [System.ConsoleColor]::Blue
        'Warning' = [System.ConsoleColor]::Yellow
        'Error'   = [System.ConsoleColor]::Red
    }

    $Level = (Get-Culture).TextInfo.ToTitleCase($Level.ToLower())
    if (-not $levelColors.ContainsKey($Level)) { $Level = 'Info' }

    $color          = $levelColors[$Level]
    $formattedLevel = $Level.PadRight(7).ToUpper()

    Write-Host "$formattedLevel" -ForegroundColor $color -NoNewline
    Write-Host " $Message"
}

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
        Log -Level 'Warning' -Message "No project named '$ProjectName' found."
    }
}

Set-Alias dev Set-DevLocation

# Autocompletion - Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion - Show previous commands with same prefix
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

# Load external utilities
. "$HOME/Documents/WindowsPowerShell/GitFlow.ps1"
. "$HOME/Documents/WindowsPowerShell/HttpServer.ps1"
