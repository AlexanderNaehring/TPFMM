DeclareModule main
  EnableExplicit
  
  Global _DEBUG     = #True ; write debug messages to log file
  Global _TESTMODE  = #False
  Global VERSION$ = "TPFMM v1.1." + #PB_Editor_BuildCount
  Global WEBSITE$ = "https://www.transportfever.net/index.php/Thread/7777-TPFMM-Transport-Fever-Mod-Manager/"
  Global VERSION_FULL$ = VERSION$ + " b" + #PB_Editor_CompileCount
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      VERSION_FULL$ + " Win"
    CompilerCase #PB_OS_Linux
      VERSION_FULL$ + " Lin"
    CompilerCase #PB_OS_MacOS
      VERSION_FULL$ + " OSX"
  CompilerEndSelect
  UseMD5Fingerprint()
  VERSION_FULL$ + " {" + StringFingerprint(CPUName() + "/" + ComputerName() + "/" + UserName(), #PB_Cipher_MD5) + "}"
  
  #PORT = 14123
  #LicenseVersion = 2
  
  #DRAG_MOD = 1
  
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
XIncludeFile "module_windowLicense.pbi"

XIncludeFile "module_mods.pbi"
XIncludeFile "module_repository.pbi"

Module main
  UseModule debugger
  
  Procedure handleError()
    Protected date$ = FormatDate("%yyyy-%mm-%dd_%hh-%ii-%ss", Date())
    Protected file, file$ = "crash/dump-"+date$+".txt"
    CreateDirectory("crash")
    
    
    file = CreateFile(#PB_Any, file$, #PB_File_NoBuffering)
    
    ; Error and System Information
    WriteStringN(file, "Please provide the following information at")
    WriteStringN(file, main::WEBSITE$)
    WriteStringN(file, "Just copy the whole file content in the text box, or attach the .txt file directly.")
    WriteStringN(file, "")
    WriteStringN(file, "[code]")
    
    WriteStringN(file, "################################################################################")
    WriteStringN(file, "ERROR @ "+date$)
    WriteStringN(file, VERSION_FULL$)
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
    WriteStringN(file, "[/code]")
    CloseFile(file)
    
    MessageRequester("ERROR", "Error "+ErrorMessage()+" (#"+ErrorCode()+")at address "+ErrorAddress()+">"+ErrorTargetAddress()+#CRLF$+"File "+ErrorFile()+" line "+ErrorLine()+#CRLF$+#CRLF$+"created "+GetFilePart(file$), #PB_MessageRequester_Error)
    
    misc::openLink(GetCurrentDirectory()+"/"+file$)
    End
  EndProcedure
  
  Procedure handleParameter(parameter$)
    Select LCase(parameter$)
      Case "-testmode"
        deb("main:: enable testing mode")
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
          windowMain::repoFindModAndDownload(parameter$)
          
        ElseIf FileSize(parameter$) > 0
          ; install mod... (this function is called, before the main window is created ....
          mods::install(parameter$)
        EndIf
        
    EndSelect
  EndProcedure
  
  Procedure startUp()
    Protected i
    
    settings::setInteger("", "eula", #LicenseVersion)
    
    ; read gameDirectory from preferences
    deb("main:: - game directory: "+settings::getString("", "path"))
    
    If misc::checkGameDirectory(settings::getString("", "path"), main::_TESTMODE) <> 0
      deb("main:: game directory not correct")
      settings::setString("", "path", "")
    EndIf
    
    ; proxy (read from preferences)
    initProxy()
    
    
    ; check if TPFMM instance is already running
    If Not instance::create(#PORT, @handleParameter())
      ; could not create instance. most likely, another instance is running
      ; try to send message to other instance
      If instance::sendString("-show")
        For i = 0 To CountProgramParameters() - 1
          instance::sendString(ProgramParameter(i))
        Next
        End
      Else
        ; could not send message to other instance... continue in this instance
      EndIf
    EndIf
    
    
    ; parameter handling
    For i = 0 To CountProgramParameters() - 1
      handleParameter(ProgramParameter(i))
    Next
    
    
    ; desktopIntegration
    updateDesktopIntegration()
    
    
    windowMain::create()
    windowSettings::create(windowMain::window)
    
    
    ;{ Restore window location (complicated version)
    Protected nDesktops, desktop, locationOK
    Protected windowX, windowY, windowWidth, windowHeight
    deb("main:: reset main window location")
    
    If #True
      windowX = settings::getInteger("window", "x")
      windowY = settings::getInteger("window", "y")
      windowWidth   = settings::getInteger("window", "width")
      windowHeight  = settings::getInteger("window", "height")
      
      ; get desktops
      nDesktops = ExamineDesktops()
      If Not nDesktops
        deb("main:: cannot find Desktop!")
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
          deb("main:: window location valid on desktop #"+desktop)
          Break
        EndIf
      Next
      
      If locationOK 
        deb("main:: set window location: ("+windowX+", "+windowY+", "+windowWidth+", "+windowHeight+")")
        ResizeWindow(windowMain::window, windowX, windowY, windowWidth, windowHeight)
        PostEvent(#PB_Event_SizeWindow, windowMain::window, 0)
      Else
        
        deb("main:: window location not valid")
        windowWidth = #PB_Ignore
        windowHeight = #PB_Ignore
        
        deb("main:: center main window on primary desktop")
        windowX = (DesktopWidth(0)  - windowWidth ) /2
        windowY = (DesktopHeight(0) - windowHeight) /2
      EndIf
    EndIf
    ;}
    
    
    ; show main window
    HideWindow(windowMain::window, #False)
    
    If settings::getString("", "path")
      mods::load()
    Else
      ; no path specified upon program start -> open settings dialog
      deb("main:: no game directory defined - open settings dialog")
      windowSettings::show()
    EndIf
    
  EndProcedure
  
  Procedure licenseDeclined()
    settings::setInteger("", "eula", 0)
    End
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
    
    InitNetwork()
    
    ; read language from preferences
    settings::setFilename("TPFMM.ini")
    locale::use(settings::getString("", "locale"))
    
    
    ; user must accept end user license agreement
    If settings::getInteger("", "eula") < #LicenseVersion
      ; current license not accepted
      DataSection
        eula:
        IncludeBinary "res/EULA.txt"
        eulaEnd:
      EndDataSection
      
      windowLicense::Show("End-User License Agreement (EULA)", PeekS(?eula, ?eulaEnd-?eula-1, #PB_UTF8), @startUp(), @licenseDeclined())
    Else
      ; license already accepted
      startUp()
    EndIf
    
    
    ; enter main loop...
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
      deb("main:: server: "+server$+", user:"+user$)
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
      ; TODO register context menu
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
    repository::freeAll()
    
    CloseWindow(windowMain::window)
    
    deb("Goodbye!")
    End
  EndProcedure
  
  Procedure loop()
    Repeat
      WaitWindowEvent()
    ForEver
  EndProcedure
  
EndModule