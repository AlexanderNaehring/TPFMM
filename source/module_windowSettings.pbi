DeclareModule windowSettings
  EnableExplicit
  
  Global window
  
  Declare create(parentWindow)
  Declare show()
  Declare updateStrings()
  Declare close()
  Declare showTab(tab)
  Declare repositoryAddURL(url$)
  
  ; custom events that can be sent to "window"
  Enumeration #PB_Event_FirstCustomValue
    #EventRefreshRepoList
    #EventBackupFolderMoved
  EndEnumeration
  
  Enumeration
    #TabGeneral
    #TabBackup
    #TabProxy
    #TabIntegration
    #TabRepository
  EndEnumeration
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_registry.pbi"
XIncludeFile "module_repository.h.pbi"
XIncludeFile "module_aes.pbi"
XIncludeFile "windowProgress.pb"

Module windowSettings
  UseModule debugger
  UseModule locale
  
  Global _parentW, _dialog
  
  Macro gadget(name)
    DialogGadget(_dialog, name)
  EndMacro
  
  Declare updateGadgets()
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
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
    Protected Dir$, locale$, oldDir$
    Protected proxyChange.b
    dir$ = GetGadgetText(gadget("installationPath"))
    dir$ = misc::Path(dir$)
    oldDir$ = settings::getString("", "path")
    settings::setString("", "path", dir$)
    
    locale$ = StringField(StringField(GetGadgetText(gadget("languageSelection")), 1, ">"), 2, "<") ; extract string between < and >
    If locale$ = ""
      locale$ = "en"
    EndIf
    If locale$ <> settings::getString("", "locale")
      locale::setLocale(locale$)
      windowMain::updateStrings()
      ; no need to update strings in this window, as they will be updated on next window show()
      ; TODO update all strings, e.g. in filter/sort dialogs
    EndIf
    settings::setString("", "locale", locale$)
    
    settings::setInteger("", "compareVersion", GetGadgetState(gadget("miscVersionCheck")))
    
    settings::setInteger("backup", "auto_delete_days", GetGadgetItemData(gadget("backupAutoDeleteTime"), GetGadgetState(gadget("backupAutoDeleteTime"))))
    settings::setInteger("backup", "after_install", GetGadgetState(gadget("backupAfterInstall")))
    settings::setInteger("backup", "before_update", GetGadgetState(gadget("backupBeforeUpdate")))
    settings::setInteger("backup", "before_uninstall", GetGadgetState(gadget("backupBeforeUninstall")))
    
    If settings::getInteger("proxy", "enabled") <> GetGadgetState(gadget("proxyEnabled")) Or
       settings::getString("proxy", "server") <> GetGadgetText(gadget("proxyServer")) Or
       settings::getString("proxy", "user") <> GetGadgetText(gadget("proxyUser")) Or
       settings::getString("proxy", "password") <> aes::encryptString(GetGadgetText(gadget("proxyPassword")))
      proxyChange = #True
    EndIf
    
    settings::setInteger("proxy", "enabled", GetGadgetState(gadget("proxyEnabled")))
    settings::setString("proxy", "server", GetGadgetText(gadget("proxyServer")))
    settings::setString("proxy", "user", GetGadgetText(gadget("proxyUser")))
    settings::setString("proxy", "password", aes::encryptString(GetGadgetText(gadget("proxyPassword"))))
    
    settings::setInteger("integration", "register_protocol", GetGadgetState(gadget("integrateRegisterProtocol")))
    settings::setInteger("integration", "register_context_menu", GetGadgetState(gadget("integrateRegisterContextMenu")))
    
    settings::setInteger("repository", "use_cache", GetGadgetState(gadget("repositoryUseCache")))
    
    main::initProxy()
    main::updateDesktopIntegration()
    
    If oldDir$ <> dir$
      ; gameDir changed
      mods::freeAll()
      mods::load()
    EndIf
    
    If proxyChange
      repository::refreshRepositories()
    EndIf
    
    GadgetCloseSettings()
  EndProcedure
  
  
  Procedure ShortcutCopy()
    Protected i
    Select GetActiveGadget()
      Case gadget("repositoryList")
        i = GetGadgetState(gadget("repositoryList"))
        If i <> -1
          SetClipboardText(GetGadgetItemText(gadget("repositoryList"), i, 0))
        EndIf
    EndSelect
  EndProcedure
  
  
  Procedure backupFolderMoved()
    DisableWindow(window, #False)
    windowProgress::closeProgressWindow()
    If EventGadget()
      MessageRequester(_("generic_success"), _("settings_backup_move_success"), #PB_MessageRequester_Info)
    Else
      MessageRequester(_("generic_error"), _("settings_backup_move_error"), #PB_MessageRequester_Error)
    EndIf
    SetGadgetText(gadget("backupFolder"), mods::backupsGetFolder())
  EndProcedure
  
  Procedure backupFolderMoveThread(*folder)
    Protected folder$
    folder$ = PeekS(*folder)
    FreeMemory(*folder)
    
    If mods::backupsMoveFolder(folder$)
      PostEvent(#EventBackupFolderMoved, window, #True)
    Else
      PostEvent(#EventBackupFolderMoved, window, #False)
    EndIf
  EndProcedure
  
  Procedure backupFolderMove()
    Protected folder$
    Protected *folder
    
    folder$ = PathRequester(_("settings_backup_change_folder"), mods::backupsGetFolder())
    If folder$ = ""
      ProcedureReturn #False
    EndIf
    
    windowProgress::showProgressWindow(_("settings_backup_change_folder_wait"))
    windowProgress::setProgressText(_("settings_backup_change_folder_wait"))
    DisableWindow(window, #True)
    
    *folder = AllocateMemory(StringByteLength(folder$) + SizeOf(character))
    PokeS(*folder, folder$)
    threads::NewThread(@backupFolderMoveThread(), *folder, "windowSettings::backupFolderMoveThread")
    
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
        SetGadgetText(gadget("installationTextStatus"), _("settings_success"))
        SetGadgetColor(gadget("installationTextStatus"), #PB_Gadget_FrontColor, RGB(0,100,0))
        DisableGadget(gadget("save"), #False)
      Else
        SetGadgetColor(gadget("installationTextStatus"), #PB_Gadget_FrontColor, RGB(255,0,0))
        DisableGadget(gadget("save"), #True)
        If ret = 1
          SetGadgetText(gadget("installationTextStatus"), _("settings_failed"))
        Else
          SetGadgetText(gadget("installationTextStatus"), _("settings_not_found"))
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
    Protected NewList repos$()
    Protected repoInfo.repository::RepositoryInformation
    
    ClearGadgetItems(gadget("repositoryList"))
    repository::ReadSourcesFromFile(repos$())
    
    ForEach repos$()
      If repository::GetRepositoryInformation(repos$(), @repoInfo)
        AddGadgetItem(gadget("repositoryList"), -1, repos$()+#LF$+repoInfo\name$+#LF$+repoInfo\maintainer$+#LF$+repoInfo\source$+#LF$+repoInfo\modCount)
      Else
        ; this repo is not loaded at the moment
        AddGadgetItem(gadget("repositoryList"), -1, repos$()+#LF$+_("settings_repository_not_loaded"))
      EndIf
    Next
  EndProcedure
  
  Procedure repositoryListEvent()
    If GetGadgetState(gadget("repositoryList")) <> -1
      DisableGadget(gadget("repositoryRemove"), #False)
    Else
      DisableGadget(gadget("repositoryRemove"), #True)
    EndIf
  EndProcedure
  
  Procedure repositoryAdd()
    Protected url$
    
    ; preset url to clipboard text if is an url
    url$ = Trim(GetClipboardText())
    If LCase(Left(url$, 7)) <> "http://" And LCase(Left(url$, 8)) <> "https://"
      url$ = ""
    EndIf
    
    ; show requester
    url$ = InputRequester(_("settings_repository_add"), _("settings_repository_input_url"), url$)
    
    repositoryAddURL(url$)
  EndProcedure
  
  Procedure repositoryAddURL(url$)
    Protected repoInfo.repository::RepositoryInformation
    Protected info$, error$
    
    If url$
      ; add repo
      If repository::CheckRepository(url$, @repoInfo)
        info$ = repoInfo\url$+#CRLF$+
                _("repository_repository")+" "+#DQUOTE$+repoInfo\name$+#DQUOTE$+" "+_("repository_maintained_by")+" "+repoInfo\maintainer$+#CRLF$+#CRLF$
        If repoInfo\info_url$
          info$ + _("repository_info_url")+" "+repoInfo\info_url$+#CRLF$
        EndIf
        If repoInfo\terms$
          info$ + _("repository_terms")+" "+repoInfo\terms$+#CRLF$
        EndIf
        info$ + repoInfo\modCount+" "+_("repository_mod_count")+#CRLF$+
                #CRLF$+
                _("repository_confirm_add")
        
        If MessageRequester(_("repository_confirm_add"), info$, #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
          repository::AddRepository(url$)
          updateRepositoryList()
          repository::refreshRepositories() ; will trigger an event when update finished which updates the repo list again
        EndIf
      Else
        Select repoInfo\error
          Case repository::#ErrorDownloadFailed
            error$ = _("repository_error_download")
          Case repository::#ErrorJSON
            error$ = _("repository_error_json")
          Case repository::#ErrorNoSource
            error$ = _("repository_error_no_source")
          Case repository::#ErrorDuplicateURL
            error$ = _("repository_error_dup_url")
          Case repository::#ErrorNoSource
            error$ = _("repository_error_no_source")
          Case repository::#ErrorDuplicateSource
            error$ = _("repository_error_dup_source")
          Case repository::#ErrorNoMods
            error$ = _("repository_error_no_mods")
          Default
            error$ = _("repository_error_unknown")
        EndSelect
        MessageRequester(_("repository_error"), error$, #PB_MessageRequester_Error)
      EndIf
    EndIf
  EndProcedure
  
  
  Procedure repositoryRemove()
    Protected selected, url$
    selected = GetGadgetState(gadget("repositoryList"))
    If selected <> -1
      url$ = GetGadgetItemText(gadget("repositoryList"), selected, 0)
      If url$
        repository::RemoveRepository(url$)
        updateRepositoryList()
        repository::refreshRepositories()
      EndIf
    EndIf
  EndProcedure
  
  Procedure repositoryRefresh()
    repository::refreshRepositories()
  EndProcedure
  
  Procedure repositoryClearThumb()
    repository::clearThumbCache()
    MessageRequester(_("generic_success"), _("settings_repository_thumb_cleared"), #PB_MessageRequester_Info)
  EndProcedure
  
  Procedure showWindow()
    HideWindow(window, #False, #PB_Window_WindowCentered)
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure updateStrings()
    UseModule locale
    
    ; set texts
    SetWindowTitle(window, _("settings_title"))
    
    SetGadgetItemText(gadget("panelSettings"), #TabGeneral,     _("settings_general"))
    SetGadgetItemText(gadget("panelSettings"), #TabBackup,      _("settings_backup"))
    SetGadgetItemText(gadget("panelSettings"), #TabProxy,       _("settings_proxy"))
    SetGadgetItemText(gadget("panelSettings"), #TabIntegration, _("settings_integrate"))
    SetGadgetItemText(gadget("panelSettings"), #TabRepository,  _("settings_repository"))
    
    SetGadgetText(gadget("save"),                   _("settings_save"))
    GadgetToolTip(gadget("save"),                   _("settings_save_tip"))
    SetGadgetText(gadget("cancel"),                 _("settings_cancel"))
    GadgetToolTip(gadget("cancel"),                 _("settings_cancel_tip"))
    
    SetGadgetText(gadget("installationFrame"),      _("settings_path"))
    SetGadgetText(gadget("installationTextSelect"), _("settings_text"))
    SetGadgetText(gadget("installationAutodetect"), _("settings_autodetect"))
    GadgetToolTip(gadget("installationAutodetect"), _("settings_autodetect_tip"))
    SetGadgetText(gadget("installationPath"),       "")
    SetGadgetText(gadget("installationBrowse"),     _("settings_browse"))
    GadgetToolTip(gadget("installationBrowse"),     _("settings_browse_tip"))
    SetGadgetText(gadget("installationTextStatus"), "")
               
    SetGadgetText(gadget("backupAutoDeleteLabel"),  _("settings_backup_auto_delete"))
    ClearGadgetItems(gadget("backupAutoDeleteTime"))
    AddGadgetItem(    gadget("backupAutoDeleteTime"), 0, _("settings_backup_auto_delete_never"))
    SetGadgetItemData(gadget("backupAutoDeleteTime"), 0, 0)
    AddGadgetItem(    gadget("backupAutoDeleteTime"), 1, _("settings_backup_auto_delete_1week"))
    SetGadgetItemData(gadget("backupAutoDeleteTime"), 1, 7)
    AddGadgetItem(    gadget("backupAutoDeleteTime"), 2, _("settings_backup_auto_delete_1month"))
    SetGadgetItemData(gadget("backupAutoDeleteTime"), 2, 31)
    AddGadgetItem(    gadget("backupAutoDeleteTime"), 3, _("settings_backup_auto_delete_3months"))
    SetGadgetItemData(gadget("backupAutoDeleteTime"), 3, 91)
    AddGadgetItem(    gadget("backupAutoDeleteTime"), 4, _("settings_backup_auto_delete_6months"))
    SetGadgetItemData(gadget("backupAutoDeleteTime"), 4, 182)
    AddGadgetItem(    gadget("backupAutoDeleteTime"), 5, _("settings_backup_auto_delete_1year"))
    SetGadgetItemData(gadget("backupAutoDeleteTime"), 5, 365)
    
    SetGadgetText(gadget("backupAutoCreateLabel"),  _("settings_backup_auto_create_label"))
    SetGadgetText(gadget("backupAfterInstall"),     _("settings_backup_after_install"))
    SetGadgetText(gadget("backupBeforeUpdate"),     _("settings_backup_before_update"))
    SetGadgetText(gadget("backupBeforeUninstall"),  _("settings_backup_before_uninstall"))
    SetGadgetText(gadget("backupFolderChange"),     _("settings_backup_change_folder"))
    
    SetGadgetText(gadget("miscFrame"),              _("settings_other"))
    SetGadgetText(gadget("miscVersionCheck"),       _("settings_versioncheck"))
    GadgetToolTip(gadget("miscVersionCheck"),       _("settings_versioncheck_tip"))
    
    SetGadgetText(gadget("languageFrame"),          _("settings_locale"))
    SetGadgetText(gadget("languageSelection"),      "")
    
    SetGadgetText(gadget("proxyEnabled"),           _("settings_proxy_enabled"))
    SetGadgetText(gadget("proxyFrame"),             _("settings_proxy_frame"))
    SetGadgetText(gadget("proxyServerLabel"),       _("settings_proxy_server"))
    SetGadgetText(gadget("proxyUserLabel"),         _("settings_proxy_user"))
    SetGadgetText(gadget("proxyPasswordLabel"),     _("settings_proxy_password"))
    
    SetGadgetText(gadget("integrateText"),                _("settings_integrate_text"))
    SetGadgetText(gadget("integrateRegisterProtocol"),    _("settings_integrate_register_protocol"))
    SetGadgetText(gadget("integrateRegisterContextMenu"), _("settings_integrate_register_context"))
    
    RemoveGadgetColumn(gadget("repositoryList"), #PB_All)
    AddGadgetColumn(gadget("repositoryList"), 0, _("settings_repository_url"), 100)
    AddGadgetColumn(gadget("repositoryList"), 1, _("settings_repository_name"), 120)
    AddGadgetColumn(gadget("repositoryList"), 2, _("settings_repository_maintainer"), 70)
    AddGadgetColumn(gadget("repositoryList"), 3, _("settings_repository_source"), 60)
    AddGadgetColumn(gadget("repositoryList"), 4, _("settings_repository_mods"), 50)
    SetGadgetText(gadget("repositoryAdd"),          _("settings_repository_add"))
    SetGadgetText(gadget("repositoryRemove"),       _("settings_repository_remove"))
    SetGadgetText(gadget("repositoryRefresh"),      _("settings_repository_refresh"))
    SetGadgetText(gadget("repositoryClearThumb"),   _("settings_repository_clear_thumb"))
    SetGadgetText(gadget("repositoryUseCache"),     _("settings_repository_usecache"))
    GadgetToolTip(gadget("repositoryUseCache"),     _("settings_repository_usecache_tip"))
    
    UnuseModule locale
  EndProcedure
  
  Procedure create(parentWindow)
    _parentW = parentWindow
    
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
    
    ; bind events
    BindEvent(#PB_Event_CloseWindow, @GadgetCloseSettings(), window)
    BindEvent(#EventRefreshRepoList, @updateRepositoryList(), window)
    BindEvent(#EventBackupFolderMoved, @backupFolderMoved(), window)
    
    AddKeyboardShortcut(window, #PB_Shortcut_Escape, 1)
    BindEvent(#PB_Event_Menu, @GadgetCloseSettings(), window, 1)
    
    AddKeyboardShortcut(window, #PB_Shortcut_Control|#PB_Shortcut_S, 2)
    BindEvent(#PB_Event_Menu, @GadgetSaveSettings(), window, 2)
    
    AddKeyboardShortcut(window, #PB_Shortcut_Control|#PB_Shortcut_C, 3)
    BindEvent(#PB_Event_Menu, @ShortcutCopy(), window, 3)
    
    ; bind gadget events
    BindGadgetEvent(gadget("installationAutodetect"), @GadgetButtonAutodetect())
    BindGadgetEvent(gadget("installationBrowse"), @GadgetButtonBrowse())
    ;BindGadgetEvent(, @GadgetButtonOpenPath())
    BindGadgetEvent(gadget("save"), @GadgetSaveSettings())
    BindGadgetEvent(gadget("cancel"), @GadgetCloseSettings())
    BindGadgetEvent(gadget("installationPath"), @updateGadgets(), #PB_EventType_Change)
    BindGadgetEvent(gadget("proxyEnabled"), @updateGadgets())
    BindGadgetEvent(gadget("backupFolderChange"), @backupFolderMove())
;     BindGadgetEvent(gadget("languageSelection"), @languageSelection(), #PB_EventType_Change)
    BindGadgetEvent(gadget("repositoryList"), @repositoryListEvent(), #PB_EventType_Change)
    BindGadgetEvent(gadget("repositoryAdd"), @repositoryAdd())
    BindGadgetEvent(gadget("repositoryRemove"), @repositoryRemove())
    BindGadgetEvent(gadget("repositoryRefresh"), @repositoryRefresh())
    BindGadgetEvent(gadget("repositoryClearThumb"), @repositoryClearThumb())
    ; receive "unhide" event
    BindEvent(#PB_Event_RestoreWindow, @showWindow(), window)
    
    updateStrings()
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure show()
    Protected locale$
    Protected days, i
    
    updateStrings()
    
    ; main
    SetGadgetText(gadget("installationPath"), settings::getString("", "path"))
    SetGadgetState(gadget("miscVersionCheck"), settings::getInteger("", "compareVersion"))
    
    ; backup
    days = settings::getInteger("backup", "auto_delete_days")
    SetGadgetState(gadget("backupAutoDeleteTime"), 0)
    For i = 0 To CountGadgetItems(gadget("backupAutoDeleteTime"))-1
      If GetGadgetItemData(gadget("backupAutoDeleteTime"), i) = days
        SetGadgetState(gadget("backupAutoDeleteTime"), i)
        Break
      EndIf
    Next
    If GetGadgetItemData(gadget("backupAutoDeleteTime"), GetGadgetState(gadget("backupAutoDeleteTime"))) <> days
      deb("windowSettings:: auto_delete_days value in settings does not fit to available selection. Reset to 0.")
      settings::setInteger("backup", "auto_delete_days", 0)
      SetGadgetState(gadget("backupAutoDeleteTime"), 0)
    EndIf
      
    
    SetGadgetState(gadget("backupAfterInstall"),    settings::getInteger("backup", "after_install"))
    SetGadgetState(gadget("backupBeforeUpdate"),    settings::getInteger("backup", "before_update"))
    SetGadgetState(gadget("backupBeforeUninstall"), settings::getInteger("backup", "before_uninstall"))
    SetGadgetText(gadget("backupFolder"),           mods::backupsGetFolder())
    
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
    locale$ = settings::getString("", "locale")
    Protected NewList locales.locale::info()
    ClearGadgetItems(gadget("languageSelection"))
    If locale::getLocales(locales())
      i = 0
      ForEach locales()
        AddGadgetItem(gadget("languageSelection"), i, "<"+locales()\locale$+"> "+locales()\name$, ImageID(locales()\flag))
        If locale$ = locales()\locale$
          SetGadgetState(gadget("languageSelection"), i)
        EndIf
        i + 1
      Next
    EndIf
    
    
    ; repositories
    updateRepositoryList()
    SetGadgetState(gadget("repositoryUseCache"), settings::getInteger("repository", "use_cache"))
    
    updateGadgets()
    
    ; show window
    RefreshDialog(_dialog)
    PostEvent(#PB_Event_RestoreWindow, window, window)
    DisableWindow(_parentW, #True)
    SetActiveWindow(window)
  EndProcedure
  
  Procedure close()
    FreeDialog(_dialog)
  EndProcedure
  
  Procedure showTab(tab)
    SetGadgetState(gadget("panelSettings"), tab)
  EndProcedure
  
EndModule
