; http://www.purebasic.fr/english/viewtopic.php?p=491904#p491904

PrototypeC lua_CFunction 	(L)
PrototypeC lua_Reader 		(L,ud,sz)
PrototypeC lua_Writer 		(L,p,sz,ud)
PrototypeC lua_Alloc 		  (ud,ptr,osize,nsize)
PrototypeC lua_Hook 			(L,ar)

#LUA_VERSION 					=	"Lua 5.1"
#LUA_RELEASE 					=	"Lua 5.1.4"
#LUA_VERSION_NUM 			=	501
#LUA_COPYRIGHT 				=	"Copyright (C) 1994-2007 Lua.org, PUC-Rio"
#LUA_AUTHORS					=	"R. Ierusalimschy, L. H. de Figueiredo & W. Celes"

;  mark for precompiled code
#LUA_SIGNATURE 				=	"\033Lua"

;option for multiple returns in `lua_pcall' and `lua_call' 
#LUA_MULTRET 					=	-1

;  pseudo-indices 
#LUA_REGISTRYINDEX 		=	(-10000)
#LUA_ENVIRONINDEX 		=	(-10001)
#LUA_GLOBALSINDEX 		=	(-10002)

;  thread status; 0 is OK  
#LUA_YIELD 						=	1
#LUA_ERRRUN 					=	2
#LUA_ERRSYNTAX 				=	3
#LUA_ERRMEM 					=	4
#LUA_ERRERR 					=	5

;  basic types 
#LUA_TNONE						=	-1
#LUA_TNIL						  =	0
#LUA_TBOOLEAN					=	1
#LUA_TLIGHTUSERDATA 	=	2
#LUA_TNUMBER					=	3
#LUA_TSTRING					=	4
#LUA_TTABLE						=	5
#LUA_TFUNCTION				=	6
#LUA_TUSERDATA				=	7
#LUA_TTHREAD					=	8

;  minimum Lua stack available to a C function 
#LUA_MINSTACK 				=	20

;  garbage-collection function and options 
#LUA_GCSTOP						=	0
#LUA_GCRESTART				=	1
#LUA_GCCOLLECT				=	2
#LUA_GCCOUNT					=	3
#LUA_GCCOUNTB					=	4
#LUA_GCSTEP						=	5
#LUA_GCSETPAUSE				=	6
#LUA_GCSETSTEPMUL 		=	7
																	
;  Event codes 																	
#LUA_HOOKCALL 				=	0
#LUA_HOOKRET 					=	1
#LUA_HOOKLINE 				=	2
#LUA_HOOKCOUNT 				=	3
#LUA_HOOKTAILRET 			=	4

;  Event masks 
#LUA_MASKCALL 				=	1 << #LUA_HOOKCALL
#LUA_MASKRET 					=	1 << #LUA_HOOKRET
#LUA_MASKLINE 				=	1 << #LUA_HOOKLINE
#LUA_MASKCOUNT 				=	1 << #LUA_HOOKCOUNT


