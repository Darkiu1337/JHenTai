# Enumerates image viewers installed for the current user.
# Output: {"viewers":[{"name":"...","path":"...","source":"win32|store"}]}
# Called from the Flutter app through ImageViewerScannerService.

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$viewers = New-Object System.Collections.ArrayList
$seen = @{}

function Read-Default($path) {
  $item = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
  if ($null -eq $item) { return $null }
  return $item.'(default)'
}

function Get-CommandPath($command) {
  if ([string]::IsNullOrWhiteSpace($command)) { return $null }
  $c = $command.Trim()
  if ($c.StartsWith('"')) {
    $end = $c.IndexOf('"', 1)
    if ($end -gt 1) { return $c.Substring(1, $end - 1) }
  }
  $m = [regex]::Match($c, '^([^\s]+\.exe)', 'IgnoreCase')
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function Get-FriendlyName($exe, $fallback) {
  try {
    $desc = (Get-Item -LiteralPath $exe -ErrorAction Stop).VersionInfo.FileDescription
    if (-not [string]::IsNullOrWhiteSpace($desc)) { return $desc }
  } catch {}
  if (-not [string]::IsNullOrWhiteSpace($fallback)) { return $fallback }
  return [System.IO.Path]::GetFileNameWithoutExtension($exe)
}

function Add-Viewer($name, $path, $source) {
  if ([string]::IsNullOrWhiteSpace($path)) { return }
  $full = [Environment]::ExpandEnvironmentVariables([string]$path)
  $full = $full.Trim().Trim('"')
  if (-not [System.IO.Path]::IsPathRooted($full)) { return }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return }
  $key = $full.ToLowerInvariant()
  if ($seen.ContainsKey($key)) { return }
  $seen[$key] = $true
  [void]$script:viewers.Add([pscustomobject]@{ name = $name; path = $full; source = $source })
}

function Find-ViewerFromProgId($progId) {
  foreach ($root in @('HKCU:\Software\Classes', 'HKLM:\Software\Classes', 'HKCR:')) {
    $cmd = Read-Default "$root\$progId\shell\open\command"
    $path = Get-CommandPath $cmd
    if ($path) {
      $friendly = (Get-ItemProperty -Path "$root\$progId" -Name 'FriendlyAppName' -ErrorAction SilentlyContinue).FriendlyAppName
      Add-Viewer (Get-FriendlyName $path $friendly) $path 'win32'
      return $true
    }
  }
  return $false
}

function Find-ViewerFromExeName($exeName) {
  $candidates = @(
    "HKCU:\Software\Classes\Applications\$exeName\shell\open\command",
    "HKLM:\Software\Classes\Applications\$exeName\shell\open\command",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$exeName",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\$exeName",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\$exeName"
  )
  foreach ($candidate in $candidates) {
    $value = Read-Default $candidate
    $path = Get-CommandPath $value
    if ($path) {
      Add-Viewer (Get-FriendlyName $path $null) $path 'win32'
      return $true
    }
  }

  try {
    $command = Get-Command $exeName -ErrorAction Stop
    if ($command -and $command.Path) {
      Add-Viewer (Get-FriendlyName $command.Path $null) $command.Path 'win32'
      return $true
    }
  } catch {}

  return $false
}

# Apps registered in the "Open with" list for JPEG.
$listKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.jpg\OpenWithList'
$props = Get-ItemProperty -Path $listKey
if ($props) {
  foreach ($p in $props.PSObject.Properties) {
    if ($p.Name -notmatch '^[A-Za-z]$') { continue }
    $exeName = [string]$p.Value
    if ($exeName -eq 'PickerHost.exe') { continue }
    [void](Find-ViewerFromExeName $exeName)
  }
}

# ProgIDs registered as handlers for JPEG.
$progIds = New-Object System.Collections.ArrayList
foreach ($root in @('HKCU:\Software\Classes\.jpg\OpenWithProgids', 'HKLM:\Software\Classes\.jpg\OpenWithProgids', 'HKCR:\.jpg\OpenWithProgids')) {
  $props = Get-ItemProperty -Path $root
  if (-not $props) { continue }
  foreach ($p in $props.PSObject.Properties) {
    if ($p.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) { continue }
    if (-not $progIds.Contains($p.Name)) { [void]$progIds.Add($p.Name) }
  }
}
foreach ($progId in $progIds) {
  [void](Find-ViewerFromProgId $progId)
}

# Packaged (MSIX/Store) full-trust applications with image-related names.
# Examples: ImageGlass from the Microsoft Store.
Get-AppxPackage | ForEach-Object {
  $pkg = $_
  if (-not $pkg.InstallLocation) { return }
  if ($pkg.Name -notmatch '(?i)image|photo|picture|view|paint|jpeg|jpg|png|media') { return }
  $manifestPath = Join-Path $pkg.InstallLocation 'AppxManifest.xml'
  if (-not (Test-Path -LiteralPath $manifestPath)) { return }

  try {
    [xml]$manifest = Get-Content -LiteralPath $manifestPath -ErrorAction Stop
  } catch {
    return
  }

  $apps = $manifest.Package.Applications.Application
  foreach ($app in $apps) {
    if (-not $app.Executable) { continue }
    if ($app.EntryPoint -ne 'Windows.FullTrustApplication') { continue }

    $exe = Join-Path $pkg.InstallLocation ($app.Executable -replace '/', '\')
    $display = $app.VisualElements.DisplayName
    if (-not $display -or $display -like 'ms-resource:*') {
      $display = ($pkg.Name -split '\.')[-1]
    }
    Add-Viewer $display $exe 'store'
  }
}

[pscustomobject]@{ viewers = @($viewers) } | ConvertTo-Json -Compress -Depth 4
