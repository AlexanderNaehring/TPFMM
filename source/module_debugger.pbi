﻿EnableExplicit

DeclareModule debugger
  Declare SetLogFile(file$)
  Declare DeleteLogFile()
  Declare Add(str$)
EndDeclareModule

Module debugger
  Global LogFile$
  
  Procedure SetLogFile(file$)
    LogFile$ = file$
  EndProcedure
  Procedure DeleteLogFile()
    DeleteFile(LogFile$, #PB_FileSystem_Force)
  EndProcedure
  Procedure Add(str$)
    Protected file
    Debug str$
    If LogFile$ <> ""
      file = OpenFile(#PB_Any, LogFile$, #PB_File_Append|#PB_File_NoBuffering)
      If file
        WriteStringN(file, str$)
        CloseFile(file)
      EndIf
    EndIf
  EndProcedure
EndModule