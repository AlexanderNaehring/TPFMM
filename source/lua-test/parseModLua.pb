IncludeFile "lua.pbi"

Global NewMap translations$()


ProcedureC LUA_Translate(L)
  *string = luaL_checkstring(L, -1)
  
  If Not *string
    Debug "lua error: no string address in lua_translate()"
    lua_pushstring(L, "invalid argument!")
    ProcedureReturn 1 ; number of arguments pushed
  EndIf
  
  string$ = PeekS(*string, -1, #PB_Ascii)
  
  ; find translation
  If FindMapElement(translations$(), string$)
    string$ = translations$(string$)
  EndIf
  
	lua_pushstring(L, string$)
	ProcedureReturn 1
EndProcedure



Procedure getAuthors(L, index)
  
EndProcedure

Procedure getTags(L, index)
  
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
      key$ = PeekS(*key, -1, #PB_Ascii)
    Else
      key$ = ""
    EndIf
    
    If key$
      val$ = ""
      val = 0
      *val = lua_tostring(L, -2)
      If *val
        val$ = PeekS(*val, -1, #PB_Ascii)
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
      Case "tags"
        Debug "tags..."
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


Procedure iterateDataTable(L, index)
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
    
    If *key And PeekS(*key, -1, #PB_Ascii) = "info" And lua_istable(L, -2)
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


Procedure openModLua(L)
  ; with help of http://stackoverflow.com/questions/6137684/iterate-through-lua-table
  
  ; open and parse mod.lua
  If luaL_dofile(L, "mod/mod.lua") <> 0
    Debug "lua error: "+PeekS(lua_tostring(L, -1), -1, #PB_Ascii)
    lua_pop(L, -1)
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
    Debug "lua error: "+PeekS(lua_tostring(L, -1), -1, #PB_Ascii)
    lua_pop(L, -1)
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
  iterateDataTable(L, -1)
   
   
   ; stack is like before table iteration, with original table on top of stack
   lua_pop(L, 1)
   
   
EndProcedure





Global L = luaL_newstate()

luaL_openlibs(L)

; enable _() function
lua_pushcfunction(L, @LUA_Translate())
lua_setglobal(L, "_")


; first step: parse strings and save to translation!
; todo


; luaopen_base(L)	; base lib laden , fuer print usw

        
openModLua(L)

lua_close(L)
