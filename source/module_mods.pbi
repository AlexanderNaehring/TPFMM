XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_unrar.pbi"

Global GadgetModNo, GadgetModNoAll, GadgetModOK, GadgetModProgress, GadgetModText, GadgetModYes, GadgetModYesAll
Global WindowMain, WindowModProgress
Global TimerFinishUnInstall, TimerUpdate
Global ListInstalled

Global ActivationInProgress, UpdateResult

; DeclareModule mods
;   EnableExplicit
  
  Enumeration
    #AnswerNone
    #AnswerYes
    #AnswerNo
    #AnswerYesAll
    #AnswerNoAll
    #AnswerOk
  EndEnumeration
  
  Enumeration
    #QueueActionNew
    #QueueActionActivate
    #QueueActionDeactivate
    #QueueActionUninstall
  EndEnumeration
  
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
  ;   Map conflicts$()
  EndStructure
  
  Structure queue
    action.i
    *modinfo.mod
  EndStructure
  
  
  Declare UserAnswer(answer)  ; receive user input upon question
  
  
  
; EndDeclareModule
; 
; 
; Module mods
  Global NewList queue.queue()
  Global ModProgressAnswer = #AnswerNone
  Global ActivationInProgress
  Global MutexQueue
  
  
  
  
  Procedure AddToQueue(action, *modinfo.mod)
    debugger::Add("AddToQueue("+Str(action)+", "+Str(*modinfo.mod)+")")
    If Not MutexQueue
      MutexQueue = CreateMutex()
    EndIf
    
    Select action
      Case #QueueActionNew
        
      Case #QueueActionActivate
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        debugger::Add("QueueActionActivate: "+*modinfo\name$)
        LockMutex(MutexQueue)
        AddElement(queue())
        queue()\action = action
        queue()\modinfo = *modinfo
        UnlockMutex(MutexQueue)
        
      Case #QueueActionDeactivate
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        LockMutex(MutexQueue)
        AddElement(queue())
        queue()\action = action
        queue()\modinfo = *modinfo
        UnlockMutex(MutexQueue)
        
      Case #QueueActionUninstall
        
    EndSelect
  EndProcedure
  
  Procedure UserAnswer(answer)
    ModProgressAnswer = answer
  EndProcedure
  
  Procedure FreeModList()
    Protected i, count
    Protected *modinfo.mod
    
    count = CountGadgetItems(ListInstalled)
    For i = 0 To count-1
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      FreeStructure(*modinfo) ; this automatically also frees all strings in the strucute element
    Next
    ListIcon::ClearListItems(ListInstalled)
  EndProcedure
  
  Procedure LoadModList()
    debugger::Add("LoadModList()")
    Protected active$
    Protected i.i
    
    If TF$ = ""
      ProcedureReturn #False
    EndIf
    
    Protected *modinfo.mod 
    Protected count
    
    OpenPreferences(misc::Path(TF$ + "TFMM") + "mods.ini")
    If ExaminePreferenceGroups()
      While NextPreferenceGroup()
        *modinfo = AllocateStructure(mod)
        With *modinfo
          \name$ = PreferenceGroupName()
          debugger::Add(" - found mod: "+\name$)
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
          
          ListIcon::AddListItem(ListInstalled, count, \name$ + Chr(10) + \author$ + Chr(10) + \version$ + Chr(10) + misc::Bytes(\size)); + Chr(10) + active$)
          ListIcon::SetListItemData(ListInstalled, count, *modinfo)
          If \active
            ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("yes")))
          Else
            ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("no")))
          EndIf
        EndWith
      Wend
    EndIf
    ClosePreferences()
    
    
    ; load dependencies
    debugger::Add("Load Dependencies")
    OpenPreferences(misc::Path(TF$ + "TFMM") + "mod-dependencies.ini")
    count = CountGadgetItems(ListInstalled)
    For i = 0 To count-1
      With *modinfo
        *modinfo = ListIcon::GetListItemData(ListInstalled, i)
        If PreferenceGroup(\name$)
          debugger::Add(" - Dependencies for "+\name$+":")
          If ExaminePreferenceKeys()
            While NextPreferenceKey()
              debugger::Add(" - - " + PreferenceKeyName() + " = " + PreferenceKeyValue())
              \dependencies$(PreferenceKeyName()) = PreferenceKeyValue()
            Wend
          EndIf
        EndIf
      EndWith
    Next
    ClosePreferences()
  EndProcedure

  Procedure FinishDeActivate()
    Protected i, *modinfo.mod
    RemoveWindowTimer(WindowModProgress, TimerFinishUnInstall)
    
