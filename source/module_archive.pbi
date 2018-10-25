XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"

DeclareModule archive
  EnableExplicit
  
  Declare extract(archive$, directory$)
  Declare pack(archive$, directory$)
  
EndDeclareModule


Module archive
  UseModule debugger
  
  
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
      
      CreateDirectory("7z")
      misc::extractBinary("7z/7z.exe",          ?data7zExe, ?data7zExeEnd - ?data7zExe, #False)
      misc::extractBinary("7z/7z.dll",          ?data7zDll, ?data7zDllEnd - ?data7zDll, #False)
      misc::extractBinary("7z/7z License.txt",  ?data7zLic, ?data7zLicEnd - ?data7zLic, #False)
      
    CompilerCase #PB_OS_Linux
      ; use "unzip"
      
      
    CompilerDefault
      CompilerError "No unpacker defined for this OS"
  CompilerEndSelect
  
  Procedure.s exitCodeError(code)
    Select code
      Case 0 ; ok
        ProcedureReturn ""
      Case 1 ; warning
        ProcedureReturn "non-fatal error"
      Case 2 ; error
        ProcedureReturn "fatal error"
      Case 7 ; command line error
        ProcedureReturn "command line error"
      Case 8 ; memory error
        ProcedureReturn "not enough memory"
      Case 255 ; user abort
        ProcedureReturn "user stopped the process"
      Default  ; unknown error
        ProcedureReturn "unknown error"
    EndSelect
  EndProcedure
  
  Procedure extract(archive$, directory$)
    ;clean dir before extract?
    Protected program$, parameter$, str$
    Protected program, exit
    Protected STDERR$, STDOUT$
    
    If FileSize(archive$) <= 0
      deb("archive:: cannot find archive {"+archive$+"}")
      ProcedureReturn #False
    EndIf
    
    misc::CreateDirectoryAll(directory$)
    If FileSize(directory$) <> -2
      deb("archive:: cannot create target directory {"+directory$+"}")
      ProcedureReturn #False
    EndIf
    
    ; define program
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        program$ = "7z/7z.exe"
        parameter$ = "x "+#DQUOTE$+archive$+#DQUOTE$+" "+#DQUOTE$+"-o"+directory$+#DQUOTE$
        
      CompilerCase #PB_OS_Linux
        ; select archiver based on installed packages
        program = RunProgram("7z", "", GetCurrentDirectory(), #PB_Program_Open|#PB_Program_Hide)
        If program
          ; 7z available, use 7z for all archive types
          If ProgramRunning(program)
            KillProgram(program)
          EndIf
          CloseProgram(program)
          
          program$ = "7z"
          parameter$ = "x -y "+#DQUOTE$+"-o"+directory$+#DQUOTE$+" "+#DQUOTE$+archive$+#DQUOTE$
        Else
          deb("archive:: extract() - 7z not found, use unzip and unrar")
          deb("archive:: extract() - to use 7z, install "+#DQUOTE$+"p7zip-full"+#DQUOTE$+" using your package manager")
          ; 7z not available - use unrar or unzip
          If LCase(GetExtensionPart(archive$)) = "rar"
            program$ = "unrar"
            parameter$ = "x "+#DQUOTE$+archive$+#DQUOTE$+" "+#DQUOTE$+directory$+#DQUOTE$
          Else
            program$ = "unzip"
            parameter$ = #DQUOTE$+archive$+#DQUOTE$+" -d "+#DQUOTE$+directory$+#DQUOTE$
          EndIf
        EndIf
        
    CompilerEndSelect
    
    ; start program
    deb("archive:: {"+program$+" "+parameter$+"}")
    program = RunProgram(program$, parameter$, GetCurrentDirectory(), #PB_Program_Open|#PB_Program_Hide|#PB_Program_Read)
    If Not program
      deb("archive:: could not start program")
      ProcedureReturn #False
    EndIf
    
    While ProgramRunning(program)
      If AvailableProgramOutput(program)
        str$ = ReadProgramString(program)
        STDOUT$ + str$ + #CRLF$
      EndIf
      str$ = ReadProgramError(program)
      If str$
        STDERR$ + str$ + #CRLF$
      EndIf
      Delay(1)
    Wend
    exit = ProgramExitCode(program)
    CloseProgram(program)
    
    If exit <> 0
      deb("archive:: exit code "+exit+", "+exitCodeError(exit)) ; exit code only valid for 7z!
      If STDERR$
        deb("archive:: stderr: "+#CRLF$+STDERR$)
      EndIf
      If STDOUT$
        deb("archive:: stdout: "+#CRLF$+STDOUT$)
      EndIf
    EndIf
    
    If exit = 0 Or exit = 1
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
    
  EndProcedure
  
  Procedure pack(archive$, directory$)
    Protected root$, str$
    Protected program$, parameter$
    Protected program, exit
    Protected STDERR$, STDOUT$
    
    DeleteFile(archive$, #PB_FileSystem_Force)
    
    If FileSize(directory$) <> -2
      deb("archive::pack() - cannot find source directory {"+directory$+"}")
      ProcedureReturn #False
    EndIf
    
    ; 7z will put files in subdir with respect to current working dir!
    directory$  = misc::path(directory$) ; single / at the end
    root$       = GetPathPart(Left(directory$, Len(directory$)-1))
    directory$  = GetFilePart(Left(directory$, Len(directory$)-1))
    
    ; define program
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        program$ = "7z/7z.exe"
        parameter$ = "a "+#DQUOTE$+archive$+#DQUOTE$+" "+#DQUOTE$+misc::path(directory$)+"*"+#DQUOTE$
        
      CompilerCase #PB_OS_Linux
        program$ = "zip"
        parameter$ = "-r "+#DQUOTE$+archive$+#DQUOTE$+" "+#DQUOTE$+directory$+#DQUOTE$
        
    CompilerEndSelect
    
    ; start program
    deb("archive:: {"+program$+" "+parameter$+"}")
    program = RunProgram(program$, parameter$, root$, #PB_Program_Open|#PB_Program_Hide|#PB_Program_Read)
    If Not program
      deb("archive:: could not start program")
      ProcedureReturn #False
    EndIf
    
    While ProgramRunning(program)
      If AvailableProgramOutput(program)
        str$ = ReadProgramString(program)
        STDOUT$ + str$ + #CRLF$
      EndIf
      str$ = ReadProgramError(program)
      If str$
        STDERR$ + str$ + #CRLF$
      EndIf
      Delay(1)
    Wend
    exit = ProgramExitCode(program)
    CloseProgram(program)
    
    If exit <> 0
      deb("archive:: exit code "+exit+", "+exitCodeError(exit)) ; exit code only valid for 7z!
      If STDERR$
        deb("archive:: stderr: "+#CRLF$+STDERR$)
      EndIf
      If STDOUT$
        deb("archive:: stdout: "+#CRLF$+STDOUT$)
      EndIf
    EndIf
    
    If exit = 0 Or exit = 1
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  
EndModule

