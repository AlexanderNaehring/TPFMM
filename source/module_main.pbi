DeclareModule main
  EnableExplicit
  
  Global _DEBUG     = #True ; write debug messages to log file
  Global _TESTMODE  = #False
  Global gameDirectory$
  Global VERSION$ = "TPFMM 1.0." + #PB_Editor_BuildCount
  Global WEBSITE$ = "https://www.transportfever.net/index.php/Thread/7777-TPFMM-Transport-Fever-Mod-Manager/"
  
  #PORT = 14123
  
  Declare init()
  Declare initProxy()
  Declare updateDesktopIntegration()
  Declare exit()
  Declare loop()
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_settings.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowMain.pbi"
XIncludeFile "module_instance.pbi"

XIncludeFile "module_mods.pbi"
XIncludeFile "module_repository.pbi"

Module main
  
  Procedure handleError()
    Protected date$ = FormatDate("%yyyy-%mm-%dd_%hh-%ii-%ss UTC", misc::time())
    Protected file, file$ = "crash/dump-"+date$+".txt"
    CreateDirectory("crash")
    
    
    file = CreateFile(#PB_Any, file$, #PB_File_NoBuffering)
    
    ; Error and System Information
    WriteStringN(file, "Please provide the following information at")
    WriteStringN(file, main::WEBSITE$)
    WriteStringN(file, "")
    WriteStringN(file, "################################################################################")
    WriteStringN(file, "ERROR @ "+date$)
    WriteStringN(file, "Error #"+ErrorCode()+" at address "+ErrorAddress()+">"+ErrorTargetAddress()+" in <"+ErrorFile()+"> line "+ErrorLine())
    WriteStringN(file, ErrorMessage(ErrorCode()))
    WriteStringN(file, "OS: "+misc::getOSVersion()+" on "+CPUName()+" ("+CountCPUs()+" CPUs)")
    WriteStringN(file, "Available Physical Memory: "+Str(MemoryStatus(#PB_System_FreePhysical)/1024/1024)+" MiB / "+Str(MemoryStatus(#PB_System_TotalPhysical)/1024/1024)+" MiB")
    If MemoryStatus(#PB_System_TotalVirtual) > 0
      WriteStringN(file, "Available Virtual Memory:  "+Str(MemoryStatus(#PB_System_FreeVirtual)/1024/1024)+" MiB / "+Str(MemoryStatus(#PB_System_TotalVirtual)/1024/1024)+" MiB")
    EndIf
    If MemoryStatus(#PB_System_TotalSwap) > 0
      WriteStringN(file, "Available Swap:            "+Str(MemoryStatus(#PB_System_FreeSwap)/1024/1024)+" MiB / "+Str(MemoryStatus(#PB_System_TotalSwap)/1024/1024)+" MiB")
    EndIf
    WriteStringN(file, "################################################################################")
    WriteStringN(file, "")
    
    
    ; copy log
    WriteStringN(file, "log:")
    WriteString(file, debugger::getLog())
    
    ; close file
    CloseFile(file)
    
    MessageRequester("ERROR", ErrorMessage(ErrorCode())+#CRLF$+#CRLF$+"created "+GetFilePart(file$), #PB_MessageRequester_Error)
    misc::openLink(file$)
    End
  EndProcedure
  
  Procedure handleParameter(parameter$)
    debugger::add("main::handleParameter() - "+parameter$)
    Select LCase(parameter$)
      Case "-testmode"
        debugger::add("main::handleParameter() - enable testing mode")
        _TESTMODE = #True
        
      Case "-show"
        If windowMain::window And IsWindow(windowMain::window)
          ; normal/maximize may behave differently on linux (linux mint 18.1: maximze = normal and normal = on left edge)
          ; catch this behaviour??
          Select GetWindowState(windowMain::window)
            Case #PB_Window_Minimize
              SetWindowState(windowMain::window, #PB_Window_Normal)
          EndSelect
        EndIf
        
      Default
        If Left(parameter$, 17) = "tpfmm://download/"
          ; handle link
          parameter$ = Mid(parameter$, 18)
          Protected source$, id.q, fileID.q
          source$ =     StringField(parameter$, 1, "/")
          id      = Val(StringField(parameter$, 2, "/"))
          fileID  = Val(StringField(parameter$, 3, "/"))
          
          windowMain::repoFindModAndDownload(source$, id, fileID)
          
        ElseIf FileSize(parameter$) > 0
          ; install mod... (this function is called, before the main window is created ....
          mods::install(parameter$)
        EndIf
        
    EndSelect
  EndProcedure
  
  Procedure init()
    Protected i
    
    If _DEBUG
      debugger::SetLogFile("tpfmm.log")
    EndIf
    debugger::DeleteLogFile()
    
    CompilerIf Not #PB_Compiler_Debugger
      OnErrorCall(@handleError())
    CompilerEndIf
    
    settings::setFilename("TPFMM.ini")
    
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
    
    
    ; parameter handling
    For i = 0 To CountProgramParameters() - 1
      handleParameter(ProgramParameter(i))
    Next
    
    
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
    
    ; proxy (read from preferences
    initProxy()
    
    ; desktopIntegration
    updateDesktopIntegration()
    
    ; default images and logos
    images::LoadImages()
    
    ; read gameDirectory from preferences
    gameDirectory$ = settings::getString("", "path")
    debugger::Add("init() - read gameDirectory: "+gameDirectory$)
    If misc::checkGameDirectory(gameDirectory$) <> 0
      debugger::add("init() - gameDirectory not correct!")
      gameDirectory$ = ""
    EndIf
    
    ; read language from preferences
    locale::use(settings::getString("", "locale"))
    
    
    windowMain::create()
    windowSettings::create(windowMain::window)
    
    
    ; Restore Window Location
    ; (complicated version)
    Protected nDesktops, desktop, locationOK
    Protected windowX, windowY, windowWidth, windowHeight
    debugger::add("main::init() - Set main window location")
    
    If #True
      windowX = settings::getInteger("window", "x")
      windowY = settings::getInteger("window", "y")
      windowWidth   = settings::getInteger("window", "width")
      windowHeight  = settings::getInteger("window", "height")
      
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
    
    
    ; restore column sizes
    Protected Dim widths(5)
    For i = 0 To 5
      widths(i) = settings::getInteger("columns", Str(i))
    Next
      
    windowMain::setColumnWidths(widths())
    
    
    HideWindow(windowMain::window, #False)
    
    If gameDirectory$
      mods::load()
    Else
      ; no path specified upon program start -> open settings dialog
      debugger::add("init() - no gameDirectory defined - open settings dialog")
      windowSettings::show()
    EndIf
    
    
    ; finish
    debugger::Add("init() -  complete")
    
    ; main loop...
    loop()
  EndProcedure
  
  Procedure initProxy()
    Protected server$, user$, password$
    
    If settings::getInteger("proxy", "enabled")
      server$   = settings::getString("proxy", "server")
      user$     = settings::getString("proxy", "user")
      password$ = aes::decryptString(settings::getString("proxy", "password"))
    EndIf
    
    If server$
      debugger::add("initProxy() - "+server$+" user:"+user$)
      HTTPProxy(server$, user$, password$)
    Else
      HTTPProxy("")
    EndIf
    
  EndProcedure
  
  Procedure updateDesktopIntegration()
    If settings::getInteger("integration", "register_protocol")
      misc::registerProtocolHandler("tpfmm", ProgramFilename(), "Transport Fever Mod Link")
    Else
      misc::registerProtocolHandler("tpfmm", "") ; unregister tpfmm
    EndIf
    
    If  settings::getInteger("integration", "register_context_menu")
      ; TODO
    EndIf
    
    ClosePreferences()
  EndProcedure
  
  Procedure exit()
    Protected i.i
    
    
    settings::setInteger("window", "x", WindowX(windowMain::window, #PB_Window_FrameCoordinate))
    settings::setInteger("window", "y", WindowY(windowMain::window, #PB_Window_FrameCoordinate))
    settings::setInteger("window", "width", WindowWidth(windowMain::window))
    settings::setInteger("window", "height", WindowHeight(windowMain::window))

    For i = 0 To 5
      settings::setInteger("columns", Str(i), windowMain::getColumnWidth(i))
    Next
    
    mods::saveList()
    mods::freeAll()
    
    Debug "close main window"
    CloseWindow(windowMain::window)
    
    debugger::add("Goodbye!")
    End
  EndProcedure
  
  Procedure loop()
    Repeat
      WaitWindowEvent()
    ForEver
  EndProcedure
  
EndModule