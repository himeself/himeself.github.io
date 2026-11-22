$siteRoot = (Resolve-Path $PSScriptRoot).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:8000/')

try {
    $listener.Start()
} catch {
    Write-Host 'Could not start the local site server. Port 8000 may already be in use.' -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host 'Serving the site at http://localhost:8000/' -ForegroundColor Green
Write-Host 'Keep this window open. Press Ctrl+C to stop the server.'
Start-Process 'http://localhost:8000/'

$rootPrefix = $siteRoot.TrimEnd('\') + '\'
$types = @{
    '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8';
    '.js' = 'application/javascript; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8';
    '.json' = 'application/json; charset=utf-8'; '.svg' = 'image/svg+xml';
    '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg';
    '.gif' = 'image/gif'; '.webp' = 'image/webp'; '.ico' = 'image/x-icon';
    '.mp4' = 'video/mp4'; '.mp3' = 'audio/mpeg'; '.woff' = 'font/woff';
    '.woff2' = 'font/woff2'; '.ttf' = 'font/ttf'; '.otf' = 'font/otf'
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
        if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
        $candidate = Join-Path $siteRoot ($relative -replace '/', '\')
        $filePath = [IO.Path]::GetFullPath($candidate)

        if (-not $filePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            $context.Response.StatusCode = 403
            $context.Response.Close()
            continue
        }
        if (Test-Path -LiteralPath $filePath -PathType Container) {
            $filePath = Join-Path $filePath 'index.html'
        }
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            $context.Response.StatusCode = 404
            $context.Response.Close()
            continue
        }

        $extension = [IO.Path]::GetExtension($filePath).ToLowerInvariant()
        if ($types.ContainsKey($extension)) { $context.Response.ContentType = $types[$extension] }
        $bytes = [IO.File]::ReadAllBytes($filePath)
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.StatusCode = 200
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.Close()
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
