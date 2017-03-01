EnableExplicit

DeclareModule debugger
  Declare SetLogFile(file$)
  Declare DeleteLogFile()
  Declare add(str$)
  Declare.s getLog()
EndDeclareModule

Module debugger
  Global LogFile$
  Global log$
  
  Procedure SetLogFile(file$)
    LogFile$ = file$
  EndProcedure
  Procedure DeleteLogFile()
    DeleteFile(LogFile$, #PB_FileSystem_Force)
  EndProcedure
  Procedure add(str$)
    Static file
    Debug str$
    log$ + #CRLF$ + str$
    If LogFile$ <> ""
      If Not file Or Not IsFile(file)
        file = OpenFile(#PB_Any, LogFile$, #PB_File_Append|#PB_File_NoBuffering)
      EndIf
      If file And IsFile(file)
        WriteStringN(file, str$)
      EndIf
    EndIf
  EndProcedure
  Procedure.s getLog()
    ProcedureReturn log$
  EndProcedure
EndModule