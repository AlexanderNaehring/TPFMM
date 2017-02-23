Macro extern(a,b)
  externX(i,a,b)
EndMacro
Macro externN(a,b)
  externX(lua_number,a,b)
EndMacro
;quad as return doesn't work!
Macro externI(a,b)
  externX(i,a,b)
EndMacro
;externP for pointers of strings, doubles etc. 
Macro externP(a,b)
  externx(i,a,b,__)
EndMacro


;-{ Lua.h
;-state manipulation
extern (lua_newstate ,(*f, *ud))
extern (lua_close ,(lua_State.i)) 
extern (lua_newthread ,(lua_State.i))
extern (lua_atpanic ,(lua_State.i, *panicf))
externP(lua_version ,(lua_State.i))

;-basic stack manipulation
extern (lua_absindex  ,(lua_State.i, idx.i))
extern (lua_gettop  ,(lua_State.i))
extern (lua_settop  ,(lua_State.i, idx.i))
extern (lua_pushvalue  ,(lua_State.i, idx.i))
extern (lua_rotate  ,(lua_State.i, idx.i, n.i))
extern (lua_copy   ,(lua_State.i, fromidx.i, toidx.i))
extern (lua_checkstack  ,(lua_State.i, sz.i))
extern (lua_xmove  ,(lua_State_from.i, lua_State_to.i, n.i))

;-access functions (stack -> C)
extern (lua_isnumber  ,(lua_State.i, idx.i))
extern (lua_isstring  ,(lua_State.i, idx.i))
extern (lua_iscfunction  ,(lua_State.i, idx.i))
extern (lua_isinteger  ,(lua_State.i, idx.i))
extern (lua_isuserdata  ,(lua_State.i, idx.i))
extern (lua_type   ,(lua_State.i, idx.i))
externP(lua_typename  ,(lua_State.i, tp.i))

externN(lua_tonumberx  ,(lua_State.i, idx.i, *isnum))
externI(lua_tointegerx  ,(lua_State.i, idx.i, *isnum))
extern (lua_toboolean  ,(lua_State.i, idx.i))
extern (lua_tolstring  ,(lua_State.i, idx.i, *len)) ; externP doesn't make sense here, because a string doesn't need the "*len"
extern (lua_rawlen  ,(lua_State.i, idx.i))
extern (lua_tocfunction  ,(lua_State.i, idx.i))
extern (lua_touserdata  ,(lua_State.i, idx.i))
extern (lua_tothread  ,(lua_State.i, idx.i))
extern (lua_topointer  ,(lua_State.i, idx.i))

extern (lua_arith  ,(lua_State.i, op.i))

extern (lua_rawequal  ,(lua_State.i, idx1.i, idx2.i))
extern (lua_compare  ,(lua_State.i, idx1.i, idx2.i, op.i))

;-push functions (C -> stack)
extern (lua_pushnil  ,(lua_State.i))
extern (lua_pushnumber  ,(lua_State.i, n.lua_Number))
extern (lua_pushinteger  ,(lua_State.i, n.lua_Integer))
extern (lua_pushlstring  ,(lua_State.i, string.p-utf8, size.i)) ; externP doesn't make sense here
extern (lua_pushstring  ,(lua_State.i, string.p-utf8)); externP doesn't make sense here
;extern (lua_pushvfstring  ,(lua_State *L, const char *fmt,va_list argp)) ; PB doesn't support va_list
;extern (lua_pushfstring)  ,(lua_State *L, const char *fmt, ...)) ; PB doesn't support ...

extern (lua_pushcclosure  ,(lua_State.i, *fn, n.i))
extern (lua_pushboolean  ,(lua_State.i, b.i))
extern (lua_pushlightuserdata ,(lua_State.i, *p))
extern (lua_pushthread  ,(lua_State.i))

