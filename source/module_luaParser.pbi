CompilerIf #PB_Compiler_IsMainFile
  XIncludeFile "module_main.pbi"
CompilerEndIf

XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_lua.pbi"

DeclareModule luaParser
  EnableExplicit
  
  Declare parseModLua(modfolder$, *mod.mods::mod, language$="")
  
EndDeclareModule


XIncludeFile "module_locale.pbi"
XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"



Module luaParser
  UseModule lua
  
  CreateDirectory("lua")
  
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      DataSection
        dataLua:
        IncludeBinary "lua/lua53_x86.dll"
        dataLuaEnd:
      EndDataSection
      misc::extractBinary("lua/lua53_x86.dll", ?dataLua, ?dataLuaEnd - ?dataLua, #False)
      
    CompilerCase #PB_OS_Linux
      DataSection
        dataLua:
        IncludeBinary "lua/liblua53.so"
        dataLuaEnd:
      EndDataSection
      
      misc::extractBinary("lua/liblua53.so", ?dataLua, ?dataLuaEnd - ?dataLua, #False)
      
    CompilerDefault
      CompilerError "no dynamic libary for this OS"
  CompilerEndSelect
  
  
  
  If Not Lua_Initialize("lua/")
    debugger::add("lua::Lua_Initialize() - ERROR: cannot load lua")
    End
  EndIf
  
  Structure language
    Map translation$()
  EndStructure
  
  Structure lua
    language$ ; currently used language for translations
    Map languages.language() ; map of all languages in strings.lua
    *mod.mods::mod
  EndStructure
  
  Global NewMap lua.lua()
  
  Procedure removeBOM(file$)
    Protected file, bom
    Protected content$
    
    If FileSize(file$) > 0
      file = OpenFile(#PB_Any, file$)
    EndIf
    
    If Not file
      ProcedureReturn #False
    EndIf
    
    bom = ReadStringFormat(file)
    
    Select bom
      Case #PB_Ascii ; no bom found (ASCII or utf-8?)
        CloseFile(file)
        ProcedureReturn #True
        
      Case #PB_UTF8 ; utf-8 BOM found...
        content$ = ReadString(file, #PB_UTF8|#PB_File_IgnoreEOL)
        
      Case #PB_Unicode ; unicode BOM UTF-16 LE
        content$ = ReadString(file, #PB_Unicode|#PB_File_IgnoreEOL)
        
      Default
        ; UTF16 BE, UTF32, UTF32 BE not supported...
        ProcedureReturn #False
    EndSelect
    
    CloseFile(file)
    file = CreateFile(#PB_Any, file$)
    If Not file
      ProcedureReturn #False
    EndIf
    
    WriteString(file, content$, #PB_UTF8)
    
    CloseFile(file)
    ProcedureReturn #True
  EndProcedure
  
  ProcedureC lua_dummy(L)
    lua_pop(L, 1)
    lua_pushnil(L)
    ProcedureReturn 1
  EndProcedure
  
  ProcedureC lua_translate(L)
    Protected *string, string$, lang$
    *string = luaL_checkstring(L, -1)
    lua_pop(L, 1); pop argument
    
    If Not *string
      debugger::add("lua::lua_translate() - LUA ERROR: no string pointer")
      lua_pushstring(L, "[[invalid argument]]")
      ProcedureReturn 1 ; number of arguments pushed
    EndIf
    
    string$ = PeekS(*string, -1, #PB_UTF8)
    
    With lua(Str(L))
    
      ; find translation for current language
      lang$ = \language$
      If lang$ = ""
        debugger::add("lua::lua_translate() - no language set, fallback to english")
        lang$ = "en"
      EndIf
      
      If FindMapElement(\languages(lang$)\translation$(), string$)
        string$ = \languages(lang$)\translation$(string$)
      Else
        ; cannot find translation for lang$, try fallback to en
        If lang$ <> "en"
          If FindMapElement(\languages("en")\translation$(), string$)
            string$ = \languages("en")\translation$(string$)
          EndIf
        EndIf
      EndIf
    EndWith
    
  	lua_pushstring(L, string$)
  	ProcedureReturn 1
  EndProcedure
  
  
  
  Procedure getAuthor(L, index)
    Protected key$, val$, val
    ; for more comments, see iterateInfoTable()
    lua_pushvalue(L, index) ; copy table
    
    If Not lua_istable(L, -1)
      debugger::add("lua::getAuthor() - lua_istable ERROR: not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    Protected *author.mods::author
    ListSize( lua(Str(L))\mod\authors())
    *author = AddElement(lua(Str(L))\mod\authors())
    
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      ; stack: -1 => key; -2 => value; -3 => key; -4 => table
      
      key$    = lua_tostring(L, -1)
      
      If key$
        val$ = lua_tostring(L, -2)
        val = lua_tointeger(L, -2)
      
        Select key$
          Case "name"
            *author\name$ = val$
          Case "role"
            *author\role$ = val$
          Case "text"
            *author\text$ = val$
          Case "steamProfile"
            *author\steamProfile$ = val$
          Case "steamId"
            *author\steamId = val
          Case "tfnetId"
            *author\tfnetId = val
        EndSelect
      EndIf
      
      ; pop value + copy of key, leaving original key
      lua_pop(L, 2)
      ; ready for next iteration
     Wend
     ; Pop table (copy)
     lua_pop(L, 1)
     
     ; add author to *mod
     
  EndProcedure
  
  Procedure getAuthors(L, index)
    ; for more comments, see iterateInfoTable()
    lua_pushvalue(L, index) ; copy table
    
    If Not lua_istable(L, -1)
      debugger::add("lua::getAuthors() - lua_istable ERROR: not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; authors found, delete old authors
    ClearList(lua(Str(L))\mod\authors())
    
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      ; stack: -1 => key; -2 => value; -3 => key; -4 => table
      
      If lua_istable(L, -2) ; value
        getAuthor(L, -2)
      EndIf
      
      ; pop value + copy of key, leaving original key
      lua_pop(L, 2)
     Wend
     ; Pop table (copy)
     lua_pop(L, 1)
  EndProcedure
  
  Procedure getTags(L, index)
    Protected val$
    lua_pushvalue(L, index) 
    
    If Not lua_istable(L, -1)
      debugger::add("lua::getTags() - lua_istable ERROR: not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    lua_pushnil(L)
    While lua_next(L, -2)
      val$ = lua_tostring(L, -1) ; value at -1
      If val$
        AddElement(lua(Str(L))\mod\tags$())
        lua(Str(L))\mod\tags$() = val$
      EndIf
      lua_pop(L, 1) ; pop value
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure iterateInfoTable(L, index)
    Protected key$
    Protected *mod.mods::mod
    *mod = lua(Str(L))\mod
    
    lua_pushvalue(L, index) ; push info-table to top of stack (copy)
    ; stack now contains: -1 => table
    lua_pushnil(L) ; initial key (nil)
    ; stack now contains: -1 => nil; -2 => table
    While lua_next(L, -2) ; iterate through table with key/table at -1/-2
      ; stack now contains: -1 => value; -2 => key; -3 => table
      ; copy the key so that lua_tostring does not modify the original
      lua_pushvalue(L, -2)
      ; stack now contains: -1 => key; -2 => value; -3 => key; -4 => table
      
      key$    = lua_tostring(L, -1)
      
      Select key$
        Case "name"
          *mod\name$ = lua_tostring(L, -2)
        Case "description"
          *mod\description$ = lua_tostring(L, -2)
        Case "minorVersion"
          *mod\minorVersion = lua_tointeger(L, -2)
        Case "authors"
          getAuthors(L, -2)
        Case "tags"
          getTags(L, -2)
        Case "visible"
          *mod\aux\hidden = Bool(Not lua_toboolean(L, -2))
          
        Default
          
      EndSelect
      
      ; pop value + copy of key, leaving original key
      lua_pop(L, 2)
      ; stack now contains: -1 => key; -2 => table
      ; ready for next iteration
     Wend
     ; stack now contains: -1 => table (when lua_next returns 0 it pops the key but does not push anything.)
     ; Pop table (copy)
     lua_pop(L, 1)
  EndProcedure
  
  Procedure iterateModDataTable(L, index)
    lua_pushvalue(L, index) ; push data-table to top of stack (copy)
    ; stack now contains: -1 => table
    lua_pushnil(L) ; initial key (nil)
    ; stack now contains: -1 => nil; -2 => table
    While lua_next(L, -2) ; iterate through table with key/table at -1/-2
      ; stack now contains: -1 => value; -2 => key; -3 => table
      ; copy the key so that lua_tostring does not modify the original
      lua_pushvalue(L, -2)
      ; stack now contains: -1 => key; -2 => value; -3 => key; -4 => table
      
      If lua_tostring(L, -1) = "info" And lua_istable(L, -2)
        ; info table found!
        ; table at -2
        iterateInfoTable(L, -2)
        
      EndIf
      
      ; pop value + copy of key, leaving original key
      lua_pop(L, 2)
      ; stack now contains: -1 => key; -2 => table
      ; ready for next iteration
     Wend
     ; stack now contains: -1 => table (when lua_next returns 0 it pops the key but does not push anything.)
     ; Pop table (copy)
     lua_pop(L, 1)
  EndProcedure

  Procedure openModLua(L, file$)
    ; with help of http://stackoverflow.com/questions/6137684/iterate-through-lua-table
    
    ; open and parse mod.lua
    removeBOM(file$)
    If luaL_dofile(L, file$) <> 0
      debugger::add("lua::openModLua() - lua_dofile ERROR: {"+lua_tostring(L, -1)+"} in file {"+file$+"}")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; get "data()" function
    lua_getglobal(L, "data")
    If Not lua_isfunction(L, -1)
      lua_pop(L, 1)
      debugger::add("lua::openModLua() - lua_isfunction ERROR: data is not a function")
      ProcedureReturn #False
    EndIf
    
    ; call data()
    If lua_pcall(L, 0, 1, 0) <> 0 ; call with 0 arguments and 1 result expected
      debugger::add("lua::openModLua() - lua_pcall ERROR: "+lua_tostring(L, -1))
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; check that return value is a table
    If Not lua_istable(L, -1)
      debugger::add("lua::openModLua() - lua_istable ERROR: not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; return of data() is table and on top of stack!
    
    ; iterate over data-table and search for "info" key!
    ; -1 = location of data-table... proceedure will leave stack as it is after finish
    iterateModDataTable(L, -1)
     
    ; stack is like before table iteration, with original table on top of stack
    lua_pop(L, 1)
    ProcedureReturn #True
  EndProcedure
  
  
  
  Procedure readStringsTranslations(L, index, language$)
    Protected key$, val$
    ; comments in iterateModDataTable()
    lua_pushvalue(L, index)
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      key$     = lua_tostring(L, -1)
      If key$
        val$= lua_tostring(L, -2)
        If val$
          lua(Str(L))\languages(language$)\translation$(key$) = val$
        EndIf
      EndIf
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure iterateStringsDataTable(L, index)
    Protected key$
    ; comments in iterateModDataTable()
    lua_pushvalue(L, index)
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      key$ = lua_tostring(L, -1)
      If key$ And lua_istable(L, -2)
        ; new language found
        readStringsTranslations(L, -2, key$)
      EndIf
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure openStringsLua(L, file$)
    ; open and parse strings.lua
    removeBOM(file$)
    If luaL_dofile(L, file$) <> 0
      debugger::add("lua::openStringsLua() - lua_dofile ERROR: {"+lua_tostring(L, -1)+"} in file {"+file$+"}")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; get "data()" function
    lua_getglobal(L, "data")
    If Not lua_isfunction(L, -1)
      lua_pop(L, 1)
      debugger::add("lua::openStringsLua() - lua_isfunction ERROR: data is not a function")
      ProcedureReturn #False
    EndIf
    
    ; call data()
    If lua_pcall(L, 0, 1, 0) <> 0 ; call with 0 arguments and 1 result expected
      debugger::add("lua::openStringsLua() - lua_pcall ERROR: "+lua_tostring(L, -1))
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; check that return value is a table
    If Not lua_istable(L, -1)
      debugger::add("lua::openStringsLua() - lua_istable ERROR: not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; return of data() is table and on top of stack!
    
    ; iterate over data-table and search for "info" key!
    ; -1 = location of data-table... proceedure will leave stack as it is after finish
    iterateStringsDataTable(L, -1)
     
    ; stack is like before table iteration, with original table on top of stack
    lua_pop(L, 1)
    
  EndProcedure

  
  ; PUBLIC FUNCTIONS
  
  Procedure parseModLua(modfolder$, *mod.mods::mod, language$="")
    If modfolder$ = "" Or FileSize(modfolder$) <> -2
      debugger::add("lua::parseModLua() - Error: {"+modfolder$+"} not found")
      ProcedureReturn #False
    EndIf
    
    If Not *mod
      debugger::add("lua::parseModLua() - Error: no *mod pointer provided")
      ProcedureReturn #False
    EndIf
    
    If language$=""
      language$ = locale::getCurrentLocale()
    EndIf
    
    debugger::add("lua::parseModLua() - read {"+language$+"} from {"+modfolder$+"}")
    
    Protected stringsLua$, modLua$
    Protected string$, tmp$
    modfolder$  = misc::path(modfolder$)
    modLua$     = modfolder$ + "mod.lua"
    stringsLua$ = modfolder$ + "strings.lua"
    
    If FileSize(modLua$) <= 0
      debugger::add("lua::parseModLua() - Error: {"+modLua$+"} not found")
      ProcedureReturn #False
    EndIf
    
    ; start
    Protected L
    L = luaL_newstate()
    
    luaL_openlibs(L) ; basic libs (require, ...)
;     luaopen_base(L)	; base lib laden , fuer print usw
    
    ; initialize variable storage for this lua state
    AddMapElement(lua(), Str(L))
    lua(Str(L))\language$ = language$
    lua(Str(L))\mod = *mod
    
    ; add search path for require function:
    tmp$ = misc::path(main::gameDirectory$, "/")
    string$ = "package.path = package.path .. ';"+tmp$+"res/config/?.lua;"+tmp$+"res/scripts/?.lua;res/scripts/?.lua';"
    luaL_dostring(L, string$)
    
    ; make translation function known to lua global
    lua_pushcfunction(L, @lua_translate())
    lua_setglobal(L, "_")
    
    ; nil some os calls
    string$ = "os.execute = nil; os.remove = nil;"
    luaL_dostring(L, string$)
    
    
    ; first step: parse strings and save to translation!
    If FileSize(stringsLua$) > 0
      openStringsLua(L, stringsLua$)
    EndIf
    
    
    Protected success = #False
    
    If openModLua(L, modLua$)
      *mod\aux\luaDate = GetFileDate(modLua$, #PB_Date_Modified)
      
      success = #True
    Else
      debugger::add("lua::parseModLua() - Error: could not read mod.lua")
    EndIf
    
    DeleteMapElement(lua(), Str(L))
    lua_close(L)
    
    ProcedureReturn success
  EndProcedure
  
  
EndModule



CompilerIf #PB_Compiler_IsMainFile

  Define *mod.mods::mod
  *mod = AllocateStructure(mods::mod)
  
  lua::parseModLua("lua/mod/", *mod, "de")
  
  
  Define json
  json = CreateJSON(#PB_Any)
  InsertJSONStructure(JSONValue(json), *mod, mods::mod)
  Debug ComposeJSON(json, #PB_JSON_PrettyPrint)
  FreeJSON(json)
  
CompilerEndIf
