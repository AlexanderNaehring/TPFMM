DeclareModule windowSettings
  EnableExplicit
  
  Global window
  
  Declare create(parentWindow)
  Declare show()
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_repository.h.pbi"
XIncludeFile "module_aes.pbi"


Module windowSettings
  UseModule debugger
  
  Global _parentW, _dialog
  
  Macro gadget(name)
    DialogGadget(_dialog, name)
  EndMacro
  
  Declare updateGadgets()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure SetCanvasColor(gadget, color)
    If IsGadget(gadget) And GadgetType(gadget) = #PB_GadgetType_Canvas
      SetGadgetData(gadget, color)
      If StartDrawing(CanvasOutput(gadget))
        Box(0, 0, GadgetWidth(gadget), GadgetHeight(gadget), color)
        StopDrawing()
      EndIf
    EndIf
  EndProcedure
  
  Procedure GetCanvasColor(gadget)
    If IsGadget(gadget) And GadgetType(gadget) = #PB_GadgetType_Canvas
      ProcedureReturn GetGadgetData(gadget)
    EndIf
  EndProcedure
  
  Procedure GadgetColor()
    Protected gadget = EventGadget()
    Protected color
    If GadgetType(gadget) = #PB_GadgetType_Canvas
      color = GetCanvasColor(gadget)
      color = ColorRequester(color)
      If color <> -1
        SetCanvasColor(gadget, color)
      EndIf
    EndIf
  EndProcedure
  
  Procedure GadgetCloseSettings() ; close settings window and apply settings
    HideWindow(window, #True)
    DisableWindow(_parentW, #False)
    SetActiveWindow(_parentW)
    
    If misc::checkGameDirectory(settings::getString("", "path"), main::_TESTMODE) <> 0
      deb("windowSettings() - gameDirectory not correct or not set - exit TPFMM now")
      main::exit()
    EndIf
    
  EndProcedure
  
  Procedure GadgetButtonAutodetect()
    Protected path$
    
    CompilerSelect #PB_Compiler_OS
      
      CompilerCase #PB_OS_Windows 
        ; try to get Steam install location                         SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800
        path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800", "InstallLocation")
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE,  "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 446800", "InstallLocation")
        EndIf
        ; try to get GOG install location
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\GOG.com\Games\1720767912", "PATH")
        EndIf
        If Not FileSize(path$) = -2
          path$ = registry::Registry_GetString(#HKEY_LOCAL_MACHINE, "SOFTWARE\WOW6432Node\GOG.com\Games\1720767912", "PATH")
        EndIf
        
      CompilerCase #PB_OS_Linux
        path$ = misc::Path(GetHomeDirectory() + "/.local/share/Steam/steamapps/common/Transport Fever/")
        
      CompilerCase #PB_OS_MacOS
        path$ = misc::Path(GetHomeDirectory() + "/Library/Application Support/Steam/SteamApps/common/Transport Fever/")
    CompilerEndSelect
    
    If path$ And FileSize(path$) = -2
      deb("windowSettings::GadgetButtonAutodetect() - found {"+path$+"}")
      SetGadgetText(gadget("installationPath"), path$)
      updateGadgets()
      ProcedureReturn #True
    EndIf
    
    deb("windowSettings::GadgetButtonAutodetect() - did not found any TF installation")
    ProcedureReturn #False
  EndProcedure
  
  Procedure GadgetButtonBrowse()
    Protected Dir$
    Dir$ = GetGadgetText(gadget("installationPath"))
    Dir$ = PathRequester("Transport Fever Installation Path", Dir$)
    If Dir$
      SetGadgetText(gadget("installationPath"), Dir$)
    EndIf
    updateGadgets()
  EndProcedure
  
  Procedure GadgetButtonOpenPath()
    misc::openLink(GetGadgetText(gadget("installationPath")))
  EndProcedure
  
  Procedure GadgetSaveSettings()
    Protected Dir$, locale$, oldDir$, restart = #False
    dir$ = GetGadgetText(gadget("installationPath"))
    dir$ = misc::Path(dir$)
    
    locale$ = StringField(StringField(GetGadgetText(gadget("languageSelection")), 1, ">"), 2, "<") ; extract string between < and >
    If locale$ = ""
      locale$ = "en"
    EndIf
    
    oldDir$ = settings::getString("", "path")
    
    settings::setString("", "path", dir$)
    If locale$ <> settings::getString("", "locale")
      restart = #True
    EndIf
    settings::setString("", "locale", locale$)
    settings::setInteger("", "compareVersion", GetGadgetState(gadget("miscVersionCheck")))
    
    settings::setInteger("backup", "after_install", GetGadgetState(gadget("miscBackupAfterInstall")))
    settings::setInteger("backup", "before_update", GetGadgetState(gadget("miscBackupBeforeUpdate")))
    settings::setInteger("backup", "before_uninstall", GetGadgetState(gadget("miscBackupBeforeUninstall")))
    
    settings::setInteger("color", "mod_up_to_date", GetCanvasColor(gadget("colorModUpToDate")))
    settings::setInteger("color", "mod_update_available", GetCanvasColor(gadget("colorModUpdateAvailable")))
    settings::setInteger("color", "mod_lua_error", GetCanvasColor(gadget("colorModLuaError")))
    settings::setInteger("color", "mod_hidden", GetCanvasColor(gadget("colorModHidden")))
    
    settings::setInteger("proxy", "enabled", GetGadgetState(gadget("proxyEnabled")))
    settings::setString("proxy", "server", GetGadgetText(gadget("proxyServer")))
    settings::setString("proxy", "user", GetGadgetText(gadget("proxyUser")))
    settings::setString("proxy", "password", aes::encryptString(GetGadgetText(gadget("proxyPassword"))))
    
    settings::setInteger("integration", "register_protocol", GetGadgetState(gadget("integrateRegisterProtocol")))
    settings::setInteger("integration", "register_context_menu", GetGadgetState(gadget("integrateRegisterContextMenu")))
    
    settings::setInteger("repository", "use_cache", GetGadgetState(gadget("repositoryUseCache")))
    
    If restart
      MessageRequester("Restart TPFMM", "TPFMM will now restart to display the selected locale")
      misc::openLink(ProgramFilename())
      End
    EndIf
    
    main::initProxy()
    main::updateDesktopIntegration()
    
    
;     If misc::checkGameDirectory(Dir$) = 0
;       ; 0   = path okay, executable found and writing possible
;       ; 1   = path okay, executable found but cannot write
;       ; 2   = path not okay
;     EndIf
    
    If oldDir$ <> dir$
      ; gameDir changed
      mods::freeAll()
      mods::load()
    EndIf
    
    repository::refreshRepositories()
    
    GadgetCloseSettings()
  EndProcedure
  
  Procedure backupFolderMoveThread(*folder)
    Protected folder$
    folder$ = PeekS(*folder)
    FreeMemory(*folder)
    
    DisableGadget(gadget("miscBackupFolderChange"), #True)
    SetGadgetText(gadget("miscBackupFolderChange"), locale::l("settings", "backup_change_folder_wait"))
    mods::moveBackupFolder(folder$)
    DisableGadget(gadget("miscBackupFolderChange"), #False)
    SetGadgetText(gadget("miscBackupFolderChange"), locale::l("settings", "backup_change_folder"))
  EndProcedure
  
  Procedure backupFolderMove()
    Protected folder$
    Protected *folder
    
    folder$ = PathRequester(locale::get("settings", "backup_change_folder"), mods::getBackupFolder())
    
    *folder = AllocateMemory(StringByteLength(folder$) + SizeOf(character))
    PokeS(*folder, folder$)
    
    CreateThread(@backupFolderMoveThread(), *folder)
    
  EndProcedure
  
  Procedure updateGadgets()
    ; check gadgets etc
    Protected ret
    Static LastDir$ = "-"
    
    If #True ; LastDir$ <> GetGadgetText(gadget("installationPath"))
      LastDir$ = GetGadgetText(gadget("installationPath"))
      
      If FileSize(LastDir$) = -2
        ; DisableGadget(, #False)
      Else
        ; DisableGadget(, #True)
      EndIf
      
      ret = misc::checkGameDirectory(LastDir$, main::_TESTMODE)
      ; 0   = path okay, executable found and writing possible
      ; 1   = path okay, executable found but cannot write
      ; 2   = path not okay
      If ret = 0
        SetGadgetText(gadget("installationTextStatus"), locale::l("settings","success"))
        SetGadgetColor(gadget("installationTextStatus"), #PB_Gadget_FrontColor, RGB(0,100,0))
        DisableGadget(gadget("save"), #False)
      Else
        SetGadgetColor(gadget("installationTextStatus"), #PB_Gadget_FrontColor, RGB(255,0,0))
        DisableGadget(gadget("save"), #True)
        If ret = 1
          SetGadgetText(gadget("installationTextStatus"), locale::l("settings","failed"))
        Else
          SetGadgetText(gadget("installationTextStatus"), locale::l("settings","not_found"))
        EndIf
      EndIf
    EndIf
    
    If GetGadgetState(gadget("proxyEnabled"))
      DisableGadget(gadget("proxyServer"), #False)
      DisableGadget(gadget("proxyUser"), #False)
      DisableGadget(gadget("proxyPassword"), #False)
    Else
      DisableGadget(gadget("proxyServer"), #True)
      DisableGadget(gadget("proxyUser"), #True)
      DisableGadget(gadget("proxyPassword"), #True)
    EndIf
    
  EndProcedure
  
  Procedure updateRepositoryList()
    Protected NewList urls$()
    repository::GetRepositories(urls$())
    ClearGadgetItems(gadget("repositoryList"))
    ForEach urls$()
      AddGadgetItem(gadget("repositoryList"), -1, urls$()+#LF$+repository::GetRepositoryModCount(urls$()))
    Next
  EndProcedure
  
  Procedure repositoryAdd()
    Protected url$
    ; preset url to clipboard text if is an url
    url$ = Trim(GetClipboardText())
    If LCase(Left(url$, 7)) <> "http://" And LCase(Left(url$, 8)) <> "https://"
      url$ = ""
    EndIf
    ; show requester
    url$ = InputRequester(locale::l("settings","repository_add"), locale::l("settings", "repository_input_url"), url$)
    
    If url$
      ; add repo
      If repository::CheckRepository(url$)
        ; TODO display some info and ask if repo should be added.
        repository::AddRepository(url$)
      Else
        MessageRequester(locale::l("settings","repository_add"),locale::l("settings","repository_invalid"), #PB_MessageRequester_Error)
      EndIf
    EndIf
    updateRepositoryList()
  EndProcedure
  
  Procedure repositoryRemove()
    Protected selected, url$
    selected = GetGadgetState(gadget("repositoryList"))
    If selected <> -1
      url$ = GetGadgetItemText(gadget("repositoryList"), selected, 0)
      If url$
        repository::RemoveRepository(url$)
      EndIf
    EndIf
    updateRepositoryList()
  EndProcedure
  
  
  Procedure showWindow()
    HideWindow(window, #False, #PB_Window_WindowCentered)
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(parentWindow)
    _parentW = parentWindow
    
    UseModule locale ; import namespace "locale" for shorthand "l()" access
    
    ; open dialog
    Protected xml 
    misc::IncludeAndLoadXML(xml, "dialogs/settings.xml")
    
    _dialog = CreateDialog(#PB_Any)
     
    If Not OpenXMLDialog(_dialog, xml, "settings", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(parentWindow))
      MessageRequester("Critical Error", "Could not open settings window!", #PB_MessageRequester_Error)
      End
    EndIf
    FreeXML(xml)
    
    window = DialogWindow(_dialog)
    
    
    ; set texts
    SetWindowTitle(window, l("settings","title"))
    
    SetGadgetItemText(gadget("panelSettings"), 0,   l("settings", "general"))
    SetGadgetItemText(gadget("panelSettings"), 1,   l("settings", "proxy"))
    SetGadgetItemText(gadget("panelSettings"), 2,   l("settings", "integrate"))
;     SetGadgetItemText(gadget("panelSettings"), ,   l("settings", "repository"))
    
    SetGadgetText(gadget("save"),                   l("settings","save"))
    GadgetToolTip(gadget("save"),                   l("settings","save_tip"))
    SetGadgetText(gadget("cancel"),                 l("settings","cancel"))
    GadgetToolTip(gadget("cancel"),                 l("settings","cancel_tip"))
    
    SetGadgetText(gadget("installationFrame"),      l("settings","path"))
    SetGadgetText(gadget("installationTextSelect"), l("settings","text"))
    SetGadgetText(gadget("installationAutodetect"), l("settings","autodetect"))
    GadgetToolTip(gadget("installationAutodetect"), l("settings","autodetect_tip"))
    SetGadgetText(gadget("installationPath"),       "")
    SetGadgetText(gadget("installationBrowse"),     l("settings","browse"))
    GadgetToolTip(gadget("installationBrowse"),     l("settings","browse_tip"))
    SetGadgetText(gadget("installationTextStatus"), "")
               
    SetGadgetText(gadget("miscFrame"),              l("settings","other"))
    SetGadgetText(gadget("miscBackupAfterInstall"),     l("settings","backup_after_install"))
    SetGadgetText(gadget("miscBackupBeforeUpdate"),     l("settings","backup_before_update"))
    SetGadgetText(gadget("miscBackupBeforeUninstall"),  l("settings","backup_before_uninstall"))
    SetGadgetText(gadget("miscBackupFolderChange"),     l("settings","backup_change_folder"))
    SetGadgetText(gadget("miscVersionCheck"),       l("settings","versioncheck"))
    GadgetToolTip(gadget("miscVersionCheck"),       l("settings","versioncheck_tip"))
    
    SetGadgetText(gadget("languageFrame"),          l("settings","locale"))
    SetGadgetText(gadget("languageSelection"),      "")
    
    SetGadgetText(gadget("colorFrame"),                   l("settings","color"))
    SetGadgetText(gadget("colorModUpToDateText"),         l("settings","color_mod_up_to_date"))
    SetGadgetText(gadget("colorModUpdateAvailableText"),  l("settings","color_mod_update_available"))
    SetGadgetText(gadget("colorModLuaErrorText"),         l("settings","color_mod_lua_error"))
    SetGadgetText(gadget("colorModHiddenText"),           l("settings","color_mod_hidden"))
    
    SetGadgetText(gadget("proxyEnabled"),           l("settings","proxy_enabled"))
    SetGadgetText(gadget("proxyFrame"),             l("settings","proxy_frame"))
    SetGadgetText(gadget("proxyServerLabel"),       l("settings","proxy_server"))
    SetGadgetText(gadget("proxyUserLabel"),         l("settings","proxy_user"))
    SetGadgetText(gadget("proxyPasswordLabel"),     l("settings","proxy_password"))
    
    SetGadgetText(gadget("integrateText"),                l("settings","integrate_text"))
    SetGadgetText(gadget("integrateRegisterProtocol"),    l("settings","integrate_register_protocol"))
    SetGadgetText(gadget("integrateRegisterContextMenu"), l("settings","integrate_register_context"))
    
    RemoveGadgetColumn(gadget("repositoryList"), 0)
    AddGadgetColumn(gadget("repositoryList"), 0, "URL", 340)
    AddGadgetColumn(gadget("repositoryList"), 1, "Mods", 40)
    SetGadgetText(gadget("repositoryAdd"),          l("settings", "repository_add"))
    SetGadgetText(gadget("repositoryRemove"),       l("settings", "repository_remove"))
    SetGadgetText(gadget("repositoryUseCache"),     l("settings", "repository_usecache"))
    GadgetToolTip(gadget("repositoryUseCache"),     l("settings", "repository_usecache_tip"))
;     SetGadgetText(gadget("repositoryAdd"),          l("settings", "repository_add"))
;     SetGadgetText(gadget("repositoryNameLabel"),        l("settings", "repository_name"))
;     SetGadgetText(gadget("repositoryCuratorLabel"),     l("settings", "repository_curator"))
;     SetGadgetText(gadget("repositoryDescriptionLabel"), l("settings", "repository_description"))
    
    
    ; bind events
    BindEvent(#PB_Event_CloseWindow, @GadgetCloseSettings(), window)
    
    ; bind gadget events
    BindGadgetEvent(gadget("installationAutodetect"), @GadgetButtonAutodetect())
    BindGadgetEvent(gadget("installationBrowse"), @GadgetButtonBrowse())
    ;BindGadgetEvent(, @GadgetButtonOpenPath())
    BindGadgetEvent(gadget("save"), @GadgetSaveSettings())
    BindGadgetEvent(gadget("cancel"), @GadgetCloseSettings())
    BindGadgetEvent(gadget("installationPath"), @updateGadgets(), #PB_EventType_Change)
    BindGadgetEvent(gadget("proxyEnabled"), @updateGadgets())
    BindGadgetEvent(gadget("miscBackupFolderChange"), @backupFolderMove())
    BindGadgetEvent(gadget("colorModUpToDate"), @GadgetColor(), #PB_EventType_LeftClick)
    BindGadgetEvent(gadget("colorModUpdateAvailable"), @GadgetColor(), #PB_EventType_LeftClick)
    BindGadgetEvent(gadget("colorModLuaError"), @GadgetColor(), #PB_EventType_LeftClick)
    BindGadgetEvent(gadget("colorModHidden"), @GadgetColor(), #PB_EventType_LeftClick)
    
    BindGadgetEvent(gadget("repositoryAdd"), @repositoryAdd())
    BindGadgetEvent(gadget("repositoryRemove"), @repositoryRemove())
    ; receive "unhide" event
    BindEvent(#PB_Event_RestoreWindow, @showWindow(), window)
    
    RefreshDialog(_dialog)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure show()
    Protected locale$
    
    ; main
    SetGadgetText(gadget("installationPath"), settings::getString("", "path"))
    locale$ = settings::getString("", "locale")
    SetGadgetState(gadget("miscVersionCheck"), settings::getInteger("", "compareVersion"))
    
    SetGadgetState(gadget("miscBackupAfterInstall"),    settings::getInteger("backup", "after_install"))
    SetGadgetState(gadget("miscBackupBeforeUpdate"),    settings::getInteger("backup", "before_update"))
    SetGadgetState(gadget("miscBackupBeforeUninstall"), settings::getInteger("backup", "before_uninstall"))
    
    SetCanvasColor(gadget("colorModUpToDate"), settings::getInteger("color", "mod_up_to_date"))
    SetCanvasColor(gadget("colorModUpdateAvailable"), settings::getInteger("color", "mod_update_available"))
    SetCanvasColor(gadget("colorModLuaError"), settings::getInteger("color", "mod_lua_error"))
    SetCanvasColor(gadget("colorModHidden"), settings::getInteger("color", "mod_hidden"))
    
    ; proxy
    SetGadgetState(gadget("proxyEnabled"), settings::getInteger("proxy", "enabled"))
    SetGadgetText(gadget("proxyServer"), settings::getString("proxy", "server"))
    SetGadgetText(gadget("proxyUser"), settings::getString("proxy", "user"))
    SetGadgetText(gadget("proxyPassword"), aes::decryptString(settings::getString("proxy", "password")))
    
    ; integration
    SetGadgetState(gadget("integrateRegisterProtocol"), settings::getInteger("integration", "register_protocol"))
    SetGadgetState(gadget("integrateRegisterContextMenu"), settings::getInteger("integration", "register_context_menu"))
    DisableGadget(gadget("integrateRegisterContextMenu"), #True)
    
    
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
      DisableGadget(gadget("integrateRegisterProtocol"), #True)
    CompilerEndIf
    
    If GetGadgetText(gadget("installationPath")) = ""
      GadgetButtonAutodetect()
    EndIf
    
    ; locale
    locale::listAvailable(gadget("languageSelection"), locale$)
    
    ; repositories
    updateRepositoryList()
    SetGadgetState(gadget("repositoryUseCache"), settings::getInteger("repository", "use_cache"))
    
    updateGadgets()
    
    ; show window
    RefreshDialog(_dialog)
    ;HideWindow(window, #False) ; linux: cannot unhide from other process  (?)
    PostEvent(#PB_Event_RestoreWindow, window, window)
    DisableWindow(_parentW, #True)
    SetActiveWindow(window)
  EndProcedure
  
EndModule
