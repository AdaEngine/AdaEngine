[CmdletBinding()]
param([switch]$WebOnly, [switch]$AndroidOnly)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'Install WSL with an Ubuntu 24.04 distribution first.' }
$workerRoot = Split-Path -Parent $PSScriptRoot
$workerLinuxRoot = (& wsl.exe --exec wslpath -a -u $workerRoot | Select-Object -Last 1).Trim()
& wsl.exe --user root --exec apt-get update
if ($LASTEXITCODE -ne 0) { throw 'WSL package index update failed.' }
& wsl.exe --user root --exec apt-get install -y build-essential clang lld cmake ninja-build git curl unzip python3 libxml2 libcurl4t64 libedit2 libsqlite3-0 libpython3.12 openjdk-17-jdk pkg-config zlib1g-dev
if ($LASTEXITCODE -ne 0) { throw 'WSL build dependencies could not be installed.' }
$workerArguments = @('--exec', 'env')
$workerLicenses = Join-Path $env:LOCALAPPDATA 'Android/Sdk/licenses'
if (Test-Path -LiteralPath $workerLicenses) {
    $workerLinuxLicenses = (& wsl.exe --exec wslpath -a -u $workerLicenses | Select-Object -Last 1).Trim()
    $workerArguments += "ADA_WINDOWS_ANDROID_LICENSES=$workerLinuxLicenses"
}
$workerArguments += @('python3', "$workerLinuxRoot/Tools/Windows/setup_build_worker.py")
if ($WebOnly) { $workerArguments += '--web' }
if ($AndroidOnly) { $workerArguments += '--android' }
& wsl.exe @workerArguments
if ($LASTEXITCODE -ne 0) { throw 'Cross-build tool setup failed. See the diagnostic above.' }
