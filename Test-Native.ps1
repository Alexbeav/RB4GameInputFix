[CmdletBinding()]
param([string]$DllPath = (Join-Path $PSScriptRoot 'build\gameinput.dll'), [switch]$PreloadRedist)
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class GameInputProbe {
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int Create(out IntPtr result);
 [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int NullCreate(IntPtr result);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint GetModuleFileName(IntPtr module, System.Text.StringBuilder path, int size);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool GetModuleHandleEx(uint flags, IntPtr address, out IntPtr module);
 public static string Owner(IntPtr address) { IntPtr module; if(!GetModuleHandleEx(6,address,out module)) throw new Exception("No module for vtable"); var path=new System.Text.StringBuilder(1024); GetModuleFileName(module,path,path.Capacity); return path.ToString(); }
}
"@
$systemDll = Join-Path $env:WINDIR 'System32\GameInput.dll'
$before = (Get-FileHash -LiteralPath $systemDll).Hash
$inbox = [Runtime.InteropServices.NativeLibrary]::Load($systemDll)
$entry = [Runtime.InteropServices.NativeLibrary]::GetExport($inbox, 'GameInputCreate')
$original = [byte[]]::new(74); [Runtime.InteropServices.Marshal]::Copy($entry,$original,0,74)
if ($PreloadRedist) {
    $redist = Join-Path $env:ProgramFiles 'Microsoft GameInput\x64\GameInputRedist.dll'
    $redistHandle = [Runtime.InteropServices.NativeLibrary]::Load($redist)
    Write-Output "Preloaded redistributable: $redist"
}
$module = [Runtime.InteropServices.NativeLibrary]::Load((Resolve-Path -LiteralPath $DllPath).Path)
$export = [Runtime.InteropServices.NativeLibrary]::GetExport($module, 'GameInputCreate')
$create = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($export,[GameInputProbe+Create])
$nullCall = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($export,[GameInputProbe+NullCreate])
if ($nullCall.Invoke([IntPtr]::Zero) -ne -2147467261) { throw 'Null argument was not rejected with E_POINTER.' }
for ($i=0; $i -lt 20; $i++) {
    $instance=[IntPtr]::Zero
    $hr=$create.Invoke([ref]$instance)
    if ($hr -lt 0 -or $instance -eq [IntPtr]::Zero) { throw ('GameInputCreate failed: 0x{0:X8}' -f $hr) }
    try {
        $vtable=[Runtime.InteropServices.Marshal]::ReadIntPtr($instance)
        $owner=[GameInputProbe]::Owner($vtable)
        if ($owner -ine $systemDll) { throw "Wrong COM implementation: $owner" }
    } finally { [void][Runtime.InteropServices.Marshal]::Release($instance) }
}
$afterBytes = [byte[]]::new(74); [Runtime.InteropServices.Marshal]::Copy($entry,$afterBytes,0,74)
if ([Convert]::ToBase64String($original) -ne [Convert]::ToBase64String($afterBytes)) { throw 'Windows executable memory changed.' }
if ((Get-FileHash -LiteralPath $systemDll).Hash -ne $before) { throw 'Windows DLL changed on disk.' }
Write-Output "PASS: null argument rejected; 20 create/release cycles; COM implementation $owner; Windows disk and export bytes unchanged."
