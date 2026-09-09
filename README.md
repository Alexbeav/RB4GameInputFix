# RB4 legacy GameInput 1.0.0

Mapper-only compatibility shim for RB4InstrumentMapper 5.3.0.0 on Windows x64.
This README is the canonical operating and compatibility guide.

The mapper uses this small app-local gameinput.dll to create the legacy Windows
GameInput object. Microsoft GameInput redistributable installations do not alter
this selection. No system files, services, registry settings, or executable memory
are modified. Use the normal mapper shortcut after installation.

## Compatibility boundary

This release supports exactly Windows GameInput.dll **0.2309.26100.9278** with SHA-256:

`F9F5ADBDE4A2883B9B307BB1848A120094904578D92B21100828BD83F7B77CB6`

The native loader hashes the Windows DLL at every process startup, verifies the
exported factory's 74-byte instruction sequence, and calls its internal legacy
factory with the same arguments as the normal fallback path. Initialization is
serialized with InitOnceExecuteOnce. The Windows module stays loaded while COM
objects can exist. There are no downloaded or redistributed Microsoft DLLs in
the release package.

The internal factory is undocumented. A Windows DLL update requires a reviewed
compatibility update; an unknown hash or changed entry point returns
`0x8007051A` (revision mismatch) instead of guessing offsets. The fix is durable
against redist reinstallations, not automatically compatible with all Windows
updates. Mapper repair/reinstallation can remove the app-local DLL; run Test-Fix.ps1
and reinstall this package if the supported dependency is still present.

## Install, inspect, remove

Use **64-bit PowerShell 7 as Administrator** for installation/removal in Program Files.
Close both mapper GUI and CLI before installing or removing. From this folder:

```powershell
.\Install-Fix.ps1
.\Test-Fix.ps1
.\Undo-Fix.ps1
```

Each accepts `-MapperDirectory` for a different mapper installation.
Installation verifies the package DLL checksum, signed Windows DLL hash, and the
supported SharpGameInput.dll hash listed in [manifest.json](manifest.json).
It refuses to replace an unknown app-local DLL. It recognizes and upgrades the
specific September 6 livestream prototype. Reinstallation is safe.

Installation writes gameinput.dll and rb4-legacy-gameinput.json in the mapper
folder. The installation record survives moving/extracting the release package.
Undo checks the installed hash, then removes those two files and restores normal
Windows DLL selection. It does not restore the experimental prototype or remove
Microsoft GameInput. The prototype backup is retained separately on eagle.

Test-Fix.ps1 runs a separate probe process. It creates/releases 20 legacy objects,
checks which module owns their COM vtable, tests null-argument rejection, and
verifies the Windows DLL and exported instructions have not changed.

## Build and test

The build uses Visual Studio 2022 Community MSVC 14.44.35207 and Windows SDK
10.0.26100.0 at the paths in [Build-Proxy.ps1](Build-Proxy.ps1). It builds x64 with
warnings as errors and a statically linked C runtime. Edit toolchain paths if your
installation differs. Source: [gameinput-proxy.c](gameinput-proxy.c).

```powershell
.\Build-Proxy.ps1
pwsh -NoProfile -File .\Test-Native.ps1
pwsh -NoProfile -File .\Test-Native.ps1 -PreloadRedist
.\Test-Package.ps1
```

Run native tests in fresh processes because DLLs and initialization results remain
cached in a process. Test-Package.ps1 requires the standard installed mapper
SharpGameInput.dll as a fixture. It writes isolated test-results folders and checks
unknown-DLL protection, initial/repeat install, verification, rollback tamper
protection, removal, and repeated removal. It does not replace the installed mapper.

The build regenerates the proxy checksum in manifest.json; it does not expand the
supported Windows or mapper versions. SHA256SUMS.txt describes the shipped package,
not later local rebuilds. The custom shim is unsigned; checksums provide integrity
checks, not publisher authentication.

## Validation through September 9, 2026

- Native create/release and ownership tests passed with the redistributable both
  absent from the probe and explicitly preloaded from its installed x64 directory.
- Installed mapper CLI initialized GameInput and ViGEmBus, created GuitarRPCS3Mapper,
  and exited normally after an 8-second mapping test.
- Installation and rollback tests passed in an isolated directory.
- Windows GameInput.dll remained unchanged on disk and in tested executable memory.
- The prototype worked through an approximately five-hour livestream. On September 9,
  the final build passed physical gameplay validation: The Joker, 100%, a 428-note
  streak, with tilt/star power confirmed working.
- A Windows reboot and actual redistributable reinstall were not performed.

Background: [upstream issue 71](https://github.com/TheNathannator/RB4InstrumentMapper/issues/71).
This is a local compatibility workaround, not an upstream RB4InstrumentMapper release.

## Upstream status

A proposed technical report is in [UPSTREAM-REPORT.md](UPSTREAM-REPORT.md).
It has not been posted. This repository does not claim to fix all GameInput versions.
From a source checkout, run Build-Proxy.ps1 before Install-Fix.ps1; compiled DLLs
are distributed in release packages rather than committed to Git.
