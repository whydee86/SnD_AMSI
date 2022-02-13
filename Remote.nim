import winim

proc ConvertToString(CharArr :array[256,char]): string =
    var index = 0
    while CharArr[index] != '\x00':
        result.add(CharArr[index])
        index += 1

proc GetRemoteModuleHandle * (hProcess:HANDLE, ModuleName: string): HMODULE =
    var 
        modEntry : MODULEENTRY32A
        snapshot : HANDLE

    snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE,GetProcessId(hProcess))
    if snapshot != INVALID_HANDLE_VALUE:
        modEntry.dwSize = DWORD(sizeof(MODULEENTRY32A))
        if Module32FirstA(snapshot, addr modEntry):
            while Module32NextA(snapshot, addr modEntry):
                if ConvertToString(modEntry.szModule) == ModuleName:
                    return modEntry.hModule
    CloseHandle(snapshot)
    return 0

proc GetRemoteProcAddress * (hProcess : HANDLE, hModule : HMODULE, FuncName : string): FARPROC =
    var
        baseModule : UINT_PTR = cast[UINT64](hModule)
        dosHeader : IMAGE_DOS_HEADER
        ntHeader : IMAGE_NT_HEADERS
        exportDirectory : IMAGE_EXPORT_DIRECTORY
        ExportTable : DWORD = 0
        ExportFunctionTableVA : UINT_PTR = 0
        ExportNameTableVA : UINT_PTR = 0
        ExportOrdinalTableVA  : UINT_PTR = 0
        ExportNameTable: seq[DWORD]
        ExportFunctionTable: seq[DWORD]
        ExportOrdinalsTable: seq[WORD] 
        MinFunNumber : UINT_PTR  = 0
        Func : DWORD = 0
        Ord : WORD = 0
        CharIndex : UINT_PTR = 0
        TempChar : char
        Done : bool = false
        TempFunctionName : string = ""

    if ReadProcessMemory(hProcess, cast[LPCVOID](baseModule), addr dosHeader, sizeof(dosHeader), NULL) == 0:
        echo "Failed to Read the DOS header and check it's magic number: ", GetlastError()
        return NULL
    if ReadProcessMemory(hProcess, cast[LPCVOID](baseModule + dosHeader.e_lfanew), addr ntHeader, sizeof(ntHeader), NULL) == 0:
        echo "Failed to Read and check the NT signature: ", GetlastError()
        return NULL

    ExportTable = (ntHeader.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT]).VirtualAddress
    
    if ReadProcessMemory(hProcess, cast[LPCVOID](baseModule + ExportTable), addr exportDirectory, sizeof(exportDirectory), NULL) == 0:
        echo "Failed to Read the main export table ", GetlastError()

    ExportFunctionTableVA = cast[UINT_PTR](baseModule) + exportDirectory.AddressOfFunctions
    ExportNameTableVA = cast[UINT_PTR](baseModule) + exportDirectory.AddressOfNames
    ExportOrdinalTableVA = cast[UINT_PTR](baseModule) + exportDirectory.AddressOfNameOrdinals
    
    for FunNum in MinFunNumber .. exportDirectory.NumberOfNames:
        Func = 0
        Ord = 0 
        if ReadProcessMemory(hProcess, cast[LPCVOID](ExportNameTableVA + FunNum * sizeof(DWORD)), addr Func, sizeof(Func), NULL) == 0:
            echo "Failed to copy name table ", GetlastError()
            return NULL
        if ReadProcessMemory(hProcess, cast[LPCVOID](ExportOrdinalTableVA + FunNum * sizeof(WORD)), addr Ord, sizeof(Ord), NULL) == 0:
            echo "Failed to copy Ordinal table ", GetlastError()
            return NULL
        ExportNameTable.add(Func)
        ExportOrdinalsTable.add(Ord)
    
    for FunNum in MinFunNumber .. exportDirectory.NumberOfFunctions:
        Func = 0
        if ReadProcessMemory(hProcess, cast[LPCVOID](ExportFunctionTableVA + FunNum * sizeof(DWORD)), addr Func, sizeof(Func), NULL) == 0:
            echo "Failed to copy fucntion table ", GetlastError()
            return NULL
        ExportFunctionTable.add(Func)
    
    for FunNum in MinFunNumber .. exportDirectory.NumberOfNames:
        CharIndex = 0
        Done = false
        TempFunctionName = ""
        while Done == false:
            if ReadProcessMemory(hProcess, cast[LPCVOID](baseModule + ExportNameTable[FunNum] + CharIndex), addr TempChar, sizeof(TempChar), NULL) == 0:
                echo "Failed to read the names of the functions", GetlastError()
                return NULL
            if TempChar == '\0' or TempChar == '`' or TempChar == '\176':
                Done = true
            else:
                TempFunctionName.add(TempChar)
            CharIndex += 1
        if TempFunctionName == FuncName:
            return cast[FARPROC](baseModule + ExportFunctionTable[ExportOrdinalsTable[FunNum]])
    echo "[X] Proc name does not exits"
    return NULL


