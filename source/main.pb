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
    If FileSize(dir$) <> -2 ; "new" directory does not exist
      If FileSize(GetHomeDirectory()+".tpfmm") = -2 ; "old" directory does exist
        Debug "migrate data: "+GetHomeDirectory()+".tpfmm >> "+dir$
        If RenameFile(GetHomeDirectory()+".tpfmm", dir$)
          Debug "data migration complete"
        Else
          Debug "could not migrate data"
        EndIf
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
