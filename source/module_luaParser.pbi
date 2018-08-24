CompilerIf #PB_Compiler_IsMainFile
  XIncludeFile "module_main.pbi"
CompilerEndIf

XIncludeFile "module_lua.pbi"
XIncludeFile "module_mods.h.pbi"

DeclareModule luaParser
  EnableExplicit
  
  Declare parseModLua(modfolder$, *mod, language$="")
  Declare parseSettingsLua(modfolder$, Map settings.mods::modSetting(), language$="")
  
EndDeclareModule

XIncludeFile "module_locale.pbi"
XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"

Module luaParser
  UseModule lua
  UseModule debugger
  
  CreateDirectory("lua")
  
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      CompilerIf #PB_Compiler_Processor=#PB_Processor_x64
        #LUA_FILE = "lua/lua53.dll"
      CompilerEndIf
    CompilerCase #PB_OS_Linux
      CompilerIf #PB_Compiler_Processor=#PB_Processor_x64
        #LUA_FILE = "lua/liblua53.so"
      CompilerEndIf
  CompilerEndSelect
  
  DataSection
    dataLua:
    IncludeBinary #LUA_FILE
    dataLuaEnd:
  EndDataSection
  misc::extractBinary(#LUA_FILE, ?dataLua, ?dataLuaEnd - ?dataLua, #False)
  
  
  If Not Lua_Initialize("lua/")
    deb("lua:: cannot load lua")
    End
  EndIf
  
  Structure language
    Map translation$()
  EndStructure
  
  Structure lua
    language$ ; currently used language for translations
    Map languages.language() ; map of all languages in strings.lua
    *mod.mods::LocalMod
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
      deb("lua:: no string pointer")
      lua_pushstring(L, "[[invalid argument]]")
      ProcedureReturn 1 ; number of arguments pushed
    EndIf
    
    string$ = PeekS(*string, -1, #PB_UTF8)
    
    With lua(Str(L))
    
      ; find translation for current language
      lang$ = \language$
      If lang$ = ""
        deb("lua:: no language set, fallback to english")
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
  
  Procedure.s getTableValue(L, index)
    Protected value$
    If lua_isboolean(L, index)
      If lua_toboolean(L, index)
        value$ = "true"
      Else
        value$ = "false"
      EndIf
    ElseIf lua_isnumber(L, index)
      value$ = StrD(lua_tonumber(L, index))
    Else
      value$ = lua_tostring(L, index)
      value$ = ReplaceString(value$, "\", "\\")
      value$ = ReplaceString(value$, #DQUOTE$, "\"+#DQUOTE$)
      value$ = #DQUOTE$+value$+#DQUOTE$
    EndIf
    ProcedureReturn value$
  EndProcedure
  
  
  ;- mod.lua related functions
  
  ; mod.lua -> data -> info
  
  Procedure modlua_getAuthor(L, index)
    Protected key$, val$, val
    ; for more comments, see modlua_iterateInfoTable()
    lua_pushvalue(L, index) ; copy table
    
    If Not lua_istable(L, -1)
      deb("lua:: lua_istable ERROR: not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    Protected *author.mods::author
    *author = lua(Str(L))\mod\addAuthor()
    
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
  
  Procedure modlua_getAuthors(L, index)
    ; for more comments, see modlua_iterateInfoTable()
    lua_pushvalue(L, index) ; copy table
    
    If Not lua_istable(L, -1)
      deb("lua:: authors not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; authors found, delete old authors
    lua(Str(L))\mod\clearAuthors()
    
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      ; stack: -1 => key; -2 => value; -3 => key; -4 => table
      
      If lua_istable(L, -2) ; value
        modlua_getAuthor(L, -2)
      EndIf
      
      ; pop value + copy of key, leaving original key
      lua_pop(L, 2)
     Wend
     ; Pop table (copy)
     lua_pop(L, 1)
  EndProcedure
  
  Procedure modlua_getTags(L, index)
    Protected val$
    lua_pushvalue(L, index) 
    
    If Not lua_istable(L, -1)
      deb("lua:: tags not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    lua(Str(L))\mod\clearTags()
    
    lua_pushnil(L)
    While lua_next(L, -2)
      val$ = lua_tostring(L, -1) ; value at -1
      If val$
        lua(Str(L))\mod\addTag(val$)
      EndIf
      lua_pop(L, 1) ; pop value
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure modlua_getDependencies(L, index)
    Protected val$
    lua_pushvalue(L, index) 
    
    If Not lua_istable(L, -1)
      deb("lua:: dependencies not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    lua(Str(L))\mod\clearDependencies()
    
    lua_pushnil(L)
    While lua_next(L, -2)
      val$ = lua_tostring(L, -1)
      If val$
        lua(Str(L))\mod\addDependency(val$)
      EndIf
      lua_pop(L, 1)
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure modlua_iterateInfoTable(L, index)
    Protected key$, val$
    Protected *mod.mods::LocalMod
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
          val$ =  lua_tostring(L, -2)
          
          *mod\setName(val$)
        Case "description"
          *mod\setDescription(lua_tostring(L, -2))
        Case "minorVersion"
          *mod\setMinorVersion(lua_tointeger(L, -2))
        Case "authors"
          modlua_getAuthors(L, -2)
        Case "tags"
          modlua_getTags(L, -2)
        Case "visible"
          *mod\setHidden(Bool(Not lua_toboolean(L, -2)))
        Case "tfnetId"
          ; only store if <> zero (especially: do not overwrite info saved during install)
          If lua_tointeger(L, -2) <> 0
            *mod\setTFNET(lua_tointeger(L, -2))
          EndIf
        Case "steamId"
          If lua_tointeger(L, -2) <> 0
            *mod\setWorkshop(lua_tointeger(L, -2))
          EndIf
        Case "workshop"
          If lua_tointeger(L, -2) <> 0
            *mod\setWorkshop(lua_tointeger(L, -2))
          EndIf
        Case "dependencies"
          modlua_getDependencies(L, -2)
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
  
  ; mod.lua -> data -> settings
  
  Procedure modlua_readSettingsDefaultTable(L, index, *setting.mods::modLuaSetting)
    Protected value$
    
    ; format: tables in table:
    ; default = { value1, value2, value3 }
    
    lua_pushvalue(L, index)
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      
      ; key$ = lua_tostring(L, -1) ; key is not used
      ; read value in correct format (apply same formatting as used for "tableValues")
      value$ = getTableValue(L, -2)
      
      If value$
        AddElement(*setting\tableDefaults$())
        *setting\tableDefaults$() = value$
      EndIf
      
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
    
  EndProcedure
  
  Procedure modlua_readSettingsValuesTable(L, index, *setting.mods::modLuaSetting)
    ; read the possible values for the "table" type mod setting
    Protected key$, text$, value$
    
    ; format: tables in table:
    ; values = {
    ;   { name = "name", value = 1, },
    ;   { name = "other", value = false },
    ; },
    
    lua_pushvalue(L, index)
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      
      text$   = ""
      value$  = ""
      
      ; -> the table hold multiple tables...
      ; key = 1,2,3,4,...
      ; value = table
      lua_pushvalue(L, -2)
      lua_pushnil(L)
      While lua_next(L, -2)
        lua_pushvalue(L, -2)
        
        key$ = lua_tostring(L, -1)
        Select key$
          Case "text"
            text$ = lua_tostring(L, -2)
          Case "value"
            ; already format all values correctly depending on their type (string with ", boolean as true/false, ...)
            value$ = getTableValue(L, -2)
        EndSelect
        
        lua_pop(L, 2)
      Wend
      lua_pop(L, 1)
      ; end of "inner" table
      
      If text$ And value$
        AddElement(*setting\tableValues())
        *setting\tableValues()\text$  = text$
        *setting\tableValues()\value$ = value$
      EndIf
      
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
    
  EndProcedure
  
  Procedure modlua_readSettingsTableOption(L, index, *setting.mods::modLuaSetting)
    Protected key$
    
    lua_pushvalue(L, index)
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      
      key$    = lua_tostring(L, -1)
      
      Select key$
        Case "type"
          ; boolean, string, number
          *setting\type$ = lua_tostring(L, -2)
        Case "default"
          If lua_isboolean(L, -2)
            ; lua_toString cannot typecast "boolean", do typecast here: true = 1, false = 0
            *setting\default$ = Str(lua_toboolean(L, -2))
          ElseIf lua_istable(L, -2) ; default value is a table -> read all defaults...
            ; default table type values, values saved in table
            modlua_readSettingsDefaultTable(L, -2, *setting)
          Else
            *setting\default$ = lua_tostring(L, -2)
          EndIf
        Case "name"
          *setting\name$ = lua_tostring(L, -2)
        Case "description"
          *setting\description$ = lua_tostring(L, -2)
        Case "image"
          *setting\image$ = lua_tostring(L, -2)
;         Case "subtype"
;           settings()\subtype$ = lua_tostring(L, -2)
        Case "min"
          *setting\min = lua_tonumber(L, -2)
        Case "max"
          *setting\max = lua_tonumber(L, -2)
        Case "multiSelect"
          *setting\multiSelect = lua_toboolean(L, -2)
        Case "values"
          modlua_readSettingsValuesTable(L, -2, *setting)
        Case "order"
          *setting\order = lua_tonumber(L, -2)
          
        Default
          
      EndSelect
      
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure modlua_iterateSettingsTable(L, index)
    Protected key$
    Protected *setting.mods::modLuaSetting,
              *modSetting.mods::modLuaSetting
    Protected order.i
    Protected *mod.mods::LocalMod
    *mod = lua(Str(L))\mod
    
    ; clear list bevor reading new settings...
    *mod\clearSettings()
    
    lua_pushvalue(L, index) 
    lua_pushnil(L)
    While lua_next(L, -2) 
      lua_pushvalue(L, -2)
      
      key$ = lua_tostring(L, -1) ; name of this parameter
      
      *setting = AllocateStructure(mods::modLuaSetting)
      *setting\key$ = key$
      
      *setting\order = order
      order + 1
      
      ; default values
      *setting\min = -2147483648
      *setting\max =  2147483647
      *setting\multiSelect = #True
      
      ; read type, default value and name of this parameter
      modlua_readSettingsTableOption(L, -2, *setting) 
      
      Protected addToMod = #True
      Select *setting\type$
        Case "boolean"
        Case "string"
        Case "number"
        Case "table"
        Default
          addToMod = #False
      EndSelect
      If *setting\name$ = ""
        addToMod = #False
      EndIf
      
      If addToMod
        *modSetting = *mod\addSetting()
        CopyStructure(*setting, *modSetting, mods::modLuaSetting)
      EndIf
      
      FreeStructure(*setting)
      
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
     
     *mod\sortSettings()
     
  EndProcedure
  
  ; mod.lua -> data
  
  Procedure modlua_iterateDataTable(L, index)
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
        modlua_iterateInfoTable(L, -2)
        
      ElseIf lua_tostring(L, -1) = "settings" And lua_istable(L, -2)
        modlua_iterateSettingsTable(L, -2)
        
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
  
  ; mod.lua 
  
  Procedure modlua_open(L, file$)
    ; with help of http://stackoverflow.com/questions/6137684/iterate-through-lua-table
    
    ; open and parse mod.lua
    removeBOM(file$)
    If luaL_dofile(L, file$) <> 0
      deb("lua:: lua_dofile: {"+lua_tostring(L, -1)+"} in file {"+file$+"}")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; get "data()" function
    lua_getglobal(L, "data")
    If Not lua_isfunction(L, -1)
      lua_pop(L, 1)
      deb("lua:: lua_isfunction: 'data' is not a function")
      ProcedureReturn #False
    EndIf
    
    ; call data()
    If lua_pcall(L, 0, 1, 0) <> 0 ; call with 0 arguments and 1 result expected
      deb("lua:: lua_pcall: "+lua_tostring(L, -1))
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; check that return value is a table
    If Not lua_istable(L, -1)
      deb("lua:: data return value not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; return of data() is table and on top of stack!
    
    ; iterate over data-table and search for "info" key!
    ; -1 = location of data-table... proceedure will leave stack as it is after finish
    modlua_iterateDataTable(L, -1)
     
    ; stack is like before table iteration, with original table on top of stack
    lua_pop(L, 1)
    ProcedureReturn #True
  EndProcedure
  
  ;- strings.lua related functions
  
  Procedure stringslua_readStringTranslations(L, index, language$)
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
  
  Procedure stringslua_iterateDataTable(L, index)
    Protected key$
    ; comments in iterateModDataTable()
    lua_pushvalue(L, index)
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      key$ = lua_tostring(L, -1)
      If key$ And lua_istable(L, -2)
        ; new language found
        stringslua_readStringTranslations(L, -2, key$)
      EndIf
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure openStringsLua(L, file$)
    ; open and parse strings.lua
    removeBOM(file$)
    If luaL_dofile(L, file$) <> 0
      deb("lua::openStringsLua() - lua_dofile: {"+lua_tostring(L, -1)+"} in file {"+file$+"}")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; get "data()" function
    lua_getglobal(L, "data")
    If Not lua_isfunction(L, -1)
      lua_pop(L, 1)
      deb("lua::openStringsLua() - lua_isfunction: data is not a function")
      ProcedureReturn #False
    EndIf
    
    ; call data()
    If lua_pcall(L, 0, 1, 0) <> 0 ; call with 0 arguments and 1 result expected
      deb("lua::openStringsLua() - lua_pcall: "+lua_tostring(L, -1))
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; check that return value is a table
    If Not lua_istable(L, -1)
      deb("lua::openStringsLua() - lua_istable: not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    ; return of data() is table and on top of stack!
    
    ; iterate over data-table and search for "info" key!
    ; -1 = location of data-table... proceedure will leave stack as it is after finish
    stringslua_iterateDataTable(L, -1)
     
    ; stack is like before table iteration, with original table on top of stack
    lua_pop(L, 1)
    
  EndProcedure
  
  ;- settings.lua related functions
  
  Procedure settingslua_readTable(L, index, Map settings.mods::modSetting())
    Protected key$, val$
    lua_pushvalue(L, index)
    lua_pushnil(L)
    While lua_next(L, -2)
      lua_pushvalue(L, -2)
      
      key$ = lua_tostring(L, -1)
      If lua_istable(L, -2)
        ;fill settings(key$)\value$()
        
        ; start table
        lua_pushvalue(L, -2)
        lua_pushnil(L)
        While lua_next(L, -2)
          lua_pushvalue(L, -2)
          
          val$ = getTableValue(L, -2)
          If val$
            AddElement(settings(key$)\values$())
            settings(key$)\values$() = val$
          EndIf
          
          lua_pop(L, 2)
        Wend
        lua_pop(L, 1)
        ; end table
        
        
      Else
        If lua_isboolean(L, -2)
          val$ = Str(lua_toboolean(L, -2))
        Else
          val$ = lua_tostring(L, -2)
        EndIf
        settings(key$)\value$ = val$
      EndIf
      
      lua_pop(L, 2)
     Wend
     lua_pop(L, 1)
  EndProcedure
  
  Procedure openSettingsLua(L, file$, Map settings.mods::modSetting())
    ; read settings.lua (user settings for mod)
    removeBOM(file$)
    
    If luaL_dofile(L, file$) <> 0
      deb("lua:: lua_dofile: {"+lua_tostring(L, -1)+"} in file {"+file$+"}")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    If Not lua_istable(L, -1)
      deb("lua:: settings not a table")
      lua_pop(L, 1)
      ProcedureReturn #False
    EndIf
    
    settingslua_readTable(L, -1, settings())
     
    lua_pop(L, 1)
    ProcedureReturn #True
    
  EndProcedure
  
  ;- init
  
  Procedure initLUA(modfolder$)
    Protected L
    Protected tmp$, string$
    
    L = luaL_newstate()
    
    ; basic libs (require, ...)
    luaL_openlibs(L) 
;     luaopen_base(L)	; base lib laden , fuer print usw
    
    ; add search path for require function:
    tmp$ = misc::path(settings::getString("", "path"), "/")
    string$ = "package.path = '"+tmp$+"res/config/?.lua;"+tmp$+"res/scripts/?.lua;"+misc::path(modfolder$, "/")+"res/scripts/?.lua';"
    luaL_dostring(L, string$)
    
    ; make translation function known to lua global
    lua_pushcfunction(L, @lua_translate())
    lua_setglobal(L, "_")
    
    ; nil some os calls
    string$ = "os.execute = nil; os.remove = nil;"
    luaL_dostring(L, string$)
    
    ; register dummy functions
    string$ = "function addFileFilter() end; function addModifier() end;"
    luaL_dostring(L, string$)
    
    
    ; initialize variable storage for this lua state
    AddMapElement(lua(), Str(L))
    
    
    
    ProcedureReturn L
  EndProcedure
  
  ;- PUBLIC FUNCTIONS
  
  Procedure parseModLua(modfolder$, *mod.mods::LocalMod, language$="")
    If modfolder$ = "" Or FileSize(modfolder$) <> -2
      deb("lua:: {"+modfolder$+"} not found")
      ProcedureReturn #False
    EndIf
    
    If Not *mod
      deb("lua:: no *mod pointer provided")
      ProcedureReturn #False
    EndIf
    
    If language$=""
      language$ = locale::getCurrentLocale()
    EndIf
    
    Protected stringsLua$, modLua$
    Protected string$, tmp$
    modfolder$  = misc::path(modfolder$)
    modLua$     = modfolder$ + "mod.lua"
    stringsLua$ = modfolder$ + "strings.lua"
    
    If FileSize(modLua$) <= 0
      deb("lua:: {"+modLua$+"} not found")
      ProcedureReturn #False
    EndIf
    
    ; start
    Protected L
    L = initLUA(modfolder$)
    
    lua(Str(L))\language$ = language$
    lua(Str(L))\mod = *mod
    
    ; first step: parse strings and save to translation!
    If FileSize(stringsLua$) > 0
      openStringsLua(L, stringsLua$)
    EndIf
    
    
    Protected success = #False
    
    If modlua_open(L, modLua$)
      *mod\setLuaDate(GetFileDate(modLua$, #PB_Date_Modified))
      *mod\setLuaLanguage(locale::getCurrentLocale())
      
      success = #True
    Else
      deb("lua:: could not read "+modLua$)
    EndIf
    
    DeleteMapElement(lua(), Str(L))
    lua_close(L)
    
    ProcedureReturn success
  EndProcedure
  
  Procedure parseSettingsLua(modfolder$, Map settings.mods::modSetting(), language$="")
    modfolder$ = misc::path(modfolder$)
    
    Protected settingsLua$ = modfolder$ + "settings.lua"
    Protected stringsLua$ = modfolder$ + "strings.lua"
    
    If FileSize(settingsLua$) <= 0
      ProcedureReturn #False
    EndIf
    
    If language$ = ""
      language$ = locale::getCurrentLocale()
    EndIf
    
    Protected L
    L = initLUA(modfolder$)
    
    lua(Str(L))\language$ = language$
    
    If FileSize(stringsLua$) > 0
      openStringsLua(L, stringsLua$)
    EndIf
    
    openSettingsLua(L, settingsLua$, settings())
    
    DeleteMapElement(lua(), Str(L))
    lua_close(L)
    
  EndProcedure
  
EndModule



CompilerIf #PB_Compiler_IsMainFile
  Define *mod.mods::mod
  *mod = AllocateStructure(mods::mod)
  
  luaParser::parseModLua("lua/mod/", *mod, "de")
  
  Define json
  json = CreateJSON(#PB_Any)
  InsertJSONStructure(JSONValue(json), *mod, mods::mod)
  Debug ComposeJSON(json, #PB_JSON_PrettyPrint)
  FreeJSON(json)
CompilerEndIf
