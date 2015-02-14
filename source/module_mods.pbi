XIncludeFile "module_ListIcon.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"
XIncludeFile "module_images.pbi"
XIncludeFile "module_unrar.pbi"
XIncludeFile "module_locale.pbi"

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
    categoryDisplay$
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
  
  Structure filetrackerEntry
    file$
    md5$
    required.b
  EndStructure
  
  Structure filetracker
    mod$
    file.filetrackerEntry
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
  
Procedure checkTFPath(Dir$)
  If Dir$
    If FileSize(Dir$) = -2
      Dir$ = misc::Path(Dir$)
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
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
      CompilerElse
        If FileSize(Dir$ + "TrainFever") > 1
          If CreateFile(0, Dir$ + "TFMM.tmp")
            CloseFile(0)
            DeleteFile(Dir$ + "TFMM.tmp")
            ProcedureReturn #True
          EndIf
          ProcedureReturn -1
        EndIf
      CompilerEndIf
    EndIf
  EndIf
  ProcedureReturn #False
EndProcedure

  
  Procedure CreateID(*modinfo.mod)
    debugger::Add("CreateID("+Str(*modinfo)+")")
    Protected id$, name$, author$, author_tmp$
    Static RegExp
    If Not RegExp
      RegExp = CreateRegularExpression(#PB_Any, "[^A-Za-z0-9]") ; non-alphanumeric characters
      ; regexp matches all non alphanum characters including spaces etc.
    EndIf
    
    With *modinfo
      LastElement(\author())
      Repeat
        author_tmp$ = LCase(ReplaceRegularExpression(RegExp, \author()\name$, "")) ; remove all non alphanum + make lowercase
        If author_tmp$ <> ""
          If author$ <> ""
            author$ + "."
          EndIf
          author$ + author_tmp$
        EndIf
      Until Not PreviousElement(\author())
      If author$ = ""
        author$ = "unknown"
      EndIf
      
      name$ = "unknown"
      If \name$
        name$ = LCase(ReplaceRegularExpression(RegExp, \name$, "")) ; remove all non alphanum + make lowercase
      EndIf
      
      id$ = author$ + "." + name$
      
      \id$ = id$
    EndWith
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure ValidateID(*modinfo.mod)
    Protected id$
    
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    
    Static RegExp
    If Not RegExp : RegExp = CreateRegularExpression(#PB_Any, "^([a-z0-9]+\.)+[a-z0-9]+$") : EndIf ; ID match TODO : case-sensitive?
    
    With *modinfo
      \id$ = LCase(\id$)
      If Not MatchRegularExpression(RegExp, \id$) ; if regexp matches, ID is valid, if not -> create new ID
        CreateID(*modinfo)
      EndIf
    EndWith
    ProcedureReturn #True 
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
          
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActionNew: " + File$)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\File$ = File$
        UnlockMutex(MutexQueue)
        
      Case #QueueActionActivate
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActionActivate: " + *modinfo\name$)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\modinfo = *modinfo
        UnlockMutex(MutexQueue)
        
      Case #QueueActionDeactivate
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActionDeactivate: " + *modinfo\name$)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\modinfo = *modinfo
        UnlockMutex(MutexQueue)
        
      Case #QueueActionUninstall
        If Not *modinfo
          ProcedureReturn #False
        EndIf
        
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActionUninstall: " + *modinfo\name$)
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
          debugger::Add("LoadModList() - {"+\name$+"}")
          \file$ = ReadPreferenceString("file", "")
          If \file$ = ""
            ; no valid mod
            ; free memory and continue with next entry
            FreeStructure(*modinfo)
            Continue
          EndIf
          
          ClearList(\author())
          \id$ = ReadPreferenceString("id", "") ; ID will be checked and rewritten after reading name & author
          \name$ = ReadPreferenceString("name", \name$)
          author$ = ReadPreferenceString("author", "")
          author$ = ReplaceString(author$, "/", ",")
          \version$ = ReadPreferenceString("version", "")
          \category$ = ReadPreferenceString("category", "")
          \categoryDisplay$ = l("category", \category$)
          
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
          
          ValidateID(*modinfo) ; check ID and create new if neccessary
          
          count = CountGadgetItems(ListInstalled)
          ListIcon::AddListItem(ListInstalled, count, \name$ + Chr(10) + \authors$ + Chr(10) + \categoryDisplay$ + Chr(10) + \version$); + Chr(10) + active$)
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
      debugger::Add("ExtractModZip() - error opening pack "+File$)
      ProcedureReturn #False 
    EndIf
    
    If Not ExaminePack(zip)
      debugger::Add("ExtractModZip() - error examining pack "+File$)
      ProcedureReturn #False
    EndIf
    
    Path$ = misc::Path(Path$)
    
    While NextPackEntry(zip)
      ; filter out Mac OS X bullshit
      If FindString(PackEntryName(zip), "__MACOSX") Or FindString(PackEntryName(zip), ".DS_Store") Or Left(GetFilePart(PackEntryName(zip)), 2) = "._"
        debugger::Add("ExtractModZip() - skip "+PackEntryName(zip))
        Continue
      EndIf
      
      If PackEntryType(zip) = #PB_Packer_File And PackEntrySize(zip) > 0
        If FindString(PackEntryName(zip), "res/") ; only extract files to list which are located in subfoldres of res/
          File$ = PackEntryName(zip)
          File$ = Mid(File$, FindString(File$, "res/")) ; let all paths start with "res/" (if res is located in a subfolder!)
          ; adjust path delimiters to OS
          File$ = misc::Path(GetPathPart(File$)) + GetFilePart(File$)
          misc::CreateDirectoryAll(GetPathPart(Path$ + File$))
          If UncompressPackFile(zip, Path$ + File$, PackEntryName(zip)) = 0
            debugger::Add("ExtractModZip() - ERROR: uncrompressing zip: '"+PackEntryName(zip)+"' to '"+Path$ + File$+"' failed!")
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
      
      ; filter out Mac OS X bullshit
      If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
        debugger::Add("ExtractModRar() - skip "+Entry$)
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; skip these files / entries
        Continue
      EndIf
      
      If FindString(Entry$, "res\") ; only extract files to list which are located in subfoldres of res
        Entry$ = Entry$
        Entry$ = Mid(Entry$, FindString(Entry$, "res\")) ; let all paths start with "res\" (if res is located in a subfolder!)
        Entry$ = misc::Path(GetPathPart(Entry$)) + GetFilePart(Entry$) ; translate to correct delimiter: \ or /
  
        If unrar::RARProcessFile(hRAR, unrar::#RAR_EXTRACT, #NULL$, Path$ + Entry$) <> unrar::#ERAR_SUCCESS ; uncompress current file to modified tmp path
          debugger::Add("ExtractModRar() - ERROR: uncrompressing rar: '"+File$+"' failed!")
        EndIf
      Else
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; file not in "res", skip it
      EndIf
      
    Wend
    unrar::RARCloseArchive(hRAR)
  
    ProcedureReturn #True
  EndProcedure
  
  Procedure ActivateThread_ReadFiles(dir$, List files$())
    Protected dir, Entry$
    
    dir$ = misc::Path(dir$)
    
    dir = ExamineDirectory(#PB_Any, dir$, "")
    If Not dir
      ProcedureReturn #False
    EndIf
    
    While NextDirectoryEntry(dir)
      Entry$ = DirectoryEntryName(dir)
      If DirectoryEntryType(dir) = #PB_DirectoryEntry_Directory ; DIR: recursively call function, ignore ., .., __MACOS
        If Entry$ <> "." And Entry$ <> ".." And Entry$ <> "__MACOS"
          ActivateThread_ReadFiles(dir$ + Entry$, files$())
        EndIf
      ElseIf DirectoryEntryType(dir) = #PB_DirectoryEntry_File  ; FILE: add file to list, ignore .DS_Store, thumbs.db
        If Entry$ <> ".DS_Store" And LCase(Entry$) <> "thumbs.db"
          debugger::Add("ActivateThread_ReadFiles() - add file to list {" + dir$ + Entry$ + "}")
          AddElement(files$())
          files$() = dir$ + Entry$
        EndIf
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
      InstallInProgress = #False
      ProcedureReturn #False
    EndIf
    
    If *modinfo\active
      InstallInProgress = #False
      ProcedureReturn #False
    EndIf
    
    
    Protected dir, i, CopyFile, isModded, error, count, ok, time
    Protected NewList Files$(), NewList FileTracker.filetracker()
    Protected Backup$, File$, Mod$, tmpDir$, extension$, ReqMod$, ReqVer$
    Protected *tmpinfo.mod
    Protected NewMap strings$()
    
    With *modinfo
      Mod$ = misc::Path(TF$ + "TFMM/Mods") + \file$
      tmpDir$ = misc::Path(TF$ + "TFMM/mod_tmp")
      
      debugger::Add("ActivateThread() - id={"+\id$+"} name={"+\name$+"} file={"+\file$+"}")
      
      ; --------------------------------------------------------------------------------------------------
      ; check dependencies
      
      debugger::Add("ActivateThread() - ##### checking dependencies #####")
      SetGadgetText(GadgetModText, l("management", "dependencies"))
      
      ForEach \dependencies$()
        debugger::Add("ActivateThread() - check dependency {"+MapKey(\dependencies$())+"}")
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
            If *tmpinfo\name$ = ReqMod$ Or *tmpinfo\id$ = ReqMod$ ; TODO ID check as only option? - other option? - think about...
              If ReqVer$ = "" Or *tmpinfo\version$ = ReqVer$ Or *tmpinfo\version$ >= ReqVer$
                debugger::Add("ActivateThread() - dependency match found :)")
                ok = #True
                Break
              EndIf
            EndIf
          EndIf
        Next
        If Not ok
          debugger::Add("ActivateThread() - no match found for dependency - abort activation")
          ModProgressAnswer = #AnswerNone
          If ReqVer$
            ReqVer$ = "v" + ReqVer$ + ""
          EndIf
          
          ClearMap(strings$())
          strings$("name") = ReqMod$
          strings$("version") = ReqVer$
          SetGadgetText(GadgetModText, locale::getEx("management", "requires", strings$()))
          HideGadget(GadgetModOk, #False)
          While ModProgressAnswer = #AnswerNone
            Delay(10)
          Wend
          ; task clean up procedure
          AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
          ProcedureReturn #False
        EndIf
      Next
      
      ; --------------------------------------------------------------------------------------------------
      ; start installation
      
      debugger::Add("ActivateThread() - ##### loading modification #####")
      time = ElapsedMilliseconds()
      SetGadgetText(GadgetModText, l("management", "loading"))
      ; clean temporary directory
      debugger::Add("ActivateThread() - create temporary directoy {"+tmpDir$+"}")
      DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive | #PB_FileSystem_Force)  ; delete temp dir
      misc::CreateDirectoryAll(tmpDir$)                                            ; create temp dir
      debugger::Add("ActivateThread() - uncompress into temporary folder")
      If FileSize(tmpDir$) <> -2
        debugger::Add("ActivateThread() - failed to create temporary directory")
        ; error with tmpDir$
        ModProgressAnswer = #AnswerNone
        SetGadgetText(GadgetModText, l("management", "error_tmpdir"))
        HideGadget(GadgetModOk, #False)
        While ModProgressAnswer = #AnswerNone
          Delay(10)
        Wend
        ; task clean up procedure
        AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
        ProcedureReturn #False
      EndIf
      
      error = #False 
      extension$ = LCase(GetExtensionPart(Mod$))
      debugger::Add("ActivateThread() - check extension {"+extension$+"} and choose extractor")
      If extension$ = "zip"
        If Not ExtractModZip(Mod$, tmpDir$)
          error = #True
        EndIf
      ElseIf extension$ = "rar"
        If Not ExtractModRar(Mod$, tmpDir$)
          error = #True
        EndIf
      Else ; unknown extension
        debugger::Add("ActivateThread() - no extractor for {"+extension$+"}")
        error = #True
      EndIf
      
      If error
        ; error opening archive
        debugger::Add("ActivateThread() - error extracting modification")
        DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
        ModProgressAnswer = #AnswerNone
        SetGadgetText(GadgetModText, l("management", "error_open"))
        HideGadget(GadgetModOk, #False)
        While ModProgressAnswer = #AnswerNone
          Delay(10)
        Wend
        ; task clean up procedure
        AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
        ProcedureReturn #False
      EndIf
      
      
      ; mod should now be extracted to temporary directory tmpDir$
      debugger::Add("ActivateThread() - reading modification content into file list")
      ClearList(files$())
      If Not ActivateThread_ReadFiles(tmpDir$, files$()) ; add all files from tmpDir to files$()
        ; error opening tmpDir$
        DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive|#PB_FileSystem_Force)  ; delete temp dir
        ModProgressAnswer = #AnswerNone
        SetGadgetText(GadgetModText, l("management", "error_reading"))
        HideGadget(GadgetModOk, #False)
        While ModProgressAnswer = #AnswerNone
          Delay(10)
        Wend
        ; task clean up procedure
        AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
        ProcedureReturn #False
      EndIf
      
      debugger::Add("ActivateThread() - found "+Str(ListSize(files$()))+" files for activation")
      debugger::Add("ActivateThread() - loaded modification in "+Str(ElapsedMilliseconds()-time)+"ms")
      
      Backup$ = misc::Path(TF$ + "TFMM/Backup/")
      debugger::Add("ActivateThread() - backup folder for vanilla game files {"+Backup$+"}")
      misc::CreateDirectoryAll(Backup$)
      
      
      ; --------------------------------------------------------------------------------------------------
      ; load filetracker list
      debugger::Add("ActivateThread() - ##### load filetracker #####")
      time = ElapsedMilliseconds()
      ClearList(FileTracker())
      OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
      ExaminePreferenceGroups()
      While NextPreferenceGroup()
        PreferenceGroup(PreferenceGroupName())
        ExaminePreferenceKeys()
        While NextPreferenceKey()
          AddElement(FileTracker())
          FileTracker()\file\file$ = PreferenceKeyName()
          FileTracker()\file\md5$ = PreferenceKeyValue()
          FileTracker()\mod$ = PreferenceGroupName()
        Wend
      Wend
      ClosePreferences()
      debugger::Add("ActivateThread() - filetracker found "+Str(ListSize(FileTracker()))+" files in "+Str(ElapsedMilliseconds()-time)+"ms")
      
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Minimum, 0)
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Maximum, ListSize(files$()))
      SetGadgetState(GadgetModProgress, 0)
      HideGadget(GadgetModProgress, #False)
      i = 0
      ModProgressAnswer = #AnswerNone
      
      ; --------------------------------------------------------------------------------------------------
      ; process all files
      debugger::Add("ActivateThread() - ##### process files #####")
      time = ElapsedMilliseconds()
      ForEach Files$()
        Delay(0) ; let the CPU breath
        File$ = Files$()
        File$ = misc::Path(GetPathPart(File$)) + GetFilePart(File$)
        File$ = RemoveString(File$, tmpDir$) ; File$ contains only the relative path of mod
        
        ClearMap(strings$())
        strings$("file") = GetFilePart(File$)
        SetGadgetText(GadgetModText, locale::getEx("management", "processing", strings$()))
        
        ; normal case: copy the modificated file to game directoy
        CopyFile = #True
        isModded = #False
        
        ; check filetracker for any other mods that may have modified this file before
        ForEach FileTracker()
          ; compare files from filetracker with files from new mod
          
          If LCase(FileTracker()\file\file$) = LCase(File$) ; check also other cases (for case insensitive filesystems - all mods should be case sensitive but should work with insensitive environments like windows)
            debugger::Add("ActivateThread() - found conflict match in filetracker {"+File$+"}")
            ; file found in list of already installed files
            CopyFile = #False
            isModded = #True
            
            If MD5FileFingerprint(TF$ + File$) = MD5FileFingerprint(Files$())
              debugger::Add("ActivateThread() - installed file is identical to new file")
              ; check if md5 of already installed modded file is identical to new modded file
              ; if file has same md5 -> save to overwrite (since it is already the same file)
              If ModProgressAnswer <> #AnswerYesAll And ModProgressAnswer <> #AnswerNoAll
                ; choose anser only if user has not already selected a "to all" answer
                ; yes all -> file is copied anyway
                ; no all -> no file is copied (respect users answer in this case)
                ; file is added to filetracker in any case
                ModProgressAnswer = #AnswerYes
              EndIf
            EndIf
            
            ; ask user if file should be overwritten
            If ModProgressAnswer = #AnswerNone
              ; only ask again if user has not selected "yes/no to all" before or md5 match 
              ClearMap(strings$())
              strings$("file") = GetFilePart(FileTracker()\file\file$)
              strings$("name") = FileTracker()\mod$
              SetGadgetText(GadgetModText, locale::getEx("management", "overwrite", strings$()))
              HideGadget(GadgetModYes, #False)
              HideGadget(GadgetModNo, #False)
              HideGadget(GadgetModYesAll, #False)
              HideGadget(GadgetModNoAll, #False)
              While ModProgressAnswer = #AnswerNone
                Delay(10)
              Wend
              ClearMap(strings$())
              strings$("file") = GetFilePart(File$)
              SetGadgetText(GadgetModText, locale::getEx("management", "processing", strings$()))
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
            ; this also works with automatic overwrite in case of MD5 match since only the currently installed file is checked
          EndIf
        Next
        
        ; --------------------------------------------------------------------------------------------------
        ; copy file
        
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
            debugger::Add("ActivateThread() - copy file {"+File$+"}")
          Else
            debugger::Add("ActivateThread() - ERROR: failed to move file: {("+Files$()+"} -> {"+TF$+File$+"}")
          EndIf
        EndIf
        
        ; --------------------------------------------------------------------------------------------------
        ; Add to filetracker -> Even if file is NOT copied, it is still required by the modification -> add in any case!
        
        OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
        PreferenceGroup(\name$) ; TODO : may overwrite entry here (only in case of other errors, since no two mods are allowed to have the same name)
        ; TODO : change to \id$ (have to update all old entries in order to do this)
        ; write md5 of _NEW_ file in order to keep track of all files that have been changed by this mod
        WritePreferenceString(File$, MD5FileFingerprint(TF$ + File$))
        ClosePreferences()
        
        ; --------------------------------------------------------------------------------------------------
        i = i + 1 ; count files for progress bar
        SetGadgetState(GadgetModProgress, i)
      Next
      debugger::Add("ActivateThread() - processed files in "+Str(ElapsedMilliseconds()-time)+"ms")
      SetGadgetText(GadgetModText, "")
      
      ; --------------------------------------------------------------------------------------------------
      ; install finished
      debugger::Add("ActivateThread() - ##### finish activation #####")
      HideGadget(GadgetModProgress, #True)
      If Not DeleteDirectory(tmpDir$, "", #PB_FileSystem_Recursive | #PB_FileSystem_Force)  ; delete temp dir
        debugger::Add("ActivateThread() - ERROR: failed to remove tmpDir$ {"+tmpDir$+"}")
      EndIf
      
      ; activate mod in mod list
      \active = #True
      WriteModToIni(*modinfo) ; update mod entry
      
      
      ; task clean up procedure
      debugger::Add("ActivateThread() - activation finished successfully")
      AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
      ProcedureReturn #True 
    EndWith
  EndProcedure
  
  Procedure DeactivateThread(*modinfo.mod)
    debugger::Add("DeactivateThread("+Str(*modinfo)+")")
    If Not *modinfo
      InstallInProgress = #False
      ProcedureReturn #False
    EndIf
    
    If Not *modinfo\active
      InstallInProgress = #False
      ProcedureReturn #False
    EndIf
    
    Protected File$, md5$, Backup$
    Protected NewList Files.filetrackerEntry(), NewList Filetracker.filetracker()
    Protected count, countAll, countReq, i, time
    Protected *tmpinfo.mod
    Protected NewMap strings$()
    
    debugger::Add("DeactivateThread() - id={"+*modinfo\id$+"} name={"+*modinfo\name$+"}")
    
    debugger::Add("DeactivateThread() - ##### check dependencies #####")
    SetGadgetText(GadgetModText, l("management", "dependencies"))
    count = CountGadgetItems(ListInstalled)
    For i = 0 To count-1
      *tmpinfo = ListIcon::GetListItemData(ListInstalled, i)
      With *tmpinfo
        If \active
          ForEach \dependencies$()
            If MapKey(\dependencies$()) = *modinfo\name$ Or MapKey(\dependencies$()) = *modinfo\id$ ; TODO - ID system!
              ; this mod is required by another active mod!
              debugger::Add("DeactivateThread() - ERROR: this mod is required required by id={"+\id$+"} name={"+\name$+"}")
              ModProgressAnswer = #AnswerNone
              ClearMap(strings$())
              strings$("name") = \name$
              SetGadgetText(GadgetModText, locale::getEx("management", "required", strings$()))
              HideGadget(GadgetModYes, #False)
              HideGadget(GadgetModNo, #False)
              While ModProgressAnswer = #AnswerNone
                Delay(10)
              Wend
              If ModProgressAnswer = #AnswerYes
                ; queue deactivation of this mod
                ; continue loop!
                debugger::Add("DeactivateThread() - queue deactivation {"+\name$+"}")
                AddToQueue(#QueueActionDeactivate, *tmpinfo)
                SetGadgetText(GadgetModText, l("management", "dependencies"))
                HideGadget(GadgetModYes, #True)
                HideGadget(GadgetModNo, #True)
              Else
                ; if user does not want to deactivate this mod -> cancel deactivation
                debugger::Add("DeactivateThread() - abort deactivation")
                ; task clean up procedure
                AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
                ProcedureReturn #False
              EndIf
            EndIf
          Next
        EndIf 
      EndWith
    Next
    
    SetGadgetText(GadgetModText, l("management", "loading"))
    
    ; read list of files from ini file
    debugger::Add("DeactivateThread() - ##### load filetracker #####")
    time = ElapsedMilliseconds()
    ClearList(FileTracker())
    ClearList(Files())
    OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
    ExaminePreferenceGroups()
    While NextPreferenceGroup()
      PreferenceGroup(PreferenceGroupName())
      If PreferenceGroupName() = *modinfo\name$ ; TODO change to ID?
        ; filetracker of current mod!
        ; add to "files()" list
        ExaminePreferenceKeys()
        While NextPreferenceKey()
          AddElement(Files())
          Files()\file$ = PreferenceKeyName()
          Files()\md5$ = PreferenceKeyValue()
        Wend
      Else
        ; filetracker of other mods!
        ; add to "filertracker()" list
        ExaminePreferenceKeys()
        While NextPreferenceKey()
          AddElement(FileTracker())
          FileTracker()\file\file$ = PreferenceKeyName()
          Filetracker()\file\md5$ = PreferenceKeyValue()
          FileTracker()\mod$ = PreferenceGroupName()
        Wend
      EndIf
    Wend
    ClosePreferences()
    debugger::Add("DeactivateThread() - filetracker: found " + Str(ListSize(FileTracker())) + " files in "+Str(ElapsedMilliseconds()-time)+"ms")
    
    debugger::Add("DeactivateThread() - filetracker: filecheck")
    time = ElapsedMilliseconds()
    ResetList(Files())
    countAll = ListSize(Files())
    countReq = 0
    ForEach Files()
      ; check all Files of the mod about to be deactivated
      Files()\required = #False ; init: assume file is not required by other mods
      ForEach Filetracker()
        If LCase(Files()\file$) = LCase(Filetracker()\file\file$) ; TODO case sensitive?
          ; the same file is required by another mod currently activated
          Files()\required = #True
          countReq + 1
          Break
        EndIf
      Next
    Next
    count = countAll - countReq
    debugger::Add("DeactivateThread() - filetracker: filecheck finished in"+Str(ElapsedMilliseconds()-time)+"ms")
    debugger::Add("DeactivateThread() - filetracker: "+Str(countReq)+"/"+Str(countAll)+" files are required by other mods")
    debugger::Add("DeactivateThread() - filetracker: deactivate "+Str(count)+" files")
    
    ; --------------------------------------------------------------------------------------------------
    ; start deactivation
    With *modinfo
      Backup$ = misc::Path(TF$ + "TFMM/Backup/")
      debugger::Add("DeactivateThread() - backup folder {"+Backup$+"}")
      misc::CreateDirectoryAll(Backup$)
      i = 0
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Minimum, 0)
      SetGadgetAttribute(GadgetModProgress, #PB_ProgressBar_Maximum, ListSize(Files()))
      HideGadget(GadgetModProgress, #False)
      
      
      debugger::Add("DeactivateThread() - ##### process files #####")
      time = ElapsedMilliseconds()
      ForEach Files()
        If files()\required ; do not touch files required by other mods
          Continue
        EndIf
        
        File$ = Files()\file$
        
        ClearMap(strings$())
        strings$("file") = GetFilePart(File$)
        SetGadgetText(GadgetModText, locale::getEx("management", "processing", strings$()))
        
        ; delete file
        debugger::Add("DeactivateThread() - delete file: "+File$)
        DeleteFile(TF$ + File$,  #PB_FileSystem_Force)
        
        ; restore backup if any
        If FileSize(Backup$ + File$) >= 0
          debugger::Add("DeactivateThread() - restore backup: "+File$)
          RenameFile(Backup$ + File$, TF$ + File$)
        EndIf
        
        i = i + 1
        SetGadgetState(GadgetModProgress, i)
      Next
      debugger::Add("DeactivateThread() - processing took "+Str(ElapsedMilliseconds()-time)+"ms")
      
      SetGadgetText(GadgetModText, "")
      HideGadget(GadgetModProgress, #True)
      
      debugger::Add("DeactivateThread() - remove mod from filetracker")
      SetGadgetText(GadgetModText, "Cleanup...")
      
      ; update filetracker. All files that are currently altered by this mod have been removed (restored) -> delete all entries from filetracker
      OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      
      debugger::Add("DeactivateThread() - update modinfo")
      \active = #False
      WriteModToIni(*modinfo) ; update mod entry
      
    EndWith
    
    debugger::Add("DeactivateThread() - deactivation finished successfully!")
    AddWindowTimer(WindowModProgress, TimerFinishUnInstall, 100)
    ProcedureReturn #False
  EndProcedure
  
  Procedure ShowProgressWindow(*modinfo.mod)
    Protected NewMap var$()
    
    var$("name") = *modinfo\name$
    var$("id") = *modinfo\id$
    If *modinfo\active
      SetWindowTitle(WindowModProgress, locale::getEx("management", "deactivate", var$()))
    Else
      SetWindowTitle(WindowModProgress, locale::getEx("management", "activate", var$()))
    EndIf
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
    debugger::Add("RemoveModFromList("+Str(*modinfo)+")")
    Protected i
    
    If Not *modinfo
      ProcedureReturn #False
    EndIf
    If *modinfo\active
      debugger::Add("RemoveModFromList() - ERROR: mod "+Str(*modinfo)+" is still active - cancel uninstall")
      ProcedureReturn #False
    EndIf
    
    InstallInProgress = #True
    
    With *modinfo
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mods.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mod-dependencies.ini")
      RemovePreferenceGroup(\name$)
      ClosePreferences()
      
      debugger::Add("RemoveModFromList() - delete file " + *modinfo\file$)
      DeleteFile(misc::Path(TF$ + "TFMM/Mods/") + *modinfo\file$, #PB_FileSystem_Force)
      debugger::Add("RemoveModFromList() - delete dir  " + *modinfo\id$)
      DeleteDirectory(misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$), "", #PB_FileSystem_Recursive | #PB_FileSystem_Force)
      
      For i = 0 To CountGadgetItems(ListInstalled) - 1
        If *modinfo = ListIcon::GetListItemData(ListInstalled, i)
          debugger::Add("RemoveModFromList() - remove list item " + Str(i))
          ListIcon::RemoveListItem(ListInstalled, i)
          FreeStructure(*modinfo)
          InstallInProgress = #False
          debugger::Add("RemoveModFromList() - finished!")
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
  Files$() = "header.jpg" ; backwards compatibility
  
  File$ = misc::Path(TF$ + "TFMM/Mods/") + *modinfo\file$
  misc::CreateDirectoryAll(Path$)
  
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


Procedure ExtractFilesZip(ZIP$, List Files$(), dir$) ; extracts all Files$() (from all subdirs!) to given directory
  debugger::Add("ExtractFilesZip("+ZIP$+", Files$(), "+dir$+")")
  debugger::Add("ExtractFilesZip() - search for:")
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
        
        If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
          debugger::Add("ExtractFilesZip() - skip "+Entry$)
          Continue
        EndIf
        
        ForEach Files$()
          If LCase(Entry$) = LCase(Files$()) Or LCase(Right(Entry$, Len(Files$())+1)) = "/" + LCase(Files$())
            debugger::Add("ExtractFilesZip() - UncompressPackFile("+dir$ + Files$()+")")
            UncompressPackFile(zip, dir$ + Files$())
            DeleteElement(Files$()) ; if file is extracted, delete from list
            Break ; ForEach
          EndIf
        Next
      Wend
    EndIf
    ClosePack(zip)
  Else
    debugger::Add("ExtractFilesZip() - Error opnening zip: "+ZIP$)
  EndIf
EndProcedure

Procedure ExtractFilesRar(RAR$, List Files$(), dir$) ; extracts all Files$() (from all subdirs!) to given directory
  debugger::Add("ExtractFilesRar("+RAR$+", Files$(), "+dir$+")")
  debugger::Add("ExtractFilesRar() - search for:")
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
      
      ; filter out Mac OS X bullshit
      If FindString(Entry$, "__MACOSX") Or FindString(Entry$, ".DS_Store") Or Left(GetFilePart(Entry$), 2) = "._"
        debugger::Add("ExtractFilesRar() - skip "+Entry$)
        unrar::RARProcessFile(hRAR, unrar::#RAR_SKIP, #NULL$, #NULL$) ; skip these files / entries
        Continue
      EndIf
      
      hit = #False
      ForEach Files$()
        If LCase(Entry$) = LCase(Files$()) Or LCase(Right(Entry$, Len(Files$())+1)) = "\" + LCase(Files$())
          debugger::Add("ExtractFilesRar() - RARProcessFile("+dir$ + Files$()+")")
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
    debugger::Add("ExtractFilesRar() - Error opnening rar: "+RAR$)
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
    DeleteFile(tmpDir$ + "tfmm.ini", #PB_FileSystem_Force) ; clean old tfmm.ini if exists
                                                           ; TODO Check If tfmm.ini is deleted?
    
    Protected NewList Files$()
    AddElement(Files$())
    Files$() = "tfmm.ini"
    If extension$ = "zip"
      ExtractFilesZip(File$, Files$(), tmpDir$)
    ElseIf extension$ = "rar"
      ExtractFilesRar(File$, Files$(), tmpDir$)
    EndIf
    ClearList(Files$())
    
    OpenPreferences(tmpDir$ + "tfmm.ini")
    ; Read required TFMM version
    If ReadPreferenceInteger("tfmm", #PB_Editor_CompileCount) > #PB_Editor_CompileCount
      MessageRequester("Newer version of TFMM required", "Please update TFMM in order to have full functionality!" + #CRLF$ + "Select 'File' -> 'Update' to check for newer versions.")
    EndIf
    
    \id$ = ReadPreferenceString("id", "") ; ID will be checked after reading name & author
    \name$ = ReadPreferenceString("name", \name$)
    \name$ = ReplaceString(ReplaceString(\name$, "[", "("), "]", ")")
    \version$ = ReadPreferenceString("version", \version$)
    author$ = ReadPreferenceString("author", "")
    author$ = ReplaceString(author$, "/", ",")
    \category$ = ReadPreferenceString("category", "")
    \categoryDisplay$ = l("category",\category$)
    
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
    
    ValidateID(*modinfo)
    
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
  
  *modinfo\file$ = FileTarget$
  
  ; extract images etc
  ExtractModInformation(*modinfo, misc::Path(TF$ + "TFMM/Mods/" + *modinfo\id$))
  WriteModToIni(*modinfo)
  
  count = CountGadgetItems(ListInstalled)
  With *modinfo
    ListIcon::AddListItem(ListInstalled, count, \name$ + Chr(10) + \authors$ + Chr(10) + \categoryDisplay$ + Chr(10) + \version$)
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
    
    misc::openLink(File$)
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
    
    misc::openLink(File$)
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
; CursorPosition = 447
; FirstLine = 92
; Folding = CQBIC+
; EnableUnicode
; EnableXP