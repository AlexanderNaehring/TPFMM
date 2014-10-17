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
  Map dependencies$()
;   List conflicts$()
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
Declare checkUpdate(auto.i)

Procedure.s Path(path$, delimiter$ = "")
  path$ + "/"                             ; add a / delimiter to the end
  path$ = ReplaceString(path$, "\", "/")  ; replace all \ with /
  While FindString(path$, "//")           ; strip multiple /
    path$ = ReplaceString(path$, "//", "/")
  Wend
  If delimiter$ = ""
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      delimiter$ = "\"
    CompilerElse
      delimiter$ = "/"
    CompilerEndIf
  EndIf
  If delimiter$ <> "/"
    path$ = ReplaceString(path$, "/", delimiter$)
  EndIf
  ProcedureReturn path$  
EndProcedure

Procedure CreateDirectoryAll(dir$, delimiter$ = "")
  Protected result, dir_sub$, dir_total$, count
  
  dir$ = Path(dir$, delimiter$)
  
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
      Dir$ = Path(Dir$)
      If FileSize(Dir$ + "TrainFever.exe") > 1
        ; TrainFever.exe is located in this path!
        ; seems to be valid
        
        ; check if able to write to path
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
      SetGadgetText(GadgetRights, "Path is correct and TFMM is able to write to the game directory. Let's mod!")
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
  SetGadgetState(GadgetSettingsAutomaticUpdate, ReadPreferenceInteger("update", 1))
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
  
  TF$ = Dir$ ; store in global variable
  OpenPreferences("TFMM.ini")
  WritePreferenceString("path", TF$)
  WritePreferenceInteger("windowlocation", GetGadgetState(GadgetSettingsWindowLocation))
  If Not GetGadgetState(GadgetSettingsWindowLocation)
    RemovePreferenceGroup("window")
  EndIf
  WritePreferenceInteger("update", GetGadgetState(GadgetSettingsAutomaticUpdate))
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
  Protected rarheader.unrar::RARHeaderDataEx
  Protected hRAR
  Protected Entry$
  
  hRAR = unrar::OpenRar(File$, unrar::#RAR_OM_LIST) ; only list rar files (do not extract)
  If hRAR
    While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS ; read header of file in rar
      CompilerIf #PB_Compiler_Unicode
        Entry$ = PeekS(@rarheader\FileNameW)
      CompilerElse
        Entry$ = PeekS(@rarheader\FileName,#PB_Ascii)
      CompilerEndIf
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
  Protected rarheader.unrar::RARHeaderDataEx
  Protected hRAR
  Protected Entry$
  
  hRAR = unrar::OpenRar(File$, unrar::#RAR_OM_EXTRACT)
  If hRAR
    While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS
      CompilerIf #PB_Compiler_Unicode
        Entry$ = PeekS(@rarheader\FileNameW)
      CompilerElse
        Entry$ = PeekS(@rarheader\FileName,#PB_Ascii)
      CompilerEndIf

      If LCase(Entry$) = "tfmm.ini" Or LCase(Right(Entry$, 9)) = "\tfmm.ini"
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
  Protected tmpDir$, extension$
  extension$ = LCase(GetExtensionPart(File$))
  tmpDir$ = GetTemporaryDirectory()
  
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
    ; Read required TFMM version
    If ReadPreferenceInteger("tfmm", #PB_Editor_CompileCount) > #PB_Editor_CompileCount
      MessageRequester("Newer version of TFMM required", "Please update TFMM in order to have full functionality!" + #CRLF$ + "Select 'File' -> 'Update' to check for newer versions.")
    EndIf
    \name$ = ReadPreferenceString("name", \name$)
    \author$ = ReadPreferenceString("author", \author$)
    \version$ = ReadPreferenceString("version", \version$)
    ; read dependencies from tfmm.ini
    If PreferenceGroup("dependencies")
      Debug "dependencies found:"
      If ExaminePreferenceKeys()
        While NextPreferenceKey()
          Debug PreferenceKeyName() + " = " + PreferenceKeyValue()
          \dependencies$(PreferenceKeyName()) = PreferenceKeyValue()
        Wend
      EndIf 
    Else
      Debug "No dependencies"
      ClearMap(\dependencies$())
    EndIf
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
    
    ; write dependencies
    If MapSize(\dependencies$()) > 0
      OpenPreferences(Path(TF$ + "TFMM") + "mod-dependencies.ini")
      RemovePreferenceGroup(\name$)
      PreferenceGroup(\name$)
      ForEach \dependencies$()
        WritePreferenceString(MapKey(\dependencies$()), \dependencies$())
      Next
      ClosePreferences()
    EndIf
    
    
    
  EndWith
EndProcedure

Procedure ExtractModZip(File$, Path$)
  Protected zip, error
  
  zip = OpenPack(#PB_Any, File$)
  If Not zip
    ProcedureReturn #False 
  EndIf
  
  If Not ExaminePack(zip)
    ProcedureReturn #False
  EndIf
  
  Path$ = Path(Path$)
  
  While NextPackEntry(zip)
    If PackEntryType(zip) = #PB_Packer_File
      If FindString(PackEntryName(zip), "res/") ; only extract files to list which are located in subfoldres of res/
        File$ = PackEntryName(zip)
        File$ = Mid(File$, FindString(File$, "res/")) ; let all paths start with "res/" (if res is located in a subfolder!)
        ; adjust path delimiters to OS
        File$ = Path(GetPathPart(File$)) + GetFilePart(File$)
        CreateDirectoryAll(GetPathPart(Path$ + File$))
        If UncompressPackFile(zip, Path$ + File$, PackEntryName(zip)) = 0
          Debug "ERROR: uncrompressing zip: '"+PackEntryName(zip)+"' to '"+Path$ + File$+"' failed!"
        EndIf
      EndIf
    EndIf
  Wend
  
  ClosePack(zip)
  
  ProcedureReturn #True
EndProcedure

Procedure ExtractModRar(File$, Path$)
  Protected rarheader.unrar::RARHeaderDataEx
  Protected hRAR
  Protected Entry$
  
  hRAR = unrar::OpenRar(File$, unrar::#RAR_OM_EXTRACT)
  If Not hRAR
    ProcedureReturn #False
  EndIf
  
  While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS
    CompilerIf #PB_Compiler_Unicode
      Entry$ = PeekS(@rarheader\FileNameW)
    CompilerElse
      Entry$ = PeekS(@rarheader\FileName,#PB_Ascii)
    CompilerEndIf
    
    If FindString(Entry$, "res\") ; only extract files to list which are located in subfoldres of res
      Entry$ = Entry$
      Entry$ = Mid(Entry$, FindString(Entry$, "res\")) ; let all paths start with "res\" (if res is located in a subfolder!)
      Entry$ = Path(GetPathPart(Entry$)) + GetFilePart(Entry$)

      unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #NULL$, Path$ + Entry$) ; uncompress current file to modified tmp path 
    Else
      unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; file not in "res", skip it
    EndIf
    
  Wend
  unrar::RARCloseArchive(hRAR)

  ProcedureReturn #True
EndProcedure

Procedure ActivateThread_ReadFiles(dir$, List files$())
  Protected dir, Entry$
  
  dir$ = Path(dir$)
  
  dir = ExamineDirectory(#PB_Any, dir$, "")
  If Not dir
    ProcedureReturn #False
  EndIf
  
  While NextDirectoryEntry(dir)
    Entry$ = DirectoryEntryName(dir)
    If DirectoryEntryType(dir) = #PB_DirectoryEntry_Directory
      If Entry$ <> "." And Entry$ <> ".."
        ActivateThread_ReadFiles(dir$ + Entry$, files$())
      EndIf
    ElseIf DirectoryEntryType(dir) = #PB_DirectoryEntry_File
      AddElement(files$())
      files$() = dir$ + Entry$
    EndIf
  Wend
  FinishDirectory(dir)
  
  If ListSize(files$()) <= 0
    ProcedureReturn #False
  EndIf
  
  ProcedureReturn #True
EndProcedure

Procedure ActivateThread(*modinfo.mod)
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  Protected dir, i, CopyFile, isModded, error, count, ok
  Protected NewList Files$(), NewList FileTracker$()
  Protected Backup$, File$, Mod$, tmpDir$, extension$, ReqMod$, ReqVer$
  Protected *tmpinfo.mod
  
  With *modinfo
    Mod$ = Path(TF$ + "TFMM/mods") + \file$
    tmpDir$ = Path(TF$ + "TFMM/mod_tmp")
    
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
    
    ;--------------------------------------------------------------------------------------------------
    ;- check dependencies
    
    SetGadgetText(GadgetModText, "Checking dependencies...")
    
    ForEach \dependencies$()
      ReqMod$ = MapKey(\dependencies$())
      ReqVer$ = \dependencies$()
      If ReqVer$ = "0" Or ReqVer$ = "any"
        ReqVer$ = ""
      EndIf
      ok = #False
      
      ; search for required mod in list of installed mods
      count = CountGadgetItems(ListInstalled)
      For i = 0 To count-1
        *tmpinfo.mod = GetGadgetItemData(ListInstalled, i)
        If *tmpinfo\active
          If *tmpinfo\name$ = ReqMod$
            If *tmpinfo\version$ = ReqVer$ Or ReqVer$ = ""
              ok = #True
              Break
            EndIf
          EndIf
        EndIf
      Next
      If Not ok
        ModProgressAnswer = #AnswerNone
        If ReqVer$
          ReqVer$ = " version '" + ReqVer$ + "'"
        EndIf
        SetGadgetText(GadgetModText, "This modification requires '" + ReqMod$ + "'" + ReqVer$ + "." + #CRLF$ + "Please make sure all required mods are activated.")
        HideGadget(GadgetModOk, #False)
        While ModProgressAnswer = #AnswerNone
          Delay(10)
        Wend
        ; task clean up procedure
        AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
        ProcedureReturn #False
      EndIf
    Next
    
    ;--------------------------------------------------------------------------------------------------
    ;- start installation
    
    SetGadgetText(GadgetModText, "Loading modification...")
    
    ; first step: uncompress complete mod into temporary folder!
    extension$ = LCase(GetExtensionPart(Mod$))
    ; clean temporary directory
    DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
    CreateDirectoryAll(tmpDir$)                                                  ; create temp dir
    error = #False 
    If extension$ = "zip"
      If Not ExtractModZip(Mod$, tmpDir$)
        error = #True
      EndIf
    ElseIf extension$ = "rar"
      If Not ExtractModRar(Mod$, tmpDir$)
        error = #True
      EndIf
    Else ; unknown extension
      error = #True
    EndIf
    
    If error
      ; error opening archive
      DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
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
    
    
    ; mod should now be extracted to temporary directory tmpDir$
    
    SetGadgetText(GadgetModText, "Reading modification...")
    ClearList(files$())
    If Not ActivateThread_ReadFiles(tmpDir$, files$()) ; add all files from tmpDir to files$()
      ; error opening tmpDir$
      DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
      ModProgressAnswer = #AnswerNone
      SetGadgetText(GadgetModText, "Error reading extracted files!")
      HideGadget(GadgetModOk, #False)
      While ModProgressAnswer = #AnswerNone
        Delay(10)
      Wend
      ; task clean up procedure
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #False
    EndIf
    
    Debug "found "+Str(ListSize(files$()))+" files for activation"
    SetGadgetText(GadgetModText, Str(ListSize(files$()))+" files found")
    
    Backup$ = Path(TF$ + "TFMM/Backup/")
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
    
    
    ;--------------------------------------------------------------------------------------------------
    ;- process all files
    
    ForEach files$()
      Delay(0) ; let the CPU breath
      File$ = files$()
      File$ = Path(GetPathPart(File$)) + GetFilePart(File$)
      File$ = RemoveString(File$, tmpDir$) ; File$ contains only the relative path ofthe mod
      
      SetGadgetText(GadgetModText, "Processing file '" + GetFilePart(Files$()) + "'...")
      
      ; normal case: copy the modificated file to game directoy
      CopyFile = #True
      isModded = #False
      
      ; check filetracker for any other mods that may have modified this file before
      ForEach FileTracker$()
        ; compare files from filetracker with files from new mod
        If FileTracker$() = Path(LCase(Files$()), "/") ; all filetracker entries are stored with "/" as delimiter
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
          
          ; filetracker will list the file as modified by multiple mods! (multiple entries for single file)
          ; leave multiple entries for logging purpose and information during deactivation
          
          Break ; foreach loop can be broke after one entry is found in filetracker
        EndIf
      Next
      
      ;--------------------------------------------------------------------------------------------------
      ;- copy file
    
      If CopyFile ; install (copy) new modification file
        ; backup original file if any
        ; only backup vanilla files, DO NOT BACKUP MODDED FILES!
        If Not isModded
          If FileSize(TF$ + File$) >= 0
            ; file already exists in Game Folder -> backup this file
            If FileSize(Backup$ + File$) = -1
              ; no backup of this file present! -> create new backup
              CreateDirectoryAll(GetPathPart(Backup$ + File$))
;               CopyFile(TF$ + File$, Backup$ + File$)
              RenameFile(TF$ + File$, Backup$ + File$)
            EndIf
          EndIf
        EndIf
        
        ; make sure that the target directory exists (in case of newly added files / direcotries)
        CreateDirectoryAll(GetPathPart(TF$ + File$))
        ; move the file from the temporary directory to the game directory
        ;UncompressPackFile(zip, TF$ + File$, files$())
        
        DeleteFile(TF$ + File$)
        If Not RenameFile(Files$(), TF$ + File$)
          Debug "ERROR: failed to move file: RenameFile(" + Files$() + ", " + TF$ + File$ + ")"
        EndIf
        
        
        OpenPreferences(TF$ + "TFMM\filetracker.ini")
        PreferenceGroup(\name$)
        ; TODO check if overwriting entries ?
        ; write md5 of _NEW_ file in order to keep track of all files that have been changed by this mod
        WritePreferenceString(File$, MD5FileFingerprint(TF$ + File$))
        ClosePreferences()
      EndIf
      
      i = i + 1
      SetGadgetState(GadgetModProgress, i)
    Next 
    
    ;--------------------------------------------------------------------------------------------------
    ;- install finished
    
    HideGadget(GadgetModProgress, #True)
    If Not DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
      Debug "ERROR: failed to remove tmpDir$ ("+tmpDir$+")"
    EndIf
    
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
  Protected *tmpinfo.mod
  
  ; check dependencies
  count = CountGadgetItems(ListInstalled)
  For i = 0 To count-1
    With *tmpinfo
      *tmpinfo = GetGadgetItemData(ListInstalled, i)
      If \active
        ForEach \dependencies$()
          If MapKey(\dependencies$()) = *modinfo\name$
            ; this mod is required by another active mod!
            ModProgressAnswer = #AnswerNone
            SetGadgetText(GadgetModText, "This modification is required by '" + \name$ + "'." + #CRLF$ + "Please deactivate all mods that depend on this mod before deactivating this mod.")
            HideGadget(GadgetModOk, #False)
            While ModProgressAnswer = #AnswerNone
              Delay(10)
            Wend
            ; task clean up procedure
            AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
            ProcedureReturn #False
          EndIf
        Next
      EndIf 
    EndWith
  Next
  
  
  ; read list of files from ini file
  With *modinfo
    
    OpenPreferences(TF$ + "TFMM\filetracker.ini")
    PreferenceGroup(\name$)
    ; read md5 of installed files in order to keep track of all files that have been changed by this mod
    ExaminePreferenceKeys()
    count = 0
    countAll = 0
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
      SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present. All other files may have been altered by other mods and cannot be restored savely. Do you want to deactivate this modification?")
    ElseIf count > 0 And count = countAll
      SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(count) + " files. Do you want to deactivate this modification?")
    Else
      SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present. Do you want to deactivate this mod?")
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
  Debug "LoadModList()"
  Protected active$
  Protected i.i
  
  If TF$ = ""
    ProcedureReturn #False
  EndIf
  
  Protected *modinfo.mod 
  Protected count
  
  OpenPreferences(Path(TF$ + "TFMM") + "mods.ini")
  If ExaminePreferenceGroups()
    While NextPreferenceGroup()
      *modinfo = AllocateStructure(mod)
      With *modinfo
        \name$ = PreferenceGroupName()
        Debug " - found mod: "+\name$
        \file$ = ReadPreferenceString("file", "")
        If \file$ = ""
          ; no valid mod
          ; free memory and continue with next entry
          FreeStructure(*modinfo)
          Continue
        EndIf
        \author$ = ReadPreferenceString("author", "")
        \version$ = ReadPreferenceString("version", "")
        \size = ReadPreferenceInteger("size", 0)
        \md5$ = ReadPreferenceString("md5", "")
        \active = ReadPreferenceInteger("active", 0)
        
        count = CountGadgetItems(ListInstalled)
        If \active
          active$ = "Yes"
        Else
          active$ = "No"
        EndIf
        
        AddGadgetItem(ListInstalled, count, \name$ + Chr(10) + \author$ + Chr(10) + \version$ + Chr(10) + Bytes(\size) + Chr(10) + active$)
        SetGadgetItemData(ListInstalled, count, *modinfo)
      EndWith
    Wend
  EndIf
  ClosePreferences()
  
  
  ; load dependencies
  Debug "Load Dependencies"
  OpenPreferences(Path(TF$ + "TFMM") + "mod-dependencies.ini")
  count = CountGadgetItems(ListInstalled)
  For i = 0 To count-1
    With *modinfo
      *modinfo = GetGadgetItemData(ListInstalled, i)
      If PreferenceGroup(\name$)
        Debug " - Dependencies for "+\name$+":"
        If ExaminePreferenceKeys()
          While NextPreferenceKey()
            Debug " - - " + PreferenceKeyName() + " = " + PreferenceKeyValue()
            \dependencies$(PreferenceKeyName()) = PreferenceKeyValue()
          Wend
        EndIf
      EndIf
    EndWith
  Next
  ClosePreferences()
EndProcedure

Procedure AddModToList(File$) ; Read File$ from any location, extract mod into mod-directory, add info, this procedure calls WriteModToList()
  Debug "AddModToList("+File$+")"
  Protected *modinfo.mod, *tmp.mod
  Protected FileTarget$, tmp$, active$
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
          ToggleMod(*tmp)
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
               "Current modification:"+#CRLF$+
               #TAB$+"Name: "+*tmp\name$+#CRLF$+
               #TAB$+"Version: "+*tmp\version$+#CRLF$+
               #TAB$+"Author: "+*tmp\author$+#CRLF$+
               #TAB$+"Size: "+Bytes(*tmp\size)+#CRLF$+
               "New modification:"+#CRLF$+
               #TAB$+"Name: "+*modinfo\name$+#CRLF$+
               #TAB$+"Version: "+*modinfo\version$+#CRLF$+
               #TAB$+"Author: "+*modinfo\author$+#CRLF$+
               #TAB$+"Size: "+Bytes(*modinfo\size)+#CRLF$+
               "Do you want to replace the modification?"
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
    If \active
      active$ = "Yes"
    Else
      active$ = "No"
    EndIf
    AddGadgetItem(ListInstalled, count, \name$ + Chr(10) + \author$ + Chr(10) + \version$ + Chr(10) + Bytes(\size) + Chr(10) + active$)
    SetGadgetItemData(ListInstalled, count, *modinfo)
    ToggleMod(*modinfo)      
  EndWith
  
EndProcedure

Procedure RemoveModFromList(*modinfo.mod) ; Deletes entry from ini file and deletes file from mod folder
  If Not *modinfo
    ProcedureReturn #False
  EndIf
  
  With *modinfo
    OpenPreferences(Path(TF$ + "TFMM") + "mods.ini")
    RemovePreferenceGroup(\name$)
    ClosePreferences()
    OpenPreferences(Path(TF$ + "TFMM") + "mod-dependencies.ini")
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

Procedure MenuItemHomepage(event)
  RunProgram(#DQUOTE$+"http://goo.gl/utB3xn"+#DQUOTE$) ; Download Page (Train-Fever.net)
EndProcedure

Procedure MenuItemUpdate(event)
  CreateThread(@checkUpdate(), 0)
EndProcedure

Procedure MenuItemLicense(event)
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

Procedure checkUpdate(auto.i)
  Debug "checkUpdate"
  Protected URL$
  
  DeleteFile("tfmm-update.ini")
  URL$ = URLEncoder("http://update.alexandernaehring.eu/tfmm/?build="+Str(#PB_Editor_CompileCount)+"&auto="+Str(auto))
  Debug URL$
  If ReceiveHTTPFile("http://update.alexandernaehring.eu/tfmm/?build="+Str(#PB_Editor_CompileCount)+"&auto="+Str(auto), "tfmm-update.ini")
    OpenPreferences("tfmm-update.ini")
    If ReadPreferenceInteger("version", #PB_Editor_CompileCount) > #PB_Editor_CompileCount
      Debug "Update: new version available"
      MessageRequester("Update", "A new version of TFMM is available." + #CRLF$ + "Go to 'File' -> 'Homepage' to access the project page.")
    Else
      Debug "Update: no new version"
      If Not auto
        MessageRequester("Update", "You already have the newest version of TFMM.")
      EndIf
    EndIf
    ClosePreferences()
    DeleteFile("tfmm-update.ini")
  Else
    Debug "ERROR: failed to download ini"
    If Not auto
      MessageRequester("Update", "Failed to retrieve version info from server.")
    EndIf
  EndIf
EndProcedure

;----------------------------------------

Procedure init()
  If Not UseZipPacker()
    MessageRequester("Error", "Could not initialize ZIP decompression.")
    End
  EndIf
  If Not InitNetwork()
    Debug "ERROR: InitNetwork()"
  EndIf
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
  If ReadPreferenceInteger("update", 0)
    CreateThread(@checkUpdate(), 1)
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
; CursorPosition = 1346
; FirstLine = 459
; Folding = ECgYQBwA9
; EnableUnicode
; EnableXP