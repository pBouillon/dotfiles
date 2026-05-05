$DEV_BASE_DIR = "D:/Dev"

# Logging Utility
function Log {
    param(
        [String]$Level = 'Info',
        [String]$Message,
        [Switch]$ShowTimestamp
    )

    $levelColors = @{
        'Success' = [System.ConsoleColor]::Green
        'Verbose' = [System.ConsoleColor]::Gray
        'Debug'   = [System.ConsoleColor]::Cyan
        'Info'    = [System.ConsoleColor]::Blue
        'Warning' = [System.ConsoleColor]::Yellow
        'Error'   = [System.ConsoleColor]::Red
    }

    if (-not $levelColors.ContainsKey($Level)) { $Level = 'Info' }
    $color = $levelColors[$Level]

    $maxLength = 7
    $formattedLevel = $Level.PadRight($maxLength).ToUpper()

    if ($ShowTimestamp) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] $formattedLevel" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$formattedLevel" -ForegroundColor $color -NoNewline
    }

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

# Utility - Local PocketBase Versions Launcher
function Get-PocketBaseVersions {
    $basePath = "$DEV_BASE_DIR/Tools/PocketBase"
    if (Test-Path $basePath) {
        Get-ChildItem -Path $basePath -Directory | Where-Object { $_.Name -match '^v\d+\.\d+\.\d+$' } | ForEach-Object { $_.Name.Substring(1) }
    } else {
        Log -Level 'Error' -Message "PocketBase directory not found at $basePath"
        return @()
    }
}

function Invoke-PocketBase {
    param(
        [string]$Version = 'latest'
    )

    $versions = Get-PocketBaseVersions
    if ($versions.Count -eq 0) {
        Log -Level 'Error' -Message "No PocketBase versions found."
        return
    }

    if ($Version -eq 'latest') {
        # Find the highest version
        $latestVersion = $versions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
        $Version = $latestVersion
    }

    if ($Version -ne 'latest' -and $Version -notin $versions) {
        Log -Level 'Error' -Message "Version '$Version' not found."
        Log -Level 'Error' -Message "Available versions:"
        $versions | ForEach-Object {
            Log -Level 'Error' -Message "- $_"
        }
        return
    }

    $basePath = "$DEV_BASE_DIR/Tools/PocketBase"
    $exePath = Join-Path -Path $basePath -ChildPath "v$Version/pocketbase.exe"

    if (Test-Path $exePath) {
        
        Log -Level 'Success' -Message "Running PocketBase v$Version"
        & $exePath serve
    } else {
        Log -Level 'Error' -Message "PocketBase executable not found at $exePath"
    }
}

# Utility - Simple, local HTTP server
function Start-HttpServer {
    param(
        [String]$Path, 
        [int]$Port = 8080
    )
    if (-not $Path) { $Path = $PWD }
    
    # Initialize PSDrive for the web root
    if (Get-PSDrive "wwwroot" -ErrorAction SilentlyContinue) { Remove-PSDrive "wwwroot" }
    $drive = New-PSDrive -Name "wwwroot" -PSProvider "FileSystem" -Root $Path
    
    $default = "index.html"
    $prefix = "http://localhost:$Port/"
    
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    try {
        $listener.Start()
        Log -Level 'Success' -Message "Server started! Listening on $prefix"
        Log -Level 'Info' -Message "Root Path: $Path (press Ctrl+C to stop)"
        while ($listener.IsListening) {
            # Non-blocking wait to keep the session responsive to Ctrl+C
            $task = $listener.GetContextAsync()
            while (-not $task.AsyncWaitHandle.WaitOne(500)) {
                if (-not $listener.IsListening) { break }
            }
            if (-not $listener.IsListening) { break }
            $context = $task.GetAwaiter().GetResult()
            $request = $context.Request
            $response = $context.Response
            
            # --- Request Logging Logic ---
            $logMsg = New-Object System.Text.StringBuilder
            [void]$logMsg.Append("$($request.HttpMethod) $($request.Url.LocalPath)")
            # Append Query Strings
            if ($request.QueryString.Count -gt 0) {
                $spacer = "?"
                foreach ($key in $request.QueryString.AllKeys) {
                    [void]$logMsg.Append("$spacer$key=$($request.QueryString[$key])")
                    $spacer = "&"
                }
            }
            # Read Body if present
            if ($request.HasEntityBody) {
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                [void]$logMsg.Append(" | Body: $body")
                $reader.Dispose()
            }

            # --- File Serving Logic ---
            $url = $request.Url.LocalPath
            if ($url.EndsWith("/")) { $url = "$($url)$default" }
            
            $fullPath = "wwwroot:$url"
            $content = $null
            if (Test-Path $fullPath -PathType Leaf) {
                # Serve the real file
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    $content = Get-Content -Path $fullPath -AsByteStream -Raw
                } else {
                    $content = Get-Content -Path $fullPath -Encoding Byte -Raw
                }
                $ext = [System.IO.Path]::GetExtension($url)
                $response.ContentType = [Microsoft.Win32.Registry]::GetValue("HKEY_CLASSES_ROOT\$ext", "Content Type", "application/octet-stream")
                $response.StatusCode = 200
                $response.ContentLength64 = $content.Length
                $response.OutputStream.Write($content, 0, $content.Length)
            } else {
                # SPA fallback: serve index.html for routes with no file extension.
                # Requests for real assets (.js, .css, etc.) that are missing still get a 404.
                $ext = [System.IO.Path]::GetExtension($url)
                $fallbackPath = "wwwroot:\$default"
                if (-not $ext -and (Test-Path $fallbackPath -PathType Leaf)) {
                    if ($PSVersionTable.PSVersion.Major -ge 6) {
                        $content = Get-Content -Path $fallbackPath -AsByteStream -Raw
                    } else {
                        $content = Get-Content -Path $fallbackPath -Encoding Byte -Raw
                    }
                    $response.ContentType = "text/html"
                    $response.StatusCode = 200
                    $response.ContentLength64 = $content.Length
                    $response.OutputStream.Write($content, 0, $content.Length)
                } else {
                    $response.StatusCode = 404
                    $errorBytes = [System.Text.Encoding]::UTF8.GetBytes("404 - Not Found")
                    $response.ContentLength64 = $errorBytes.Length
                    $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
                }
            }

            # Log the final result
            $logLevel = if ($response.StatusCode -eq 200) { 'Debug' } else { 'Warning' }
            Log -Level $logLevel -Message "$($response.StatusCode): $($logMsg.ToString())" -ShowTimestamp
            $response.Close()
        }
    }
    catch {
        Log -Level 'Error' -Message $_.Exception.Message
    }
    finally {
        if ($null -ne $listener) {
            $listener.Stop()
            $listener.Close()
        }
        if (Get-PSDrive "wwwroot" -ErrorAction SilentlyContinue) { 
            Remove-PSDrive "wwwroot" 
        }
        Log -Level 'Info' -Message "Server stopped and PSDrive removed."
    }
}

Set-Alias pb Invoke-PocketBase

# Autocompletion - Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion - Show previous commands with same prefix
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
