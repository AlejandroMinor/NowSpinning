# Builds dist\NowSpinning: nowspinning.exe, the Qt it runs on and the widget's
# QML, ready to run with nothing else installed. From the repository, in a
# Developer PowerShell for Visual Studio (for the compiler, and the Ninja and
# CMake that come with it), with Qt's bin folder on the PATH: Qt 6.5 or newer
# for MSVC, with the Qt 5 Compatibility module.
param([string] $Version = "0.0.0")

$ErrorActionPreference = "Stop"
$build = "build\windows"
$out = "dist\NowSpinning"

cmake -S windows -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release "-DNOWSPINNING_VERSION=$Version"
if ($LASTEXITCODE) { exit $LASTEXITCODE }
cmake --build $build
if ($LASTEXITCODE) { exit $LASTEXITCODE }

if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item "$build\nowspinning.exe" $out

# Qt, and the QML modules the widget imports. Quickshell's own aren't found
# (nowspinning.exe brings those): only a warning.
windeployqt --release --no-translations --no-system-d3d-compiler --no-opengl-sw --no-compiler-runtime `
    --qmldir nowspinning --qmldir windows\shim "$out\nowspinning.exe"
if ($LASTEXITCODE) { exit $LASTEXITCODE }

# The C++ runtime of the compiler that built it, beside the program, so it
# needs no Visual C++ Redistributable installed.
$crt = Get-ChildItem "$env:VCToolsRedistDir\x64" -Directory -Filter "Microsoft.VC*.CRT" | Select-Object -First 1
if (-not $crt) { throw "No C++ runtime under $env:VCToolsRedistDir; run this from a Developer PowerShell" }
Copy-Item "$($crt.FullName)\*.dll" $out

Copy-Item -Recurse nowspinning "$out\nowspinning"
Copy-Item LICENSE, config.example.json $out
Copy-Item nowspinning\fonts\PermanentMarker-LICENSE.txt $out

$size = (Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
"{0} is {1:N0} MB" -f $out, $size
