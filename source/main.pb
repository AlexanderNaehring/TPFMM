EnableExplicit

; set current working directory
Define dir$
CompilerSelect #PB_Compiler_OS
  CompilerCase #PB_OS_Linux
    dir$ = GetUserDirectory(#PB_Directory_ProgramData) + "tpfmm"
    CreateDirectory(dir$)
    SetCurrentDirectory(dir$)
    
  CompilerCase #PB_OS_Windows
    dir$ = GetUserDirectory(#PB_Directory_ProgramData) + "TPFMM"
    If FileSize(GetHomeDirectory()+".tpfmm") = -2
      Debug "migrate data"
      ; old directory exists, migrate data
      If FileSize(dir$) = -2
        DeleteDirectory(dir$, "", #PB_FileSystem_Force|#PB_FileSystem_Recursive)
      EndIf
      If RenameFile(GetHomeDirectory()+".tpfmm", dir$)
        Debug "data migration complete"
      Else
        Debug "could not migrate TPFMM settings"
      EndIf
    EndIf
    
    CreateDirectory(dir$)
    SetCurrentDirectory(dir$)
    
  CompilerDefault
    DebuggerError("Unknown operating system")
    
CompilerEndSelect

XIncludeFile "module_main.pbi"

main::init()

End
