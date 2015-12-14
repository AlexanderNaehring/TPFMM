EnableExplicit

DeclareModule main
  EnableExplicit
  
  Global _DEBUG = #False
  Global _TESTMODE = #False
  Global TF$
  Global ready
  
  Declare init()
  Declare exit()
  Declare loop()
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowMain.pbi"
XIncludeFile "module_windowSettings.pbi"
XIncludeFile "module_windowProgress.pbi"
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_updater.pbi"
XIncludeFile "module_queue.pbi"
XIncludeFile "module_mods.pbi"

Module main
  
  Procedure init()
    Protected i
    ; program parameter
    For i = 0 To CountProgramParameters() - 1
      Select LCase(ProgramParameter(i)) 
        Case "-debug"
          Debug "parameter: enable debug mode"
          _DEBUG = #True
        Case "-testmode"
          Debug "parameter: enable testing mode"
          _TESTMODE = #True
        Default
          Debug "unknown parameter: " + ProgramParameter(i)
      EndSelect
    Next
    
    debugger::DeleteLogFile()
    If _DEBUG
      debugger::SetLogFile("tfmm-output.txt")
    EndIf
    
    ;   SetCurrentDirectory(GetPathPart(ProgramFilename()))
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
      misc::CreateDirectoryAll(misc::path(GetHomeDirectory()+"/.tfmm"))
      SetCurrentDirectory(misc::path(GetHomeDirectory()+"/.tfmm"))
    CompilerEndIf
    
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
    
    ; open all windows
    windowMain::create()
    windowSettings::create(windowMain::id)
    windowProgress::create(windowMain::id) ;OpenWindowProgress()
    updater::create(windowMain::id)
    
    
    
    debugger::Add("init() - load settings")
    OpenPreferences("TFMM.ini")
    TF$ = ReadPreferenceString("path", "")
    
    ; Window Location
    If ReadPreferenceInteger("windowlocation", #False)
      PreferenceGroup("window")
      ResizeWindow(windowMain::id,
                   ReadPreferenceInteger("x", #PB_Ignore),
                   ReadPreferenceInteger("y", #PB_Ignore),
                   ReadPreferenceInteger("width", #PB_Ignore),
                   ReadPreferenceInteger("height", #PB_Ignore))
      PreferenceGroup("")
      ; reload column sizing
      PreferenceGroup("columns")
      Protected Dim widths(5)
      For i = 0 To 5
        widths(i) = ReadPreferenceInteger(Str(i), 0)
      Next
      
      PreferenceGroup("")
    EndIf
    
    
    ; update
    debugger::Add("init() - start updater")
    If ReadPreferenceInteger("update", 0)
      CreateThread(updater::@checkUpdate(), 1)
    EndIf
    
    ClosePreferences()
    
    If TF$ = ""
      ; no path specified upon program start -> open settings dialog
      windowSettings::show()
    EndIf
    
    
    If TF$ <> ""
      ; load library
      queue::add(queue::#QueueActionLoad)
      
      ; check for old TFMM configuration, trigger conversion if found
      If FileSize(misc::Path(TF$ + "/TFMM/") + "mods.ini") >= 0
        queue::add(queue::#QueueActionConvert, TF$)
      EndIf
    EndIf
    
    debugger::Add("init complete")
  EndProcedure
  
  Procedure exit()
    Protected i.i
    HideWindow(windowMain::id, #True)
    
    mods::saveList()
    mods::freeAll()
    
    OpenPreferences("TFMM.ini")
    If ReadPreferenceInteger("windowlocation", #False)
      PreferenceGroup("window")
      WritePreferenceInteger("x", WindowX(windowMain::id))
      WritePreferenceInteger("y", WindowY(windowMain::id))
      WritePreferenceInteger("width", WindowWidth(windowMain::id))
      WritePreferenceInteger("height", WindowHeight(windowMain::id))
    EndIf
    PreferenceGroup("columns")
    For i = 0 To 5
      WritePreferenceInteger(Str(i), windowMain::getColumnWidth(i))
    Next
    ClosePreferences()
    
    End
  EndProcedure
  
  Procedure loop()
    Protected event
    Repeat
      event = WaitWindowEvent(100)
      
      Select EventWindow()
        Case windowMain::id
          windowMain::events(event)
        Case windowSettings::window
          windowSettings::events(event)
        Case windowProgress::id
          windowProgress::events(event)
        Case windowInformation::id
          windowInformation::events(event)
        Case updater::window
          updater::windowEvents(Event)
      EndSelect
    ForEver
  EndProcedure
  
EndModule


main::init()
main::loop()
End