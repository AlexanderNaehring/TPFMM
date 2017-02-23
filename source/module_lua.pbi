

;https://www.lua.org/manual/5.3/manual.html
;http://www.fh-wedel.de/~si/seminare/ws09/Ausarbeitung/09.lua/lua0.htm

DeclareModule LUA
  EnableExplicit
  #LUA_VERSION_PUREBASIC = 533
  
  ;-{ luaconf.h
  
;   CompilerIf #PB_Compiler_Processor=#PB_Processor_x86
;     CompilerError "No 32 Bit support"
;   CompilerEndIf  
  
  ;By default, Lua on Windows use (some) specific Windows features
  CompilerIf #PB_Compiler_Processor=#PB_Processor_x86
    CompilerSelect #PB_Compiler_OS 
      CompilerCase #PB_OS_Windows
        #LUA_DLL_NAME="lua53_x86.dll"
        
      CompilerCase #PB_OS_Linux 
        #LUA_DLL_NAME="liblua53_x86.so"
        
      CompilerCase #PB_OS_MacOS
        #LUA_DLL_NAME="liblua53_x86.dylib"
        
    CompilerEndSelect
  CompilerElse
    CompilerSelect #PB_Compiler_OS 
      CompilerCase #PB_OS_Windows
        #LUA_DLL_NAME="lua53.dll"
        
      CompilerCase #PB_OS_Linux 
        #LUA_DLL_NAME="liblua53.so"
        
      CompilerCase #PB_OS_MacOS
        #LUA_DLL_NAME="liblua53.dylib"
        
    CompilerEndSelect
    
  CompilerEndIf

  
  ; LUAI_BITSINT defines the (minimum) number of bits in an 'int'.
  #LUAI_BITSINT=32 ;Always 64bit or 32Bit
  
  ; predefined options for LUA_INT_TYPE
  #LUA_INT_INT		 = 1
  #LUA_INT_LONG		 = 2
  #LUA_INT_LONGLONG	= 3
  
  ; predefined options for LUA_FLOAT_TYPE
  #LUA_FLOAT_FLOAT		 = 1
  #LUA_FLOAT_DOUBLE	 = 2
  #LUA_FLOAT_LONGDOUBLE	= 3
  
  ;default configuration for 64-bit Lua ('long long' and 'double')
  #LUA_INT_TYPE =	#LUA_INT_LONGLONG
  #LUA_FLOAT_TYPE	= #LUA_FLOAT_DOUBLE
  
  ;Configuration for Numbers
  #LUA_MAXINTEGER = 9223372036854775807
  #LUA_MININTEGER =-9223372036854775808 
  
  ;LUAI_MAXSTACK limits the size of the Lua stack.
  #LUAI_MAXSTACK = 1000000
  
  ;LUA_EXTRASPACE defines the size of a raw memory area associated with a Lua state With very fast access.
  #LUA_EXTRASPACE =SizeOf(integer)
  
  ;LUA_IDSIZE gives the maximum size for the description of the source of a function in Debug information.
  #LUA_IDSIZE = 60
  
  ;LUAL_BUFFERSIZE is the buffer size used by the lauxlib buffer system.
  #LUAL_BUFFERSIZE = 8192
  
  ;}
  
  ;-{ Lua.h
  
  #LUA_VERSION_MAJOR = "5"
  #LUA_VERSION_MINOR = "3"
  #LUA_VERSION_NUM = 503
  #LUA_VERSION_RELEASE = "3"
  
  #LUA_VERSION  = "Lua "+#LUA_VERSION_MAJOR+"."+#LUA_VERSION_MINOR
  #LUA_RELEASE  = #LUA_VERSION+"."+#LUA_VERSION_RELEASE
  #LUA_COPYRIGHT  = #LUA_RELEASE+" Copyright (C) 1994-2016 Lua.org, PUC-Rio"
  #LUA_AUTHORS  = "R. Ierusalimschy, L. H. de Figueiredo, W. Celes"
  
  #LUA_SIGNATURE = Chr($1b) + "Lua" ; mark for precompiled code ('<esc>Lua')
  #LUA_MULTRET  = -1                ; option for multiple returns in 'lua_pcall' and 'lua_call'
  
  
  ;-Pseudo-indices
  #LUA_REGISTRYINDEX = (-#LUAI_MAXSTACK - 1000) ;(-LUAI_MAXSTACK is the minimum valid index; we keep some free empty space after that To help overflow detection)
  Macro lua_upvalueindex(i) : (#LUA_REGISTRYINDEX - (i)) : EndMacro
  
  ;-Thread status
  #LUA_OK  = 0 ; Thread Status Ok
  #LUA_YIELD  = 1 ; Thread Status Yield
  #LUA_ERRRUN  = 2; Thread Status Runtime Error
  #LUA_ERRSYNTAX = 3 ; Thread Status Syntax Error
  #LUA_ERRMEM  = 4   ; Thread Status Memory Allocation Error
  #LUA_ERRGCMM  = 5  ; Thread Status Garbage Collector?
  #LUA_ERRERR  = 6   ; Thread Status Double Error Attempt to Print
  
  ;-basic types
  #LUA_TNONE  = -1 ; Nothing
  #LUA_TNIL  = 0   ; Nil
  #LUA_TBOOLEAN = 1; Boolean
  #LUA_TLIGHTUSERDATA = 2 ; Light User Data
  #LUA_TNUMBER  = 3       ; Number
  #LUA_TSTRING  = 4       ; String
  #LUA_TTABLE  = 5        ; Table
  #LUA_TFUNCTION = 6      ; Function
  #LUA_TUSERDATA = 7      ; Heavy User Data
  #LUA_TTHREAD  = 8       ; Thread
  #LUA_NUMTAGS  = 9       ; Total Types
  
  ;-minimum Lua stack available to a C function
  #LUA_MINSTACK = 20 
  
  ;-predefined values in the registry
  #LUA_RIDX_MAINTHREAD = 1 ; Main Thread
  #LUA_RIDX_GLOBALS = 2    ; Global
  #LUA_RIDX_LAST = #LUA_RIDX_GLOBALS
  
  
  ;-type of numbers in Lua
  Macro lua_Number 
    d
  EndMacro
  #sizeof_lua_Number=SizeOf(double)
  
  ;-type for integer functions
  Macro lua_Integer
    q
  EndMacro
  #sizeof_lua_Integer=SizeOf(quad)
  Macro lua_Unsigned
    q
  EndMacro
  #sizeof_lua_Unsigned=SizeOf(quad)
  
  ;-state manipulation
  
  ;-basic stack manipulation
  
  ;-access functions (stack -> C)
  
  ;-Comparison and arithmetic functions
  #LUA_OPADD  = 0
  #LUA_OPSUB  = 1
  #LUA_OPMUL  = 2
  #LUA_OPMOD  = 3
  #LUA_OPPOW  = 4
  #LUA_OPDIV  = 5
  #LUA_OPIDIV  = 6
  #LUA_OPBAND  = 7
  #LUA_OPBOR  = 8
  #LUA_OPBXOR  = 9
  #LUA_OPSHL  = 10
  #LUA_OPSHR  = 11
  #LUA_OPUNM  = 12
  #LUA_OPBNOT  = 13
  
  #LUA_OPEQ  = 0 ; ==
  #LUA_OPLT  = 1 ; <
  #LUA_OPLE  = 2 ; 
  
  ;-push functions (C -> stack)
  
  ;-get functions (Lua -> stack)
  
  ;-set functions (stack -> Lua)
  
  ;-'load' and 'call' functions (load and run Lua code)
  Macro lua_call(L, n, r) : lua_callk((L), (n), (r), 0, #Null) : EndMacro
  
  Macro lua_pcall(L, n, r, f): lua_pcallk((L), (n), (r), (f), 0, #Null) : EndMacro
  
  ;-coroutine functions
  Macro lua_yield(L, n) : lua_yieldk((L), (n), 0, #Null) : EndMacro
  
  
  ;-garbage-collection function and options
  #LUA_GCSTOP  = 0 ; Stop
  #LUA_GCRESTART = 1 ; Restart
  #LUA_GCCOLLECT = 2 ; Collect
  #LUA_GCCOUNT  = 3  ; Amount of Memory Kilobytes Used by Lua
  #LUA_GCCOUNTB = 4  ; Remainder of Dividing Bytes of Memory by 1024
  #LUA_GCSTEP  = 5   ; Step
  #LUA_GCSETPAUSE = 6; Set Pause
  #LUA_GCSETSTEPMUL = 7 ; Set Step Mul
  #LUA_GCISRUNNING = 9  ; Is Running
  
  ;-miscellaneous functions
  
  ;-some useful macros
  Macro lua_getextraspace(L) :	((L) - #LUA_EXTRASPACE)) : EndMacro
  Macro lua_tonumber(L,i) : lua_tonumberx(L,(i),#Null) : EndMacro
  Macro lua_tointeger(L,i) : lua_tointegerx(L,(i),#Null) : EndMacro
  
  Macro lua_pop(L,n) : lua_settop(L, -(n)-1) : EndMacro
  
  Macro lua_newtable(L) : lua_createtable(L, 0, 0) : EndMacro
  
  Macro lua_register(L,n,f) : lua_pushcfunction(L, (f)) : lua_setglobal(L, (n)) :EndMacro
  
  Macro lua_pushcfunction(L,f):lua_pushcclosure(L, (f), 0) : EndMacro
  
  Macro lua_isfunction(L,n) : Bool(lua_type(L, (n)) = #LUA_TFUNCTION) : EndMacro
  Macro lua_istable(L,n) : Bool(lua_type(L, (n)) = #LUA_TTABLE) : EndMacro
  Macro lua_islightuserdata(L,n): Bool(lua_type(L, (n)) = #LUA_TLIGHTUSERDATA) : EndMacro
  Macro lua_isnil(L,n) : Bool(lua_type(L, (n)) = #LUA_TNIL) : EndMacro
  Macro lua_isboolean(L,n) : Bool(lua_type(L, (n)) = #LUA_TBOOLEAN) : EndMacro
  Macro lua_isthread(L,n) : Bool(lua_type(L, (n)) = #LUA_TTHREAD) : EndMacro
  Macro lua_isnone(L,n) : Bool(lua_type(L, (n)) = #LUA_TNONE) : EndMacro
  Macro lua_isnoneornil(L, n): Bool(lua_type(L, (n)) <= 0) : EndMacro
  
  Macro lua_pushliteral(L, s): lua_pushstring(L, s): EndMacro
  
  Macro lua_pushglobaltable(L):(lua_rawgeti(L, #LUA_REGISTRYINDEX, #LUA_RIDX_GLOBALS)) : EndMacro
  
  ;Macro lua_tostring(L,i) : lua_tolstring(L, (i), #Null) : EndMacro
  Declare.s lua_tostring(l,i)
  
  
  Macro lua_insert(L,idx)	 : lua_rotate(L, (idx), 1) : EndMacro
  
  Macro lua_remove(L,idx) : lua_rotate(L, (idx), -1): lua_pop(L, 1) : EndMacro
  
  Macro lua_replace(L,idx) : lua_copy(L, -1, (idx)): lua_pop(L, 1) : EndMacro
  
  ;-Debug API
  
  ;-Event codes
  #LUA_HOOKCALL = 0
  #LUA_HOOKRET  = 1
  #LUA_HOOKLINE = 2
  #LUA_HOOKCOUNT = 3
  #LUA_HOOKTAILRET = 4
  
  ;-Event masks
  #LUA_MASKCALL = 1 << #LUA_HOOKCALL
  #LUA_MASKRET  = 1 << #LUA_HOOKRET
  #LUA_MASKLINE = 1 << #LUA_HOOKLINE
  #LUA_MASKCOUNT = 1 << #LUA_HOOKCOUNT
  
  ;-Functions to be called by the debugger in specific events
  
  Structure lua_Debug 
    event.i
    *name.ascii
    *namewhat.ascii;	/* (n) 'global', 'local', 'field', 'method' */
    *what.ascii    ;	/* (S) 'Lua', 'C', 'main', 'tail' */
    *source.ascii  ;	/* (S) */
    
    currentline.i;	/* (l) */
    linedefined.i;	/* (S) */
    lastlinedefined.i;	/* (S) */
    nups.a           ;	/* (u) number of upvalues */
    nparams.a        ;/* (u) number of parameters */
    isvararg.b       ; /* (u) */
    istailcall.b     ;	/* (t) */
    short_src.b[#LUA_IDSIZE]; /* (S) */
                            ;/* private part */
    *i_ci.callinfo          ; /* active function */
  EndStructure
  
  ;}
  
  ;-{ lualib.h
  #LUA_COLIBNAME = "coroutine"
  #LUA_TABLIBNAME = "table"
  #LUA_IOLIBNAME = "io"
  #LUA_OSLIBNAME = "os"
  #LUA_STRLIBNAME = "string"
  #LUA_UTF8LIBNAME = "utf8"
  #LUA_BITLIBNAME = "bit32"
  #LUA_MATHLIBNAME = "math"
  #LUA_DBLIBNAME = "debug"
  #LUA_LOADLIBNAME = "package"
  
  ;- open all previous libraries 
  ;}
  
  ;-{ luaxlib.h
  
  ;-extra error code For 'luaL_load'
  #LUA_ERRFILE = (#LUA_ERRERR+1) 
  
  Structure luaL_Reg 
    *name.ascii
    *func
  EndStructure
  
  #LUAL_NUMSIZES	=( #SizeOf_lua_Integer*16 + #SizeOf_lua_Number)
  
  Macro luaL_checkversion(L) : luaL_checkversion_(L, #LUA_VERSION_NUM, #LUAL_NUMSIZES) : EndMacro
  
  ;-predefined references 
  #LUA_NOREF  = -2
  #LUA_REFNIL = -1
  
  Macro luaL_loadfile(L,f):	 luaL_loadfilex(L,f,"bt") : EndMacro
  
  ;-some useful macros
  Macro luaL_newlibtable(L,ll) : lua_createtable(L, 0, SizeOf(ll)/SizeOf(luaL_Reg) - 1) : EndMacro
  
  Macro luaL_newlib(L,ll) : luaL_checkversion(L) : luaL_newlibtable(L,ll) : luaL_setfuncs(L,ll,0) : EndMacro
  
  Macro luaL_argcheck(L, cond,arg,extramsg)	 : Bool ((cond) Or luaL_argerror(L, (arg), (extramsg))) : EndMacro
  
  Macro luaL_checkstring(L,n) : luaL_checklstring(L, (n), #Null) : EndMacro
  Macro luaL_optstring(L,n,d) : luaL_optlstring(L, (n), (d), #Null)) : EndMacro
  
  Macro luaL_typename(L,i) : lua_typename(L, lua_type(L,(i))) : EndMacro
  
  Macro luaL_dofile(L, fn) : Bool (luaL_loadfile(L, fn) Or lua_pcall(L, 0, #LUA_MULTRET, 0)) : EndMacro
  
  Macro luaL_dostring(L, s) : Bool (luaL_loadstring(L, s) Or lua_pcall(L, 0, #LUA_MULTRET, 0)) : EndMacro
  
  Macro luaL_getmetatable(L,n) : lua_getfield(L, #LUA_REGISTRYINDEX, (n)) : EndMacro
  
  Macro luaL_opt(L,f,n,d) : lua::__lua_cmp(lua_isnoneornil(L,(n)) ,(d) , f(L,(n))) :EndMacro
  
  Macro luaL_loadbuffer(L,s,sz,n) : luaL_loadbufferx(L,s,sz,n,"bt") :EndMacro
  
  ;-Generic Buffer manipulation
  Structure luaL_Buffer
    *b.ascii;  /* buffer address */
    size.i;  /* buffer size */
    n.i;  /* number of characters in buffer */
    lua_State.i
    initb.ascii[#LUAL_BUFFERSIZE];  /* initial buffer */
  EndStructure
  
  ;no idea how to translate....
  ;#define luaL_addchar(B,c) \
  ;((void)((B)->n < (B)->size || luaL_prepbuffsize((B), 1)), \
  ;((B)->b[(B)->n++] = (c)))
  ;#define luaL_addsize(B,s)	((B)->n += (s))
  
  Macro luaL_prepbuffer(B) : luaL_prepbuffsize(B, #LUAL_BUFFERSIZE) : EndMacro
  
  ;-File handles for IO library
  #LUA_FILEHANDLE = "FILE*"


  Structure luaL_Stream 
    *f.file;  /* stream (NULL for incompletely created streams) */
    *closef;  /* to close stream (NULL for closed streams) */
  EndStructure
  
  ;}
  
  ;-{ declare extern
  Macro externX(x,a,b,c=)
    PrototypeC.x __proto_#c#a b
    Global c#a.__proto_#c#a
  EndMacro
  IncludeFile "module_lua_extern.pbi"
  UndefineMacro externX
  ;}
  
  Declare Lua_Initialize(path.s="")
  Declare Lua_Dispose()
  Declare __lua_cmp(a,b,c)
  Declare.s lua_typename(lua_state.i, tp.i)
  Declare.d lua_version(lua_State.i)
EndDeclareModule


Module LUA
  Global DLL_LUA.i ; DLL Handle
  
  Procedure.d lua_version(lua_State.i)
    Protected *d.double=__lua_version(lua_State.i)
    If *d
      ProcedureReturn *d\d
    EndIf
    ProcedureReturn 0
  EndProcedure
  
  Procedure.s lua_typename(lua_state.i, tp.i)
    Protected *str=__lua_typename(lua_state,tp)
    If *str
      ProcedureReturn PeekS(*str,-1,#PB_UTF8)
    EndIf
    ProcedureReturn ""
  EndProcedure
  
  Procedure.s lua_tostring(state,i)
    Protected *str=lua_tolstring(state,i,#Null)
    If *str
      ProcedureReturn PeekS(*str,-1,#PB_UTF8)
    EndIf
    ProcedureReturn ""
  EndProcedure
  Procedure __lua_cmp(a,b,c)
    If a
      ProcedureReturn b
    Else
      ProcedureReturn c
    EndIf
  EndProcedure
    
  Procedure Lua_Initialize(path.s="")
    If dll_lua
      ProcedureReturn #False
    EndIf
    
    
    Debug "open lua: "+path+ #LUA_DLL_NAME
    dll_lua = OpenLibrary(#PB_Any,path+ #LUA_DLL_NAME)
    
    If dll_lua=#False
      Debug "Failed to load "+path+ #LUA_DLL_NAME
      ProcedureReturn #False
    EndIf
    
    ;Declare all functions from the lib
    Macro c34()
      "
    EndMacro 
    Macro externX(x,a,b,c=)
      c#a = GetFunction(DLL_LUA, c34()a#c34())
      CompilerIf #PB_Compiler_Debugger
        If c#a=0
          Debug c34()a#c34() + " is not declared in the "+ #LUA_DLL_NAME
        EndIf
      CompilerEndIf      
    EndMacro
    IncludeFile "module_lua_extern.pbi"
    UndefineMacro externX
    UndefineMacro c34 
    
    ProcedureReturn #True
  EndProcedure
  Procedure Lua_Dispose()
    If dll_lua  
      CloseLibrary(DLL_LUA)
      
      Macro externX(x,a,b,c=)
        c#a = 0
      EndMacro
      IncludeFile "module_lua_extern.pbi"
      UndefineMacro externX
      
    EndIf
    dll_lua=#False
  EndProcedure
  
  
  
EndModule



