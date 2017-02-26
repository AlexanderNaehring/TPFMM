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
  
  Procedure handleError()
    MessageRequester("ERROR", ErrorMessage(ErrorCode()), #PB_MessageRequester_Error)
    End
  EndProcedure
  
  
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
    
    OnErrorCall(@handleError())
    
    
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
    If OpenPreferences(settingsFile$)
      locale::use(ReadPreferenceString("locale","en"))
      ClosePreferences()
    EndIf
    
    ;-TODO: First: Check path, etc.. then open required windows.
    ; only if everything is fine: show main window...
    
    ; open all windows
    windowMain::create()
    windowSettings::create(windowMain::window)
;     windowProgress::create(windowMain::id)
;     updater::create(windowMain::id)
    
    
    If OpenPreferences(settingsFile$)
      gameDirectory$ = ReadPreferenceString("path", "")
      If misc::checkGameDirectory(gameDirectory$) <> 0
        gameDirectory$ = ""
      EndIf
      ClosePreferences()
    EndIf
    
    
    
    ; Window Location
    ; (For testing purposes, may be solved more easy using #PB_Window_ScreenCentered and OS functions.....)
    Protected nDesktops, desktop, locationOK
    Protected windowX, windowY, windowWidth, windowHeight
    If OpenPreferences(settingsFile$)
      debugger::add("main::init() - Set main window location")
      PreferenceGroup("window")
      windowX = ReadPreferenceInteger("x", #PB_Ignore)
      windowY = ReadPreferenceInteger("y", #PB_Ignore)
      windowWidth   = ReadPreferenceInteger("width", WindowWidth(windowMain::window))
      windowHeight  = ReadPreferenceInteger("height", WindowHeight(windowMain::window))
      ClosePreferences()
      
      ; get desktops
      nDesktops = ExamineDesktops()
      If Not nDesktops
        debugger::add("main::init() - Error: Cannot find Desktop!")
        End
      EndIf
      
      ; check if location is valid
      locationOK = #False
      For desktop = 0 To nDesktops - 1
        ; location is okay, if whole window is in desktop!
        If windowX                > DesktopX(desktop)                         And ; left
           windowX + windowHeight < DesktopX(desktop) + DesktopWidth(desktop) And ; right
           windowY                > DesktopY(desktop)                         And ; top
           windowY + windowHeight < DesktopY(desktop) + DesktopHeight(desktop)    ; bottom
          locationOK = #True
          debugger::add("main::init() - window location valid on desktop #"+desktop)
          Break
        EndIf
      Next
      
      
      If locationOK 
        debugger::add("main::init() - set window location: ("+windowX+", "+windowY+", "+windowWidth+", "+windowHeight+")")
        ResizeWindow(windowMain::window, windowX, windowY, windowWidth, windowHeight)
        PostEvent(#PB_Event_SizeWindow, windowMain::window, 0)
      Else
        
        debugger::add("main::init() - window location not valid")
        windowWidth = #PB_Ignore
        windowHeight = #PB_Ignore
        
        debugger::add("main::init() - center main window on primary desktop")
        windowX = (DesktopWidth(0)  - windowWidth ) /2
        windowY = (DesktopHeight(0) - windowHeight) /2
      EndIf
      
    EndIf
    
    
    
    ; column sizes
    If OpenPreferences(settingsFile$)
      PreferenceGroup("columns")
      Protected Dim widths(5)
      For i = 0 To 5
        widths(i) = ReadPreferenceInteger(Str(i), 0)
      Next
      ClosePreferences()
    EndIf
    
    
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
    
    
    If OpenPreferences(settingsFile$)
      PreferenceGroup("window")
      ;TODO: Check: linux does not seem to read the location correctly?
      WritePreferenceInteger("x", WindowX(windowMain::window, #PB_Window_InnerCoordinate))
      WritePreferenceInteger("y", WindowY(windowMain::window, #PB_Window_InnerCoordinate))
      WritePreferenceInteger("width", WindowWidth(windowMain::window))
      WritePreferenceInteger("height", WindowHeight(windowMain::window))
      PreferenceGroup("columns")
      For i = 0 To 5
        WritePreferenceInteger(Str(i), windowMain::getColumnWidth(i))
      Next
      ClosePreferences()
    Else
      debugger::add("main::exit() - Error: could not open preferences file")
    EndIf
    
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