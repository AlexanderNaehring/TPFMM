EnableExplicit

DeclareModule debugger
  Declare SetLogFile(file$)
  Declare.s GetLogFile()
  Declare DeleteLogFile()
  Declare deb(str$)
  Declare.s getLog()
EndDeclareModule

Module debugger
  Global LogFile$
  Global log$
  Global mutexDebug = CreateMutex()
  
  Procedure SetLogFile(file$)
    LockMutex(mutexDebug)
    LogFile$ = file$
    UnlockMutex(mutexDebug)
  EndProcedure
  
  Procedure.s GetLogFile()
    ProcedureReturn LogFile$
  EndProcedure
  
  Procedure DeleteLogFile()
    LockMutex(mutexDebug)
    DeleteFile(LogFile$, #PB_FileSystem_Force)
    UnlockMutex(mutexDebug)
  EndProcedure
  
  Procedure deb(str$)
    Static file
    LockMutex(mutexDebug)
    Debug "| "+str$
    
    log$ + #CRLF$ + str$
    If LogFile$ <> ""
      If Not file Or Not IsFile(file)
        file = OpenFile(#PB_Any, LogFile$, #PB_File_Append|#PB_File_NoBuffering)
      EndIf
      If file And IsFile(file)
        WriteStringN(file, str$)
      EndIf
    EndIf
    UnlockMutex(mutexDebug)
  EndProcedure
  
  Procedure.s getLog()
    Protected str$
    LockMutex(mutexDebug)
    ret$ = log$
    UnlockMutex(mutexDebug)
    ProcedureReturn ret$
  EndProcedure
EndModule