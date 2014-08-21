EnableExplicit

XIncludeFile "WindowMain.pbf"
XIncludeFile "WindowSettings.pbf"
XIncludeFile "WindowModProgress.pbf"
XIncludeFile "registry.pbi"

Structure mod
  name$
  file$
  author$
  version$
  size.i
  md5$
  active.i
EndStructure

Enumeration
  #AnswerNone
  #AnswerYes
  #AnswerNo
  #AnswerYesAll
  #AnswerNoAll
  #AnswerOk
EndEnumeration

Global TimerSettingsGadgets = 100, TimerMainGadgets = 101, TimerFinishUnInstall = 102
Global Event
Global TF$
Global ModProgressAnswer = #AnswerNone, InstallInProgress

Declare FreeModList()
Declare LoadModList()

Procedure CreateDirectoryAll(dir.s)
  Protected result, dir_sub.s, dir_total.s, count
  
  count = 1
  dir_sub = StringField(dir, count, "\")
  dir_total = dir_sub + "\"
  
  While dir_sub <> ""
    result = CreateDirectory(dir_total)
    
    count + 1
    dir_sub = StringField(dir, count, "\")
    dir_total + dir_sub + "\"
  Wend
  ProcedureReturn result
EndProcedure

Procedure exit(dummy)
  HideWindow(WindowMain, #True)
  
  End
EndProcedure

Procedure GadgetButtonBrowse(event)
  Protected Dir$
  Dir$ = GetGadgetText(GadgetPath)
  Dir$ = PathRequester("Train Fever installation path", Dir$)
  If Dir$
    SetGadgetText(GadgetPath, Dir$)
  EndIf
EndProcedure

Procedure GadgetButtonAutodetect(event)
  Protected Dir$
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows 
    Dir$ = Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    If Not FileSize(Dir$) = -2 ; -2 = directory
      Dir$ = Registry_GetString(#HKEY_LOCAL_MACHINE,"SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304730", "InstallLocation")
    EndIf
  CompilerEndIf
 
  If Dir$
    SetGadgetText(GadgetPath, Dir$)  
  EndIf
  
EndProcedure

Procedure GadgetButtonOpenPath(event)
  RunProgram(#DQUOTE$+GetGadgetText(GadgetPath)+#DQUOTE$)
EndProcedure

Procedure checkTFPath(Dir$)
  If Dir$
    If FileSize(Dir$) = -2
      ; is directory
      If (Not Right(Dir$, 1) = "\") And (Not Right(Dir$, 1) = "/")
        Dir$ = Dir$ + "\"
      EndIf
      ; path ends with a slash
      If FileSize(Dir$ + "TrainFever.exe") > 1
        ; TrainFever.exe is located in this path!
        ; seems to be valid
        
        ; check ifable to write to path
        If CreateFile(0, Dir$ + "TFMM.tmp")
          CloseFile(0)
          DeleteFile(Dir$ + "TFMM.tmp")
          ProcedureReturn #True
        EndIf
        ProcedureReturn -1
      EndIf
    EndIf
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure TimerSettingsGadgets()
  ; check gadgets etc
  Protected ret
  Static LastDir$
  
  If LastDir$ <> GetGadgetText(GadgetPath)
    LastDir$ = GetGadgetText(GadgetPath)
    
    If FileSize(LastDir$) = -2
      DisableGadget(GadgetOpenPath, #False)
    Else
      DisableGadget(GadgetOpenPath, #True)
    EndIf
    
    ret = checkTFPath(LastDir$)
    If ret = #True
      SetGadgetText(GadgetRights, "Path is correct and TFMM is able to write to the game directory. Let's get started modding!")
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, RGB(0,100,0))
      DisableGadget(GadgetSaveSettings, #False)
    Else
      SetGadgetColor(GadgetRights, #PB_Gadget_FrontColor, #Red)
      DisableGadget(GadgetSaveSettings, #True)
      If ret = -1
        SetGadgetText(GadgetRights, "TFMM is not able to write to the game directory. Administrative privileges may be required.")
      Else
        SetGadgetText(GadgetRights, "Train Fever cannot be found at this path. Please specify the install path of Train Fever.")
      EndIf
    EndIf
  EndIf
EndProcedure

Procedure TimerMainGadgets()
  Static LastDir$ = ""
  Static LastSelected
  Protected SelectedMod
  Protected *modinfo.mod
  
  If LastDir$ <> TF$
    LastDir$ = TF$
    If checkTFPath(TF$) <> #True 
      MenuItemSettings(0)
    EndIf
  EndIf
  
  
  SelectedMod =  GetGadgetState(ListInstalled)
  If LastSelected <> SelectedMod
    LastSelected = SelectedMod
    If SelectedMod = -1
      SetGadgetText(GadgetActivate, "Activate Mod")
      DisableGadget(GadgetActivate, #True)
      DisableGadget(GadgetUninstall, #True)
    Else
      DisableGadget(GadgetActivate, #False)
      DisableGadget(GadgetUninstall, #False)
      *modinfo = GetGadgetItemData(ListInstalled, SelectedMod)
      If *modinfo\active
        SetGadgetText(GadgetActivate, "Deactivate Mod")
        SetGadgetState(GadgetActivate, 1)
      Else
        SetGadgetText(GadgetActivate, "Activate Mod")
        SetGadgetState(GadgetActivate, 0)
      EndIf
    EndIf
  EndIf
  
EndProcedure

Procedure MenuItemSettings(event) ; open settings window
  AddWindowTimer(WindowSettings, TimerSettingsGadgets, 100)
  HideWindow(WindowSettings, #False, #PB_Window_WindowCentered)
  DisableWindow(WindowMain, #True)
  SetActiveWindow(WindowSettings)
EndProcedure

Procedure GadgetCloseSettings(event) ; close settings window and apply settings
  RemoveWindowTimer(WindowSettings, TimerSettingsGadgets)
  HideWindow(WindowSettings, #True)
  DisableWindow(WindowMain, #False)
  SetActiveWindow(WindowMain)
  
  If checkTFPath(TF$) <> #True
    exit(0)
  EndIf
  
EndProcedure

Procedure GadgetSaveSettings(event)
  Protected Dir$
  Dir$ = GetGadgetText(GadgetPath)
  
  If (Not Right(Dir$, 1) = "\") And (Not Right(Dir$, 1) = "/")
    Dir$ = Dir$ + "\"
  EndIf
  TF$ = Dir$ ; save in global variable
  OpenPreferences("TFMM.ini")
  WritePreferenceString("path", TF$)
  ClosePreferences()
  FreeModList()
  LoadModList()
    
  StatusBarText(0, 0, TF$)
    
  GadgetCloseSettings(event)
EndProcedure

Procedure CheckModFile(File$)
  If OpenPack(0, File$)
    If ExaminePack(0)
      While NextPackEntry(0)
        If FindString(PackEntryName(0), "res/")
          ProcedureReturn #True
        EndIf
      Wend
    EndIf
    ClosePack(0)
  EndIf
EndProcedure

Procedure OpenMod(Path$)
  If OpenPack(0, Path$)
    If ExaminePack(0)
      While NextPackEntry(0)
        Debug "Name: " + PackEntryName(0) + ", Size: " + PackEntrySize(0)
      Wend
    EndIf
    ClosePack(0)
  EndIf
EndProcedure

Procedure GetModInfo(File$, *modinfo.mod)
  Protected tmpDir$
  Protected zip
  
  With *modinfo
    \file$ = GetFilePart(File$)
    \name$ = GetFilePart(File$, #PB_FileSystem_NoExtension)
    \author$ = ""
    \version$ = ""
    \size = FileSize(File$)
    \md5$ = MD5FileFingerprint(File$)
    \active = 0
  
    ; read name from TFMM.ini in mod if any
    zip = OpenPack(#PB_Any, File$, #PB_PackerPlugin_Zip)
    If zip
      If ExaminePack(zip)
        While NextPackEntry(zip)
          If LCase(Right(PackEntryName(zip), 9)) = "/tfmm.ini"
            tmpDir$ = GetTemporaryDirectory()
            UncompressPackFile(zip, tmpDir$ + "tfmm.ini")
            OpenPreferences(tmpDir$ + "tfmm.ini")
            \name$ = ReadPreferenceString("name", \name$)
            \author$ = ReadPreferenceString("author", \author$)
            \version$ = ReadPreferenceString("version", \version$)
            ClosePreferences()
            DeleteFile(tmpDir$ + "tfmm.ini")
            Break
          EndIf
        Wend
      EndIf
      ClosePack(zip)
    EndIf
  EndWith
  
  ProcedureReturn #True
EndProcedure

Procedure.s Bytes(bytes.d)
  If bytes > 1024*1024*1024
    ProcedureReturn StrD(bytes/1024/1024/1024,2) + " GiB"
  ElseIf bytes > 1024*1024
    ProcedureReturn StrD(bytes/1024/1024,2) + " MiB"
  ElseIf bytes > 1024
    ProcedureReturn StrD(bytes/1024,0) + " KiB"
  ElseIf bytes > 0
    ProcedureReturn StrD(bytes,0) + " Byte"
  Else
    ProcedureReturn ""
  EndIf
EndProcedure

Procedure FinishUnIstall()
  RemoveWindowTimer(WindowModProgress, TimerFinishUnInstall)
  
  FreeModList()
  LoadModList()
  
  DisableWindow(WindowMain, #False)
  HideWindow(WindowModProgress, #True)
  SetActiveWindow(WindowMain)
  InstallInProgress = #False 
EndProcedure

Procedure WriteModToList(*modinfo.mod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  With *modinfo
    OpenPreferences(TF$ + "TFMM\mods.ini")
    PreferenceGroup(\name$)
    WritePreferenceString("file", \file$)
    WritePreferenceString("author", \author$)
    WritePreferenceString("version", \version$)
    WritePreferenceInteger("size", \size)
    WritePreferenceString("md5", \md5$)
    WritePreferenceInteger("active", \active)
    ClosePreferences()
  EndWith
EndProcedure

Procedure ActivateThread(*modinfo.mod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  Protected zip, i
  Protected NewList files$()
  Protected Backup$, File$
  
  With *modinfo
    ModProgressAnswer = #AnswerNone
    SetGadgetText(GadgetModText, "Do you want to install '"+\name$+"'?")
    HideGadget(GadgetModYes, #False)
    HideGadget(GadgetModNo, #False)
    
    While ModProgressAnswer = #AnswerNone
      Delay(10)
    Wend
    
    If ModProgressAnswer = #AnswerNo
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    EndIf
    
    ; start installation
    HideGadget(GadgetModYes, #True)
    HideGadget(GadgetModNo, #True)
    SetGadgetText(GadgetModText, "Reading modification...")
    
    zip = OpenPack(#PB_Any, TF$ + "TFMM\mods\" + \file$)
    If zip
      ClearList(files$())
      If ExaminePack(zip)
        While NextPackEntry(zip)
          SetGadgetText(GadgetModText, "reading"+#CRLF$+PackEntryName(zip))
          If PackEntryType(zip) = #PB_Packer_File
            If FindString(PackEntryName(zip), "res/") ; only add files to list which are located in subfoldres of res/
              AddElement(files$())
              files$() = PackEntryName(zip)
            EndIf
          EndIf
        Wend
        
        SetGadgetText(GadgetModText, "Found "+Str(ListSize(files$()))+" files in res/ to install")
        
        Backup$ = TF$ + "TFMM\Backup\"
        CreateDirectory(Backup$)
        
        SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Maximum, ListSize(files$()))
        SetGadgetState(GadgetModProgress, 0)
        HideGadget(GadgetModProgress, #False)
        i = 0
        ForEach files$()
          ; install each individual file
          File$ = Mid(files$(), FindString(files$(), "res/")) ; let all paths start with "res/"
          CompilerIf #PB_Compiler_OS = #PB_OS_Windows
            File$ = ReplaceString(File$, "/", "\")
          CompilerEndIf
          
          ; first step: backup original file if any
          If FileSize(TF$ + File$) >= 0
            ; file already exists -> backup this file
            ; check if there is already a backup of this file!
            If FileSize(Backup$ + File$) = -1
              ; no backup of this file present!
              ; create new backup
              CreateDirectoryAll(GetPathPart(Backup$ + File$))
              CopyFile(TF$ + File$, Backup$ + File$)
            Else
              ; there is already a backup
              ; which means, that this file was replaced by another mod
              ; TODO display message and ask if overwrite mod file
            EndIf
          EndIf
          
          ; TODO extract file and write to game folder
          ; TODO save newly extracted file to list
          ; TODO save MD5 of newly extracted file to list
          
          ; CreateDirectoryAll(GetPathPart(TF$ + File$))
          ; UncompressPackFile(zip, TF$ + File$, files$())
          
          i = i + 1
        SetGadgetState(GadgetModProgress, i)
        Next 
        HideGadget(GadgetModProgress, #True)
        
        \active = #True
        WriteModToList(*modinfo) ; update mod entry
        
        SetGadgetText(GadgetModText, "'" + \name$ + "' was successfully activated")
        HideGadget(GadgetModProgress, #True)
        HideGadget(GadgetModOk, #False)
        ModProgressAnswer = #AnswerNone
        While ModProgressAnswer = #AnswerNone
          Delay(10)
        Wend
        
        AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
        ProcedureReturn #True 
        
      EndIf
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    Else
      ; error
      ModProgressAnswer = #AnswerNone
      SetGadgetText(GadgetModText, "Error opening modification file!")
      HideGadget(GadgetModOk, #False)
      While ModProgressAnswer = #AnswerNone
        Delay(10)
      Wend
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    EndIf
    
    
    AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
  EndWith
EndProcedure

Procedure DeactivateThread(*modinfo.mod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  ; TODO only reset files from list of installed files which match md5!
  
  *modinfo\active = #False
  WriteModToList(*modinfo) ; update mod entry
  
  
  AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
  ProcedureReturn #False
EndProcedure

Procedure ToggleMod(*modinfo.mod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  If InstallInProgress
    ProcedureReturn #False
  EndIf
  InstallInProgress = #True
  
  ; reset all gadgets
  SetGadgetText(GadgetModText, "loading...")
  HideGadget(GadgetModYes, #True)
  HideGadget(GadgetModNo, #True)
  HideGadget(GadgetModYesAll, #True)
  HideGadget(GadgetModNoAll, #True)
  HideGadget(GadgetModProgress, #True)
  HideGadget(GadgetModOk, #True)
  HideWindow(WindowModProgress, #False)
  DisableWindow(WindowMain, #True)
  SetActiveWindow(WindowModProgress)
  
  If *modinfo\active
    ;- Uninstall
    SetWindowTitle(WindowModProgress, "Deactivate modification")
    CreateThread(@DeactivateThread(), *modinfo)
    ProcedureReturn #True 
  Else
    ;- Install
    SetWindowTitle(WindowModProgress, "Activate modification")
    CreateThread(@ActivateThread(), *modinfo)
    ProcedureReturn #True 
  EndIf
EndProcedure

Procedure FreeModList()
  Protected i, count
  Protected *modinfo.mod
  
  count = CountGadgetItems(ListInstalled)
  For i = 0 To count-1
    *modinfo = GetGadgetItemData(ListInstalled, i)
    FreeStructure(*modinfo) ; this automatically also frees all strings in the strucute element
  Next
  ClearGadgetItems(ListInstalled)  
EndProcedure

Procedure LoadModList()
  If TF$ = ""
    ProcedureReturn #False
  EndIf
  
  Protected *modinfo.mod 
  Protected count
  
  OpenPreferences(TF$ + "TFMM\mods.ini")
  If ExaminePreferenceGroups()
    While NextPreferenceGroup()
      *modinfo = AllocateStructure(mod)
      With *modinfo
        \name$ = PreferenceGroupName()
        \file$ = ReadPreferenceString("file", "")
        \author$ = ReadPreferenceString("author", "")
        \version$ = ReadPreferenceString("version", "")
        \size = ReadPreferenceInteger("size", 0)
        \md5$ = ReadPreferenceString("md5", "")
        \active = ReadPreferenceInteger("active", 0)
        
        count = CountGadgetItems(ListInstalled)
        AddGadgetItem(ListInstalled, count, \name$ + Chr(10) + \author$ + Chr(10) + \version$ + Chr(10) + Bytes(\size) + Chr(10) + Str(\active))
        SetGadgetItemData(ListInstalled, count, *modinfo)
      EndWith
    Wend
  EndIf
  
  ClosePreferences()
EndProcedure

Procedure AddModToList(File$)
  Protected *modinfo.mod
  Protected items
  
  *modinfo = AllocateStructure(mod)
  If Not GetModInfo(File$, *modinfo)
    ProcedureReturn #False
  EndIf
  
  ; TODO check if already in list!!!
  WriteModToList(*modinfo)
  
  With *modinfo
    items = CountGadgetItems(ListInstalled)
    AddGadgetItem(ListInstalled, items, \name$ + Chr(10) + \author$ + Chr(10) + \version$ + Chr(10) + Bytes(\size) + Chr(10) + "no")
    SetGadgetItemData(ListInstalled, items, *modinfo)
 
    ToggleMod(*modinfo)
      
  EndWith
EndProcedure

Procedure UNUSED_ListMods()
  Protected Path$ = TF$+"TFMM\Mods\"
  Protected File$
  If ExamineDirectory(0, Path$, "*.zip")
    While NextDirectoryEntry(0)
      If DirectoryEntryType(0) = #PB_DirectoryEntry_File
        File$ = Path$ + DirectoryEntryName(0)
        If CheckModFile(File$)
          Debug DirectoryEntryName(0)
        Else
          DeleteFile(File$)
        EndIf
      EndIf
    Wend
  EndIf
EndProcedure

Procedure GadgetButtonActivate(event)
  Protected SelectedMod
  Protected *modinfo.mod
  
  SelectedMod =  GetGadgetState(ListInstalled)
  If SelectedMod <> -1
    *modinfo = GetGadgetItemData(ListInstalled, SelectedMod)
    ToggleMod(*modinfo)
  EndIf
EndProcedure

Procedure GadgetNewMod(event)
  Protected File$
  File$ = OpenFileRequester("Select new modification to add", "", "File archives|*.zip|All files|*.*", 0)
  
  If FileSize(TF$) <> -2
    ProcedureReturn #False
  EndIf
  
  If File$
    If CheckModFile(File$)
      CreateDirectory(TF$ + "TFMM\")
      CreateDirectory(TF$ + "TFMM\Mods\")
      ; TODO check if file already exists!
      ; handle appropriately
      If CopyFile(File$, TF$ + "TFMM\Mods\" + GetFilePart(File$))
        AddModToList(File$)
      Else
        ProcedureReturn #False 
      EndIf
    EndIf
  EndIf
EndProcedure

Procedure MenuItemUpdate(event)
  RunProgram(#DQUOTE$+"http://www.train-fever.net/"+#DQUOTE$)
EndProcedure

Procedure GadgetModYes(event)
  ModProgressAnswer = #AnswerYes
EndProcedure

Procedure GadgetModNo(event)
  ModProgressAnswer = #AnswerNo
EndProcedure

Procedure GadgetModYesAll(event)
  ModProgressAnswer = #AnswerYesAll
EndProcedure

Procedure GadgetModNoAll(event)
  ModProgressAnswer = #AnswerNoAll
EndProcedure

Procedure GadgetModOk(event)
  ModProgressAnswer = #AnswerOk
EndProcedure

;----------------------------------------


UseZipPacker()
OpenWindowMain()
OpenWindowSettings()
OpenWindowModProgress()
WindowBounds(WindowMain, 640, 300, #PB_Ignore, #PB_Ignore) 
AddWindowTimer(WindowMain, TimerMainGadgets, 100)
BindEvent(#PB_Event_SizeWindow, @ResizeGadgetsWindowMain(), WindowMain)


OpenPreferences("TFMM.ini")
TF$ = ReadPreferenceString("path", "")
ClosePreferences()
StatusBarText(0, 0, TF$)
SetGadgetText(GadgetPath, TF$)
If TF$ = ""
  ; no path specified upon program start -> open settings
  MenuItemSettings(0)
  GadgetButtonAutodetect(0)
EndIf
LoadModList()

Repeat
  Event = WaitWindowEvent(100)
  If Event = #PB_Event_Timer
    Select EventTimer()
      Case TimerSettingsGadgets
        TimerSettingsGadgets()
      Case TimerMainGadgets
        TimerMainGadgets()
      Case TimerFinishUnInstall
        FinishUnIstall()
    EndSelect
  EndIf
  
  Select EventWindow()
    Case WindowMain
      If Not WindowMain_Events(Event)
        exit(0)
      EndIf
    Case WindowSettings
      If Not WindowSettings_Events(Event)
        GadgetCloseSettings(0)
      EndIf
    Case WindowModProgress
      If Not WindowModProgress_Events(Event)
        ; progress window closed -> no action, just wait for progress to finish
      EndIf
  EndSelect
ForEver
End
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 401
; FirstLine = 117
; Folding = QAAPFw
; EnableUnicode
; EnableXP