;-get functions (Lua -> stack)
extern (lua_getglobal  ,(lua_State.i, name.p-utf8))
extern (lua_gettable  ,(lua_State.i, idx.i))
extern (lua_getfield  ,(lua_State.i, idx.i, k.p-utf8))
extern (lua_geti   ,(lua_State.i, idx.i, n.lua_Integer))
extern (lua_rawget  ,(lua_State.i, idx.i))
extern (lua_rawgeti  ,(lua_State.i, idx.i, n.lua_Integer))
extern (lua_rawgetp  ,(lua_State.i, idx.i, p.p-utf8))

extern (lua_createtable  ,(lua_State.i, narr.i, nrec.i))
extern (lua_newuserdata  ,(lua_State.i, sz.i))
extern (lua_getmetatable  ,(lua_State.i, objindex.i))
extern (lua_getuservalue  ,(lua_State.i, idx.i))

;-set functions (stack -> Lua)
extern (lua_setglobal  ,(lua_State.i, var.p-utf8))
extern (lua_settable  ,(lua_State.i, idx.i))
extern (lua_setfield  ,(lua_State.i, idx.i, k.p-utf8))
extern (lua_seti   ,(lua_State.i, idx.i, n.lua_Integer))
extern (lua_rawset  ,(lua_State.i, idx.i))
extern (lua_rawseti  ,(lua_State.i, idx.i, n.lua_Integer))
extern (lua_rawsetp  ,(lua_State.i, idx.i, p.p-utf8))
extern (lua_setmetatable  ,(lua_State.i, objindex.i))
extern (lua_setuservalue  ,(lua_State.i, idx.i))

;-'load' and 'call' functions (load and run Lua code)
extern (lua_callk  ,(lua_State.i, nargs.i, nresults.i, ctx.i, *k))
extern (lua_pcallk  ,(lua_State.i, nargs.i, nresults.i, *errfunc, ctx.i, *k))
extern (lua_load   ,(lua_State.i, reader.i, *dt, chunkname.p-utf8, mode.p-utf8))
extern (lua_dump   ,(lua_State.i, writer.i, *data_, strip.i))

;-coroutine functions
extern (lua_yieldk  ,(lua_State.i, nresults.i, ctx.i, *k))
extern (lua_resume  ,(lua_State.i, lua_State_from.i, narg.i))
extern (lua_status  ,(lua_State.i))
extern (lua_isyieldable  ,(lua_State.i))

;-garbage-collection function and options
extern (lua_gc   ,(lua_State.i, what.i, data_.i))

;-miscellaneous functions
extern (lua_error  ,(lua_State.i))
extern (lua_next   ,(lua_State.i, idx.i))
extern (lua_concat  ,(lua_State.i, n.i))
extern (lua_len   ,(lua_State.i, idx.i))
extern (lua_stringtonumber ,(lua_State.i, str.p-utf8))
extern (lua_getallocf  ,(lua_State.i, *ud))
extern (lua_setallocf  ,(lua_State.i, *f, *ud))

;-Debug API

;-Functions to be called by the debugger in specific events
extern (lua_getstack , (lua_State.i, level.i, *ar))
extern (lua_getinfo , (lua_State.i, what.p-utf8, *ar))
extern (lua_getlocal , (lua_State.i, *ar, n.i))
extern (lua_setlocal , (lua_State.i, *ar, n.i))
extern (lua_getupvalue , (lua_State.i, funcindex.i, n.i))
extern (lua_setupvalue , (lua_State.i, funcindex.i, n.i))

extern (lua_upvalueid , (lua_State.i, fidx.i, n.i))
extern (lua_upvaluejoin , (lua_State.i, fidx1.i, n1.i, fidx2.i, n2.i))

extern (lua_sethook , (lua_State.i, *func, mask.i, count.i))
extern (lua_gethook , (lua_State.i))
extern (lua_gethookmask , (lua_State.i))
extern (lua_gethookcount , (lua_State.i))

;}

;-{ lualib.h
extern (luaopen_base, (lua_State.i))
extern (luaopen_coroutine, (lua_State.i))
extern (luaopen_table, (lua_State.i))
extern (luaopen_io, (lua_State.i))
extern (luaopen_os, (lua_State.i))
extern (luaopen_string, (lua_State.i))
extern (luaopen_utf8, (lua_State.i))
extern (luaopen_bit32, (lua_State.i))
extern (luaopen_math, (lua_State.i))
extern (luaopen_debug, (lua_State.i))
extern (luaopen_package, (lua_State.i))

;- open all previous libraries 
extern (luaL_openlibs, (lua_State.i))
;}

