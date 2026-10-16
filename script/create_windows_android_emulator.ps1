[CmdletBinding()]
param([string]$Name = 'AdaStudio_API35', [string]$AndroidSdk = (Join-Path $env:LOCALAPPDATA 'Android/Sdk'))
$ErrorActionPreference = 'Stop'
if ($Name -notmatch '^[A-Za-z0-9_-]+$') { throw 'Use letters, digits, underscores or hyphens for the emulator name.' }
$emulatorImage = Join-Path $AndroidSdk 'system-images/android-35/default/x86_64'
if (-not (Test-Path -LiteralPath (Join-Path $emulatorImage 'system.img'))) { throw 'Install Android API 35 x86_64 system image first.' }
$emulatorHome = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.android/avd'
$emulatorProfile = Join-Path $emulatorHome "$Name.avd"
if (Test-Path -LiteralPath (Join-Path $emulatorProfile 'config.ini')) { Write-Output $Name; exit 0 }
New-Item -ItemType Directory -Path $emulatorProfile -Force | Out-Null
@"
avd.ini.encoding=UTF-8
path=$emulatorProfile
target=android-35
"@ | Set-Content -LiteralPath (Join-Path $emulatorHome "$Name.ini") -Encoding utf8NoBOM
@"
AvdId=$Name
avd.ini.encoding=UTF-8
avd.name=$Name
abi.type=x86_64
hw.cpu.arch=x86_64
hw.cpu.ncore=4
hw.ramSize=2048
hw.lcd.width=1080
hw.lcd.height=1920
hw.lcd.density=420
hw.gpu.enabled=yes
hw.gpu.mode=host
disk.dataPartition.size=4G
image.sysdir.1=$emulatorImage
tag.id=default
tag.display=Default
showDeviceFrame=no
fastboot.forceColdBoot=yes
"@ | Set-Content -LiteralPath (Join-Path $emulatorProfile 'config.ini') -Encoding utf8NoBOM
Write-Output $Name
