EnableExplicit

CreateDirectory(GetHomeDirectory()+"/.tpfmm")
SetCurrentDirectory(GetHomeDirectory()+"/.tpfmm")

CompilerSelect #PB_Compiler_OS
  CompilerCase #PB_OS_Linux
  CompilerCase #PB_OS_Windows
    SetFileAttributes(GetCurrentDirectory(), #PB_FileSystem_Hidden)
  CompilerCase #PB_OS_MacOS
CompilerEndSelect

DeclareModule main
  EnableExplicit
  
  Global _DEBUG     = #True ; write debug messages to log file
  Global _TESTMODE  = #False
  Global ready      = #False
  Global gameDirectory$
  Global settingsFile$ = "TPFMM.ini"
  Global VERSION$ = "TPFMM 1.0." + #PB_Editor_BuildCount
  
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
XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_queue.pbi"
XIncludeFile "module_mods.pbi"
XIncludeFile "module_repository.pbi"
XIncludeFile "module_archive.pbi"

Module main
  
  Procedure init()
    Protected i
    ; program parameter
    For i = 0 To CountProgramParameters() - 1
      Debug "Parameter: "+ProgramParameter(i)
      Select LCase(ProgramParameter(i)) 
        Case "-testmode"
          Debug "enable testing mode"
          _TESTMODE = #True
        Default
          If FileSize(ProgramParameter(i))
            ; install mod?
          EndIf
      EndSelect
    Next
    
    If _DEBUG
      debugger::SetLogFile("tpfmm.log")
    EndIf
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
    If Not UsePNGImageDecoder() Or
       Not UsePNGImageEncoder() Or 
       Not UseJPEGImageDecoder() Or
       Not UseTGAImageDecoder()
      debugger::Add("ERROR: ImageDecoder")
      MessageRequester("Error", "Could not initialize Image Decoder.")
      End
    EndIf
    
    images::LoadImages()
    
    debugger::Add("init() - read locale")
    OpenPreferences(settingsFile$)
    locale::use(ReadPreferenceString("locale","en"))
    ClosePreferences()
    
    ; open all windows
    windowMain::create()
    windowSettings::create(windowMain::window)
;     windowProgress::create(windowMain::id)
;     updater::create(windowMain::id)
    
    debugger::Add("init() - load settings")
    OpenPreferences(settingsFile$)
    gameDirectory$ = ReadPreferenceString("path", "")
    
    ; Window Location
    If ReadPreferenceInteger("windowlocation", #False)
      PreferenceGroup("window")
      ResizeWindow(windowMain::window,
                   ReadPreferenceInteger("x", #PB_Ignore),
                   ReadPreferenceInteger("y", #PB_Ignore),
                   ReadPreferenceInteger("width", #PB_Ignore),
                   ReadPreferenceInteger("height", #PB_Ignore))
      PostEvent(#PB_Event_SizeWindow, windowMain::window, 0)
      PreferenceGroup("")
      ; reload column sizing
      PreferenceGroup("columns")
      Protected Dim widths(5)
      For i = 0 To 5
        widths(i) = ReadPreferenceInteger(Str(i), 0)
      Next
      
      PreferenceGroup("")
    EndIf
    ClosePreferences()
    
;     ; start update in background
;     debugger::Add("init() - start updater")
;     If ReadPreferenceInteger("update", 0)
;       CreateThread(updater::@checkUpdate(), 1)
;     EndIf
    
    
    If gameDirectory$
      queue::add(queue::#QueueActionLoad)
    Else
      ; no path specified upon program start -> open settings dialog
      windowSettings::show()
    EndIf
    
    debugger::Add("init complete")
    
    loop()
  EndProcedure
  
  Procedure exit()
    Protected i.i
    
    HideWindow(windowMain::window, 1)
    
    OpenPreferences(settingsFile$)
    If ReadPreferenceInteger("windowlocation", #False)
      PreferenceGroup("window")
      WritePreferenceInteger("x", WindowX(windowMain::window))
      WritePreferenceInteger("y", WindowY(windowMain::window))
      WritePreferenceInteger("width", WindowWidth(windowMain::window))
      WritePreferenceInteger("height", WindowHeight(windowMain::window))
    EndIf
    PreferenceGroup("columns")
    For i = 0 To 5
      WritePreferenceInteger(Str(i), windowMain::getColumnWidth(i))
    Next
    ClosePreferences()
    
    mods::saveList()
    mods::freeAll()
    
    Debug "close main window"
    CloseWindow(windowMain::window)
    
    Debug "Shutdown now"
    End
  EndProcedure
  
  Procedure loop()
    Repeat
      WaitWindowEvent(100)
    ForEver
  EndProcedure
  
EndModule

main::init()

End
; IDE Options = PureBasic 5.51 (Linux - x64)
; CursorPosition = 17
; Folding = -
; EnableXP