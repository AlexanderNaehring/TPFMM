EnableExplicit

#VERSION$ = "Version 0.3." + #PB_Editor_BuildCount + " Build " + #PB_Editor_CompileCount
#DEBUG = #False

Enumeration
  #UpdateNew
  #UpdateCurrent
  #UpdateFailed
EndEnumeration

Global Event
Global TF$, Ready

Declare checkTFPath(Dir$)
Declare checkUpdate(auto.i)
Declare AddModToList(File$)

XIncludeFile "Windows.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_unrar.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_mods.pbi"

Procedure exit(dummy)
  HideWindow(WindowMain, #True)
  
  FreeModList()
  
  OpenPreferences("TFMM.ini")
  If ReadPreferenceInteger("windowlocation", #False)
    PreferenceGroup("window")
    WritePreferenceInteger("x", WindowX(WindowMain))
    WritePreferenceInteger("y", WindowY(WindowMain))
    WritePreferenceInteger("width", WindowWidth(WindowMain))
    WritePreferenceInteger("height", WindowHeight(WindowMain))
  EndIf
  ClosePreferences()
  
  End
EndProcedure

Procedure checkTFPath(Dir$)
  If Dir$
    If FileSize(Dir$) = -2
      Dir$ = misc::Path(Dir$)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        If FileSize(Dir$ + "TrainFever.exe") > 1
          ; TrainFever.exe is located in this path!
          ; seems to be valid
          
          ; check if able to write to path
          If CreateFile(0, Dir$ + "TFMM.tmp")
            CloseFile(0)
            DeleteFile(Dir$ + "TFMM.tmp")
            ProcedureReturn #True
          EndIf
          ProcedureReturn -1
        EndIf
      CompilerElse
        If FileSize(Dir$ + "TrainFever") > 1
          If CreateFile(0, Dir$ + "TFMM.tmp")
            CloseFile(0)
            DeleteFile(Dir$ + "TFMM.tmp")
            ProcedureReturn #True
          EndIf
          ProcedureReturn -1
        EndIf
      CompilerEndIf
    EndIf
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure checkUpdate(auto.i)
  debugger::Add("checkUpdate")
  Protected URL$
  
  DeleteFile("tfmm-update.ini")
  URL$ = URLEncoder("http://update.alexandernaehring.eu/tfmm/?build="+Str(#PB_Editor_CompileCount)+"&auto="+Str(auto))
  Debug URL$
  If ReceiveHTTPFile("http://update.alexandernaehring.eu/tfmm/?build="+Str(#PB_Editor_CompileCount)+"&auto="+Str(auto), "tfmm-update.ini")
    OpenPreferences("tfmm-update.ini")
    If ReadPreferenceInteger("version", #PB_Editor_CompileCount) > #PB_Editor_CompileCount
      debugger::Add("Update: new version available")
      UpdateResult = #UpdateNew
      AddWindowTimer(WindowMain, TimerUpdate, 100)
    Else
      debugger::Add("Update: no new version")
      If Not auto
        UpdateResult = #UpdateCurrent
        AddWindowTimer(WindowMain, TimerUpdate, 100)
      EndIf
    EndIf
    ClosePreferences()
    DeleteFile("tfmm-update.ini")
  Else
    debugger::Add("ERROR: failed to download ini")
    If Not auto
      UpdateResult = #UpdateFailed
      AddWindowTimer(WindowMain, TimerUpdate, 100)
    EndIf
  EndIf
EndProcedure

;----------------------------------------

Procedure init()
  If #DEBUG
    debugger::SetLogFile("tfmm-output.txt")
  EndIf
  debugger::DeleteLogFile()
  debugger::Add("init()")
  If Not UseZipPacker()
    debugger::Add("ERROR: UseZipPacker()")
    MessageRequester("Error", "Could not initialize ZIP decompression.")
    End
  EndIf
  If Not InitNetwork()
    debugger::Add("ERROR: InitNetwork()")
  EndIf
  If Not UsePNGImageDecoder()
    debugger::Add("ERROR: UsePNGImageDecoder()")
    MessageRequester("Error", "Could not initialize PNG Decoder.")
    End
  EndIf
  images::LoadImages()
  
  InitWindows()
  
  debugger::Add("load settings")
  OpenPreferences("TFMM.ini")
  TF$ = ReadPreferenceString("path", "")
  If ReadPreferenceInteger("windowlocation", #False)
    PreferenceGroup("window")
    ResizeWindow(WindowMain,
                 ReadPreferenceInteger("x", #PB_Ignore),
                 ReadPreferenceInteger("y", #PB_Ignore),
                 ReadPreferenceInteger("width", #PB_Ignore),
                 ReadPreferenceInteger("height", #PB_Ignore))
  EndIf
  If ReadPreferenceInteger("update", 0)
    CreateThread(@checkUpdate(), 1)
  EndIf
  ClosePreferences()
  
  SetGadgetText(GadgetPath, TF$)
  If TF$ = ""
    ; no path specified upon program start -> open settings dialog
    MenuItemSettings(0)
    GadgetButtonAutodetect(0)
  EndIf
  LoadModList()
  
  debugger::Add("init complete")
EndProcedure

init()

Repeat
  Event = WaitWindowEvent(100)
  If Event = #PB_Event_Timer
    Select EventTimer()
      Case TimerSettingsGadgets
        TimerSettingsGadgets()
      Case TimerMainGadgets
        TimerMain()
      Case TimerFinishUnInstall
        FinishDeActivate()
      Case TimerUpdate
        TimerUpdate()
    EndSelect
  EndIf
  
  If Event = #PB_Event_WindowDrop
    If EventWindow() = WindowMain
      HandleDroppedFiles(EventDropFiles())
    EndIf
  EndIf
  
  Select EventWindow()
    Case WindowMain
      If Not WindowMain_Events(Event)
        exit(0)
      EndIf
    Case WindowSettings
      If Not WindowSettings_Events(Event)
        GadgetCloseSettings(0)
      EndIf
    Case WindowModProgress
      If Not WindowModProgress_Events(Event)
        ; user wants to close progress window -> no action, just wait for progress to finish
      EndIf
  EndSelect
ForEver
End
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 74
; FirstLine = 7
; Folding = k
; EnableUnicode
; EnableXP