# Report submitted to RB4InstrumentMapper issue #71

Posted September 9, 2026: [https://github.com/TheNathannator/RB4InstrumentMapper/issues/71#issuecomment-5600867756](https://github.com/TheNathannator/RB4InstrumentMapper/issues/71#issuecomment-5600867756).

I have a tested, app-local workaround and some detail on where the redirection happens.

With RB4InstrumentMapper 5.3.0.0, SharpGameInput already P/Invokes
`gameinput.dll!GameInputCreate`. In Windows GameInput.dll version
`0.2309.26100.9278` (x64), that exported function itself checks for
`GameInputRedist.dll` and forwards to it when available. Selecting the System32
GameInput.dll by full path alone therefore does not necessarily force the legacy
implementation.

I built a small app-local proxy that loads the genuine System32 GameInput.dll,
verifies its exact SHA-256 and factory entry-point instructions, then invokes the
same internal factory used by the export's legacy fallback. It changes no system
files, registry entries, services, or executable memory. Removing the app-local
proxy restores normal DLL selection. No Microsoft DLLs are redistributed.

The serious limitation: this uses undocumented internal offsets. It supports
exactly one Windows DLL hash and refuses unknown builds with 0x8007051A. It is a
compatibility workaround, not a general fix suitable for unconditional inclusion
in the mapper.

Tested configuration and evidence:

- RB4InstrumentMapper 5.3.0.0; Xbox One guitar; RPCS3 compatibility output.
- Inbox GameInput: 0.2309.26100.9278 x64; redistributable installed: 3.3.221.0.
- Inbox SHA-256: F9F5ADBDE4A2883B9B307BB1848A120094904578D92B21100828BD83F7B77CB6.
- The first prototype ran for approximately five hours of gameplay.
- The final implementation passed a physical gameplay test: The Joker, 100%,
  428-note streak, including working tilt/star power.
- A separate probe passed repeated create/release tests with the redistributable
  explicitly preloaded, and verified that the resulting COM vtable belongs to
  System32 GameInput.dll. Windows file hashes and exported code bytes were unchanged.
- The mapper CLI detected the guitar, created its virtual controller, and exited normally.

A reboot or actual redistributable reinstall was not performed as part of this
validation. The 64-bit System32 redist DLL was already absent during the initial
inspection; the preloaded-redist probe verifies implementation selection, not a
complete reproduction of every affected installation.

Would the maintainers prefer a standalone diagnostic/workaround reference, or a
PR adding loader/version diagnostics to help investigate a supported fix for the
newer GameInput runtime? A broader fix should check raw-report behavior and API
compatibility on current redistributables, rather than depend on these offsets.

Source, installation/rollback scripts, and validation probes: https://github.com/Alexbeav/RB4GameInputFix (commit 760e5f7). I can also provide further disassembly details.
