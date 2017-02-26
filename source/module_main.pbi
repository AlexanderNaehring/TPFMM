DeclareModule main
  EnableExplicit
  
  Global _DEBUG     = #True ; write debug messages to log file
  Global _TESTMODE  = #False
  Global ready      = #False
  Global gameDirectory$
  Global settingsFile$ = "TPFMM.ini"
  Global VERSION$ = "TPFMM 1.0." + #PB_Editor_BuildCount
  
  #PORT = 14123
  
  Declare init()
  Declare exit()
  Declare loop()
EndDeclareModule


XIncludeFile "module_debugger.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowMain.pbi"
XIncludeFile "module_instance.pbi"


XIncludeFile "module_mods.pbi"
XIncludeFile "module_repository.pbi"



Module main
  
  Procedure handleParameter(parameter$)
    Debug debugger::add("main::handleParameter() - "+parameter$)
    Select LCase(parameter$)
      Case "-testmode"
        debugger::add("main::handleParameter() - enable testing mode")
        _TESTMODE = #True
        
      Case "-show"
        If windowMain::window And IsWindow(windowMain::window)
          ; normal/maximize may behave differently on linux (linux mint 18.1: maximze = normal and normal = on left edge)
          ; catch this behaviour??
          Select GetWindowState(windowMain::window)
            Case #PB_Window_Maximize
              SetWindowState(windowMain::window, #PB_Window_Minimize)
              SetWindowState(windowMain::window, #PB_Window_Maximize)
            Default
              SetWindowState(windowMain::window, #PB_Window_Minimize)
              SetWindowState(windowMain::window, #PB_Window_Normal)
          EndSelect
        EndIf
        
      Default
        If FileSize(parameter$) > 0
          ; install mod... (this function is called, before the main window is created ....
          ; Todo: Check if thisworks at program start.
          queue::add(queue::#QueueActionInstall, parameter$)
        EndIf
        
    EndSelect
  EndProcedure
  
  Procedure init()
    Protected i
    
    If _DEBUG
      debugger::SetLogFile("tpfmm.log")
    EndIf
    debugger::DeleteLogFile()
    
    
    ; parameter handling
    For i = 0 To CountProgramParameters() - 1
      handleParameter(ProgramParameter(i))
    Next
    
    
    
    ; check if TPFMM instance is already running
    If Not instance::create(#PORT, @handleParameter())
      ; could not create instance. most likely, another instance is running
      ; try to send message to other instance
      Debug "main::init() - could not create new instance. Try to send message to other instance..."
      If instance::sendString("-show")
        For i = 0 To CountProgramParameters() - 1
          instance::sendString(ProgramParameter(i))
        Next
        Debug "main::init() - send all parameters. exit now"
        End
      Else
        Debug "main::init() - could not send message to other instance... Continue with this instance!"
      EndIf
    EndIf
    
    
    
    debugger::Add("init() - load plugins")
    
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
    
    ; user init...
    
    debugger::Add("init() - read locale")
    OpenPreferences(settingsFile$)
    locale::use(ReadPreferenceString("locale","en"))
    ClosePreferences()
    
    ;-TODO: First: Check path, etc.. then open required windows.
    ; only if everything is fine: show main window...
    
    ; open all windows
    windowMain::create()
    windowSettings::create(windowMain::window)
;     windowProgress::create(windowMain::id)
;     updater::create(windowMain::id)
    
    debugger::Add("init() - load settings")
    OpenPreferences(settingsFile$)
    gameDirectory$ = ReadPreferenceString("path", "")
    If misc::checkGameDirectory(gameDirectory$) <> 0
      gameDirectory$ = ""
    EndIf
    
    
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
    
    
    
    ; finish
    debugger::Add("init complete")
    
    ; main loop...
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
      WaitWindowEvent()
    ForEver
  EndProcedure
  
EndModule