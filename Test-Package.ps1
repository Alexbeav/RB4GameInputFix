$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $PSScriptRoot ('test-results\' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Copy-Item -LiteralPath 'C:\Program Files\RB4InstrumentMapper\SharpGameInput.dll' -Destination $testRoot
$target = Join-Path $testRoot 'gameinput.dll'
[IO.File]::WriteAllBytes($target, [byte[]](1,2,3))
$rejected = $false
try { & (Join-Path $PSScriptRoot 'Install-Fix.ps1') -MapperDirectory $testRoot } catch { if ($_.Exception.Message -notmatch 'Unknown local') { throw }; $rejected=$true }
if (!$rejected -or [IO.File]::ReadAllBytes($target).Length -ne 3) { throw 'Unknown DLL protection failed.' }
Remove-Item -LiteralPath $target
& (Join-Path $PSScriptRoot 'Install-Fix.ps1') -MapperDirectory $testRoot
& (Join-Path $PSScriptRoot 'Install-Fix.ps1') -MapperDirectory $testRoot
& (Join-Path $PSScriptRoot 'Test-Fix.ps1') -MapperDirectory $testRoot
$original=[IO.File]::ReadAllBytes($target)
[IO.File]::WriteAllBytes($target,[byte[]](1,2,3))
$rejected=$false
try { & (Join-Path $PSScriptRoot 'Undo-Fix.ps1') -MapperDirectory $testRoot } catch { if ($_.Exception.Message -notmatch 'has changed') { throw }; $rejected=$true }
if (!$rejected -or [IO.File]::ReadAllBytes($target).Length -ne 3) { throw 'Rollback tamper protection failed.' }
[IO.File]::WriteAllBytes($target,$original)
& (Join-Path $PSScriptRoot 'Undo-Fix.ps1') -MapperDirectory $testRoot
& (Join-Path $PSScriptRoot 'Undo-Fix.ps1') -MapperDirectory $testRoot
if (Test-Path -LiteralPath $target) { throw 'Rollback left DLL installed.' }
Write-Output 'PASS: unknown DLL protection, install, reinstall, runtime check, rollback tamper protection, undo and repeated undo.'
