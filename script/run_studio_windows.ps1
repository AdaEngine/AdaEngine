# Builds and opens the native Windows Studio with the verified shader compiler.
[CmdletBinding()]
param(
    [string]$ScratchPath
)

$ErrorActionPreference = 'Stop'
$studioBin = (& (Join-Path $PSScriptRoot 'build_studio_windows.ps1') -Configuration debug -ScratchPath $ScratchPath | Select-Object -Last 1).Trim()
$studioEditor = Join-Path (Split-Path -Parent $PSScriptRoot) 'Editor'
Start-Process -FilePath (Join-Path $studioBin 'AdaEditor.exe') -WorkingDirectory $studioEditor -WindowStyle Normal
