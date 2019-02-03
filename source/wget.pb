DeclareModule wget
  EnableExplicit
  
  Prototype callbackFunction(*wget)
  
  Interface wget
    download()
    free()
    
    setUserAgent(useragent$="")
    setTimeout(timeout.l)
    setAsync(async.b)
    setUserData(*userdata)
    
    getUserAgent.s()
    getTimeout.l()
    getAsync.b()
    getUserData()
    getProgress.b()
    getRemote.s()
    getFilename.s()
    getLastError.s()
    
    waitFinished(timeout.l = 0)
    
    EventOnProgress(event=0)
    EventOnSuccess(event=0)
    EventOnError(event=0)
    
    CallbackOnProgress(*function.callbackFunction = #Null)
    CallbackOnSuccess(*function.callbackFunction = #Null)
    CallbackOnError(*function.callbackFunction = #Null)
  EndInterface
  
  Declare NewDownload(remote$, local$, timeout.l=10, async.b=#True)
  Declare StartDownload(*wget.wget)
  Declare FreeDownload(*wget.wget)
  
  Declare setUserAgent(*wget.wget, useragent$="")
  Declare setTimeout(*wget.wget, timeout.l)
  Declare setAsync(*wget.wget, async.b)
  Declare setUserData(*wget.wget, *userdata)
  
  Declare.s getUserAgent(*wget.wget)
  Declare.l getTimeout(*wget.wget)
  Declare.b getAsync(*wget.wget)
  Declare getUserData(*wget.wget)
  Declare.b getProgress(*wget.wget)
  Declare.s getRemote(*wget.wget)
  Declare.s getFilename(*wget.wget)
  Declare.s getLastError(*wget.wget)
  
  Declare waitFinished(*wget.wget, timeout.l = 0)
  
  Declare EventOnProgress(*wget.wget, event=0)
  Declare EventOnSuccess(*wget.wget, event=0)
  Declare EventOnError(*wget.wget, event=0)
  
  Declare CallbackOnProgress(*wget.wget, *function.callbackFunction = #Null)
  Declare CallbackOnSuccess(*wget.wget, *function.callbackFunction = #Null)
  Declare CallbackOnError(*wget.wget, *function.callbackFunction = #Null)
  
  Declare setProxy(host$, username$="", password$="")
  Declare freeAll()
EndDeclareModule

Module wget
  
  ;{ VT
  DataSection
    vt:
    Data.i @StartDownload()
    Data.i @FreeDownload()
    
    Data.i @setUserAgent()
    Data.i @setTimeout()
    Data.i @setAsync()
    Data.i @setUserData()
    
    Data.i @getUserAgent()
    Data.i @getTimeout()
    Data.i @getAsync()
    Data.i @getUserData()
    Data.i @getProgress()
    Data.i @getRemote()
    Data.i @getFilename()
    Data.i @getLastError()
    
    Data.i @waitFinished()
    
    Data.i @EventOnProgress()
    Data.i @EventOnSuccess()
    Data.i @EventOnError()
    Data.i @CallbackOnProgress()
    Data.i @CallbackOnSuccess()
    Data.i @CallbackOnError()
  EndDataSection
  ;}
  
  ;{ struct
  Structure callback
    event.i
    callback.callbackFunction
  EndStructure
  
  Structure _wget
    *vt.wget
    
    program.i
    thread.i
    mutex.i
    *userdata
    
    remote$
    local$
    useragent$
    timeout.l
    async.b
    
    progress.b
    exitCode.i
    STDERR$
    STDOUT$
    
    onProgress.callback
    onError.callback
    onSuccess.callback
    cancel.b
    lastError$
  EndStructure
  ;}
  
  ;{ globals
  Global _proxy$
  Global _mutexList = CreateMutex()
  Global NewList *objects._wget()
  ;}
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    misc::useBinary("wget\wget.exe", #False)
  CompilerEndIf
  
  CompilerIf Defined(debugger, #PB_Module)
    ; in bigger project, use custom module (writes debug messages to log file)
    UseModule debugger
  CompilerElse
    ; if module not available, just print message
    Macro deb(s)
      Debug s
    EndMacro
  CompilerEndIf
  
  ;- Private
  
  Procedure downloadThread(*this._wget)
    Protected program$, parameter$,
              str$, STDOUT$, STDERR$,
              HTTPstatus
    Protected regExpProgress
    
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      program$ = "wget\wget.exe"
    CompilerElse
      program$ = "wget"
    CompilerEndIf
    parameter$ = "--server-response --timeout="+Str(*this\timeout)+" --tries=1 --https-only -U "+#DQUOTE$+*this\useragent$+#DQUOTE$+" "+#DQUOTE$+"--header='Accept: text/html,*/*'"+#DQUOTE$+" --progress=dot:Default -O "+#DQUOTE$+*this\local$+#DQUOTE$+" "+#DQUOTE$+*this\remote$+#DQUOTE$
    ; --proxy-user=user --proxy-password=password  or use environment variable
    ; -U user-agent
    ; -S print HTTP headers
    ; -T timeout-seconds
    ; -t try_count
    ; --https-only
    ; -O output-file
    ; -o log-file
    
    ; exit:
    ; 0 ok, 1 error, 2 parse error, 3 file error, 4 network error, 5 ssl error, 6 username/password error, 7 protocol error, 8 server error
    
    Debug program$+" "+parameter$
    *this\program = RunProgram(program$, parameter$, GetCurrentDirectory(), #PB_Program_Open|#PB_Program_Read|#PB_Program_Error|#PB_Program_Hide)
    
    If *this\program
      deb("wget:: start #"+*this+" "+#DQUOTE$+*this\remote$+#DQUOTE$+" > "+#DQUOTE$+*this\local$+#DQUOTE$)
      regExpProgress = CreateRegularExpression(#PB_Any, "([0-9]+)%")
      While ProgramRunning(*this\program)
        If *this\cancel
          deb("wget:: #"+*this+" cancel download, kill wget.exe")
          KillProgram(*this\program)
          Debug "killed"
          *this\exitCode = -1
          Break
        EndIf
        If AvailableProgramOutput(*this\program)
          str$ = ReadProgramString(*this\program)
          STDOUT$ + str$ + #CRLF$
        EndIf
        str$ = ReadProgramError(*this\program)
        If str$
          STDERR$ + str$ + #CRLF$
          
          If ExamineRegularExpression(regExpProgress, str$)
            If NextRegularExpressionMatch(regExpProgress)
              *this\progress = Val(RegularExpressionGroup(regExpProgress, 1))
              If *this\onProgress\event
                PostEvent(*this\onProgress\event, *this\progress, *this)
              EndIf
              If *this\onProgress\callback
                *this\onProgress\callback(*this)
              EndIf
            EndIf
          EndIf
        EndIf
        Delay(1)
      Wend
      FreeRegularExpression(regExpProgress)
      If Not *this\cancel
        *this\exitCode = ProgramExitCode(*this\program)
      EndIf
      CloseProgram(*this\program)
      *this\program = #Null
      
      If *this\exitCode = 0
        Deb("wget:: #"+*this+": download ok")
      Else
        Select *this\exitCode
          Case 0 ; no error, cannot be reached
          Case 1
            *this\lastError$ = "generic error"
          Case 2
            *this\lastError$ = "parse error"
          Case 3
            *this\lastError$ = "I/O error"
          Case 4
            *this\lastError$ = "network error"
          Case 5
            *this\lastError$ = "SSL error"
          Case 6
            *this\lastError$ = "authentification error"
          Case 7
            *this\lastError$ = "protocol error"
          Case 8
            *this\lastError$ = "server error"
          Case -1
            *this\lastError$ = "program error"
          Default
            *this\lastError$ = "unknown error"
        EndSelect
        
        deb("wget:: #"+*this+": "+*this\lastError$)
        
        If STDOUT$
          deb("wget:: #"+*this+" STDOUT output:"+#CRLF$+STDOUT$+#CRLF$)
        EndIf
        If STDERR$
          deb("wget:: #"+*this+" STDERR output:"+#CRLF$+STDERR$+#CRLF$)
        EndIf
      EndIf
      
    Else ; could not start program
      *this\lastError$ = "could not start wget"
      deb("wget:: #"+*this+": "+*this\lastError$)
      *this\exitCode = -1
    EndIf
    
    *this\cancel = #False
    *this\thread = #Null
    UnlockMutex(*this\mutex)
    
    Protected ret = *this\exitCode
    ; attention: OnError and OnSuccess callbacks might be used to free() *this!
    ; callback at the end of the thread!
    ; STILL, if e.g. "waitFinished()" is active and the callback is used to free() the data, waitFinished() will have invalid memory access!
    ; MUST BE FIXED!
    ; I would like a completely event-based approach (no direkt callback functions).
    ; This way, all destructive functions could be limited To the main thread in which no concurrency is happening.
    ; however, PB event queue is based on window events, so only the window module can coordinate all events that happen.
    If *this\exitCode = 0
      If *this\onSuccess\event
        PostEvent(*this\onSuccess\event, #Null, *this)
      EndIf
      If *this\onSuccess\callback
        *this\onSuccess\callback(*this)
      EndIf
    Else ; error
      If *this\onError\event
        PostEvent(*this\onError\event, #Null, *this)
      EndIf
      If *this\onError\callback
        *this\onError\callback(*this) 
      EndIf
    EndIf
    
    ProcedureReturn ret
  EndProcedure
  
  ;- Public
  
  Procedure NewDownload(remote$, local$, timeout.l=10, async.b=#True)
    Protected *this._wget
    *this = AllocateStructure(_wget)
    *this\vt = ?vt
    
    *this\remote$ = remote$
    *this\local$  = local$
    *this\timeout = timeout
    *this\async   = async
    *this\mutex   = CreateMutex()
    
    LockMutex(_mutexList)
    AddElement(*objects())
    *objects() = *this
    UnlockMutex(_mutexList)
    
    ProcedureReturn *this
  EndProcedure
  
  Procedure StartDownload(*this._wget)
    If TryLockMutex(*this\mutex)
      *this\cancel = #False
      If *this\async
        *this\thread = CreateThread(@downloadThread(), *this)
        ProcedureReturn Bool(*this\thread)
      Else
        *this\thread = #False
        ProcedureReturn downloadThread(*this)
      EndIf
    Else
      deb("wget:: download already active")
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure FreeDownload(*this._wget)
    Protected found.b
    LockMutex(_mutexList)
    ForEach *objects()
      If *objects() = *this
        DeleteElement(*objects())
        found = #True
        Break
      EndIf
    Next
    UnlockMutex(_mutexList)
    
    If Not found
      deb("wget:: free() could not find download in local list, might be invalid/already freed!")
      ProcedureReturn #False
    EndIf
    
    If *this\thread And IsThread(*this\thread)
      *this\cancel = #True
      ; thread will trigger a error callback if defined. That callback might trigger a "FreeDownload()" call
      ; therefore, each freedownload call checks if the object is still in the internal list
      ; this is some overhead, but also used for the freeAll() method
      WaitThread(*this\thread)
    EndIf
    FreeMutex(*this\mutex)
    FreeStructure(*this)
  EndProcedure
  
  Procedure setUserAgent(*this._wget, useragent$="")
    *this\useragent$ = useragent$
  EndProcedure
  
  Procedure setTimeout(*this._wget, timeout.l)
    *this\timeout = timeout
  EndProcedure
  
  Procedure setAsync(*this._wget, async.b)
    *this\async = async
  EndProcedure
  
  Procedure setUserData(*this._wget, *userdata)
    *this\userdata = *userdata
  EndProcedure
  
  Procedure.s getUserAgent(*this._wget)
    ProcedureReturn *this\useragent$
  EndProcedure
  
  Procedure.l getTimeout(*this._wget)
    ProcedureReturn *this\timeout
  EndProcedure
  
  Procedure.b getAsync(*this._wget)
    ProcedureReturn *this\async
  EndProcedure
  
  Procedure getUserData(*this._wget)
    ProcedureReturn *this\userdata
  EndProcedure
  
  Procedure.b getProgress(*this._wget)
    ProcedureReturn *this\progress
  EndProcedure
  
  Procedure.s getRemote(*this._wget)
    ProcedureReturn *this\remote$
  EndProcedure
  
  Procedure.s getFilename(*this._wget)
    ProcedureReturn *this\local$
  EndProcedure
  
  Procedure.s getLastError(*this._wget)
    ProcedureReturn *this\lastError$
  EndProcedure
  
  Procedure waitFinished(*this._wget, timeout.l=0) ; should not be called in a callback function, as the thread itself calls the callback
    Protected thread = *this\thread
    If thread And IsThread(thread)
      If timeout
        If WaitThread(thread, timeout.l)
          ; thread ended
          ProcedureReturn #True
        Else
          ;thread timeout
          *this\cancel = #True ; signal thread to cancel download
          WaitThread(thread) ; hopefully, this finishes in time!
          ProcedureReturn #False
        EndIf
      Else
        ; wait, possibly indefinately
        WaitThread(thread)
        ProcedureReturn #True
      EndIf
    Else ; no thread active
      ProcedureReturn #True
    EndIf
  EndProcedure
  
  Procedure EventOnProgress(*this._wget, event=0)
    *this\onProgress\event = event
  EndProcedure
  
  Procedure EventOnSuccess(*this._wget, event=0)
    *this\onSuccess\event = event
  EndProcedure
  
  Procedure EventOnError(*this._wget, event=0)
    *this\onError\event = event
  EndProcedure
  
  Procedure CallbackOnProgress(*this._wget, *function.callbackFunction = #Null)
    *this\onProgress\callback = *function
  EndProcedure
  
  Procedure CallbackOnSuccess(*this._wget, *function.callbackFunction = #Null)
    *this\onSuccess\callback = *function
  EndProcedure
  
  Procedure CallbackOnError(*this._wget, *function.callbackFunction = #Null)
    *this\onError\callback = *function
  EndProcedure
  
  ;- Static
  
  Procedure setProxy(host$, username$="", password$="")
    Protected proxy$
    If host$
      If FindString(host$, "://")
        host$ = Mid(host$, FindString(host$, "://")+3) ; remove any protocol (e.g. http://) in front of host adress
      EndIf
      proxy$ = "http://"+username$+":"+password$+"@"+host$
      SetEnvironmentVariable("http_proxy", proxy$)
      SetEnvironmentVariable("https_proxy", proxy$)
    Else
      RemoveEnvironmentVariable("http_proxy")
      RemoveEnvironmentVariable("https_proxy")
    EndIf
  EndProcedure
  
  Procedure freeAll()
    Protected NewList *obj._wget()
    deb("wget:: freeAll()")
    
    LockMutex(_mutexList)
    If ListSize(*objects())
      deb("wget:: "+ListSize(*objects())+" downloads active, kill all downloads")
      CopyList(*objects(), *obj())
    EndIf
    UnlockMutex(_mutexList)
    
    ForEach *obj()
      FreeDownload(*obj())
    Next
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  Enumeration #PB_Event_FirstCustomValue
    #EventDownloadProgress
    #EventDownloadError
    #EventDownloadSuccess
  EndEnumeration
  
  Define win
  win = OpenWindow(#PB_Any, 0, 0, 600, 35, "Download...", #PB_Window_SystemMenu|#PB_Window_Tool|#PB_Window_ScreenCentered)
  progressbar = ProgressBarGadget(#PB_Any, 5, 5, 590, 25, 0, 100)
  
  Define *wget.wget::wget
;   wget::setProxy("http://proxy.net", "xxx", "xxx")
  *wget = wget::NewDownload("https://www.transportfevermods.com/repository/mods/workshop.json", GetTemporaryDirectory()+"workshop.json")
  *wget\setTimeout(1)
  *wget\setAsync(#True)
  *wget\EventOnProgress(#EventDownloadProgress)
  *wget\EventOnError(#EventDownloadError)
  *wget\EventOnSuccess(#EventDownloadSuccess)
  *wget\start()
  
  Repeat
    Select WaitWindowEvent()
      Case #PB_Event_CloseWindow
        Debug "close window"
        *wget\free()
        *wget = #Null
        CloseWindow(win)
        End
        
      Case #EventDownloadError
        Debug "event: download error!"
        *wget = EventGadget()
        Debug "last wget error message: "+*wget\getLastError()
        *wget\free()
        *wget = #Null
        End
        
      Case #EventDownloadProgress
        *wget = EventGadget()
        SetGadgetState(progressbar, *wget\getProgress())
        SetWindowTitle(win, Str(*wget\getProgress())+"%")
        
      Case #EventDownloadSuccess
        Debug "event: download success!"
        *wget = EventGadget()
        *wget\free()
        *wget = #Null
        End
        
    EndSelect
  ForEver
CompilerEndIf
