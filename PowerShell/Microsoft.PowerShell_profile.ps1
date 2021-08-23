### %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Services

## Starship

### Launch on startup
Invoke-Expression (&starship init powershell)
# Autocompletion

## Enable autocomplete

### Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

### Autocompletion for arrow keys
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

### %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Aliases

## Docker

### Launch docker
${function:startdocker} = { start "C:\Program Files\Docker\Docker\Docker Desktop.exe" }
Set-Alias start-docker startdocker

### `docker-compose` shortcut
Set-Alias dc docker-compose

### Restart the docker compose stack
function DockerComposeRestart {
    docker-compose down
    docker-compose up -d
}
Set-Alias dcr DockerComposeRestart

### Restart and rebuild the docker compose stack
function DockerComposeRebuildRestart {
    docker-compose down
    docker-compose up -d --build
}
Set-Alias dcrr DockerComposeRebuildRestart

## Productivity

### Create an empty file

function CreateFile([string]$Path) {
    echo "" > $Path
}
Set-Alias touch CreateFile

### Delete a folder

function DeleteFolder([string]$Path) {
    rm -Force -Recurse $Path
}
Set-Alias delete DeleteFolder

### Look for a .sln file in the current directory and open it with VS201X
function OpenCurrentDirectorySolution {
    Get-ChildItem $Path -Filter "*.sln" |
    ForEach-Object {
        Write-Output "Opening solution: $($_)"
        Start-Process $_
    }
}
Set-Alias vs OpenCurrentDirectorySolution

Set-Alias sudo gsudo

## Scoop

### Updater
${function:UpdateScoop} = { scoop update; scoop update *; scoop cleanup *; scoop cache rm * }
Set-Alias update-scoop UpdateScoop

## Shortcuts

### Open the dev directory
${function:OpenDev} = { Set-Location ~/Documents/Dev }
Set-Alias open-dev OpenDev
