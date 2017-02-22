XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"

DeclareModule archive
  EnableExplicit
  
  Declare extract(archive$, directory$)
  Declare pack(archive$, directory$)
  
EndDeclareModule


Module archive
  
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      ; important: create 7z.exe and 7z.dll files
      DataSection
        data7zExe:
          IncludeBinary "7z/7z.exe"
        data7zExeEnd:
        
        data7zDll:
          IncludeBinary "7z/7z.dll"
        data7zDllEnd:
        
        data7zLic:
          IncludeBinary "7z/7z License.txt"
        data7zLicEnd:
      EndDataSection
    
      misc::extractBinary("7z/7z.exe",          ?data7zExe, ?data7zExeEnd - ?data7zExe, #False)
      misc::extractBinary("7z/7z.dll",          ?data7zDll, ?data7zDllEnd - ?data7zDll, #False)
      misc::extractBinary("7z/7z License.txt",  ?data7zLic, ?data7zLicEnd - ?data7zLic, #False)
    CompilerDefault
      CompilerError "No unpacker defined for this OS"
  CompilerEndSelect
  
  
  Procedure extract(archive$, directory$)
    ;clean dir before extract?
    Protected program$, parameter$
    Protected program, exit
    
    If FileSize(archive$) <= 0
      debugger::add("archive::extract() - Error: Cannot find archive {"+archive$+"}")
      ProcedureReturn #False
    EndIf
    
    misc::CreateDirectoryAll(directory$)
    If FileSize(directory$) <> -2
      debugger::add("archive::extract() - Error: Cannot create target directory {"+directory$+"}")
      ProcedureReturn #False
    EndIf
    
    ; define program
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        program$ = "7z/7z.exe"
        parameter$ = "x "+#DQUOTE$+archive$+#DQUOTE$+" -o"+#DQUOTE$+directory$+#DQUOTE$
    CompilerEndSelect
    
    ; start program
    debugger::add("archive::extract() - {"+program$+" "+parameter$+"}")
    program = RunProgram(program$, parameter$, GetCurrentDirectory(), #PB_Program_Open)
    If Not program
      debugger::add("archive::extract() - Error: could not start program")
      ProcedureReturn #False
    EndIf
    
    ; wait for program to finish and check result
    WaitProgram(program) ;TODO add timeout?
    If ProgramRunning(program)
      KillProgram(program)
    EndIf
    exit = ProgramExitCode(program)
    CloseProgram(program)
    ; error codes 7z.exe:
    ; 0    No error
    ; 1    Warning (Non fatal error(s)). For example, one or more files were locked by some other application, so they were not compressed.
    ; 2    Fatal error
    ; 7    Command line error
    ; 8    Not enough memory for operation
    ; 255  User stopped the process
    If exit = 0
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  Procedure pack(archive$, directory$)
    ; not yet implemented
    Debug "packing not yet implemented"
  EndProcedure
  
  
EndModule

