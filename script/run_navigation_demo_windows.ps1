# Run the navigation playground with the same Windows AdaScript dependency used by Studio.
[CmdletBinding()]
param(
    [switch]$ValidateScript,
    [string]$CapturePath,
    [string]$ScratchPath
)

$ErrorActionPreference = 'Stop'
$demoRoot = Split-Path -Parent $PSScriptRoot
$demoEnvironment = @{}
$demoVariables = @('ADAENGINE_HEADLESS', 'ADAENGINE_DISABLE_SWAN', 'ADAENGINE_GRAVITY_PACKAGE_PATH', 'TINT_EXECUTABLE')
foreach ($name in $demoVariables) { $demoEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    if (-not $env:ADAENGINE_GRAVITY_PACKAGE_PATH) {
        $demoGravity = & python (Join-Path $PSScriptRoot 'ensure_windows_gravity.py')
        if ($LASTEXITCODE -ne 0) { throw 'Windows AdaScript dependency preparation failed.' }
        $env:ADAENGINE_GRAVITY_PACKAGE_PATH = ($demoGravity | Select-Object -Last 1).Trim()
    }
    $env:ADAENGINE_HEADLESS = if ($ValidateScript) { '1' } else { '0' }
    if (-not $ValidateScript) {
        $env:ADAENGINE_DISABLE_SWAN = '0'
        if (-not $env:TINT_EXECUTABLE) {
            $demoTint = & python (Join-Path $PSScriptRoot 'ensure_tint.py') --jobs 2
            if ($LASTEXITCODE -ne 0) { throw 'Tint preparation failed.' }
            $env:TINT_EXECUTABLE = ($demoTint | Select-Object -Last 1).Trim()
        }
    }
    $demoArguments = @('run', '--package-path', $demoRoot)
    if ($ScratchPath) { $demoArguments += @('--scratch-path', $ScratchPath) }
    $demoArguments += 'NavigationDemo'
    if ($ValidateScript) { $demoArguments += '--validate-script' }
    elseif ($CapturePath) {
        $demoArguments += @('--capture', $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CapturePath))
    }
    & swift @demoArguments
    if ($LASTEXITCODE -ne 0) { throw "Navigation demo failed with exit code $LASTEXITCODE." }
} finally {
    foreach ($name in $demoVariables) { [Environment]::SetEnvironmentVariable($name, $demoEnvironment[$name], 'Process') }
}
