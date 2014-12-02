EnableExplicit

#VERSION$ = "Version 0.5." + #PB_Editor_BuildCount + " Build " + #PB_Editor_CompileCount
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
XIncludeFile "module_locale.pbi"

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
  If Not UseJPEGImageDecoder()
    debugger::Add("ERROR: UseJPEGImageDecoder()")
    MessageRequester("Error", "Could not initialize JPEG Decoder.")
    End
  EndIf
  images::LoadImages()
  
  CreateRegularExpression(0, "[^A-Za-z0-9]") ; non-alphanumeric characters
  
  OpenPreferences("TFMM.ini")
  locale::use(ReadPreferenceString("locale","en"))
  ClosePreferences()
  
  InitWindows() ; open and initialize windows
  
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
      If Event = #PB_Event_Menu
        Select EventMenu()
          Case #MenuItem_Activate
            GadgetButtonActivate(#PB_EventType_LeftClick)
          Case #MenuItem_Deactivate
            GadgetButtonDeactivate(#PB_EventType_LeftClick)
          Case #MenuItem_Uninstall
            GadgetButtonUninstall(#PB_EventType_LeftClick)
          Case #MenuItem_Information
            GadgetButtonInformation(#PB_EventType_LeftClick)
        EndSelect
      EndIf
    Case WindowSettings
      If Not WindowSettings_Events(Event)
        GadgetCloseSettings(0)
      EndIf
    Case WindowModProgress
      If Not WindowModProgress_Events(Event)
        ; user wants to close progress window -> no action, just wait for progress to finish
      EndIf
    Case WindowModInformation
      If EventType() = #PB_EventType_LeftClick
        ForEach InformationGadgetAuthor()
          If EventGadget() = InformationGadgetAuthor()
            If GetGadgetData(InformationGadgetAuthor())
              misc::openLink("http://www.train-fever.net/index.php/User/" + Str(GetGadgetData(InformationGadgetAuthor())))
            EndIf
          EndIf
        Next
      EndIf
      If IsWindow(WindowModInformation)
        If Not WindowModInformation_Events(Event)
          GadgetButtonInformationClose(#PB_EventType_LeftClick)
        EndIf
      EndIf
  EndSelect
ForEver
End
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 192
; FirstLine = 48
; Folding = 1
; EnableUnicode
; EnableXP