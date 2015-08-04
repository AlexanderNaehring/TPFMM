EnableExplicit

DeclareModule glob
  Global _DEBUG = #False
  Global _TESTMODE = #False
  Global TF$
  Global ready
EndDeclareModule
Module glob
  
EndModule

Enumeration
  #UpdateNew
  #UpdateCurrent
  #UpdateFailed
EndEnumeration

Global Event

Declare AddModToList(File$)

XIncludeFile "Windows.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_unrar.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_mods.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_conversion.pbi"

Procedure exit(dummy)
  Protected i.i
  HideWindow(WindowMain, #True)
  
  mods::freeAll()
  
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
    WritePreferenceInteger(Str(i), GetGadgetItemAttribute(Library, #PB_Any, #PB_Explorer_ColumnWidth, i))
  Next
  ClosePreferences()
  
  End
EndProcedure

Procedure init()
  Protected i
  ; program parameter
  For i = 0 To CountProgramParameters() - 1
    Select LCase(ProgramParameter(i)) 
      Case "-debug"
        Debug "parameter: enable debug mode"
        glob::_DEBUG = #True
      Case "-testmode"
        Debug "parameter: enable testing mode"
        glob::_TESTMODE = #True
      Default
        Debug "unknown parameter: " + ProgramParameter(i)
    EndSelect
  Next
  
  If glob::_DEBUG
    debugger::SetLogFile("tfmm-output.txt")
  EndIf
  ;   SetCurrentDirectory(GetPathPart(ProgramFilename()))
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    misc::CreateDirectoryAll(misc::path(GetHomeDirectory()+"/.tfmm"))
    SetCurrentDirectory(misc::path(GetHomeDirectory()+"/.tfmm"))
  CompilerEndIf
  debugger::DeleteLogFile()
  
  debugger::Add("init() - load plugins")
  If Not UseZipPacker()
    debugger::Add("ERROR: UseZipPacker()")
    MessageRequester("Error", "Could not initialize ZIP.")
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
  If Not UseTGAImageDecoder()
    debugger::Add("ERROR: UseTGAImageDecoder()")
    MessageRequester("Error", "Could not initialize TGA Decoder.")
    End
  EndIf
  
  
  images::LoadImages()
  
  
  debugger::Add("init() - read locale")
  OpenPreferences("TFMM.ini")
  locale::use(ReadPreferenceString("locale","en"))
  ClosePreferences()
  
  InitWindows() ; open and initialize windows
  
  debugger::Add("init() - load settings")
  OpenPreferences("TFMM.ini")
  glob::TF$ = ReadPreferenceString("path", "")
  
  ; Window Location
  If ReadPreferenceInteger("windowlocation", #False)
    PreferenceGroup("window")
    ResizeWindow(WindowMain,
                 ReadPreferenceInteger("x", #PB_Ignore),
                 ReadPreferenceInteger("y", #PB_Ignore),
                 ReadPreferenceInteger("width", #PB_Ignore),
                 ReadPreferenceInteger("height", #PB_Ignore))
    PreferenceGroup("")
    ; reload column sizing
    PreferenceGroup("columns")
    For i = 0 To 5
      If ReadPreferenceInteger(Str(i), 0)
        SetGadgetItemAttribute(Library, #PB_Any, #PB_Explorer_ColumnWidth, ReadPreferenceInteger(Str(i), 0), i)
        ; Sorting
        ListIcon::SetColumnFlag(Library, i, ListIcon::#String) 
      EndIf
    Next
    PreferenceGroup("")
  EndIf
  
  
  ; update
  debugger::Add("init() - start updater")
  If ReadPreferenceInteger("update", 0)
    CreateThread(updater::@checkUpdate(), 1)
  EndIf
  
  ClosePreferences()
  
  If glob::TF$ = ""
    ; no path specified upon program start -> open settings dialog
    windowSettings::show()
  EndIf
  
  
  If glob::TF$ <> ""
    ; load library
    queue::add(queue::#QueueActionLoad, glob::TF$)
    
    ; check for old TFMM configuration, trigger conversion if found
    If FileSize(misc::Path(glob::TF$ + "/TFMM/") + "mods.ini") >= 0
      queue::add(queue::#QueueActionConvert, glob::TF$)
    EndIf
  EndIf
  
  debugger::Add("init complete")
EndProcedure

init()

Repeat
  Event = WaitWindowEvent(100)
  If Event = #PB_Event_Timer
    Select EventTimer()
      Case TimerMainGadgets
        TimerMain()
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
          Case #MenuItem_Install
            GadgetButtonInstall(#PB_EventType_LeftClick)
          Case #MenuItem_Remove
            GadgetButtonRemove(#PB_EventType_LeftClick)
          Case #MenuItem_Delete
            GadgetButtonDelete(#PB_EventType_LeftClick)
          Case #MenuItem_Information
            GadgetButtonInformation(#PB_EventType_LeftClick)
        EndSelect
      EndIf
    Case windowSettings::window
      windowSettings::events(Event)
      
    Case WindowModProgress
      If Not WindowProgress_Events(Event)
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
    Case updater::window
      updater::windowEvents(Event)
  EndSelect
ForEver
End
; IDE Options = PureBasic 5.31 (Windows - x64)
; CursorPosition = 166
; FirstLine = 151
; Folding = -
; EnableUnicode
; EnableXP