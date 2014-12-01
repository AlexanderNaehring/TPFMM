Macro Min(a,b)
   (Bool((a)<=(b)) * (a) + Bool((b)<(a)) * (b))
 EndMacro
 
 Macro Max(a,b)
   (Bool((a)>=(b)) * (a) + Bool((b)>(a)) * (b))
EndMacro


DeclareModule misc
  EnableExplicit
  
  Declare.s Path(path$, delimiter$ = "")
  Declare.s Bytes(bytes.d)
  Declare CreateDirectoryAll(dir$, delimiter$ = "")
  Declare extractBinary(filename$, *adress, len.i, overwrite = #True)
EndDeclareModule


Module misc
  
  Procedure.s Path(path$, delimiter$ = "")
    path$ + "/"                             ; add a / delimiter to the end
    path$ = ReplaceString(path$, "\", "/")  ; replace all \ with /
    While FindString(path$, "//")           ; strip multiple /
      path$ = ReplaceString(path$, "//", "/")
    Wend
    If delimiter$ = ""
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        delimiter$ = "\"
      CompilerElse
        delimiter$ = "/"
      CompilerEndIf
    EndIf
    If delimiter$ <> "/"
      path$ = ReplaceString(path$, "/", delimiter$)
    EndIf
    ProcedureReturn path$  
  EndProcedure

  Procedure CreateDirectoryAll(dir$, delimiter$ = "")
    debugger::Add("CreateDirectoryAll("+dir$+")")
    Protected result, dir_sub$, dir_total$, count
    If delimiter$ = ""
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        delimiter$ = "\"
      CompilerElse
        delimiter$ = "/"
      CompilerEndIf
    EndIf
    
    dir$ = Path(dir$, delimiter$)
    
    If FileSize(dir$) = -2
      ProcedureReturn #True
    EndIf
    
    count = 1
    dir_sub$ = StringField(dir$, count, delimiter$) + delimiter$
    dir_total$ = dir_sub$
    
    While dir_sub$ <> ""
      If Not FileSize(dir_total$) = -2
        CreateDirectory(dir_total$)
      EndIf
      count + 1
      dir_sub$ = StringField(dir$, count, delimiter$)
      dir_total$ + dir_sub$ + delimiter$
    Wend
    ProcedureReturn #True
  EndProcedure

  Procedure.s Bytes(bytes.d)
    If bytes > 1024*1024*1024
      ProcedureReturn StrD(bytes/1024/1024/1024,2) + " GiB"
    ElseIf bytes > 1024*1024
      ProcedureReturn StrD(bytes/1024/1024,2) + " MiB"
    ElseIf bytes > 1024
      ProcedureReturn StrD(bytes/1024,0) + " KiB"
    ElseIf bytes > 0
      ProcedureReturn StrD(bytes,0) + " Byte"
    Else
      ProcedureReturn ""
    EndIf
  EndProcedure
  
  Procedure extractBinary(filename$, *adress, len.i, overwrite = #True)
    Protected file.i, written.i
    If len <= 0
      ProcedureReturn #False
    EndIf
    If Not overwrite And FileSize(filename$) >= 0
      ProcedureReturn #False
    EndIf
    file = CreateFile(#PB_Any, filename$)
    If Not file
      ProcedureReturn #False
    EndIf
    written = WriteData(file, *adress, len)
    CloseFile(file)
    If written = len
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 107
; Folding = sy
; EnableUnicode
; EnableXP