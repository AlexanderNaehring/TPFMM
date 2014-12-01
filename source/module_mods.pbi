XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_unrar.pbi"

Global GadgetModNo, GadgetModNoAll, GadgetModOK, GadgetModProgress, GadgetModText, GadgetModYes, GadgetModYesAll
Global WindowMain, WindowModProgress
Global TimerFinishUnInstall, TimerUpdate
Global ListInstalled

Global InstallInProgress, UpdateResult

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
  
  Structure author
    name$
    tfnet_id.i
  EndStructure
    
  Structure mod
    id$
    name$
    file$
    authors$ ; full list
    List author.author()
    version$
    category$
    tfnet_mod_id.i
    size.i
    md5$
    active.i
    Map dependencies$()
  ;   Map conflicts$()
  EndStructure
  
  Structure queue
    action.i
    *modinfo.mod
    File$
  EndStructure
  
  
  Declare UserAnswer(answer)  ; receive user input upon question
  
  Declare ExtractModInformation(*modinfo.mod, Path$)
  Declare ExtractFilesZip(ZIP$, List Files$(), dir$)
  Declare ExtractFilesRar(RAR$, List Files$(), dir$)
  
 
; EndDeclareModule
; 
; 
; Module mods
  Global NewList queue.queue()
  Global ModProgressAnswer = #AnswerNone
  Global MutexQueue
  
  
  Procedure.s CreateNewID(*modinfo.mod)
    Protected id$, name$, author$
    
    With *modinfo
      If ListSize(\author()) = 0
        author$ = "unknown"
      Else
        LastElement(\author())
        Repeat
          If author$ <> ""
            author$ + "."
          EndIf
          author$ + LCase(ReplaceRegularExpression(0, \author()\name$, ""))
        Until Not PreviousElement(\author())
      EndIf
      
      name$ = "unknown"
      If \name$
        name$ = LCase(ReplaceRegularExpression(0, \name$, ""))
      EndIf
      
      id$ = author$ + "." + name$
      
      If \id$ = ""
        \id$ = id$
      EndIf
    EndWith
    
    ProcedureReturn id$
  EndProcedure
  
  Procedure AddToQueue(action, *modinfo.mod, File$="")
    debugger::Add("AddToQueue("+Str(action)+", "+Str(*modinfo.mod)+", "+File$+")")
    If Not MutexQueue
      debugger::Add("MutexQueue = CreateMutex()")
      MutexQueue = CreateMutex()
    EndIf
    
    Select action
      Case #QueueActionNew
        If File$ = ""
          ProcedureReturn #False
        EndIf
          
        debugger::Add("Append to queue: QueueActionNew: " + File$)
        LockMutex(MutexQueue)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\File$ = File$
        UnlockMutex(MutexQueue)
        
      Case #QueueActionActivate
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        
        debugger::Add("Append to queue: QueueActionActivate: " + *modinfo\name$)
        LockMutex(MutexQueue)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\modinfo = *modinfo
        UnlockMutex(MutexQueue)
        
      Case #QueueActionDeactivate
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        
        debugger::Add("Append to queue: QueueActionDeactivate: " + *modinfo\name$)
        LockMutex(MutexQueue)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\modinfo = *modinfo
        UnlockMutex(MutexQueue)
        
      Case #QueueActionUninstall
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        
        debugger::Add("Append to queue: QueueActionUninstall: " + *modinfo\name$)
        LockMutex(MutexQueue)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\modinfo = *modinfo
        UnlockMutex(MutexQueue)
        
        
    EndSelect
  EndProcedure
  
  Procedure UserAnswer(answer)
    ModProgressAnswer = answer
  EndProcedure
  
  Procedure FreeModList()
    debugger::Add("FreeModList()")
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
    Protected active$, author$, tfnet_author_id$, Path$
    Protected i.i, count.i
    Protected *modinfo.mod
    
    If TF$ = ""
      ProcedureReturn #False
    EndIf
    
    
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
          
          ClearList(\author())
          \name$ = ReadPreferenceString("name", \name$)
          author$ = ReadPreferenceString("author", "")
          author$ = ReplaceString(author$, "/", ",")
          \version$ = ReadPreferenceString("version", "")
          \category$ = ReadPreferenceString("category", "")
          tfnet_author_id$ = ReadPreferenceString("online_tfnet_author_id", "")
          \tfnet_mod_id = ReadPreferenceInteger("online_tfnet_mod_id", 0) ; http://www.train-fever.net/filebase/index.php/Entry/xxx
          \md5$ = ReadPreferenceString("md5", "")
          \size = ReadPreferenceInteger("size", 0)
          \active = ReadPreferenceInteger("active", 0)
          
          count  = CountString(author$, ",") + 1
          For i = 1 To count
            AddElement(\author())
            \author()\name$ = Trim(StringField(author$, i, ","))
            \author()\tfnet_id = Val(Trim(StringField(tfnet_author_id$, i, ",")))
          Next i
          
          \authors$ = ""
          If ListSize(\author()) > 0
            ResetList(\author())
            ForEach \author()
              If \authors$ <> ""
                \authors$ + ", "
              EndIf
              \authors$ + \author()\name$
            Next
          EndIf
          
          \id$ = ReadPreferenceString("id", CreateNewID(*modinfo))
          
          count = CountGadgetItems(ListInstalled)
          ListIcon::AddListItem(ListInstalled, count, \name$ + Chr(10) + \authors$ + Chr(10) + \category$ + Chr(10) + \version$); + Chr(10) + active$)
          ListIcon::SetListItemData(ListInstalled, count, *modinfo)
          If \active
            ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("yes")))
          Else
            ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("no")))
          EndIf
          
          ; check additional data (preview.png, tfmm.ini, readme.txt, etc...)
          ; new versions extract these information directy
          ; for backwards compatibility: extract also when loading list
          Path$ = misc::Path(TF$ + "TFMM/Mods/" + \id$)
          If FileSize(Path$) <> -2 ; if directory does not exist
            misc::CreateDirectoryAll(Path$)
            ExtractModInformation(*modinfo, Path$)
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
    debugger::Add("FinishDeActivate()")
    Protected i, *modinfo.mod
    RemoveWindowTimer(WindowModProgress, TimerFinishUnInstall)
    
    For i = 0 To CountGadgetItems(ListInstalled) - 1
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      If *modinfo\active
        ListIcon::SetListItemImage(ListInstalled, i, ImageID(images::Images("yes")))
      Else
        ListIcon::SetListItemImage(ListInstalled, i, ImageID(images::Images("no")))
      EndIf
    Next i
    
    DisableWindow(WindowMain, #False)
    HideWindow(WindowModProgress, #True)
    SetActiveWindow(WindowMain)
    InstallInProgress = #False 
  EndProcedure
  
  Procedure WriteModToIni(*modinfo.mod) ; write *modinfo to mod list ini file
    Protected author$, tfnet_author_id$
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    
    With *modinfo
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mods.ini")
      PreferenceGroup(\name$)
      WritePreferenceString("file", \file$)
      ForEach \author()
        If author$ <> ""
          author$ + ", "
          tfnet_author_id$ + ", "
        EndIf
        author$ + \author()\name$
        tfnet_author_id$ + Str(\author()\tfnet_id)
      Next
      WritePreferenceString("id", \id$)
      WritePreferenceString("name", \name$)
      WritePreferenceString("version", \version$)
      WritePreferenceString("author", author$)
      WritePreferenceString("category", \category$)
      WritePreferenceString("online_tfnet_author_id", tfnet_author_id$)
      WritePreferenceInteger("online_tfnet_mod_id", \tfnet_mod_id)
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
    InstallInProgress = #True
    
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
      WriteModToIni(*modinfo) ; update mod entry
      
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
    InstallInProgress = #True
    
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
      
      ModProgressAnswer = #AnswerNone
      If count = 0 ;And countAll > 0
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files."+#CRLF$+"All of these files have been overwritten Or altered by other modifications."+#CRLF$+"This modification currently has no effect To the game And can savely be deactiveted."+#CRLF$+"Do you want To deactivate this modification?")
        ModProgressAnswer = #AnswerYes
      ElseIf count > 0 And count = countAll
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(count) + " files."+#CRLF$+"Do you want to deactivate this modification?")
        ModProgressAnswer = #AnswerYes
      ElseIf count > 0 And count < countAll
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present."+#CRLF$+"All other files may have been altered by other mods and cannot be restored savely."+#CRLF$+"Do you want to deactivate this modification?")
      Else
        SetGadgetText(GadgetModText, "Modification '" + \name$ + "' has changed " + Str(countAll) + " files of which " + Str(count) + " are still present."+#CRLF$+"Do you want to deactivate this mod?")
      EndIf
      
      HideGadget(GadgetModNo, #False)
      HideGadget(GadgetModYes, #False)
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
      WriteModToIni(*modinfo) ; update mod entry
      
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
  
  Procedure RemoveModFromList(*modinfo.mod) ; Deletes entry from ini file and deletes file from mod folder
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    Protected i
    InstallInProgress = #True
    
    With *modinfo
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mods.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mod-dependencies.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      
      DeleteFile(misc::Path(TF$ + "TFMM/Mods/") + *modinfo\file$, #PB_FileSystem_Force)
      DeleteDirectory(misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$), "", #PB_FileSystem_Recursive | #PB_FileSystem_Force)
      
      For i = 0 To CountGadgetItems(ListInstalled) - 1
        If *modinfo = ListIcon::GetListItemData(ListInstalled, i)
          ListIcon::RemoveListItem(ListInstalled, i)
          InstallInProgress = #False
          ProcedureReturn #True
        EndIf
      Next i
    EndWith
    InstallInProgress = #False
    ProcedureReturn #False 
  EndProcedure
  
  ; EndModule
  
Procedure ExtractModInformation(*modinfo.mod, Path$)
  debugger::Add("ExtractModInformation("+*modinfo\id$+", "+Path$+")")
  
  Protected NewList Files$()
  Protected File$
  
  AddElement(Files$())
  Files$() = "tfmm.ini"
  AddElement(Files$())
  Files$() = "preview.png"
  AddElement(Files$())
  Files$() = "readme.txt"
  AddElement(Files$())
  Files$() = "header.jpg" ; out of compatibility reasons
  
  File$ = misc::Path(TF$ + "TFMM/Mods/") + *modinfo\file$
  
  Select LCase(GetExtensionPart(File$))
    Case "zip"
      ExtractFilesZip(File$, Files$(), Path$)
    Case "rar"
      ExtractFilesRar(File$, Files$(), Path$)
    Default
      debugger::Add("unknown file extension: "+*modinfo\file$)
  EndSelect
EndProcedure

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


Procedure ExtractFilesZip(ZIP$, List Files$(), dir$) ; extracts all Files$() (all subdirs!) to given directory
  debugger::Add("ExtractFilesZip("+ZIP$+", Files$(), "+dir$+")")
  debugger::Add("search for:")
  ForEach Files$()
    debugger::Add(Files$())
  Next
  
  Protected zip, Entry$
  dir$ = misc::Path(dir$)
  
  zip = OpenPack(#PB_Any, ZIP$, #PB_PackerPlugin_Zip)
  If zip
    If ExaminePack(zip)
      While NextPackEntry(zip)
        Entry$ = PackEntryName(zip)
        ForEach Files$()
          If LCase(Entry$) = LCase(Files$()) Or LCase(Right(Entry$, Len(Files$())+1)) = "/" + LCase(Files$())
            debugger::Add("UncompressPackFile("+dir$ + Files$()+")")
            UncompressPackFile(zip, dir$ + Files$())
            DeleteElement(Files$()) ; if file is extracted, delete from list
            Break ; ForEach
          EndIf
        Next
      Wend
    EndIf
    ClosePack(zip)
  Else
    debugger::Add("Error opnening zip: "+ZIP$)
  EndIf
EndProcedure

Procedure ExtractFilesRar(RAR$, List Files$(), dir$) ; extracts all Files$() (all subdirs!) to given directory
  debugger::Add("ExtractFilesRar("+RAR$+", Files$(), "+dir$+")")
  debugger::Add("search for:")
  ForEach Files$()
    debugger::Add(Files$())
  Next
  
  Protected rarheader.unrar::RARHeaderDataEx
  Protected hRAR, hit
  Protected Entry$
  dir$ = misc::Path(dir$)
  
  hRAR = unrar::OpenRar(RAR$, unrar::#RAR_OM_EXTRACT)
  If hRAR
    While unrar::RARReadHeader(hRAR, rarheader) = unrar::#ERAR_SUCCESS
      CompilerIf #PB_Compiler_Unicode
        Entry$ = PeekS(@rarheader\FileNameW)
      CompilerElse
        Entry$ = PeekS(@rarheader\FileName, #PB_Ascii)
      CompilerEndIf
      
      hit = #False
      ForEach Files$()
        If LCase(Entry$) = LCase(Files$()) Or LCase(Right(Entry$, Len(Files$())+1)) = "\" + LCase(Files$())
          debugger::Add("RARProcessFile("+dir$ + Files$()+")")
          unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #NULL$, dir$ + Files$())
          DeleteElement(Files$()) ; if file is extracted, delete from list
          hit = #True
          Break ; ForEach
        EndIf
      Next
      
      If Not hit
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$)
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
  Else
    debugger::Add("Error opnening rar: "+RAR$)
  EndIf
  ProcedureReturn #False
EndProcedure



Procedure GetModInfo(File$, *modinfo.mod)
  Protected tmpDir$, extension$, author$, tfnet_author_id$
  Protected count.i, i.i
  extension$ = LCase(GetExtensionPart(File$))
  tmpDir$ = GetTemporaryDirectory()
  
  With *modinfo
    \file$ = GetFilePart(File$)
    \name$ = GetFilePart(File$, #PB_FileSystem_NoExtension)
    ClearList(\author())
    \version$ = ""
    \size = FileSize(File$)
    \md5$ = MD5FileFingerprint(File$)
    \active = 0
    
    ; read info from TFMM.ini in mod if any
    DeleteFile(tmpDir$ + "tfmm.ini") ; clean old tfmm.ini if exists
                                     ; TODO Check if tfmm.ini is deleted?
    Protected NewList Files$()
    AddElement(Files$())
    Files$() = "tfmm.ini"
    If extension$ = "zip"
;       ExtractTFMMiniZip(File$, tmpDir$)
      ExtractFilesZip(File$, Files$(), tmpDir$)
    ElseIf extension$ = "rar"
;       ExtractTFMMiniRar(File$, tmpDir$)
      ExtractFilesRar(File$, Files$(), tmpDir$)
    EndIf
    ClearList(Files$())
    
    OpenPreferences(tmpDir$ + "tfmm.ini")
    ; Read required TFMM version
    If ReadPreferenceInteger("tfmm", #PB_Editor_CompileCount) > #PB_Editor_CompileCount
      MessageRequester("Newer version of TFMM required", "Please update TFMM in order to have full functionality!" + #CRLF$ + "Select 'File' -> 'Update' to check for newer versions.")
    EndIf
    
    \name$ = ReadPreferenceString("name", \name$)
    \name$ = ReplaceString(ReplaceString(\name$, "[", "("), "]", ")")
    \version$ = ReadPreferenceString("version", \version$)
    author$ = ReadPreferenceString("author", "")
    author$ = ReplaceString(author$, "/", ",")
    \category$ = ReadPreferenceString("category", "")
    
    ; read online category
    PreferenceGroup("online")
    tfnet_author_id$ = ReadPreferenceString("tfnet_author_id", "")
    \tfnet_mod_id = ReadPreferenceInteger("tfnet_mod_id", 0) ; http://www.train-fever.net/filebase/index.php/Entry/xxx
    
    ; create author list
    count  = CountString(author$, ",") + 1
    For i = 1 To count
      AddElement(\author())
      \author()\name$ = Trim(StringField(author$, i, ","))
      \author()\tfnet_id = Val(Trim(StringField(tfnet_author_id$, i, ",")))
    Next i
    \authors$ = ""
    If ListSize(\author()) > 0
      ResetList(\author())
      ForEach \author()
        If \authors$ <> ""
          \authors$ + ", "
        EndIf
        \authors$ + \author()\name$
      Next
    EndIf
    
    PreferenceGroup("")
    \id$ = ReadPreferenceString("id", CreateNewID(*modinfo))
    
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
  Protected sameName.b, sameHash.b, sameID.b
  
  If Not CheckModFile(File$)
    debugger::Add("CheckModFile("+File$+") failed")
    MessageRequester("Error", "Selected file is not a valid Train Fever modification or may not be compatible with TFMM")
    ProcedureReturn #False
  EndIf
  
  *modinfo = AllocateStructure(mod)
  debugger::Add("new *modinfo created @"+Str(*modinfo))
  If Not GetModInfo(File$, *modinfo)
    debugger::Add("failed to retrieve *modinfo")
    ProcedureReturn #False
  EndIf
    
  ; check for existing mods with same name / ID!
  For i = 0 To CountGadgetItems(ListInstalled) - 1
    sameName = #False
    sameHash = #False
    sameID  = #False
    
    *tmp = ListIcon::GetListItemData(ListInstalled, i)
    If *tmp\id$ = *modinfo\id$
      debugger::Add("ID check found match!: *tmp = "+Str(*tmp)+", modinfo ="+Str(*modinfo)+"")
      sameName = #True
    EndIf
    If LCase(*tmp\name$) = LCase(*modinfo\name$)
      debugger::Add("Name check foudn match!: *tmp = "+Str(*tmp)+", modinfo ="+Str(*modinfo)+"")
      sameName = #True
    EndIf
    If *tmp\md5$ = *modinfo\md5$
      debugger::Add("MD5 check found match!: *tmp = "+Str(*tmp)+", modinfo ="+Str(*modinfo)+"")
      sameHash = #True
    EndIf
    
    If sameHash ; same hash indicates a duplicate - do not care about name or ID!
      debugger::Add("same hash indicates a duplicate - do not care about name or ID! - abort installation")
      If *tmp\active
        MessageRequester("Error installing '"+*modinfo\name$+"'", "The modification '"+*tmp\name$+"' is already installed and activated.", #PB_MessageRequester_Ok)
      Else
        If MessageRequester("Error installing '"+*modinfo\name$+"'", "The modification '"+*tmp\name$+"' is already installed."+#CRLF$+"Do you want To activate it now?", #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
          AddToQueue(#QueueActionActivate, *tmp)
        EndIf
      EndIf
      FreeStructure(*modinfo)
      ProcedureReturn #True
    EndIf
    
    If (sameName Or sameID) And Not sameHash ; a mod with the same name is installed, but it is not identical (maybe a new version?)
      tmp$ = "Match with already installed modification found:"+#CRLF$+
             "Current modification:"+#CRLF$+
             #TAB$+"ID: "+*tmp\id$+#CRLF$+
             #TAB$+"Name: "+*tmp\name$+#CRLF$+
             #TAB$+"Version: "+*tmp\version$+#CRLF$+
             #TAB$+"Author: "+*tmp\authors$+#CRLF$+
             #TAB$+"Size: "+misc::Bytes(*tmp\size)+#CRLF$+
             "New modification:"+#CRLF$+
             #TAB$+"ID: "+*modinfo\id$+#CRLF$+
             #TAB$+"Name: "+*modinfo\name$+#CRLF$+
             #TAB$+"Version: "+*modinfo\version$+#CRLF$+
             #TAB$+"Author: "+*modinfo\authors$+#CRLF$+
             #TAB$+"Size: "+misc::Bytes(*modinfo\size)+#CRLF$+
             "Do you want to replace the old modification with the new one?"
      If MessageRequester("Error", tmp$, #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
        ; user does not want to replace
        debugger::Add("User does not want to replace old mod with new mod. Free new mod: "+Str(*modinfo))
        FreeStructure(*modinfo)
        ProcedureReturn #False
      EndIf
      ; user wants to replace mod -> deactivate and uninstall old mod
      
      If *tmp\active
        AddToQueue(#QueueActionDeactivate, *tmp)
      EndIf
      AddToQueue(#QueueActionUninstall, *tmp)
      
      ; after old mod is uninstalled: shedule installation of new mod again!
      ; TODO make a more efficient way of this process!
      AddToQueue(#QueueActionNew, 0, File$)
      FreeStructure(*modinfo)
      ProcedureReturn #False
    EndIf
  Next ; loop though installed mods
  
  ; when reaching this point, the mod can be installed!
  misc::CreateDirectoryAll(TF$ + "TFMM/Mods/")
  
  ; user wants to install this mod! Therefore, find a possible file name!
  i = 0
  FileTarget$ = *modinfo\id$ + "." + GetExtensionPart(File$)
  While FileSize(misc::Path(TF$ + "TFMM/Mods/") + FileTarget$) > 0
    ; try to find a filename which does not exist
    i = i + 1
    FileTarget$ = *modinfo\id$ + "_" + Str(i) + "." + GetExtensionPart(File$)
  Wend
  
  ; import file to mod folder
  If Not CopyFile(File$, misc::Path(TF$ + "TFMM/Mods/") + FileTarget$)
    ; Copy error
    FreeStructure(*modinfo)
    ProcedureReturn #False 
  EndIf
  
  ; extract images etc
  ExtractModInformation(*modinfo, misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$))
  
  *modinfo\file$ = FileTarget$
  
  WriteModToIni(*modinfo)
  
  count = CountGadgetItems(ListInstalled)
  With *modinfo
    ListIcon::AddListItem(ListInstalled, count, \name$ + Chr(10) + \authors$ + Chr(10) + \category$ + Chr(10) + \version$)
    ListIcon::SetListItemData(ListInstalled, count, *modinfo)
    If \active
      ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("yes")))
    Else
      ListIcon::SetListItemImage(ListInstalled, count, ImageID(images::Images("no")))
    EndIf
  EndWith
  
  AddToQueue(#QueueActionActivate, *modinfo)
EndProcedure

Procedure ExportModListHTML(all, File$)
  Protected file, i
  Protected *modinfo.mod
  Protected author$
  
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
          author$ = ""
          ForEach \author()
            If author$ <> ""
              author$ + ", "
            EndIf
            author$ + \author()\name$
          Next
          WriteString(file, "<tr><td>" + \name$ + "</td><td>" + \version$ + "</td><td>" + author$ + "</td></tr>", #PB_UTF8)
        EndIf
      EndWith
      
    Next i
    WriteString(file, "</table>", #PB_UTF8)
    WriteString(file, "<footer><article><a href='http://goo.gl/utB3xn'>TFMM</a> &copy; 2014-"+FormatDate("%yyyy",Date())+" <a href='http://www.alexandernaehring.eu/'>Alexander Nähring</a></article></footer>", #PB_UTF8)
    
    WriteString(file, "</body></html>", #PB_UTF8)
    CloseFile(file)
    
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        RunProgram(File$)
      CompilerCase #PB_OS_Linux
        RunProgram("xdg-open", File$, "")
    CompilerEndSelect
  EndIf
EndProcedure

Procedure ExportModListTXT(all, File$)
  Protected file, i
  Protected *modinfo.mod
  Protected author$
  
  WriteStringN(file, "Mod" + Chr(9) + "Version" + Chr(9) + "Author", #PB_UTF8)
               
  file = CreateFile(#PB_Any, File$)
  If file
    For i = 0 To CountGadgetItems(ListInstalled) - 1
      *modinfo = ListIcon::GetListItemData(ListInstalled, i)
      With *modinfo
        If all Or \active
          author$ = ""
          ForEach \author()
            If author$ <> ""
              author$ + ", "
            EndIf
            author$ + \author()\name$
          Next
          WriteStringN(file, \name$ + Chr(9) + \version$ + Chr(9) + author$, #PB_UTF8)
        EndIf
      EndWith
      
    Next i    
    CloseFile(file)
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        RunProgram(File$)
      CompilerCase #PB_OS_Linux
        RunProgram("xdg-open", File$, "")
    CompilerEndSelect
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
; CursorPosition = 70
; FirstLine = 46
; Folding = AIARz
; Markers = 1320
; EnableUnicode
; EnableXP