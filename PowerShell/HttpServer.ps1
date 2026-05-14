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
                # Handle PS version differences for byte reading
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
                $response.StatusCode = 404
                $errorBytes = [System.Text.Encoding]::UTF8.GetBytes("404 - Not Found")
                $response.ContentLength64 = $errorBytes.Length
                $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
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
