EnableExplicit

XIncludeFile "WindowMain.pbf"
XIncludeFile "registry.pbi"

Global TimerGadgets = 100

OpenWindowMain()
WindowBounds(WindowMain, 640, 480, #PB_Ignore, #PB_Ignore) 
AddWindowTimer(WindowMain, TimerGadgets, 100)

GadgetButtonAutodetect(0)

Global Event

Procedure exit(dummy)
  HideWindow(WindowMain, #True)
  
  End
EndProcedure

Procedure GadgetButtonBrowse(event)
  Protected Dir$
  Dir$ = GetGadgetText(GadgetPath)
  Dir$ = PathRequester("Train Fever installation path", Dir$)
  If Dir$
    SetGadgetText(GadgetPath, Dir$)
  EndIf
EndProcedure

Procedure GadgetButtonAutodetect(event)
  Protected Dir$
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows 
    Dir$ = Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    If Not FileSize(Dir$) = -2 ; -2 = directory
      Dir$ = Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    EndIf
  CompilerEndIf
 
  If Dir$
    SetGadgetText(GadgetPath, Dir$)  
  EndIf
  
EndProcedure

Procedure TimerGadgets()
  ; check gadgets etc
  Protected Dir$, valid = #False
  
  Dir$ = GetGadgetText(GadgetPath)
  If Dir$
    If FileSize(Dir$) = -2
      ; is directory
      If (Not Right(Dir$, 1) = "\") And (Not Right(Dir$, 1) = "/")
        Dir$ = Dir$ + "/"
      EndIf
      ; path ends with a slash
      If FileSize(Dir$ + "TrainFever.exe") > 1
        ; TrainFever.exe is located in this path!
        ; seems to be valid
        valid = #True
      EndIf
    EndIf
  EndIf
  
  If valid
    SetGadgetColor(GadgetPath, #PB_Gadget_FrontColor, -1)
  Else
    SetGadgetColor(GadgetPath, #PB_Gadget_FrontColor, #Red)
  EndIf
    
EndProcedure


Repeat
  Event = WaitWindowEvent(100)
  If Event = #PB_Event_Timer
    Select EventTimer()
      Case TimerGadgets
        TimerGadgets()
    EndSelect
  EndIf
  
  Select EventWindow()
    Case WindowMain
      If Not WindowMain_Events(Event)
        exit(0)
      EndIf
  EndSelect
ForEver
End
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 47
; FirstLine = 27
; Folding = -
; EnableUnicode
; EnableXP