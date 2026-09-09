[CmdletBinding()]
param([string]$MapperDirectory = 'C:\Program Files\RB4InstrumentMapper')
$ErrorActionPreference = 'Stop'
$MapperDirectory = (Resolve-Path -LiteralPath $MapperDirectory).Path
$target = Join-Path $MapperDirectory 'gameinput.dll'
$recordPath = Join-Path $MapperDirectory 'rb4-legacy-gameinput.json'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$proxy = Join-Path $PSScriptRoot 'build\gameinput.dll'
$systemDll = Join-Path $env:WINDIR 'System32\GameInput.dll'
if (![Environment]::Is64BitProcess) { throw 'Use 64-bit PowerShell 7.' }
if (Get-Process -Name RB4InstrumentMapper,RB4InstrumentMapper.CLI -ErrorAction SilentlyContinue) { throw 'Close RB4InstrumentMapper before installation.' }
if ((Get-FileHash -LiteralPath $proxy).Hash -ne $manifest.ProxySHA256) { throw 'Package DLL checksum mismatch.' }
if ((Get-FileHash -LiteralPath $systemDll).Hash -ne $manifest.WindowsSHA256) { throw 'Unsupported Windows GameInput build. No changes made.' }
if ((Get-AuthenticodeSignature -LiteralPath $systemDll).Status -ne 'Valid') { throw 'Windows DLL signature is not valid.' }
if ((Get-FileHash -LiteralPath (Join-Path $MapperDirectory 'SharpGameInput.dll')).Hash -ne $manifest.SharpGameInputSHA256) { throw 'Unsupported mapper dependency. No changes made.' }
$oldBytes = $null
$oldRecord = $null
if (Test-Path -LiteralPath $recordPath) { $oldRecord = [IO.File]::ReadAllBytes($recordPath) }
if (Test-Path -LiteralPath $target) {
    $currentHash = (Get-FileHash -LiteralPath $target).Hash
    $knownHashes = @($manifest.ProxySHA256, 'CB506B8BD7A3D73571AA239494278893A98907A41542CCC1E93B495CCD1A2EA2')
    if ($oldRecord) {
        $previous = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
        if ($previous.Target -ine $target) { throw 'Installation record target mismatch.' }
        $knownHashes += $previous.ProxySHA256
    }
    if ($currentHash -notin $knownHashes) { throw 'Unknown local gameinput.dll. Refusing to overwrite it.' }
    $oldBytes = [IO.File]::ReadAllBytes($target)
}
$staged = Join-Path $MapperDirectory ('gameinput.' + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    Copy-Item -LiteralPath $proxy -Destination $staged
    [IO.File]::Move($staged, $target, $true)
    [ordered]@{ Version=$manifest.Version; Target=$target; ProxySHA256=$manifest.ProxySHA256; WindowsSHA256=$manifest.WindowsSHA256; Installed=(Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding utf8
} catch {
    if ($null -ne $oldBytes) { [IO.File]::WriteAllBytes($target,$oldBytes) }
    elseif ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target).Hash -eq $manifest.ProxySHA256) { Remove-Item -LiteralPath $target }
    if ($null -ne $oldRecord) { [IO.File]::WriteAllBytes($recordPath,$oldRecord) }
    throw
} finally { if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged } }
Write-Output "Installed legacy GameInput $($manifest.Version) for $MapperDirectory"
