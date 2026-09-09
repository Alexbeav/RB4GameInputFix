[CmdletBinding()]
param([string]$MapperDirectory = 'C:\Program Files\RB4InstrumentMapper')
$ErrorActionPreference = 'Stop'
$record = Get-Content -LiteralPath (Join-Path $MapperDirectory 'rb4-legacy-gameinput.json') -Raw | ConvertFrom-Json
$target = Join-Path (Resolve-Path -LiteralPath $MapperDirectory).Path 'gameinput.dll'
if ($record.Target -ine $target) { throw 'Installation target mismatch.' }
if ((Get-FileHash -LiteralPath $target).Hash -ne $record.ProxySHA256) { throw 'Installed proxy checksum mismatch.' }
if ((Get-FileHash -LiteralPath (Join-Path $env:WINDIR 'System32\GameInput.dll')).Hash -ne $record.WindowsSHA256) { throw 'Windows GameInput changed. This release requires an updated compatibility profile.' }
& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $PSScriptRoot 'Test-Native.ps1') -DllPath $target
if ($LASTEXITCODE -ne 0) { throw 'Native validation failed.' }
Write-Output "PASS: installed release $($record.Version) is healthy."
