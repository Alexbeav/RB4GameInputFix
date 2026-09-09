[CmdletBinding()]
param([string]$MapperDirectory = 'C:\Program Files\RB4InstrumentMapper')
$ErrorActionPreference = 'Stop'
$MapperDirectory = (Resolve-Path -LiteralPath $MapperDirectory).Path
$target = Join-Path $MapperDirectory 'gameinput.dll'
$recordPath = Join-Path $MapperDirectory 'rb4-legacy-gameinput.json'
if (Get-Process -Name RB4InstrumentMapper,RB4InstrumentMapper.CLI -ErrorAction SilentlyContinue) { throw 'Close RB4InstrumentMapper first.' }
if (!(Test-Path -LiteralPath $target)) { Write-Output 'Mapper-local DLL is already absent.'; return }
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
if ($record.Target -ine $target) { throw 'Installation record target mismatch.' }
if ((Get-FileHash -LiteralPath $target).Hash -ne $record.ProxySHA256) { throw 'Local DLL has changed. Refusing to remove it.' }
Remove-Item -LiteralPath $target
Remove-Item -LiteralPath $recordPath
Write-Output 'Removed mapper-local shim. Normal Windows GameInput selection restored.'
