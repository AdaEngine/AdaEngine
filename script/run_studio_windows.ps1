# Builds and opens the native Windows Studio with the verified shader compiler.
[CmdletBinding()]
param(
    [string]$ScratchPath
)

$ErrorActionPreference = 'Stop'
$studioRoot = Split-Path -Parent $PSScriptRoot
$studioEditor = Join-Path $studioRoot 'Editor'
if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
    throw 'This launcher requires Windows.'
}

# Headless builds are useful for tests, but cannot display Studio.
$env:ADAENGINE_HEADLESS = '0'
$env:ADAENGINE_DISABLE_SWAN = '0'
$env:ADAENGINE_PACKAGE_PATH = $studioRoot
& python (Join-Path $studioRoot 'script/ensure_windows_icon.py')
if ($LASTEXITCODE -ne 0) { throw 'Studio icon compilation failed.' }

if (-not $env:ADAENGINE_GRAVITY_PACKAGE_PATH) {
    $studioGravity = & python (Join-Path $studioRoot 'script/ensure_windows_gravity.py')
    if ($LASTEXITCODE -ne 0) { throw 'Windows AdaScript dependency preparation failed.' }
    $env:ADAENGINE_GRAVITY_PACKAGE_PATH = ($studioGravity | Select-Object -Last 1).Trim()
}
& python (Join-Path $studioRoot 'script/ensure_windows_export_tools.py')
if ($LASTEXITCODE -ne 0) { throw 'AdaScript export compiler preparation failed.' }

if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $studioVS = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($studioVS) {
            $studioNinja = Join-Path $studioVS 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja'
            if (Test-Path -LiteralPath (Join-Path $studioNinja 'ninja.exe')) {
                $env:Path = "$studioNinja;$env:Path"
            }
        }
    }
}

$studioTint = & python (Join-Path $studioRoot 'script/ensure_tint.py')
if ($LASTEXITCODE -ne 0) { throw 'Tint setup failed. Check Python, CMake, Ninja and the C++ toolchain.' }
$env:TINT_EXECUTABLE = ($studioTint | Select-Object -Last 1).Trim()

$studioBuildArguments = @('build', '--package-path', $studioEditor, '--product', 'AdaEditor')
if ($ScratchPath) { $studioBuildArguments += @('--scratch-path', $ScratchPath) }
& swift @studioBuildArguments
if ($LASTEXITCODE -ne 0) { throw 'Studio build failed. The compiler diagnostics are above.' }

$studioBinaryArguments = @('build', '--package-path', $studioEditor, '--show-bin-path')
if ($ScratchPath) { $studioBinaryArguments += @('--scratch-path', $ScratchPath) }
$studioBin = (& swift @studioBinaryArguments | Select-Object -Last 1).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not locate the built Studio executable.' }
Start-Process -FilePath (Join-Path $studioBin 'AdaEditor.exe') -WorkingDirectory $studioEditor -WindowStyle Normal
