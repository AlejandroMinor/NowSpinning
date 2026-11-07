# Tries the package at -Package as a user would run it: with no Qt or
# compiler on the PATH. Fails unless it keeps running, on its own DLLs, with
# no QML error, through every skin, and closes cleanly on --quit.
#
# -Demo plays a made-up track (NOWSPINNING_DEMO): there's no player on a
# build machine. -Shots saves a screenshot of each skin there. -Forbidden is
# a folder none of its DLLs may come from: where Qt was installed to build it.
param(
    [Parameter(Mandatory)] [string] $Package,
    [switch] $Demo,
    [string] $Shots = "",
    [string] $Forbidden = ""
)

$ErrorActionPreference = "Stop"
$folder = (Resolve-Path $Package).Path
$exe = Join-Path $folder "nowspinning.exe"
$env:Path = "$env:SystemRoot\system32;$env:SystemRoot"
Remove-Item Env:QT_PLUGIN_PATH, Env:QML_IMPORT_PATH, Env:QML2_IMPORT_PATH -ErrorAction SilentlyContinue

$config = Join-Path ([IO.Path]::GetTempPath()) ("nowspinning-smoke-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $config | Out-Null
$env:NOWSPINNING_CONFIG_DIR = $config
if ($Demo) { $env:NOWSPINNING_DEMO = "1" } else { Remove-Item Env:NOWSPINNING_DEMO -ErrorAction SilentlyContinue }
$log = Join-Path $env:LOCALAPPDATA "nowspinning\nowspinning.log"

function Set-Skin([string] $skin) {
    $json = '{ "skin": "' + $skin + '", "anchor": "center", "discSize": "large", "lyrics": false, "showArm": true }'
    [IO.File]::WriteAllText((Join-Path $config "config.json"), $json)
}

# Any QML error or warning carries the file it came from.
function Assert-CleanLog {
    $problems = Get-Content $log | Where-Object { $_ -match "file:///|qrc:/|TypeError|ReferenceError|is not a type|Cannot assign|fatal:|error:" }
    if ($problems) {
        Get-Content $log
        throw "The log has errors:`n$($problems -join "`n")"
    }
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
function Save-Screen([string] $name) {
    if (-not $Shots) { return }
    New-Item -ItemType Directory -Force $Shots | Out-Null
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    [System.Drawing.Graphics]::FromImage($bitmap).CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save((Join-Path $Shots "$name.png"))
    $bitmap.Dispose()
}

Set-Skin "vinyl"
$process = Start-Process $exe -PassThru
Start-Sleep -Seconds 10

$process.Refresh()
if ($process.HasExited) {
    Get-Content $log -ErrorAction SilentlyContinue
    throw "nowspinning did not keep running (exit code $($process.ExitCode))"
}
$modules = (Get-Process -Id $process.Id).Modules.FileName
if ($Forbidden) {
    $outside = $modules | Where-Object { $_ -like "$Forbidden*" }
    if ($outside) { throw "nowspinning loaded DLLs from $($Forbidden): $outside" }
}
Write-Host "nowspinning runs with $($modules.Count) modules"
Save-Screen "0-start"
Assert-CleanLog

if ($Demo) {
    $skins = "vinyl", "cd", "disc", "cassette", "minidisc", "walkman", "single",
             "crt", "ascii", "pixel", "polaroid", "hologram", "foil", "riso", "lcd", "stainedglass", "blueprint",
             "hud", "shard", "neon", "neondisc", "matrix", "terminal", "datamosh",
             "sleeve", "deco", "gallery", "ticket", "magazine", "stamp", "poster", "cards",
             "session", "episode", "phantom"
    foreach ($skin in $skins) {
        Set-Skin $skin
        Start-Sleep -Milliseconds 2500
        if ($process.HasExited) { Get-Content $log; throw "nowspinning closed on the $skin skin" }
        Save-Screen $skin
    }
    Assert-CleanLog
    Write-Host "Every skin loaded"
}

# A second start closes it, as --quit does.
& $exe --quit
if (-not $process.WaitForExit(15000)) { throw "nowspinning did not close on --quit" }
if ($process.ExitCode -ne 0) { Get-Content $log; throw "nowspinning closed with exit code $($process.ExitCode)" }
Assert-CleanLog
Get-Content $log
Remove-Item -Recurse -Force $config
