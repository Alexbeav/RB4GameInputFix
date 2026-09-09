$ErrorActionPreference = 'Stop'
$compiler = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207'
$sdk = 'C:\Program Files (x86)\Windows Kits\10'
$version = '10.0.26100.0'
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
& "$compiler\bin\Hostx64\x64\cl.exe" /nologo /LD /O2 /MT /W4 /WX `
    "/I$compiler\include" "/I$sdk\Include\$version\ucrt" `
    "/I$sdk\Include\$version\shared" "/I$sdk\Include\$version\um" `
    (Join-Path $PSScriptRoot 'gameinput-proxy.c') "/Fo$build\gameinput.obj" `
    /link "/OUT:$build\gameinput.dll" "/IMPLIB:$build\gameinput.lib" `
    "/LIBPATH:$compiler\lib\x64" "/LIBPATH:$sdk\Lib\$version\ucrt\x64" `
    "/LIBPATH:$sdk\Lib\$version\um\x64" kernel32.lib bcrypt.lib
if ($LASTEXITCODE -ne 0) { throw 'Proxy build failed.' }

$manifestPath = Join-Path $PSScriptRoot 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.ProxySHA256 = (Get-FileHash -LiteralPath (Join-Path $build 'gameinput.dll')).Hash
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
