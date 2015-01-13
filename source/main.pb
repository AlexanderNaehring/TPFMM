EnableExplicit

#VERSION$ = "Version 0.6." + #PB_Editor_BuildCount + " Build " + #PB_Editor_CompileCount
#DEBUG = #True

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

CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
  MessageRequester("TFMM for Mac OS", "TFMM for Mac OS is still in Beta. Please use with caution!")
CompilerEndIf

Procedure exit(dummy)
  Protected i.i
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
  PreferenceGroup("columns")
  For i = 0 To 5
    WritePreferenceInteger(Str(i), GetGadgetItemAttribute(ListInstalled, #PB_Any, #PB_Explorer_ColumnWidth, i))
  Next
  ClosePreferences()
  
  End
EndProcedure

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
  If Not UsePNGImageEncoder()
    debugger::Add("ERROR: UsePNGImageEncoder()")
    MessageRequester("Error", "Could not initialize PNG Encoder.")
    End
  EndIf
  If Not UseJPEGImageDecoder()
    debugger::Add("ERROR: UseJPEGImageDecoder()")
    MessageRequester("Error", "Could not initialize JPEG Decoder.")
    End
  EndIf
  
  ;   SetCurrentDirectory(GetPathPart(ProgramFilename()))
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    debugger::Add("CurrentDirectory = {"+GetCurrentDirectory()+"}")
    misc::CreateDirectoryAll(misc::path(GetHomeDirectory()+"/.tfmm"))
    SetCurrentDirectory(misc::path(GetHomeDirectory()+"/.tfmm"))
    debugger::Add("CurrentDirectory = {"+GetCurrentDirectory()+"}")
  CompilerEndIf
  
  images::LoadImages()
  
  OpenPreferences("TFMM.ini")
  locale::use(ReadPreferenceString("locale","en"))
  ClosePreferences()
  
  InitWindows() ; open and initialize windows
  
  debugger::Add("load settings")
  OpenPreferences("TFMM.ini")
  
  TF$ = ReadPreferenceString("path", "")
  
  ; Window Location
  If ReadPreferenceInteger("windowlocation", #False)
    PreferenceGroup("window")
    ResizeWindow(WindowMain,
                 ReadPreferenceInteger("x", #PB_Ignore),
                 ReadPreferenceInteger("y", #PB_Ignore),
                 ReadPreferenceInteger("width", #PB_Ignore),
                 ReadPreferenceInteger("height", #PB_Ignore))
    PreferenceGroup("")
  EndIf
  
  ; reload column sizing
  Protected i.i
  PreferenceGroup("columns")
  For i = 0 To 5
    If ReadPreferenceInteger(Str(i), 0)
      SetGadgetItemAttribute(ListInstalled, #PB_Any, #PB_Explorer_ColumnWidth, ReadPreferenceInteger(Str(i), 0), i)
      ; Sorting
      ListIcon::SetColumnFlag(ListInstalled, i, ListIcon::#String) 
    EndIf
  Next
  PreferenceGroup("")
  
  ; update
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
          If EventGadget() = InformationGadgetAuthor()\display
            If GetGadgetData(InformationGadgetAuthor()\display)
              misc::openLink("http://www.train-fever.net/index.php/User/" + Str(GetGadgetData(InformationGadgetAuthor()\display)))
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
; CursorPosition = 116
; FirstLine = 67
; Folding = 9
; EnableUnicode
; EnableXP