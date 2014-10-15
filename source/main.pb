EnableExplicit

XIncludeFile "WindowMain.pbf"
XIncludeFile "WindowSettings.pbf"
XIncludeFile "WindowModProgress.pbf"
XIncludeFile "registry.pbi"
XIncludeFile "unrar_module.pbi"

Structure mod
  name$
  file$
  author$
  version$
  readme$
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

CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  #DS$ = "\"
CompilerElse
  #DS$ = "/"
CompilerEndIf

Global TimerSettingsGadgets = 100, TimerMainGadgets = 101, TimerFinishUnInstall = 102
Global Event
Global TF$
Global ModProgressAnswer = #AnswerNone, InstallInProgress

Declare FreeModList()
Declare LoadModList()
Declare RemoveModFromList(*modinfo.mod)

Procedure.s Path(path$) ; OS specific path separator
  path$ = RTrim(RTrim(path$, "\"), "/")
  path$ + #DS$
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ReplaceString(path$, "/", "\")
  CompilerElse
    ReplaceString(path$, "\", "/")
  CompilerEndIf
  ProcedureReturn path$  
EndProcedure

Procedure CreateDirectoryAll(dir$)
  Protected result, dir_sub$, dir_total$, count
  
  dir$ = Path(dir$)
  
  count = 1
  dir_sub$ = StringField(dir$, count, #DS$)
  dir_total$ = dir_sub$ + #DS$
  
  While dir_sub$ <> ""
    result = CreateDirectory(dir_total$)
    
    count + 1
    dir_sub$ = StringField(dir$, count, #DS$)
    dir_total$ + dir_sub$ + #DS$
  Wend
  ProcedureReturn result
EndProcedure

Procedure exit(dummy)
  HideWindow(WindowMain, #True)
  
  FreeModList()
  
  OpenPreferences("TFMM.ini")
  If ReadPreferenceInteger("windowlocation", #False)
    PreferenceGroup("window")
    WritePreferenceInteger("x", WindowX(WindowMain))
    WritePreferenceInteger("y", WindowY(WindowMain))
    WritePreferenceInteger("width", WindowWidth(WindowMain))
    WritePreferenceInteger("height", WindowHeight(WindowMain))
  EndIf
  ClosePreferences()
  
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
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    Dir$ = GetHomeDirectory() + "/.local/share/Steam/SteamApps/common/Train Fever/"
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
      Dir$ = Path(Dir$)
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
        SetGadgetText(GadgetRights, "Train Fever cannot be found at this path. Administrative privileges may be required.")
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
  
  OpenPreferences("TFMM.ini")
  SetGadgetText(GadgetPath, ReadPreferenceString("path", TF$))
  SetGadgetState(GadgetSettingsWindowLocation, ReadPreferenceInteger("windowlocation", 0))
  ClosePreferences()
  
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
  
  Dir$ = Path(Dir$)
  
  TF$ = Dir$ ; save in global variable
  OpenPreferences("TFMM.ini")
  WritePreferenceString("path", TF$)
  WritePreferenceInteger("windowlocation", GetGadgetState(GadgetSettingsWindowLocation))
  If Not GetGadgetState(GadgetSettingsWindowLocation)
    RemovePreferenceGroup("window")
  EndIf
  ClosePreferences()
  FreeModList()
  LoadModList()
    
  StatusBarText(0, 0, TF$)
    
  GadgetCloseSettings(event)
EndProcedure

Procedure CheckModFileZip(File$)
  Debug "CheckModFileZip("+File$+")"
  If OpenPack(0, File$)
    If ExaminePack(0)
      While NextPackEntry(0)
        If FindString(PackEntryName(0), "res/")
          ClosePack(0)
          ProcedureReturn #True ; found a "res" subfolder, assume this mod is valid
        EndIf
      Wend
    EndIf
    ClosePack(0)
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure CheckModFileRar(File$)
  Debug "CheckModFileRar("+File$+")"
  Protected raropen.unrar::RAROpenArchiveDataEx
  Protected rarheader.unrar::RARHeaderDataEx
  Protected hRAR
  Protected Entry$
  
  CompilerIf #PB_Compiler_Unicode
    raropen\ArcNameW = @File$
  CompilerElse
    raropen\ArcName = @File$
  CompilerEndIf
  raropen\OpenMode = unrar::#RAR_OM_LIST ; only list rar files (do not extract)
  
  hRAR = unrar::RAROpenArchive(raropen)
  If hRAR
    While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS ; read header of file in rar
      CompilerIf #PB_Compiler_Unicode
        Entry$ = PeekS(@rarheader\FileNameW)
      CompilerElse
        Entry$ = PeekS(@rarheader\FileName,#PB_Ascii)
      CompilerEndIf
      Debug Entry$
      If FindString(Entry$, "res\")
        unrar::RARCloseArchive(hRAR)
        ProcedureReturn #True ; found a "res" subfolder, assume this mod is valid
      EndIf
      unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; skip to next entry in rar
    Wend
    unrar::RARCloseArchive(hRAR)
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure CheckModFile(File$) ; Check mod for a "res" folder!
  Debug "CheckModFile("+File$+")"
  Protected extension$
  extension$ = LCase(GetExtensionPart(File$))
  If extension$ = "zip"
    ProcedureReturn CheckModFileZip(File$)
  ElseIf extension$ = "rar"
    ProcedureReturn CheckModFileRar(File$)
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure ExtractTFMMiniZip(File$, dir$) ; extracts tfmm.ini to given directory
  Protected zip
  
  zip = OpenPack(#PB_Any, File$, #PB_PackerPlugin_Zip)
  If zip
    If ExaminePack(zip)
      While NextPackEntry(zip)
        If LCase(PackEntryName(zip)) = "tfmm.ini" Or LCase(Right(PackEntryName(zip), 9)) = "/tfmm.ini"
          UncompressPackFile(zip, dir$ + "tfmm.ini")
          Break 
        EndIf
      Wend
    EndIf
    ClosePack(zip)
  EndIf
EndProcedure

Procedure ExtractTFMMiniRar(File$, dir$) ; extracts tfmm.ini to given directory
  Protected raropen.unrar::RAROpenArchiveDataEx
  Protected rarheader.unrar::RARHeaderDataEx
  Protected hRAR
  Protected Entry$
  
  CompilerIf #PB_Compiler_Unicode
    raropen\ArcNameW = @File$
  CompilerElse
    raropen\ArcName = @File$
    CharToOem_(dir$, dir$)
  CompilerEndIf
  raropen\OpenMode = unrar::#RAR_OM_EXTRACT
  
  hRAR = unrar::RAROpenArchive(raropen)
  If hRAR
    While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS
      CompilerIf #PB_Compiler_Unicode
        Entry$ = PeekS(@rarheader\FileNameW)
      CompilerElse
        Entry$ = PeekS(@rarheader\FileName,#PB_Ascii)
      CompilerEndIf
      If FindString(Entry$, "res/")
        unrar::RARCloseArchive(hRAR)
        ProcedureReturn #True ; found a "res" subfolder, assume this mod is valid
      EndIf

      If LCase(Entry$) = "tfmm.ini" Or LCase(Right(Entry$, 9)) = "/tfmm.ini"
        unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #NULL$, dir$ + "tfmm.ini")
        Break
      Else
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$)
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure GetModInfo(File$, *modinfo.mod)
  Protected extension$
  Protected tmpDir$
  extension$ = LCase(GetExtensionPart(File$))
  
  With *modinfo
    \file$ = GetFilePart(File$)
    \name$ = GetFilePart(File$, #PB_FileSystem_NoExtension)
    \author$ = ""
    \version$ = ""
    \size = FileSize(File$)
    \md5$ = MD5FileFingerprint(File$)
    \active = 0
    
    ; read info from TFMM.ini in mod if any
    DeleteFile(tmpDir$ + "tfmm.ini") ; clean old tfmm.ini if exists
    ;- Todo : Check if tfmm.ini is deleted?
    If extension$ = "zip"
      ExtractTFMMiniZip(File$, tmpDir$)
    ElseIf extension$ = "rar"
      ExtractTFMMiniRar(File$, tmpDir$)
    EndIf
    
    OpenPreferences(tmpDir$ + "tfmm.ini")
    \name$ = ReadPreferenceString("name", \name$)
    \author$ = ReadPreferenceString("author", \author$)
    \version$ = ReadPreferenceString("version", \version$)
    ClosePreferences()
    DeleteFile(tmpDir$ + "tfmm.ini")
    
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
    OpenPreferences(Path(TF$ + "TFMM") + "mods.ini")
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
    SetGadgetText(GadgetModText, "Do you want to activate '"+\name$+"'?")
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
    
    zip = OpenPack(#PB_Any, Path(TF$ + "TFMM/mods") + \file$)
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
    
    SetGadgetText(GadgetModText, "Found "+Str(ListSize(files$()))+" files in res/ for activation")
    
    Backup$ = path(TF$ + "TFMM/Backup/")
    CreateDirectoryAll(Backup$)
    
    ; load filetracker list
    OpenPreferences(Path(TF$ + "TFMM") + "filetracker.ini")
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
      Delay(0) ; let the CPU breath
      ; install each individual file
      File$ = Mid(files$(), FindString(files$(), "res/")) ; let all (game folder) paths start with "res/"
      ; adjust path delimiters to OS
      File$ = Path(GetPathPart(File$)) + GetFilePart(File$)
;       CompilerIf #PB_Compiler_OS = #PB_OS_Windows
;         File$ = ReplaceString(File$, "/", "\") ; crappy windows has "\" delimiters
;       CompilerEndIf
      
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
          ; may delete filetracker entry (better leave it there for logging purposes)
          
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
        ; TODO check if overwriting entries ?
        ; TODO -> check earlier, if mod with same name is already installed
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

Procedure AddModToList(File$) ; Read File$ from any location, extract mod into mod-directory, add info, this procedure calls WriteModToList()
  Debug "AddModToList("+File$+")"
  Protected *modinfo.mod, *tmp.mod
  Protected FileTarget$, tmp$
  Protected count, i
  Protected sameName.b, sameHash.b
  
  If Not CheckModFile(File$)
    MessageRequester("Error", "Selected file is not a valid Train Fever modification or not compatible with TFMM")
    ProcedureReturn #False
  EndIf
  
  *modinfo = AllocateStructure(mod)
  If Not GetModInfo(File$, *modinfo)
    ProcedureReturn #False
  EndIf
  
  ; check for existing mods with same name
  count = CountGadgetItems(ListInstalled)
  For i = 0 To count-1
    sameName = #False
    sameHash = #False
    
    *tmp = GetGadgetItemData(ListInstalled, i)
    If LCase(*tmp\name$) = LCase(*modinfo\name$)
      sameName = #True
    EndIf
    If *tmp\md5$ = *modinfo\md5$
      sameHash = #True
    EndIf
    
    If sameHash ; same hash indicates a duplicate - do not care about name!
      If *tmp\active
        MessageRequester("Error", "The modification '"+*tmp\name$+"' is already installed and activated.", #PB_MessageRequester_Ok)
      Else
        If MessageRequester("Error", "The modification '"+*tmp\name$+"' is already installed."+#CRLF$+"Do you want to activate it now?", #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
          ToggleMod(*modinfo)
        EndIf
      EndIf
      FreeStructure(*modinfo)
      ProcedureReturn #True
    EndIf
    
    If sameName And Not sameHash ; a mod with the same name is installed, but it is not identical (maybe a new version?)
      If *tmp\active
        MessageRequester("Error", "There is already a modification '"+*tmp\name$+"' installed and activated. Please deactivate the old modification before installing a new one.", #PB_MessageRequester_Ok)
        FreeStructure(*modinfo)
        ProcedureReturn #False
      Else
        ; mod is installed but not active -> replace old mod
        tmp$ = "A modification named '"+*tmp\name$+"' is already installed but not active."+#CRLF$+
               "Do you want to replace the modification?"+#CRLF$+
               "Current modification:"+#CRLF$+
               #TAB$+"Name: "+*tmp\name$+#CRLF$+
               #TAB$+"Version: "+*tmp\version$+#CRLF$+
               #TAB$+"Author: "+*tmp\author$+#CRLF$+
               #TAB$+"Size: "+Bytes(*tmp\size)+#CRLF$+
               "New modification:"+#CRLF$+
               #TAB$+"Name: "+*modinfo\name$+#CRLF$+
               #TAB$+"Version: "+*modinfo\version$+#CRLF$+
               #TAB$+"Author: "+*modinfo\author$+#CRLF$+
               #TAB$+"Size: "+Bytes(*modinfo\size)
        If MessageRequester("Error", tmp$, #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
          ; user does not want to replace
          FreeStructure(*modinfo)
          ProcedureReturn #False
        EndIf
        ; user wants to replace
        RemoveModFromList(*tmp)
        Break ; leave loop in order to continue installation
      EndIf
    EndIf
  Next
  
  ; when reaching this point, the mod can be installed
  CreateDirectoryAll(TF$ + "TFMM\Mods\")
  
  ; user wants to install this mod! Therefore, find a possible file name!
  i = 0
  FileTarget$ = GetFilePart(File$,  #PB_FileSystem_NoExtension) + "." + GetExtensionPart(File$)
  While FileSize(TF$ + "TFMM\Mods\" + FileTarget$) > 0
    ; try to find a filename which does not exist
    i = i + 1
    FileTarget$ = GetFilePart(File$,  #PB_FileSystem_NoExtension) + "(" + Str(i) + ")." + GetExtensionPart(File$)
  Wend
  
  ; import file to mod folder
  If Not CopyFile(File$, TF$ + "TFMM\Mods\" + FileTarget$)
    ; Copy error
    FreeStructure(*modinfo)
    ProcedureReturn #False 
  EndIf
  
  *modinfo\file$ = FileTarget$
  
  WriteModToList(*modinfo)
  
  With *modinfo
    count = CountGadgetItems(ListInstalled)
    AddGadgetItem(ListInstalled, count, \name$ + Chr(10) + \author$ + Chr(10) + \version$ + Chr(10) + Bytes(\size) + Chr(10) + Str(\active))
    SetGadgetItemData(ListInstalled, count, *modinfo)
    ToggleMod(*modinfo)      
  EndWith
  
EndProcedure

Procedure RemoveModFromList(*modinfo.mod) ;Deletes entry from ini file And deletes file from mod folder
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
  File$ = OpenFileRequester("Select new modification to add", "", "File archives|*.zip;*.rar|All files|*.*", 0)
  
  If FileSize(TF$) <> -2
    ProcedureReturn #False
  EndIf
  
  If File$
    AddModToList(File$)
  EndIf
EndProcedure

Procedure MenuItemUpdate(event)
  RunProgram(#DQUOTE$+"http://goo.gl/utB3xn"+#DQUOTE$) ; Download Page (Train-Fever.net)
EndProcedure

Procedure MenuItemLicense(event) ; open settings window
  MessageRequester("License",
                   "Train Fever Mod Manager"+#CRLF$+
                   "© 2014 Alexander Nähring / Xanos"+#CRLF$+
                   "Distribution: www.train-fever.net"+#CRLF$+
                   #CRLF$+
                   "unrar © Alexander L. Roshal")
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

Procedure GadgetListInstalled(event)
  If event = #PB_EventType_LeftDoubleClick
    GadgetButtonToggle(#PB_EventType_LeftClick)
  EndIf
EndProcedure

Procedure GadgetButtonStartGame(event)
  RunProgram(#DQUOTE$ + "steam://run/304730/" + #DQUOTE$)
EndProcedure

;----------------------------------------

Procedure init()
  UseZipPacker()
  OpenWindowMain()
  OpenWindowSettings()
  OpenWindowModProgress()
  WindowBounds(WindowMain, 640, 300, #PB_Ignore, #PB_Ignore) 
  AddWindowTimer(WindowMain, TimerMainGadgets, 100)
  BindEvent(#PB_Event_SizeWindow, @ResizeGadgetsWindowMain(), WindowMain)
  
  OpenPreferences("TFMM.ini")
  TF$ = ReadPreferenceString("path", "")
  If ReadPreferenceInteger("windowlocation", #False)
    PreferenceGroup("window")
    ResizeWindow(WindowMain,
                 ReadPreferenceInteger("x", #PB_Ignore),
                 ReadPreferenceInteger("y", #PB_Ignore),
                 ReadPreferenceInteger("width", #PB_Ignore),
                 ReadPreferenceInteger("height", #PB_Ignore))
  EndIf
  ClosePreferences()
  
  StatusBarText(0, 0, TF$)
  SetGadgetText(GadgetPath, TF$)
  If TF$ = ""
    ; no path specified upon program start -> open settings
    MenuItemSettings(0)
    GadgetButtonAutodetect(0)
  EndIf
  LoadModList()
  
EndProcedure

init()

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
; CursorPosition = 1017
; FirstLine = 125
; Folding = EigxAAIA-
; EnableUnicode
; EnableXP