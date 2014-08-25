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
      SetGadgetText(GadgetToggle, "Activate Mod")
      SetGadgetState(GadgetToggle, 0)
      DisableGadget(GadgetToggle, #True)
      DisableGadget(GadgetUninstall, #True)
    Else
      DisableGadget(GadgetToggle, #False)
      *modinfo = GetGadgetItemData(ListInstalled, SelectedMod)
      If *modinfo\active
        SetGadgetText(GadgetToggle, "Deactivate Mod")
        SetGadgetState(GadgetToggle, 1)
        DisableGadget(GadgetUninstall, #True)
      Else
        SetGadgetText(GadgetToggle, "Activate Mod")
        SetGadgetState(GadgetToggle, 0)
        DisableGadget(GadgetUninstall, #False)
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
          If LCase(PackEntryName(zip)) = "tfmm.ini" Or LCase(Right(PackEntryName(zip), 9)) = "/tfmm.ini" 
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

Procedure WriteModToList(*modinfo.mod) ; write *modinfo to mod list ini file
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
  
  Protected zip, i, CopyFile, isModded
  Protected NewList Files$()
  Protected Backup$, File$
  Protected NewList FileTracker$()
  
  With *modinfo
    ModProgressAnswer = #AnswerNone
    SetGadgetText(GadgetModText, "Do you want to install '"+\name$+"'?")
    HideGadget(GadgetModYes, #False)
    HideGadget(GadgetModNo, #False)
    While ModProgressAnswer = #AnswerNone
      Delay(10)
    Wend
    HideGadget(GadgetModYes, #True)
    HideGadget(GadgetModNo, #True)
    
    If ModProgressAnswer = #AnswerNo
      ; task clean up procedure
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    EndIf
    
    ; start installation
    SetGadgetText(GadgetModText, "Reading modification...")
    
    zip = OpenPack(#PB_Any, TF$ + "TFMM\mods\" + \file$)
    If Not zip
      ; error opening zip file (not a zip file?)
      ModProgressAnswer = #AnswerNone
      SetGadgetText(GadgetModText, "Error opening modification file!")
      HideGadget(GadgetModOk, #False)
      While ModProgressAnswer = #AnswerNone
        Delay(10)
      Wend
      ; task clean up procedure
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    EndIf
    
    ClearList(files$())
    If Not ExaminePack(zip)
      ; task clean up procedure
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    EndIf
    
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
    CreateDirectoryAll(Backup$)
    
    ; load filetracker list
    OpenPreferences(TF$ + "TFMM\filetracker.ini")
    ExaminePreferenceGroups()
    While NextPreferenceGroup()
      PreferenceGroup(PreferenceGroupName())
      ExaminePreferenceKeys()
      While NextPreferenceKey()
        AddElement(FileTracker$())
        FileTracker$() = LCase(PreferenceKeyName())
      Wend
    Wend
    ClosePreferences()
    
    SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Minimum, 0)
    SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Maximum, ListSize(files$()))
    SetGadgetState(GadgetModProgress, 0)
    HideGadget(GadgetModProgress, #False)
    i = 0
    ModProgressAnswer = #AnswerNone
    ForEach files$()
      Delay(1) ; let the CPU breath
      ; install each individual file
      File$ = Mid(files$(), FindString(files$(), "res/")) ; let all (game folder) paths start with "res/"
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        File$ = ReplaceString(File$, "/", "\") ; crappy windows has "\" delimiters
      CompilerEndIf
      
      SetGadgetText(GadgetModText, "Processing file '" + GetFilePart(File$) + "'...")
      
      ; normal case: copy the modificated file to game directoy
      CopyFile = #True
      isModded = #False
      
      ; check filetracker for any other mods that may have modified this file before
      ForEach FileTracker$()
        If FileTracker$() = LCase(File$)
          ; file found in list of already installed files
          CopyFile = #False
          isModded = #True
          
          ; ask user if file should be overwritten
          If ModProgressAnswer = #AnswerNone
            ; only ask again if user has not selected "yes/no to all" before
            SetGadgetText(GadgetModText, "'" + GetFilePart(File$) + "' has already been modified by another mod." +#CRLF$+ "Do you want To overwrite this file?")
            HideGadget(GadgetModYes, #False)
            HideGadget(GadgetModNo, #False)
            HideGadget(GadgetModYesAll, #False)
            HideGadget(GadgetModNoAll, #False)
            While ModProgressAnswer = #AnswerNone
              Delay(10)
            Wend
            SetGadgetText(GadgetModText, "Processing file '" + GetFilePart(File$) + "'...")
            HideGadget(GadgetModYes, #True)
            HideGadget(GadgetModNo, #True)
            HideGadget(GadgetModYesAll, #True)
            HideGadget(GadgetModNoAll, #True)
          EndIf
          
          Select ModProgressAnswer
            Case #AnswerNo
              CopyFile = #False
              ModProgressAnswer = #AnswerNone
            Case #AnswerYes
              CopyFile = #True
              ModProgressAnswer = #AnswerNone
            Case #AnswerYesAll
              CopyFile = #True
              ; do not reset answer!
            Case #AnswerNoAll
              CopyFile = #False
              ; do not reset answer
          EndSelect
          
          ; filetracker will list the file as modified by multiple mods!
          ; TODO may delete filetracker entry (better leave it there for logging purposes)
          
          Break ; foreach loop can be broke after one entry is found
        EndIf
      Next
      
      If CopyFile 
        ; backup original file if any
        ; only backup vanilla files, DO NOT BACKUP MODDED FILES!
        If Not isModded
          If FileSize(TF$ + File$) >= 0
            ; file already exists in Game Folder -> backup this file
            If FileSize(Backup$ + File$) = -1
              ; no backup of this file present! -> create new backup
              CreateDirectoryAll(GetPathPart(Backup$ + File$))
              CopyFile(TF$ + File$, Backup$ + File$)
            EndIf
          EndIf
        EndIf
        
        ; make sure that the target directory exists (in case of newly added files / direcotries)
        CreateDirectoryAll(GetPathPart(TF$ + File$))
        ; uncompress the file from the mod zip to the game directory
        UncompressPackFile(zip, TF$ + File$, files$())
        
        OpenPreferences(TF$ + "TFMM\filetracker.ini")
        PreferenceGroup(\name$)
        ; TODO check if overwriting entries!!!
        ; write md5 of _NEW_ file in order to keep track of all files that have been changed by this mod
        WritePreferenceString(File$, MD5FileFingerprint(TF$ + File$))
        ClosePreferences()
      EndIf
      
      i = i + 1
      SetGadgetState(GadgetModProgress, i)
    Next 
    
    HideGadget(GadgetModProgress, #True)
    
    ; activate mod in mod list
    \active = #True
    WriteModToList(*modinfo) ; update mod entry
    
    HideGadget(GadgetModProgress, #True)
    SetGadgetText(GadgetModText, "'" + \name$ + "' was successfully activated")
    HideGadget(GadgetModOk, #False)
    ModProgressAnswer = #AnswerNone
    While ModProgressAnswer = #AnswerNone
      Delay(10)
    Wend
    
    ; task clean up procedure
    AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
    ProcedureReturn #True 
  EndWith
EndProcedure

Procedure DeactivateThread(*modinfo.mod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  Protected File$, md5$, Backup$
  Protected NewList Files$()
  Protected count, countAll, i
  
  ; read list of files from ini file
  With *modinfo
    
    OpenPreferences(TF$ + "TFMM\filetracker.ini")
    PreferenceGroup(\name$)
    ; read md5 of installed file in order to keep track of all files that have been changed by this mod
    ExaminePreferenceKeys()
    While NextPreferenceKey()
      countAll = countAll + 1
      File$ = PreferenceKeyName()
      md5$ = ReadPreferenceString(File$, "")
      If File$ And md5$
        If FileSize(TF$ + File$) >= 0
          If MD5FileFingerprint(TF$ + File$) = md5$
            count = count + 1
            AddElement(Files$())
            Files$() = File$
          EndIf
        EndIf
      EndIf
    Wend
    ClosePreferences()
    
    If countAll <= 0
      Debug "no files altered?"
    EndIf
    
    If count = 0 And countAll > 0
      SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files. However, all of these files have been overwritten or altered by other modifications. This modification currently has no effect to the game and can savely be deactiveted. Do you want to deactivate this modification?")
    ElseIf count > 0 And count < countAll
      SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present in their original state and can be restored. All other files may have been altered by additional mods and cannot be restored savely. Do you want to deactivate this modification?")
    ElseIf count > 0 And count = countAll
      SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(count) + " files. All files can savely be restored. Do you want to restore the original files and deactivate this modification?")
    Else
      SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present in their original state. Do you want to deactivate this mod?")
    EndIf
    
    HideGadget(GadgetModNo, #False)
    HideGadget(GadgetModYes, #False)
    ModProgressAnswer = #AnswerNone
    While ModProgressAnswer = #AnswerNone
      Delay(10)
    Wend
    HideGadget(GadgetModNo, #True)
    HideGadget(GadgetModYes, #True)
    
    If ModProgressAnswer = #AnswerNo
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    EndIf
    
    Backup$ = TF$ + "TFMM\Backup\"
    CreateDirectoryAll(Backup$)
    i = 0
    SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Minimum, 0)
    SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Maximum, ListSize(Files$()))
    HideGadget(GadgetModProgress, #False)
    ForEach Files$()
      File$ = Files$()
      SetGadgetText(GadgetModText, "Processing file '" + GetFilePart(File$) + "'...")
      
      ; delete file
      DeleteFile(TF$ + File$,  #PB_FileSystem_Force)
      
      ; restore backup if any
      If FileSize(Backup$ + File$) >= 0
        CopyFile(Backup$ + File$, TF$ + File$)
        ; do not delete backup, just leave it be
      EndIf
      
      i = i + 1
      SetGadgetState(GadgetModProgress, i)
    Next
    HideGadget(GadgetModProgress, #True)
    
    SetGadgetText(GadgetModText, "Cleanup...")
    
    ; update filetracker. All files that are currently altered by this mod have been removed (restored) -> delete all entries from filetracker
    OpenPreferences(TF$ + "TFMM\filetracker.ini")
    RemovePreferenceGroup(\name$)
    ClosePreferences()
    
    \active = #False
    WriteModToList(*modinfo) ; update mod entry
    
    SetGadgetText(GadgetModText, "'" + \name$ + "' was successfully deactivated")
    HideGadget(GadgetModOk, #False)
    ModProgressAnswer = #AnswerNone
    While ModProgressAnswer = #AnswerNone
      Delay(10)
    Wend
    
  EndWith
  
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

Procedure RemoveModFromList(*modinfo.mod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  With *modinfo
    OpenPreferences(TF$ + "TFMM\mods.ini")
    RemovePreferenceGroup(\name$)
    ClosePreferences()
    
    DeleteFile(TF$ + "TFMM\Mods\" + *modinfo\file$, #PB_FileSystem_Force)
    
    FreeModList()
    LoadModList()
    
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

Procedure GadgetButtonToggle(event)
  Protected SelectedMod
  Protected *modinfo.mod
  
  SelectedMod =  GetGadgetState(ListInstalled)
  If SelectedMod <> -1
    *modinfo = GetGadgetItemData(ListInstalled, SelectedMod)
    ToggleMod(*modinfo)
  EndIf
EndProcedure

Procedure GadgetButtonUninstall(event)
  Protected SelectedMod
  Protected *modinfo.mod
  
  SelectedMod =  GetGadgetState(ListInstalled)
  If SelectedMod <> -1
    *modinfo = GetGadgetItemData(ListInstalled, SelectedMod)
    If *modinfo\active
      ProcedureReturn #False
    EndIf
    ; if selected mod is not active, it is save to delete the zip file and remove the mod from the mod list
    RemoveModFromList(*modinfo)
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
; CursorPosition = 261
; FirstLine = 43
; Folding = QAkCbA-
; EnableUnicode
; EnableXP