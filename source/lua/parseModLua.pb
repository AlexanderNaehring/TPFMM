IncludeFile "lua.pbi"


Structure strings ; individual strings per language
  name$                   ; name of mod
  description$            ; description of mod
  List tags$()
EndStructure

Structure author
  
EndStructure


Structure mod           ;-- information about mod/dlc
  foldername$           ; folder name in game: id_version or steam workshop ID
  Map strings.strings()   ; all localized strings
  majorVersion.i          ; first part of version number, identical to version in foldername
  minorVersion.i          ; latter part of version number
  version$                ; major.minor
  severityAdd$            ; potential impact to game when adding mod
  severityRemove$         ; potential impact to game when removeing mod
  List authors.author()   ; information about author(s)
  url$                    ; website with further information
EndStructure



Structure language
  Map translate$()
EndStructure
Global NewMap language.language()
Global _language$


ProcedureC LUA_Translate(L)
  *string = luaL_checkstring(L, -1)
  
  If Not *string
    Debug "lua error: no string address in lua_translate()"
    lua_pushstring(L, "invalid argument!")
    ProcedureReturn 1 ; number of arguments pushed
  EndIf
  
  string$ = PeekS(*string, -1, #PB_UTF8)
  
  ; find translation for current language
  If _language$ = ""
    Debug "lua_translate: fallback to englisch"
    _language$ = "en"
  EndIf
  
  If FindMapElement(language(_language$)\translate$(), string$)
    string$ = language(_language$)\translate$(string$)
  Else
    ; cannot find translation for _language$, try fallback to en
    If _language$ <> "en"
      If FindMapElement(language("en")\translate$(), string$)
        string$ = language("en")\translate$(string$)
      EndIf
    EndIf
  EndIf
  
	lua_pushstring(L, string$)
	ProcedureReturn 1
EndProcedure

Procedure getAuthor(L, index)
  ; for more comments, see iterateInfoTable()
  lua_pushvalue(L, index) ; copy table
  
  If Not lua_istable(L, -1)
    Debug "lua error: authors not table"
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  lua_pushnil(L)
  While lua_next(L, -2)
    lua_pushvalue(L, -2)
    ; stack: -1 => key; -2 => value; -3 => key; -4 => table
    
    *key    = lua_tostring(L, -1)
    
    If *key
      key$ = PeekS(*key, -1, #PB_UTF8)
      val$ = ""
      val = 0
      *val = lua_tostring(L, -2)
      If *val
        val$ = PeekS(*val, -1, #PB_UTF8)
      EndIf
      val = lua_tointeger(L, -2)
    
      Select key$
        Case "name"
          Debug "   name:  "+val$
        Case "role"
          Debug "   role:  "+val$
        Case "text"
          Debug "   text:  "+val$
        Case "steamProfile"
          Debug "   steam: "+val
        Case "tfnetId"
          Debug "   tfnet: "+val
      EndSelect
    EndIf
    
    ; pop value + copy of key, leaving original key
    lua_pop(L, 2)
    ; ready for next iteration
   Wend
   ; Pop table (copy)
   lua_pop(L, 1)
EndProcedure

Procedure getAuthors(L, index)
  ; for more comments, see iterateInfoTable()
  lua_pushvalue(L, index) ; copy table
  
  If Not lua_istable(L, -1)
    Debug "lua error: authors not table"
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  lua_pushnil(L)
  While lua_next(L, -2)
    lua_pushvalue(L, -2)
    ; stack: -1 => key; -2 => value; -3 => key; -4 => table
    
    If lua_istable(L, -2) ; value
      Debug "author:"
      getAuthor(L, -2)
    EndIf
    
    ; pop value + copy of key, leaving original key
    lua_pop(L, 2)
   Wend
   ; Pop table (copy)
   lua_pop(L, 1)
EndProcedure

Procedure getTags(L, index)
  Debug "tags:"
  lua_pushvalue(L, index) 
  
  If Not lua_istable(L, -1)
    Debug "lua error: tags not table"
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  lua_pushnil(L)
  While lua_next(L, -2)
    *val = lua_tostring(L, -1) ; value at -1
    If *val
      val$ = PeekS(*val, -1, #PB_UTF8)
      If val$
        Debug "   "+val$
      EndIf
    EndIf
    lua_pop(L, 1) ; pop value
   Wend
   lua_pop(L, 1)
EndProcedure

Procedure iterateInfoTable(L, index)
  lua_pushvalue(L, index) ; push info-table to top of stack (copy)
  ; stack now contains: -1 => table
  lua_pushnil(L) ; initial key (nil)
  ; stack now contains: -1 => nil; -2 => table
  While lua_next(L, -2) ; iterate through table with key/table at -1/-2
    ; stack now contains: -1 => value; -2 => key; -3 => table
    ; copy the key so that lua_tostring does not modify the original
    lua_pushvalue(L, -2)
    ; stack now contains: -1 => key; -2 => value; -3 => key; -4 => table
    
    *key    = lua_tostring(L, -1)
    
    If *key 
      key$ = PeekS(*key, -1, #PB_UTF8)
    Else
      key$ = ""
    EndIf
    
    If key$
      val$ = ""
      val = 0
      *val = lua_tostring(L, -2)
      If *val
        val$ = PeekS(*val, -1, #PB_UTF8)
      EndIf
      val = lua_tointeger(L, -2)
    EndIf
    
    Select key$
      Case "name"
        Debug "name:         "+val$
      Case "description"
        Debug "description:  "+val$
      Case "minorVersion"
        Debug "minorVersion: "+val
      Case "authors"
        getAuthors(L, -2)
      Case "tags"
        getTags(L, -2)
      Default
        Debug "pair: "+key$+" => "+val$
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
    *key    = lua_tostring(L, -1)
    ; only looking for key, value not of interest
    
    If *key And PeekS(*key, -1, #PB_UTF8) = "info" And lua_istable(L, -2)
      ; info table found!
      Debug "info table found"
      
      ; iterate over info table!
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


Procedure readStringsTranslations(L, index, language$)
  ; comments in iterateModDataTable()
  lua_pushvalue(L, index)
  lua_pushnil(L)
  While lua_next(L, -2)
    lua_pushvalue(L, -2)
    *key    = lua_tostring(L, -1)
    
    If *key
      key$ = PeekS(*key, -1, #PB_UTF8)
      
      *val = lua_tostring(L, -2)
      If *val
        val$ = PeekS(*val, -1, #PB_UTF8)
        language(language$)\translate$(key$) = val$
      EndIf
      
    EndIf
    
    lua_pop(L, 2)
   Wend
   lua_pop(L, 1)
EndProcedure

Procedure iterateStringsDataTable(L, index)
  ; comments in iterateModDataTable()
  lua_pushvalue(L, index)
  lua_pushnil(L)
  While lua_next(L, -2)
    lua_pushvalue(L, -2)
    *key    = lua_tostring(L, -1)
    
    If *key And lua_istable(L, -2)
      ; new language found
      key$ = PeekS(*key, -1, #PB_UTF8)
      Debug "found strings for language '"+key$+"'"
      
      readStringsTranslations(L, -2, key$)
      
    EndIf
    
    lua_pop(L, 2)
   Wend
   lua_pop(L, 1)
EndProcedure


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Procedure openModLua(L)
  ; with help of http://stackoverflow.com/questions/6137684/iterate-through-lua-table
  
  ; open and parse mod.lua
  If luaL_dofile(L, "mod/mod.lua") <> 0
    Debug "lua error: "+PeekS(lua_tostring(L, -1), -1, #PB_UTF8)
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  ; get "data()" function
  lua_getglobal(L, "data")
  If Not lua_isfunction(L, -1)
    lua_pop(L, 1)
    Debug "lua error: data not a function"
    ProcedureReturn #False
  EndIf
  
  ; call data()
  If lua_pcall(L, 0, 1, 0) <> 0 ; call with 0 arguments and 1 result expected
    Debug "lua error: "+PeekS(lua_tostring(L, -1), -1, #PB_UTF8)
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  ; check that return value is a table
  If Not lua_istable(L, -1)
    Debug "lua error: return value not a table"
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  ; return of data() is table and on top of stack!
  
  ; iterate over data-table and search for "info" key!
  ; -1 = location of data-table... proceedure will leave stack as it is after finish
  iterateModDataTable(L, -1)
   
  ; stack is like before table iteration, with original table on top of stack
  lua_pop(L, 1)
  
EndProcedure


Procedure openStringsLua(L)
  ; open and parse strings.lua
  If luaL_dofile(L, "mod/strings.lua") <> 0
    Debug "lua error: "+PeekS(lua_tostring(L, -1), -1, #PB_UTF8)
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  ; get "data()" function
  lua_getglobal(L, "data")
  If Not lua_isfunction(L, -1)
    lua_pop(L, 1)
    Debug "lua error: data not a function"
    ProcedureReturn #False
  EndIf
  
  ; call data()
  If lua_pcall(L, 0, 1, 0) <> 0 ; call with 0 arguments and 1 result expected
    Debug "lua error: "+PeekS(lua_tostring(L, -1), -1, #PB_UTF8)
    lua_pop(L, 1)
    ProcedureReturn #False
  EndIf
  
  ; check that return value is a table
  If Not lua_istable(L, -1)
    Debug "lua error: return value not a table"
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




Global L = luaL_newstate()

; luaL_openlibs(L) ; basic libs
; luaopen_base(L)	; base lib laden , fuer print usw

; first step: parse strings and save to translation!
openStringsLua(L)

lua_pushcfunction(L, @LUA_Translate())
lua_setglobal(L, "_")

; read mod for all available languages
; also add "en" if not available (as default/fallback)
If Not FindMapElement(language(), "en")
  AddMapElement(language(), "en")
  ; no translations available here! -> will return standard text
EndIf

ForEach language()
  _language$ = MapKey(language())
  Debug ""
  Debug ">> set language to "+_language$
  openModLua(L)
Next



lua_close(L)