Macro lua_upvalueindex(i)
	(#LUA_GLOBALSINDEX-(i))
EndMacro

Macro lua_pop(L,n)
	lua_settop(L, -(n)-1)
EndMacro

Macro lua_newtable(L)
	lua_createtable(L, 0, 0)
EndMacro

Macro lua_register(L,n,f) 
	lua_pushcfunction(L, (f)) 
	lua_setglobal(L, (n))
EndMacro

Macro lua_pushcfunction(L,f) 
	lua_pushcclosure(L, f, 0)
EndMacro

Macro lua_strlen(L,i)
	lua_objlen(L, (i))
EndMacro

Macro lua_isfunction(L,n)
	(lua_type(L, (n)) = #LUA_TFUNCTION)
EndMacro

Macro lua_istable(L,n) 
	(lua_type(L, (n)) = #LUA_TTABLE)
EndMacro

Macro lua_islightuserdata(L,n) 
	(lua_type(L, (n)) = #LUA_TLIGHTUSERDATA)
EndMacro

Macro lua_isnil(L,n)
	(lua_type(L, (n)) = #LUA_TNIL)
EndMacro

Macro lua_isboolean(L,n) 
	(lua_type(L, (n)) = #LUA_TBOOLEAN)
EndMacro

Macro lua_isthread(L,n) 
	(lua_type(L, (n)) = #LUA_TTHREAD)
EndMacro

Macro lua_isnone(L,n)
	(lua_type(L, (n)) = #LUA_TNONE)
EndMacro

Macro lua_isnoneornil(L, n) 
	(lua_type(L, (n)) <= 0)
EndMacro

Macro lua_setglobal(L,s) 
	lua_setfield(L, #LUA_GLOBALSINDEX, (s))
EndMacro

Macro lua_getglobal(L,s) 
	lua_getfield(L, #LUA_GLOBALSINDEX, (s))
EndMacro

Macro lua_tostring(L,i) 
	lua_tolstring(L, (i), #Null)
EndMacro

Macro lua_open() 
	luaL_newstate()
EndMacro

Macro lua_getregistry(L) 
	lua_pushvalue(L, #LUA_REGISTRYINDEX)
EndMacro

Macro lua_getgccount(L) 
	lua_gc(L, #LUA_GCCOUNT, 0)
EndMacro

CompilerSelect #PB_Compiler_OS
	CompilerCase #PB_OS_Windows
	  ; 	  ImportC "win/lua514.lib"
	  ImportC "win/liblua5.1.a"
	  EndImport
	CompilerCase #PB_OS_MacOS
	  ImportC "mac/liblua5.1.a"
	  EndImport
	CompilerCase #PB_OS_Linux
	  ImportC "lin/liblua5.1.a"
	  EndImport
CompilerEndSelect


ImportC ""
	lua_newstate(f.l,ud)
	lua_close(L)
	lua_newthread(L)
	lua_atpanic(L,panicf.l)
	lua_gettop(L)
	lua_settop(L,idx)
	lua_pushvalue(L,idx)
	lua_remove(L,idx)
	lua_insert(L,idx)
	lua_replace(L,idx)
	lua_checkstack(L,sz)
	lua_xmove(from_L,to_L,n)
	lua_isnumber(L,idx)
	lua_isstring(L,idx)
	lua_iscfunction(L,idx)
	lua_isuserdatas(L,idx)
	lua_type(L,idx)
	lua_typename(L,tp)
	lua_equal(L,idx1,idx2)
	lua_rawequal(L,idx1,idx2)
	lua_lessthan(L,idx1,idx2)
	lua_tonumber.d(L,idx)
	lua_tointeger(L,idx)
	lua_toboolean(L,idx)
	lua_tolstring(L,idx,len)
	lua_objlen(L,idx)
	lua_tocfunction(L,idx)
	lua_touserdatas(L,idx)
	lua_tothread(L,idx)
	lua_topointer(L,idx)
	lua_pushnil(L)
	lua_pushnumber(L,n.d)
	lua_pushinteger(L,n)
	lua_pushlstring(L,string.p-utf8,sl)
	lua_pushstring(L,string.p-utf8)
	lua_pushvfstring(L,string.p-utf8,*arg)
	;lua_pushfstring(L,string.p-utf8, ...)
	lua_pushcclosure(L,fn.l ,n)
	lua_pushboolean(L,b)
	lua_pushlightuserdatas(L,p)
	lua_pushthread(L)
	lua_gettable(L,idx)
	lua_getfield(L,idx,string.p-utf8)
	lua_rawget(L,idx)
	lua_rawgeti(L,idx,n)
	lua_createtable(L,narr,nrec)
	lua_newuserdatas(L,sz)
	lua_getmetatable(L,objindex)
	lua_getfenv(L,idx)
	lua_settable(L,idx)
	lua_setfield(L,idx,string.p-utf8)
	lua_rawset(L,idx)
	lua_rawseti(L,idx,n)
	lua_setmetatable(L,objindex)
	lua_setfenv(L,idx)
	lua_call(L,nargs,nresults)
	lua_pcall(L,nargs,nresults,errfunc)
	lua_cpcall(L,func.l ,ud)
	lua_load(L,reader,dt,string.p-utf8)
	lua_dump(L,writer,datas)
	lua_yield(L,nresults)
	lua_resume(L,narg)
	lua_status(L)
	lua_gc(L,what,datas)
	lua_error(L)
	lua_next(L,idx)
	lua_concat(L,n)
	lua_getallocf(L,ud)
	lua_setallocf (L,f.l,ud)
	lua_getstack (L,level, lua_Debugar)
	lua_getinfo (L,string.p-utf8, lua_Debugar)
	lua_getlocal (L,lua_Debugar,n)
	lua_setlocal (L,lua_Debugar,n)
	lua_getupvalue (L,funcindex,n)
	lua_setupvalue (L,funcindex,n)
	lua_sethook (L,func.l,mask,count)
	lua_gethook (L)
EndImport

; lauxlib 

#LUA_ERRFILE 					= #LUA_ERRERR+1
#LUA_NOREF 						= -2
#LUA_REFNIL						= -1

#LUAL_BUFFERSIZE				= 512

Macro luaL_dofile(L, fn) 
  ( luaL_loadfile(L, fn) | lua_pcall(L, 0, #LUA_MULTRET, 0) )
EndMacro

Macro luaL_dostring(L, s) 
	luaL_loadstring(L, s) 
	lua_pcall(L, 0, #LUA_MULTRET, 0)
EndMacro

Macro luaL_addchar(B,c) \
	CallDebugger
  ;(((B)\p < ((B)\buffer+#LUAL_BUFFERSIZE) || luaL_prepbuffer(B,(*(B)\p++ = (char)(c)))
EndMacro

Macro luaL_argcheck(L, cond,numarg,extramsg)	
		(cond | luaL_argerror(L, numarg, extramsg) )
EndMacro

Macro luaL_checkstring(L,n) 
	luaL_checklstring(L, n, #Null)
EndMacro 

Macro luaL_optstring(L,n,d) 
	luaL_optlstring(L, (n), d, #Null)
EndMacro 

Macro luaL_checkint(L,n) 
	luaL_checkinteger(L, n)
EndMacro 

Macro luaL_optint(L,n,d) 
	luaL_optinteger(L, n, d)
EndMacro 

Macro luaL_checklong(L,n) 
	luaL_checkinteger(L, n)
EndMacro 
 
Macro luaL_optlong(L,n,d) 
	luaL_optinteger(L, n, d)
EndMacro 
 
Macro luaL_typename(L,i) 
	lua_typename(L, lua_type(L,(i)))
EndMacro 
 
Macro luaL_getmetatable(L,n) 
	lua_getfield(L,#LUA_REGISTRYINDEX, n)
EndMacro 
 
Macro luaL_opt(L,f,n,d) 
	If lua_isnoneornil(L,n) 
		d 
	Else	 
		f(L,n)
	EndIf 
EndMacro 
 
Macro luaL_putchar(B,c) 
	luaL_addchar(B,c)
EndMacro 
 
Macro luaL_addsize(B,n) 
	((B)\p + n)
EndMacro 
 
Macro lua_unref(L,ref)
	luaL_unref(L, #LUA_REGISTRYINDEX, ref)
EndMacro 
 
Macro lua_getref(L,ref) 
	lua_rawgeti(L, #LUA_REGISTRYINDEX, ref)
EndMacro 
 
Macro lua_ref(L,lock) 
	If lock 
		luaL_ref(L,#LUA_REGISTRYINDEX)
	Else
		lua_pushstring(L, "unlocked references are obsolete")
		lua_error(L), 0)
	EndIf 
EndMacro
 
Structure luaL_Reg
  name.s
  func.lua_CFunction
EndStructure

Structure luaL_Buffer 
  *p.character 
  lvl.l
  *L
  buffer.c[#LUAL_BUFFERSIZE]
EndStructure

ImportC ""
	luaL_getn(L,t)
	luaL_setn(L,t,n)
	luaI_openlib(L,libname.p-utf8,rl,nup)
	luaL_register(L,libname.p-utf8,rl)
	luaL_getmetafield(L,obj,e.p-utf8)
	luaL_callmeta(L,obj,e.p-utf8)
	luaL_typerror(L,narg,tname.p-utf8)
	luaL_argerror(L,numarg,extramsg.p-utf8)
	luaL_checklstring(L,numArg,sl)
	luaL_optlstring(L,numArg,def.p-utf8,sl)
	luaL_checknumber.d(L,numArg)
	luaL_optnumber.d(L,nArg,def.d)
	luaL_checkinteger(L,numArg)
	luaL_optinteger(L,nArg,def)
	luaL_checkstack(L,sz,msg.p-utf8)
	luaL_checktype(L,narg,t)
	luaL_checkany(L,narg)
	luaL_newmetatable(L,tname.p-utf8)
	luaL_checkudata(L,ud,tname.p-utf8)
	luaL_where(L,lvl)
	;luaL_error(L, const char *fmt, ...)
	luaL_checkoption(L,narg,def.p-utf8,*lst)
	luaL_ref(L,t)
	luaL_unref(L,t,ref)
	luaL_loadfile(L,filename.p-utf8)
	luaL_loadbuffer(L,buff.p-utf8,sz,name.p-utf8)
	luaL_loadstring(L,s.p-utf8)
	luaL_newstate()
	luaL_gsub(L,s.p-utf8,p.p-utf8,r.p-utf8)
	luaL_findtable(L,idx,fname.p-utf8,szhint)
	luaL_buffinit(L, b)
	luaL_prepbuffer(b)
	luaL_addlstring(b,s.p-utf8,l)
	luaL_addstring(b,s.p-utf8)
	luaL_addvalue(b)
	luaL_pushresult(b)
EndImport


; lualib

#LUA_FILEHANDLE				= "FILE*"
#LUA_COLIBNAME 				= "coroutine"
#LUA_TABLIBNAME 				= "table"
#LUA_IOLIBNAME 				= "io"
#LUA_OSLIBNAME 				= "os"
#LUA_STRLIBNAME 				= "string"
#LUA_MATHLIBNAME 				= "math"
#LUA_DBLIBNAME 				= "debug"
#LUA_LOADLIBNAME 				= "package"

Macro lua_assert(x) 
	0
EndMacro

ImportC ""
	luaopen_base(L)
	luaopen_table(L)
	luaopen_io(L)
	luaopen_os(L)
	luaopen_string(L)
	luaopen_math(L)
	luaopen_debug(L)
	luaopen_package(L)
	luaL_openlibs(L)
EndImport


; ImportC "msvcrt.lib" 
; EndImport
