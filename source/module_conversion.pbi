XIncludeFile "module_misc.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_mods.pbi"


DeclareModule conversion
  EnableExplicit
  
  Declare convert(TF$)
EndDeclareModule


Module conversion
  EnableExplicit
  
  Structure mod
    name$
    info.mods::mod
    List files$()
  EndStructure
  
  Procedure convert(TF$)
    debugger::Add("conversion::convert("+TF$+")")
    Protected NewList mods.mod(), NewMap allFiles$()
    Protected file$
    
    If FileSize(misc::Path(TF$ + "TFMM") + "filetracker.ini") < 0
      ; filetracker not present -> no old mods active
      ProcedureReturn #False
    EndIf
    
    ; open filetracker to read all installed and activated files from res folder
    OpenPreferences(misc::Path(TF$ + "TFMM") + "filetracker.ini")
    ExaminePreferenceGroups()
    While NextPreferenceGroup()
      ; preference group = mod name
      AddElement(mods())
      mods()\name$ = PreferenceGroupName()
      ExaminePreferenceKeys()
      While NextPreferenceKey()
        ; preference key = file name
        file$ = PreferenceKeyName()
        If FileSize(misc::Path(TF$ + "/" + GetPathPart(file$) + "/") + GetFilePart(file$)) >= 0
          AddElement(mods()\files$())
          mods()\files$() = file$
          allFiles$(PreferenceKeyName()) = "true"
        Else
          debugger::Add("conversion::convert() - file {"+file$+"} not found")
          ;TODO error when file not found? -> may be indicator, that another manager already moved mods
        EndIf
      Wend
    Wend
    ClosePreferences()
    
    If ListSize(mods()) > 0
      If MessageRequester(locale::l("conversion","title"), locale::l("conversion","start"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
        MessageRequester(locale::l("conversion","title"), locale::l("conversion","legacy"))
        End
      EndIf
    EndIf
    
    debugger::Add("conversion::convert() - starting one-time conversion...")
    debugger::Add("conversion::convert() - found "+Str(ListSize(mods()))+" mods for conversion")
    
    ForEach mods()
      debugger::Add("conversion::convert() - converting mod {"+mods()\name$+ "}...")
      
      ; read mod info from mods.ini
      OpenPreferences(misc::Path(TF$ + "TFMM") + "mods.ini")
      PreferenceGroup(mods()\name$)
      
      Protected *mod.mods::mod
      *mod = mods::initMod()
      With *mod
        \aux\file$  = ReadPreferenceString("id","")
        \id$    = ReadPreferenceString("id","")
        \name$  = ReadPreferenceString("name","")
        \aux\version$ = ReadPreferenceString("version","")
        \majorVersion   = Val(StringField(\aux\version$, 1, "."))
        \minorVersion   = Val(StringField(\aux\version$, 2, "."))
        Protected count.i, i.i
        \aux\author$ = ReadPreferenceString("author","")
        \aux\tfnet_author_id$ = ReadPreferenceString("online_tfnet_author_id","")
        If \aux\author$
          count  = CountString(\aux\author$, ",") + 1
          For i = 1 To count
            AddElement(\authors())
            \authors()\name$ = Trim(StringField(\aux\author$, i, ","))
            If i = 1
              \authors()\role$ = "CREATOR"
            Else
              \authors()\role$ = "CO_CREATOR"
            EndIf
            \authors()\tfnetId = Val(Trim(StringField(\aux\tfnet_author_id$, i, ",")))
          Next i
        EndIf
        Protected tags$
        tags$ = ReadPreferenceString("category", "")
        If tags$
          count  = CountString(tags$, "/") + 1
          For i = 1 To count
            AddElement(\tags$())
            \tags$() = Trim(StringField(tags$, i, "/"))
          Next i
        EndIf
        \tfnetId = ReadPreferenceInteger("online_tfnet_mod_id", 0)
      EndWith
      
      ; generate / change / validate ID
      mods::generateID(*mod)
      ; generate info.lua
      mods::generateLUA(*mod)
      
      Protected dir$, old$, new$, backup$, info_lua$, info_lua.i
      
      ; create directory:
      dir$ = misc::Path(TF$ + "mods/" + *mod\id$ + "/")
      misc::CreateDirectoryAll(dir$)
      info_lua$ = dir$+"info.lua"
      
      ; write lua
      debugger::Add("conversion::convert() - write LUA -> {"+info_lua$+"}")
      info_lua = CreateFile(#PB_Any, info_lua$)
      If info_lua
        WriteString(info_lua, *mod\aux\lua$, #PB_UTF8)
        CloseFile(info_lua)
      EndIf
      
      ; move files to new dir
      debugger::Add("conversion::convert() - copy "+Str(ListSize(mods()\files$()))+" files")
      ForEach mods()\files$()
        old$ = TF$ + mods()\files$()
        new$ = dir$ + mods()\files$()
;         debugger::Add("conversion::convert() - copy: {"+old$+"} -> {"+new$+"}")
;         CopyFile(old$, new$)
      Next ; files
    Next ; mods
    
    ; delete all old files
    debugger::Add("conversion::convert() - delete "+Str(MapSize(allFiles$()))+" old files and restore possible backups")
    backup$ = misc::Path(TF$ + "/TFMM/Backup/")
    ForEach allFiles$()
      file$ = MapKey(allFiles$())
      old$ = TF$ + file$
;       debugger::Add("conversion::convert() - delete {"+old$+"}")
;       DeleteFile(old$, #PB_FileSystem_Force)
      If FileSize(backup$ + file$) >= 0
;         debugger::Add("conversion::convert() - restore {"+backup$ + file$+"}")
        
;         RenameFile(backup$ + file$, old$)
      EndIf
    Next
    
    ; delete filetracker
    debugger::Add("conversion::convert() - delete filetracker")
;     DeleteFile(misc::Path(TF$ + "TFMM") + "filetracker.ini")
    
    MessageRequester(locale::l("conversion","title"), locale::l("conversion","finish"))
  EndProcedure
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 93
; FirstLine = 58
; Folding = -
; EnableUnicode
; EnableXP