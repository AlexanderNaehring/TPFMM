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
  #EULAVersion = 2
  
  #DRAG_MOD = 1
  
  Declare init()
  Declare initProxy()
  Declare updateDesktopIntegration()
  Declare exit()
  Declare loop()
  Declare handleParameter(parameter$)
  
  Declare showProgressWindow(text$, PostEventOnClose=-1)
  Declare setProgressPercent(percent.b)
  Declare setProgressText(text$)
  Declare closeProgressWindow()
  
  Declare isMainThread()
EndDeclareModule

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_settings.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_windowMain.pbi"
XIncludeFile "module_instance.pbi"
XIncludeFile "module_windowLicense.pbi"
XIncludeFile "animation.pb"

XIncludeFile "module_mods.pbi"
XIncludeFile "module_repository.pbi"

Module main
  UseModule debugger
  
  ;- Error Handling
  
  Procedure onError()
    Protected date$ = FormatDate("%yyyy-%mm-%dd_%hh-%ii-%ss", Date())
    Protected file, file$ = "crash/dump-"+date$+".txt"
    CreateDirectory("crash")
    
    
    file = CreateFile(#PB_Any, file$, #PB_File_NoBuffering)
    
    ; Error and System Information
    WriteStringN(file, "Please provide the following information at")
    WriteStringN(file, main::WEBSITE$)
    WriteStringN(file, "Copy the whole file content in the text box, or attach the .txt file directly.")
    WriteStringN(file, "")
    WriteStringN(file, "[code]")
    
    WriteStringN(file, "################################################################################")
    WriteStringN(file, "ERROR @ "+date$)
    WriteStringN(file, VERSION_FULL$)
    WriteStringN(file, #DQUOTE$+ErrorMessage()+#DQUOTE$)
    WriteStringN(file, Str(ErrorCode())+"@"+ErrorAddress()+">"+ErrorTargetAddress())
    WriteStringN(file, ErrorFile()+" line "+ErrorLine())
    WriteStringN(file, "OS: "+misc::getOSVersion()+" on "+CPUName()+" (x"+CountCPUs()+")")
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
    WriteStringN(file, debugger::getLog())
    
    ; close file
    CloseFile(file)
    
    WriteStringN(file, "[/code]")
    
    MessageRequester("ERROR", ErrorMessage()+" (#"+ErrorCode()+") at address "+ErrorAddress()+">"+ErrorTargetAddress()+#CRLF$+""+ErrorFile()+" line "+ErrorLine(), #PB_MessageRequester_Error)
    
    misc::openLink(GetCurrentDirectory()+"/"+file$)
    End
  EndProcedure
  
  ;- Parameter Handling
  
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
          Deb(parameter$)
          ; handle link
          parameter$ = Mid(parameter$, 18) ; /source/modID/fileID
          windowMain::repoFindModAndDownload(parameter$)
          
        ElseIf FileSize(parameter$) > 0
          ; install mod... (this function is called, before the main window is created ....
          mods::install(parameter$)
        EndIf
        
    EndSelect
  EndProcedure
  
  ;- Progress Window
  
  Structure progress
    dialog.i
    window.i
    gText.i
    gBar.i
    onClose.i
    *ani.animation::animation
  EndStructure
  
  Global progressDialog.progress
  
  Procedure setProgressText(text$)
    If progressDialog\window
      SetGadgetText(progressDialog\gText, text$)
    EndIf
  EndProcedure
  
  Procedure setProgressPercent(percent.b)
    If progressDialog\window
      SetGadgetState(progressDialog\gBar, percent)
    EndIf
  EndProcedure
  
  Procedure closeProgressWindowEvent()
    ; cannot close a window from a thread, must be main thread
    If Not isMainThread()
      DebuggerError("main:: closeProgressWindowEvent() must always be called from main thread")
    EndIf
    
    If progressDialog\window
      progressDialog\ani\free()
      CloseWindow(progressDialog\window)
      FreeDialog(progressDialog\dialog)
      progressDialog\window = #Null
      
      If progressDialog\onClose <> -1
        PostEvent(progressDialog\onClose)
      EndIf
    EndIf
  EndProcedure
  
  Procedure closeProgressWindow()
    If progressDialog\window
      progressDialog\onClose = -1 ; decativate the "on close event" as close is triggered manually
      progressDialog\ani\pause(); if garbage collector closes window before the animation is stopped/freed, animation update will cause IMA
      
      If isMainThread()
        closeProgressWindowEvent()
      Else
        PostEvent(#PB_Event_CloseWindow, progressDialog\window, 0)
      EndIf
    EndIf
  EndProcedure
  
  Procedure showProgressWindow(title$, PostEventOnClose=-1)
    Protected xml, dialog
    
    ; only single dialog allowed
    If progressDialog\window
      progressDialog\onClose = -1
      closeProgressWindowEvent()
    EndIf
    
    misc::IncludeAndLoadXML(xml, "dialogs/progress.xml")
    dialog = CreateDialog(#PB_Any)
    OpenXMLDialog(dialog, xml, "progress")
    FreeXML(xml)
    
    progressDialog\dialog = dialog
    progressDialog\window = DialogWindow(dialog)
    progressDialog\gText  = DialogGadget(dialog, "text")
    progressDialog\gBar   = DialogGadget(dialog, "percent")
    progressDialog\onclose = PostEventOnClose
    
    SetWindowTitle(progressDialog\window, title$)
;     SetGadgetState(DialogGadget(dialog, "logo"), ImageID(images::images("logo")))
    
    progressDialog\ani = animation::new()
    progressDialog\ani\loadAni("images/logo/logo.ani")
    progressDialog\ani\setInterval(1000/60)
    progressDialog\ani\setCanvas(DialogGadget(dialog, "logo"))
    progressDialog\ani\play()
    
    SetWindowColor(progressDialog\window, #White)
    SetGadgetColor(progressDialog\gText, #PB_Gadget_BackColor, #White)
    
    RefreshDialog(dialog)
    
    BindEvent(#PB_Event_CloseWindow, @closeProgressWindowEvent(), progressDialog\window)
    
    AddKeyboardShortcut(progressDialog\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
    BindEvent(#PB_Event_Menu, @closeProgressWindowEvent(), progressDialog\window, #PB_Event_CloseWindow)
    
    HideWindow(progressDialog\window, #False, #PB_Window_ScreenCentered)
    ProcedureReturn #True
  EndProcedure
  
  ;- Startup procedure
  
  Procedure startUp()
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
    
    InitNetwork()
    
    ; check if TPFMM instance is already running
    If Not instance::create(#PORT, @handleParameter())
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
    
    If _DEBUG
      debugger::SetLogFile("tpfmm.log")
    EndIf
    debugger::DeleteLogFile()
    
    
    ; read language from preferences
    settings::setFilename("TPFMM.ini")
    locale::use(settings::getString("", "locale"))
    
    
    ; user must accept end user license agreement
    If settings::getInteger("", "eula") < #EULAVersion
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
  
  Global mainThread
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      mainThread = GetCurrentThreadId_()
    CompilerCase #PB_OS_Linux
      mainThread = pthread_self_()
  CompilerEndSelect
  
  Procedure isMainThread()
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        ProcedureReturn Bool(GetCurrentThreadId_() = mainThread)
      CompilerCase #PB_OS_Linux
        ProcedureReturn Bool(pthread_self_() = mainThread)
    CompilerEndSelect
    
  EndProcedure
  
  ;- Exit
  Procedure exit()
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