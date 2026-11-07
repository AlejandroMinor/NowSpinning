# What the widget is on a desktop, tried on a real one: above other windows,
# see-through around its disc with clicks going through there to what's
# behind, and on "bottom", behind the other windows. With backdrop.ps1, a
# magenta window, behind it: wherever the widget isn't drawn, the screen
# shows magenta, and wherever clicks go through, the backdrop counts them.
param([Parameter(Mandatory)] [string] $Package)

$ErrorActionPreference = "Stop"
$folder = (Resolve-Path $Package).Path
$exe = Join-Path $folder "nowspinning.exe"

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Desk {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    delegate bool EnumProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr data);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();

    // The biggest visible window of a process: the widget's own.
    public static RECT WindowOf(uint pid) {
        RECT best = new RECT(); long bestArea = 0;
        EnumWindows((hwnd, data) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            RECT r;
            if (owner == pid && IsWindowVisible(hwnd) && GetWindowRect(hwnd, out r)) {
                long area = (long)(r.Right - r.Left) * (r.Bottom - r.Top);
                if (area > bestArea) { bestArea = area; best = r; }
            }
            return true;
        }, IntPtr.Zero);
        return best;
    }

    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(300);  // the widget checks the pointer every 30 ms
        mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
        mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
    }
}
'@
[void][Desk]::SetProcessDPIAware()

function Get-Pixel([int] $x, [int] $y) {
    $bitmap = New-Object System.Drawing.Bitmap 1, 1
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size 1, 1))
    $color = $bitmap.GetPixel(0, 0)
    $graphics.Dispose(); $bitmap.Dispose()
    return $color
}
function Test-Magenta($color) { $color.R -gt 200 -and $color.G -lt 80 -and $color.B -gt 200 }
function Show($name, $color) { Write-Host ("{0}: rgb({1}, {2}, {3})" -f $name, $color.R, $color.G, $color.B) }

$config = Join-Path ([IO.Path]::GetTempPath()) ("nowspinning-desktop-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $config | Out-Null
$env:NOWSPINNING_CONFIG_DIR = $config
$env:NOWSPINNING_DEMO = "1"
function Set-Layer([string] $layer) {
    $json = '{ "skin": "vinyl", "anchor": "center", "discSize": "large", "lyrics": false, "layer": "' + $layer + '" }'
    [IO.File]::WriteAllText((Join-Path $config "config.json"), $json)
}

$clicks = Join-Path $config "clicks.txt"
New-Item -ItemType File -Force $clicks | Out-Null
$backdrop = Start-Process powershell.exe -ArgumentList "-NoProfile", "-File", (Join-Path $PSScriptRoot "backdrop.ps1"), "-Clicks", $clicks -PassThru
Start-Sleep -Seconds 4

Set-Layer "overlay"
$widget = Start-Process $exe -PassThru
Start-Sleep -Seconds 8
$failures = @()

try {
    $rect = [Desk]::WindowOf([uint32]$widget.Id)
    Write-Host "widget window: $($rect.Left),$($rect.Top) to $($rect.Right),$($rect.Bottom)"
    if ($rect.Right -le $rect.Left) { throw "no visible widget window" }
    $cx = [int](($rect.Left + $rect.Right) / 2)
    $cy = [int](($rect.Top + $rect.Bottom) / 2)
    $corner = @($rect.Left + 4, $rect.Top + 4)

    # Above the backdrop, see-through around the disc.
    $center = Get-Pixel $cx $cy; Show "center, on top" $center
    $edge = Get-Pixel $corner[0] $corner[1]; Show "corner, on top" $edge
    if (Test-Magenta $center) { $failures += "the widget isn't drawn above other windows" }
    if (-not (Test-Magenta $edge)) { $failures += "the widget's corner isn't see-through" }

    # Clicks: through the corner to the backdrop, but not through the disc.
    [Desk]::Click($corner[0], $corner[1]); Start-Sleep -Milliseconds 700
    $through = @(Get-Content $clicks).Count
    Write-Host "clicks on the corner that reached the backdrop: $through"
    if ($through -lt 1) { $failures += "a click on the widget's see-through corner didn't go through" }
    [Desk]::Click($cx, $cy); Start-Sleep -Milliseconds 700
    $after = @(Get-Content $clicks).Count
    Write-Host "clicks that reached the backdrop after one on the disc: $after"
    if ($after -ne $through) { $failures += "a click on the disc went through to the window behind" }
    [Desk]::SetCursorPos(5, 5) | Out-Null

    # "bottom": behind the backdrop, then back on top, applied live.
    Set-Layer "bottom"; Start-Sleep -Seconds 3
    $center = Get-Pixel $cx $cy; Show "center, on bottom" $center
    if (-not (Test-Magenta $center)) { $failures += "on the bottom layer the widget stays above other windows" }
    Set-Layer "overlay"; Start-Sleep -Seconds 3
    $center = Get-Pixel $cx $cy; Show "center, back on top" $center
    if (Test-Magenta $center) { $failures += "back on the overlay layer the widget stays behind" }
} finally {
    & $exe --quit
    $widget.WaitForExit(15000) | Out-Null
    $backdrop | Stop-Process -ErrorAction SilentlyContinue
}

if ($failures) { throw ($failures -join "`n") }
Write-Host "On top, see-through, clicked through, and behind on the bottom layer"
