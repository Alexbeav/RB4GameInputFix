#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <string.h>

// Local compatibility shim for RB4InstrumentMapper 5.3, Windows x64 only.
// Version 1.0.0: call the verified inbox factory without patching executable memory.
typedef HRESULT (WINAPI *InboxFactory)(void *, void **);
static INIT_ONCE once = INIT_ONCE_STATIC_INIT;
static InboxFactory factory;
static void *factoryContext;
static HMODULE inboxModule; // Retained while returned COM objects can exist.
static HRESULT initResult = E_FAIL;
static const BYTE supportedHash[32] = {
  0xf9,0xf5,0xad,0xbd,0xe4,0xa2,0x88,0x3b,0x9b,0x30,0x7b,0xb1,0x84,0x8a,0x12,0x00,
  0x94,0x90,0x45,0x78,0xd9,0x2b,0x21,0x10,0x08,0x28,0xbd,0x83,0xf7,0xb7,0x7c,0xb6
};

static HRESULT VerifyFile(HANDLE file)
{
    BCRYPT_ALG_HANDLE algorithm = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    BYTE buffer[16384], digest[32];
    DWORD count;
    HRESULT result = E_FAIL;
    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, NULL, 0) < 0) goto done;
    if (BCryptCreateHash(algorithm, &hash, NULL, 0, NULL, 0, 0) < 0) goto done;
    for (;;) {
        if (!ReadFile(file, buffer, sizeof(buffer), &count, NULL)) { result = HRESULT_FROM_WIN32(GetLastError()); goto done; }
        if (!count) break;
        if (BCryptHashData(hash, buffer, count, 0) < 0) goto done;
    }
    if (BCryptFinishHash(hash, digest, sizeof(digest), 0) < 0) goto done;
    result = memcmp(digest, supportedHash, sizeof(digest)) ? HRESULT_FROM_WIN32(ERROR_REVISION_MISMATCH) : S_OK;
done:
    if (hash) BCryptDestroyHash(hash);
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    return result;
}

static BOOL CALLBACK Initialize(PINIT_ONCE unusedOnce, PVOID unusedParam, PVOID *unusedContext)
{
    WCHAR path[MAX_PATH];
    UINT length = GetSystemDirectoryW(path, MAX_PATH);
    HANDLE file;
    BYTE *entry;
    // Full exported entry point, including the inbox fallback tail call.
    static const BYTE expected[] = {
      0x40,0x53,0x48,0x83,0xec,0x20,0x48,0x8b,0xd9,0xe8,0x72,0x96,0x02,0x00,
      0x85,0xc0,0x75,0x14,0x48,0x8b,0x05,0xef,0x9f,0x05,0x00,0x48,0x8b,0xcb,
      0x48,0x83,0xc4,0x20,0x5b,0xe9,0x6a,0x97,0x04,0x00,0x83,0xf8,0x01,0x74,
      0x0b,0x48,0x83,0x23,0x00,0x48,0x83,0xc4,0x20,0x5b,0xc3,0xcc,0x48,0x8b,
      0xd3,0x48,0x8d,0x0d,0x88,0x97,0x05,0x00,0x48,0x83,0xc4,0x20,0x5b,0xe9,
      0x66,0x35,0x00,0x00
    };
    (void)unusedOnce; (void)unusedParam; (void)unusedContext;
    if (!length || length + 15 >= MAX_PATH) { initResult = HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER); return TRUE; }
    lstrcatW(path, L"\\GameInput.dll");
    // Keep a non-write/non-delete sharing handle through LoadLibrary to pin the verified file.
    file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) { initResult = HRESULT_FROM_WIN32(GetLastError()); return TRUE; }
    initResult = VerifyFile(file);
    if (SUCCEEDED(initResult)) {
        inboxModule = LoadLibraryExW(path, NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!inboxModule) initResult = HRESULT_FROM_WIN32(GetLastError());
    }
    CloseHandle(file);
    if (FAILED(initResult)) { OutputDebugStringW(L"RB4 legacy GameInput: unsupported or unreadable Windows DLL. Run Test-Fix.ps1.\n"); return TRUE; }
    entry = (BYTE *)GetProcAddress(inboxModule, "GameInputCreate");
    if (entry != (BYTE *)inboxModule + 0x3880 || memcmp(entry, expected, sizeof(expected))) {
        initResult = HRESULT_FROM_WIN32(ERROR_REVISION_MISMATCH);
        return TRUE;
    }
    // Exact Windows 0.2309.26100.9278 SHA-256 above. Undocumented offsets:
    // identical arguments and destination to the verified export's fallback tail.
    factoryContext = (BYTE *)inboxModule + 0x5d048;
    factory = (InboxFactory)((BYTE *)inboxModule + 0x6e30);
    initResult = S_OK;
    return TRUE;
}

__declspec(dllexport) HRESULT WINAPI GameInputCreate(void **result)
{
    if (!result) return E_POINTER;
    *result = NULL;
    if (!InitOnceExecuteOnce(&once, Initialize, NULL, NULL)) return HRESULT_FROM_WIN32(GetLastError());
    if (FAILED(initResult)) return initResult;
    return factory(factoryContext, result);
}