;-{ luaxlib.h
extern (luaL_checkversion_, (lua_State.i,  ver.lua_Number, sz.i))

extern (luaL_getmetafield, (lua_State.i, obj.i, e.p-utf8))
extern (luaL_callmeta, (lua_State.i, obj.i, e.p-utf8))
extern (luaL_tolstring, (lua_State.i, idx.i,  *len))
extern (luaL_argerror, (lua_State.i, arg.i, extramsg.p-utf8))
extern (luaL_checklstring, (lua_State.i, arg.i, *l))
extern (luaL_optlstring, (lua_State.i, arg.i, def.p-utf8, *l))
externN(luaL_checknumber, (lua_State.i, arg.i))
externN(luaL_optnumber, (lua_State.i, arg.i, def.lua_Number))

externI(luaL_checkinteger, (lua_State.i, arg.i))
externI(luaL_optinteger, (lua_State.i, arg.i, def.lua_Integer))

extern (luaL_checkstack, (lua_State.i, sz,u, msg.p-utf8))
extern (luaL_checktype, (lua_State.i, arg.i, t,u))
extern (luaL_checkany, (lua_State.i, arg.i))

extern (luaL_newmetatable, (lua_State.i, tname.p-utf8))
extern (luaL_setmetatable, (lua_State.i, tname.p-utf8))
extern (luaL_testudata, (lua_State.i, ud.i, tname.p-utf8))
extern (luaL_checkudata, (lua_State.i, ud.i, tname.p-utf8))

extern (luaL_where, (lua_State.i, lvl.i))
;extern (luaL_error, (lua_State.i, const char *fmt, ...);  ; PB doesn't support ...
extern (luaL_error, (lua_State.i, fmt.p-utf8))

extern (luaL_checkoption, (lua_State.i, arg.i, def.p-utf8, *lst))

extern (luaL_fileresult, (lua_State.i, stat.i, fname.p-utf8))
extern (luaL_execresult, (lua_State.i, stat.i))

;-predefined references
extern (luaL_ref, (lua_State.i, t.i))
extern (luaL_unref, (lua_State.i, t.i, ref.i))

extern (luaL_loadfilex, (lua_State.i, filename.p-utf8, mode.p-utf8))

extern (luaL_loadbufferx, (lua_State.i, *buff, sz.i, name.p-utf8, mode.p-utf8))
  
extern (luaL_loadstring, (lua_State.i, s.p-utf8))

extern (luaL_newstate, ())

externI(luaL_len, (lua_State.i, idx.i))

extern (luaL_gsub, (lua_State.i, s.p-utf8, p.p-utf8, r.p-utf8))

extern (luaL_setfuncs, (lua_State.i, *l, nup.i))

extern (luaL_getsubtable, (lua_State.i, idx.i, fname.p-utf8))

extern (luaL_traceback, (lua_State.i, lua_State1.i, msg.p-utf8, level.i))

extern (luaL_requiref, (lua_State.i, modname.p-utf8, *openf, glb.i))

;-Generic Buffer manipulation
extern (luaL_buffinit, (lua_State.i, *luaL_Buffer))
extern (luaL_prepbuffsize, (*luaL_Buffer, sz.i))
extern (luaL_addlstring, (*luaL_Buffer, s.p-utf8, l.i))
extern (luaL_addstring, (*luaL_Buffer, s.p-utf8))
extern (luaL_addvalue, (*luaL_Buffer))
extern (luaL_pushresult, (*luaL_Buffer))
extern (luaL_pushresultsize, (*luaL_Buffer, sz.i))
extern (luaL_buffinitsize, (lua_State.i, *luaL_Buffer, sz.i))


;}

UndefineMacro extern
UndefineMacro externN
UndefineMacro externI
UndefineMacro externP