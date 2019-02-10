DeclareModule main
  EnableExplicit
  ; main module used for some global definitions and variables and startup and exit procedures
  
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      #OS$ = "Win"
    CompilerCase #PB_OS_Linux
      #OS$ = "Lin"
    CompilerCase #PB_OS_MacOS
      #OS$ = "OSX"
  CompilerEndSelect
  
  #DEBUG = #True ; write debug messages to log file
  #VERSION$ = "TPFMM v1.1." + #PB_Editor_BuildCount
  #WEBSITE$ = "https://www.transportfever.net/index.php/Thread/7777-TPFMM-Transport-Fever-Mod-Manager/"
  #UPDATER$ = "https://api.github.com/repos/AlexanderNaehring/TPFMM/releases/latest"
  #PORT = 14123
  #EULAVersion = 3
  
  UseMD5Fingerprint()
  
  Global _TESTMODE  = #False
  Global VERSION_FULL$ = #VERSION$ + " b" + #PB_Editor_CompileCount + " " + #OS$ + " {" + StringFingerprint(CPUName() + "/" + ComputerName() + "/" + UserName(), #PB_Cipher_MD5) + "}"
  
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
XIncludeFile "threads.pb"

XIncludeFile "module_mods.pbi"
XIncludeFile "module_repository.pbi"

Module main
  UseModule debugger
  
  ;- Error Handling
  
  Procedure onError()
    Protected date$ = FormatDate("%yyyy-%mm-%dd_%hh-%ii-%ss", Date())
    Protected file, file$ = "crash/dump-"+date$+".txt"
    Protected ErrorFile$
    CreateDirectory("crash")
    
    
    file = CreateFile(#PB_Any, file$, #PB_File_NoBuffering)
    
    ; Error and System Information
    WriteStringN(file, "Please provide the following information at")
    WriteStringN(file, main::#WEBSITE$)
    WriteStringN(file, "Copy the whole file content in the text box, or attach the .txt file directly.")
    WriteStringN(file, "")
    WriteStringN(file, "[code]")
    
    WriteStringN(file, "################################################################################")
    WriteStringN(file, "ERROR @ "+date$)
    WriteStringN(file, VERSION_FULL$)
    WriteStringN(file, #DQUOTE$+ErrorMessage()+#DQUOTE$)
    WriteStringN(file, Str(ErrorCode())+"@"+ErrorAddress()+">"+ErrorTargetAddress())
    ErrorFile$ = ReplaceString(ErrorFile(), GetPathPart(#PB_Compiler_FilePath), "")
    WriteStringN(file, ErrorFile$+" line "+ErrorLine())
    WriteStringN(file, "https://github.com/AlexanderNaehring/TPFMM/tree/master/source/"+ErrorFile$+"#L"+ErrorLine())
    WriteStringN(file, "OS: "+misc::getOSVersion()+" on "+CPUName()+" (x"+CountCPUs()+")")
    WriteStringN(file, "Available Physical Memory: "+Str(MemoryStatus(#PB_System_FreePhysical)/1024/1024)+" MiB / "+Str(MemoryStatus(#PB_System_TotalPhysical)/1024/1024)+" MiB")
    If MemoryStatus(#PB_System_TotalVirtual) > 0
      WriteStringN(file, "Available Virtual Memory:  "+Str(MemoryStatus(#PB_System_FreeVirtual)/1024/1024)+" MiB / "+Str(MemoryStatus(#PB_System_TotalVirtual)/1024/1024)+" MiB")
    EndIf
    If MemoryStatus(#PB_System_TotalSwap) > 0
      WriteStringN(file, "Available Swap:            "+Str(MemoryStatus(#PB_System_FreeSwap)/1024/1024)+" MiB / "+Str(MemoryStatus(#PB_System_TotalSwap)/1024/1024)+" MiB")
    EndIf
    WriteStringN(file, "threading information:"+#LF$+threads::GetTreeString())
    WriteStringN(file, "################################################################################")
    WriteStringN(file, "")
    
    
    ; copy log
    WriteStringN(file, "log:")
    WriteStringN(file, debugger::getLog())
    
    ; close file
    CloseFile(file)
    
    WriteStringN(file, "[/code]")
    
    MessageRequester("ERROR", ErrorMessage()+" at "+ErrorAddress()+">"+ErrorTargetAddress()+#CRLF$+""+ErrorFile$+" line "+ErrorLine(), #PB_MessageRequester_Error)
    
    misc::openLink(GetCurrentDirectory()+"/"+file$)
    ;misc::openLink(main::#WEBSITE$)
    End
  EndProcedure
  
  ;- Startup procedure
  
  Procedure licenseAccepted()
    settings::setInteger("", "eula", #EULAVersion)
    windowMain::start()
  EndProcedure
  
  Procedure licenseDeclined()
    settings::setInteger("", "eula", 0)
    End
  EndProcedure
  
  Procedure init() ; open settings, start log, check EULA, call main window start procedure
    Protected i
    
    CompilerIf Not #PB_Compiler_Debugger
      OnErrorCall(@onError())
    CompilerEndIf
    
    ; check if TPFMM instance is already running
    If Not instance::create(#PORT, windowMain::@handleParameter())
      ; could not create instance. most likely, another instance is running
      ; try to send message to other instance
      If instance::sendString("-show")
        For i = 0 To CountProgramParameters() - 1
          instance::sendString(ProgramParameter(i))
        Next
        Debug "other instance detected, end program"
        End
      Else
        ; could not send message to other instance... continue in this instance
      EndIf
    EndIf
    
    ; check for important program parameters
    ; other parameters are checked after windowMain startup
    For i = 1 To CountProgramParameters()
      Select ProgramParameter(i)
        Case "-testmode"
          deb("main:: enable testing mode")
          _TESTMODE = #True
      EndSelect
    Next
    
    CompilerIf #DEBUG
      debugger::SetLogFile("tpfmm.log")
    CompilerEndIf
    debugger::DeleteLogFile()
    
    
    ; read language from preferences
    settings::setFilename("TPFMM.ini")
    locale::LoadLocales()
    locale::setLocale(settings::getString("", "locale"))
    
    
    ; user must accept end user license agreement
    If settings::getInteger("", "eula") < #EULAVersion
      ; current license not accepted
      Protected eula$
      misc::BinaryAsString("res/EULA.txt", eula$)
      
      windowLicense::Show("End-User License Agreement (EULA)", eula$, @licenseAccepted(), @licenseDeclined())
    Else
      ; license already accepted
      licenseAccepted()
    EndIf
    
    ; enter main loop...
    loop()
  EndProcedure
  
  ;- Proxy and Desktop Integration
  
  Procedure initProxy()
    Protected server$, user$, password$
    
    If settings::getInteger("proxy", "enabled")
      server$   = settings::getString("proxy", "server")
      user$     = settings::getString("proxy", "user")
      password$ = aes::decryptString(settings::getString("proxy", "password"))
    EndIf
    
    If server$
      deb("main:: server: "+server$+", user:"+user$)
      wget::setProxy(server$, user$, password$)
    Else
      wget::setProxy("")
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
  EndProcedure
  
  ;- Exit

  Procedure exit()
    deb(Str(threads::CountActiveThreads())+" threads active, stop all now")
    deb(#LF$+threads::GetTreeString())
    threads::StopAll(500, #True)
    deb("Goodbye!")
    End
  EndProcedure
  
  ;- Main loop
  Procedure loop()
    Repeat
      WaitWindowEvent()
    ForEver
  EndProcedure
  
EndModule