;     FreeModList() ; not working in batch processing as *modinfo become invalid
;     LoadModList()
    
    For i = 0 To CountGadgetItems(ListInstalled) - 1
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      If *modinfo\active
        SetGadgetItemImage(ListInstalled, i, ImageID(images::Images("yes")))
      Else
        SetGadgetItemImage(ListInstalled, i, ImageID(images::Images("no")))
      EndIf
    Next i
    
    DisableWindow(WindowMain, #False)
    HideWindow(WindowModProgress, #True)
    SetActiveWindow(WindowMain)
    ActivationInProgress = #False 
  EndProcedure
  
  Procedure WriteModToList(*modinfo.mod) ; write *modinfo to mod list ini file
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    
    With *modinfo
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mods.ini")
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
        OpenPreferences(misc::Path(TF$ + "TFMM") + "mod-dependencies.ini")
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
    
    zip = OpenPack(#PB_Any, File$, #PB_PackerPlugin_Zip)
    If Not zip
      Debug "error opening pack "+File$
      ProcedureReturn #False 
    EndIf
    
    If Not ExaminePack(zip)
      Debug "error examining pack "+File$
      ProcedureReturn #False
    EndIf
    
    Path$ = misc::Path(Path$)
    
    While NextPackEntry(zip)
      If PackEntryType(zip) = #PB_Packer_File
        If FindString(PackEntryName(zip), "res/") ; only extract files to list which are located in subfoldres of res/
          File$ = PackEntryName(zip)
          File$ = Mid(File$, FindString(File$, "res/")) ; let all paths start with "res/" (if res is located in a subfolder!)
          ; adjust path delimiters to OS
          File$ = misc::Path(GetPathPart(File$)) + GetFilePart(File$)
          misc::CreateDirectoryAll(GetPathPart(Path$ + File$))
          If UncompressPackFile(zip, Path$ + File$, PackEntryName(zip)) = 0
            debugger::Add("ERROR: uncrompressing zip: '"+PackEntryName(zip)+"' to '"+Path$ + File$+"' failed!")
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
        Entry$ = misc::Path(GetPathPart(Entry$)) + GetFilePart(Entry$)
  
        If unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #NULL$, Path$ + Entry$) <> unrar::#ERAR_SUCCESS ; uncompress current file to modified tmp path
          debugger::Add("ERROR: uncrompressing rar: '"+File$+"' failed!")
        EndIf
      Else
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; file not in "res", skip it
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
  
    ProcedureReturn #True
  EndProcedure
  
  Procedure ActivateThread_ReadFiles(dir$, List files$())
    debugger::Add("ActivateThread_ReadFiles() - "+dir$)
    Protected dir, Entry$
    
    dir$ = misc::Path(dir$)
    
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
    debugger::Add("ActivateThread("+Str(*modinfo)+")")
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    ActivationInProgress = #True
    
    Protected dir, i, CopyFile, isModded, error, count, ok
    Protected NewList Files$(), NewList FileTracker$()
    Protected Backup$, File$, Mod$, tmpDir$, extension$, ReqMod$, ReqVer$
    Protected *tmpinfo.mod
    
    With *modinfo
      Mod$ = misc::Path(TF$ + "TFMM/Mods") + \file$
      tmpDir$ = misc::Path(TF$ + "TFMM/mod_tmp")
      
      Debug "Activate "+\file$+"'"
      
      ModProgressAnswer = #AnswerNone
      SetGadgetText(GadgetModText, "Do you want to activate '"+\name$+"'?")
      HideGadget(GadgetModYes, #False)
      HideGadget(GadgetModNo, #False)
;       While ModProgressAnswer = #AnswerNone ; batch processing: do not ask but continue
;         Delay(10)
;       Wend
      HideGadget(GadgetModYes, #True)
      HideGadget(GadgetModNo, #True)
      
;       If ModProgressAnswer = #AnswerNo
;         ; task clean up procedure
;         AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
;         ProcedureReturn #False
;       EndIf
      
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
          *tmpinfo.mod = ListIcon::GetListItemData(ListInstalled, i)
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
      misc::CreateDirectoryAll(tmpDir$)                                            ; create temp dir
      If FileSize(tmpDir$) <> -2
        ; error opening archive
        DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
        ModProgressAnswer = #AnswerNone
        SetGadgetText(GadgetModText, "Failed to create temporary directory for extraction!")
        HideGadget(GadgetModOk, #False)
        While ModProgressAnswer = #AnswerNone
          Delay(10)
        Wend
        ; task clean up procedure
        AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
        ProcedureReturn #False
      EndIf
      
  
      error = #False 
      If extension$ = "zip"
        Debug "use zip"
        If Not ExtractModZip(Mod$, tmpDir$)
          error = #True
        EndIf
      ElseIf extension$ = "rar"
        Debug "use rar"
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
      
      debugger::Add("found "+Str(ListSize(files$()))+" files for activation")
      SetGadgetText(GadgetModText, Str(ListSize(files$()))+" files found")
      
      Backup$ = misc::Path(TF$ + "TFMM/Backup/")
      debugger::Add("Backup folder: "+Backup$)
      misc::CreateDirectoryAll(Backup$)
      
      ; load filetracker list
      debugger::Add("load filetracker")
      ClearList(FileTracker$())
      OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
      ExaminePreferenceGroups()
      While NextPreferenceGroup()
        debugger::Add("filetracker: " + PreferenceGroupName())
        PreferenceGroup(PreferenceGroupName())
        ExaminePreferenceKeys()
        While NextPreferenceKey()
          AddElement(FileTracker$())
          FileTracker$() = LCase(PreferenceKeyName())
        Wend
      Wend
      ClosePreferences()
      debugger::Add("filetracker: " + Str(ListSize(FileTracker$())) + " files")
      
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Minimum, 0)
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Maximum, ListSize(files$()))
      SetGadgetState(GadgetModProgress, 0)
      HideGadget(GadgetModProgress, #False)
      i = 0
      ModProgressAnswer = #AnswerNone
      
      ;--------------------------------------------------------------------------------------------------
      ;- process all files
      debugger::Add("process files")
      ForEach files$()
        Delay(0) ; let the CPU breath
        File$ = files$()
        File$ = misc::Path(GetPathPart(File$)) + GetFilePart(File$)
        File$ = RemoveString(File$, tmpDir$) ; File$ contains only the relative path of mod
        
        SetGadgetText(GadgetModText, "Processing file '" + GetFilePart(Files$()) + "'...")
        
        ; normal case: copy the modificated file to game directoy
        CopyFile = #True
        isModded = #False
        
        ; check filetracker for any other mods that may have modified this file before
        ForEach FileTracker$()
          ; compare files from filetracker with files from new mod
          If FileTracker$() = File$
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
                ; do not reset answer!
            EndSelect
            
            ; filetracker will list the file as modified by multiple mods! (may result in multiple entries for single file)
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
                misc::CreateDirectoryAll(GetPathPart(Backup$ + File$))
                RenameFile(TF$ + File$, Backup$ + File$)  ; move file
              EndIf
            EndIf
          EndIf
          
          ; make sure that the target directory exists (in case of newly added files / direcotries)
          misc::CreateDirectoryAll(GetPathPart(TF$ + File$))
          ; move the file from the temporary directory to the game directory
          
          DeleteFile(TF$ + File$)
          If RenameFile(Files$(), TF$ + File$)
            debugger::Add("installed file "+File$)
          Else
            debugger::Add("ERROR: failed to move file: RenameFile(" + Files$() + ", " + TF$ + File$ + ")")
          EndIf
          
          
          OpenPreferences(misC::Path(TF$ + "TFMM") + "filetracker.ini")
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
      debugger::Add("finish install...")
      HideGadget(GadgetModProgress, #True)
      If Not DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
        debugger::Add("ERROR: failed to remove tmpDir$ ("+tmpDir$+")")
      EndIf
      
      ; activate mod in mod list
      \active = #True
      WriteModToList(*modinfo) ; update mod entry
      
;       HideGadget(GadgetModProgress, #True)
;       SetGadgetText(GadgetModText, "'" + \name$ + "' was successfully activated")
;       HideGadget(GadgetModOk, #False)
;       ModProgressAnswer = #AnswerNone
;       While ModProgressAnswer = #AnswerNone
;         Delay(10)
;       Wend
      
      ; task clean up procedure
      debugger::Add("install finished!")
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #True 
    EndWith
  EndProcedure
  
  Procedure DeactivateThread(*modinfo.mod)
    debugger::Add("DeactivateThread()")
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    ActivationInProgress = #True
    
    Protected File$, md5$, Backup$
    Protected NewList Files$()
    Protected count, countAll, i
    Protected *tmpinfo.mod
    
    debugger::Add("deactivate "+*modinfo\name$)
    
    debugger::Add("check dependencies")
    ; check dependencies
    count = CountGadgetItems(ListInstalled)
    For i = 0 To count-1
      With *tmpinfo
        *tmpinfo = ListIcon::GetListItemData(ListInstalled, i)
        If \active
          ForEach \dependencies$()
            If MapKey(\dependencies$()) = *modinfo\name$
              ; this mod is required by another active mod!
              debugger::Add("this mod is required required by " + \name$)
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
      debugger::Add("read filetracker and check MD5")
      OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
      PreferenceGroup(\name$)
      ; read md5 of installed files in order to keep track of all files that have been changed by this mod
      ExaminePreferenceKeys()
      count = 0
      countAll = 0
      ClearList(Files$())
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
      debugger::Add("count = "+Str(count)+", countAll = "+Str(countAll)+", Files$() = "+ListSize(Files$()))
      
      If countAll <= 0
        Debug "no files altered?"
      EndIf
      
      If count = 0 ;And countAll > 0
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files."+#CRLF$+"All of these files have been overwritten Or altered by other modifications."+#CRLF$+"This modification currently has no effect To the game And can savely be deactiveted."+#CRLF$+"Do you want To deactivate this modification?")
      ElseIf count > 0 And count < countAll
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present."+#CRLF$+"All other files may have been altered by other mods and cannot be restored savely."+#CRLF$+"Do you want to deactivate this modification?")
      ElseIf count > 0 And count = countAll
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(count) + " files."+#CRLF$+"Do you want to deactivate this modification?")
      Else
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present."+#CRLF$+"Do you want to deactivate this mod?")
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
      
      Backup$ = misc::Path(TF$ + "TFMM/Backup/")
      misc::CreateDirectoryAll(Backup$)
      i = 0
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Minimum, 0)
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Maximum, ListSize(Files$()))
      HideGadget(GadgetModProgress, #False)
      ForEach Files$()
        File$ = Files$()
        SetGadgetText(GadgetModText, "Processing file '" + GetFilePart(File$) + "'...")
        
        ; delete file
        debugger::Add("delete file: "+File$)
        DeleteFile(TF$ + File$,  #PB_FileSystem_Force)
        
        ; restore backup if any
        If FileSize(Backup$ + File$) >= 0
          debugger::Add("restore backup: "+File$)
          CopyFile(Backup$ + File$, TF$ + File$)
          DeleteFile(Backup$ + File$)
        EndIf
        
        i = i + 1
        SetGadgetState(GadgetModProgress, i)
      Next
      HideGadget(GadgetModProgress, #True)
      
      debugger::Add("finish uninstall...")
      SetGadgetText(GadgetModText, "Cleanup...")
      
      ; update filetracker. All files that are currently altered by this mod have been removed (restored) -> delete all entries from filetracker
      OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      
      \active = #False
      WriteModToList(*modinfo) ; update mod entry
      
;       SetGadgetText(GadgetModText, "'" + \name$ + "' was successfully deactivated")
;       HideGadget(GadgetModOk, #False)
;       ModProgressAnswer = #AnswerNone
;       While ModProgressAnswer = #AnswerNone
;         Delay(10)
;       Wend
      
    EndWith
    
    debugger::Add("uninstall finished!")
    AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
    ProcedureReturn #False
  EndProcedure
  
  Procedure ShowProgressWindow()
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
  EndProcedure
  
  
  Procedure ToggleMod(*modinfo.mod)
    debugger::Add("ToogleMod()")
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    If ActivationInProgress
      ProcedureReturn #False
    EndIf
    ActivationInProgress = #True
    
    ShowProgressWindow()
    
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

  Procedure RemoveModFromList(*modinfo.mod) ; Deletes entry from ini file and deletes file from mod folder
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    
    With *modinfo
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mods.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mod-dependencies.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      
      DeleteFile(TF$ + "TFMM\Mods\" + *modinfo\file$, #PB_FileSystem_Force)
      
      FreeModList()
      LoadModList()
      
    EndWith
  EndProcedure
  
  ; EndModule
  
Procedure CheckModFileZip(File$)
  debugger::Add("CheckModFileZip("+File$+")")
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
  debugger::Add("CheckModFileRar("+File$+")")
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
  debugger::Add("CheckModFile("+File$+")")
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
    \name$ = ReplaceString(ReplaceString(\name$, "[", "("), "]", ")")
    \author$ = ReadPreferenceString("author", \author$)
    \version$ = ReadPreferenceString("version", \version$)
    ; read dependencies from tfmm.ini
    If PreferenceGroup("dependencies")
      debugger::Add("dependencies found:")
      If ExaminePreferenceKeys()
        While NextPreferenceKey()
          debugger::Add(PreferenceKeyName() + " = " + PreferenceKeyValue())
          \dependencies$(PreferenceKeyName()) = PreferenceKeyValue()
        Wend
      EndIf 
    Else
      debugger::Add("No dependencies")
      ClearMap(\dependencies$())
    EndIf
    ClosePreferences()
    
    DeleteFile(tmpDir$ + "tfmm.ini")
    
  EndWith
  
  ProcedureReturn #True
EndProcedure

Procedure AddModToList(File$) ; Read File$ from any location, extract mod into mod-directory, add info, this procedure calls WriteModToList()
  debugger::Add("AddModToList("+File$+")")
  Protected *modinfo.mod, *tmp.mod
  Protected FileTarget$, tmp$, active$
  Protected count, i
  Protected sameName.b, sameHash.b
  
  If Not CheckModFile(File$)
    MessageRequester("Error", "Selected file is not a valid Train Fever modification or may not be compatible with TFMM")
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
    
    *tmp = ListIcon::GetListItemData(ListInstalled, i)
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
               #TAB$+"Size: "+misc::Bytes(*tmp\size)+#CRLF$+
               "New modification:"+#CRLF$+
               #TAB$+"Name: "+*modinfo\name$+#CRLF$+
               #TAB$+"Version: "+*modinfo\version$+#CRLF$+
               #TAB$+"Author: "+*modinfo\author$+#CRLF$+
               #TAB$+"Size: "+misc::Bytes(*modinfo\size)+#CRLF$+
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
  misc::CreateDirectoryAll(TF$ + "TFMM/Mods/")
  
  ; user wants to install this mod! Therefore, find a possible file name!
  i = 0
  FileTarget$ = GetFilePart(File$,  #PB_FileSystem_NoExtension) + "." + GetExtensionPart(File$)
  While FileSize(misc::Path(TF$ + "TFMM/Mods/") + FileTarget$) > 0
    ; try to find a filename which does not exist
    i = i + 1
    FileTarget$ = GetFilePart(File$,  #PB_FileSystem_NoExtension) + "(" + Str(i) + ")." + GetExtensionPart(File$)
  Wend
  
  ; import file to mod folder
  If Not CopyFile(File$, misc::Path(TF$ + "TFMM/Mods/") + FileTarget$)
    ; Copy error
    FreeStructure(*modinfo)
    ProcedureReturn #False 
  EndIf
  
  *modinfo\file$ = FileTarget$
  
  WriteModToList(*modinfo)
  
  With *modinfo
    count = CountGadgetItems(ListInstalled)
    ListIcon::AddListItem(ListInstalled, count, \name$ + Chr(10) + \author$ + Chr(10) + \version$ + Chr(10) + misc::Bytes(\size))
    ListIcon::SetListItemData(ListInstalled, count, *modinfo)
    If \active
      ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("yes")))
    Else
      ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("no")))
    EndIf
    ToggleMod(*modinfo)
  EndWith
  
EndProcedure

Procedure ExportModListHTML(all, File$)
  Protected file, i
  Protected *modinfo.mod
  
  file = CreateFile(#PB_Any, File$)
  If file
    WriteStringN(file, "<!DOCTYPE html>", #PB_UTF8)
    WriteString(file, "<html>", #PB_UTF8)
    WriteString(file, "<head><meta charset='utf-8' /><meta name='Author' content='TFMM' /><title>TFMM Modification List Export</title><style>", #PB_UTF8)
    WriteString(file, "h1 {color: #fff; text-align: center; width: 100%; margin: 5px 0px; padding: 10px; background: #831555} "+
                      "table {width: 60%; min-width: 640px; background: #fff; padding: 0px; margin: 5px auto; border-collapse: collapse; border-spacing: 0px; border: 1px solid; border-color: RGBA(0, 0, 0, .2); box-shadow: 3px 3px 3px RGBA(0, 0, 0, .2); } "+
                      "td { padding: 5px; text-align: left; vertical-align: middle; border: none; } "+
                      "th { padding: 5px; text-align: center; vertical-align: moddle; border: none; font-weight: bold; font-size: 1.1em; border: none;background: #413e39; color: #fff } "+
                      "tr {border: none;} "+
                      "table tr:Not(:last-child) { border-style: solid; border-width: 0px 0px 1px 0px; border-color: RGBA(0, 0, 0, .2); } "+
                      "table > tr:first-child > th { } "+
                      "table tr:nth-child(even) td, table tr:nth-child(even) th { background: RGBA(0, 0, 0, .04); } "+
                      "table tr:hover td { background: RGBA(0, 0, 0, .06) !important; } "+
                      "footer { width: 100%; margin: 20px 0px; padding: 5px; border-top: 1px solid #413e39; text-align: right; font-size: small; color: rgba(65,62,57,.5); transition: color .5s ease-in-out } "+
                      "footer:hover { color: #413e39; } "+
                      "footer article { width: 60%; min-width: 640px; margin: 0px auto; padding: 0px; } "+
                      "a { color: inherit; } "+
                      "a:hover { color: #831555; } "+
                      "", #PB_UTF8)
    WriteString(file, "</style></head>", #PB_UTF8)
    WriteString(file, "<body><h1>", #PB_UTF8)
    If all
      WriteString(file, "List of Modifications", #PB_UTF8)
    Else
      WriteString(file, "List of Activated Modifications", #PB_UTF8)
    EndIf
    WriteString(file, "</h1><table><tr><th>Modification</th><th>Version</th><th>Author</th></tr>", #PB_UTF8)
    
    For i = 0 To CountGadgetItems(ListInstalled) - 1
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      With *modinfo
        If all Or \active
          WriteString(file, "<tr><td>" + \name$ + "</td><td>" + \version$ + "</td><td>" + \author$ + "</td></tr>", #PB_UTF8)
        EndIf
      EndWith
      
    Next i
    WriteString(file, "</table>", #PB_UTF8)
    WriteString(file, "<footer><article><a href='http://goo.gl/utB3xn'>TFMM</a> &copy; 2014-"+FormatDate("%yyyy",Date())+" <a href='http://www.alexandernaehring.eu/'>Alexander Nähring</a></article></footer>", #PB_UTF8)
    
    WriteString(file, "</body></html>", #PB_UTF8)
    CloseFile(file)
    RunProgram(File$)
  EndIf
EndProcedure

Procedure ExportModListTXT(all, File$)
  Protected file, i
  Protected *modinfo.mod
  
  WriteStringN(file, "Mod" + Chr(9) + "Version" + Chr(9) + "Author", #PB_UTF8)
               
  file = CreateFile(#PB_Any, File$)
  If file
    For i = 0 To CountGadgetItems(ListInstalled) - 1
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      With *modinfo
        If all Or \active
          WriteStringN(file, \name$ + Chr(9) + \version$ + Chr(9) + \author$, #PB_UTF8)
        EndIf
      EndWith
      
    Next i    
    CloseFile(file)
    RunProgram(File$)
  EndIf
EndProcedure

Procedure ExportModList(all = #False)
  debugger::Add("Export Mod List")
  Protected File$, Extension$
  Protected ok = #False
  
  File$ = SaveFileRequester("Export Mod List", "mods.html", "HTML|*.html|TEXT|*.txt", 0)
  Extension$ = LCase(GetExtensionPart(File$))
  If Extension$ = "txt" Or Extension$ = "html"
    If FileSize(File$) > 0
      If MessageRequester("Export Mod List", "Do you want to overwrite the existing file?", #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
        ok = #True
      EndIf
    Else
      ok = #True
    EndIf
  EndIf
  
  If ok
    Select LCase(GetExtensionPart(File$))
      Case "html"
        ExportModListHTML(all, File$)
      Case "txt"
        ExportModListTXT(all, File$)
    EndSelect
  EndIf
EndProcedure

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 1117
; FirstLine = 750
; Folding = Y1jo5
; EnableUnicode
; EnableXP