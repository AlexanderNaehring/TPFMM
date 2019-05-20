DeclareModule threads
  EnableExplicit
  
  Declare NewThread(*function, *userdata, name$="")
  Declare CountActiveThreads()
  Declare StopAll(timeout=-1, kill=#True)
  Declare.s GetTreeString()
  
  Declare RequestStop(threadID)
  Declare.b WaitStop(threadID, timeout=-1, kill=#True)
  Declare.b IsStopRequested(threadID=-1)
  
  Declare GetCurrentThreadID()
  Declare isMainThread()
  
EndDeclareModule

Module threads
  
  Structure threadData
    threadPB.i    ; return value of CreateThread()
    threadID.i    ; return value of OS specific unique thread ID function
    parentID.i    ; OS specific thread ID that spawned this thread
    requestStop.b ; used to request a graceful stop of a thread
    valid.b       ; set to false when thread is finished
    paused.b      ; is thread paused?
    *function     ; function to start
    *userdata     ; parameter
    name$         ; name of thread (debug information)
    List *threads.threadData()
  EndStructure
  
  Global *_root.threadData
  Global NewMap *threadData.threadData()
  Global mutex = CreateMutex()
  
  *_root = AllocateStructure(threadData)
  *_root\threadID = GetCurrentThreadID()
  *_root\parentID = #Null
  *_root\valid    = #True
  *threadData(Str(*_root\threadID)) = *_root
  
  ;{ deb()
  CompilerIf Defined(debugger, #PB_Module)
    UseModule debugger
  CompilerElse
    Macro deb(s)
      Debug s
    EndMacro
  CompilerEndIf
  ;}
  
  ;- Private
  
  Procedure GetThreadByThreadID(threadID)
    Protected *data
    LockMutex(mutex)
    *data = FindMapElement(*threadData(), Str(threadID))
    If *data
      *data = PeekI(*data)
    EndIf
    UnlockMutex(mutex)
    ProcedureReturn *data
  EndProcedure
  
  Procedure.s TreeRecursive(*thread.threadData, level=0)
    Protected tree$
    Protected i
    Protected NewList *threads.threadData()
    
    LockMutex(mutex)
    CopyList(*thread\threads(), *threads())
    UnlockMutex(mutex)
    
    If level > 0
      tree$ + ~"\n"
    EndIf
    For i = 1 To level
      tree$ + Space(3) + "|"
    Next
    If level > 0
      tree$ + "- "
    EndIf
    
    If *thread = *_root
      tree$ + "main"
    Else
      If *thread\name$
        tree$ + *thread\name$
      Else
        tree$ + "thread"
      EndIf
    EndIf
    tree$ + "["+*thread\threadID+"]"
    
    If Not *thread\valid
      tree$ + " (stopped)"
    EndIf
    ForEach *threads()
      tree$ + TreeRecursive(*threads(), level+1)
    Next
    ProcedureReturn tree$
  EndProcedure
  
  Procedure threadStarter(*thread.threadData)
    Protected threadID
    ; this is the new thread
    threadID = GetCurrentThreadID()
    ; mutex is still locked by parent, can access map without locking
    *threadData(Str(threadID)) = *thread
    *thread\valid     = #True
    *thread\threadID  = threadID ; NewThread() waits for \threadID before continuing and releasing the mutex lock
    CallFunctionFast(*thread\function, *thread\userdata)
    *thread\valid     = #False
  EndProcedure
  
  ;- Public
  
  Procedure NewThread(*function, *userdata, name$="")
    Protected *thread.threadData
    Protected *parent.threadData
    Protected time
    ; init thread data
    *thread = AllocateStructure(threadData)
    *thread\parentID = GetCurrentThreadID()
    *thread\function = *function
    *thread\userdata = *userdata
    *thread\name$    = name$
    
    ; add thread reference to parent
    *parent = GetThreadByThreadID(*thread\parentID)
    If Not *parent
      DebuggerWarning("threads:: could not find *parent "+*thread\parentID+" for new thread "+name$)
      *parent = *_root
    EndIf
    
    LockMutex(mutex) ; lock mutex until thread is valid
    
    AddElement(*parent\threads())
    *parent\threads() = *thread
    
    ; start thread
    *thread\threadPB = CreateThread(@threadStarter(), *thread)
    time = ElapsedMilliseconds()
    While Not *thread\threadID
      Delay(0)
      If ElapsedMilliseconds() - time > 5000
        ; critical error: thread start takes too long
        DebuggerError("Thread Start Timeout: "+name$)
        Break
      EndIf
    Wend
    
    UnlockMutex(mutex)
    ProcedureReturn *thread\threadID
  EndProcedure
  
  Procedure CountActiveThreads()
    Protected count
    LockMutex(mutex)
    ForEach *threadData()
      If *threadData()\valid
        count + 1
      EndIf
    Next
    UnlockMutex(mutex)
    ProcedureReturn count
  EndProcedure
  
  Procedure StopAll(timeout=-1, kill=#True)
    Protected NewList threadIDs()
    
    LockMutex(mutex)
    ; request stop on all threads
    ; do this before WaitStop() in order to catch potentially nested threads 
    ForEach *threadData()
      If *threadData() <> *_root
        If *threadData()\valid
          *threadData()\requestStop = #True
          AddElement(threadIDs())
          threadIDs() = *threadData()\threadID
        EndIf
      EndIf
    Next
    UnlockMutex(mutex)
    
    ; wait for all threads
    ForEach threadIDs()
      WaitStop(threadIDs(), timeout, kill)
    Next
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure.s GetTreeString()
    ProcedureReturn TreeRecursive(*_root)
  EndProcedure
  
  Procedure RequestStop(threadID)
    Protected *thread.threadData
    *thread = GetThreadByThreadID(threadID)
    If *thread
      *thread\requestStop = #True
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure.b WaitStop(threadID, timeout=-1, kill=#True)
    Protected time, ret
    Protected *thread.threadData
    
    *thread = GetThreadByThreadID(threadID)
    If Not *thread
      ProcedureReturn #False 
    EndIf
    
    ret = #True
    *thread\requestStop = #True
    time = ElapsedMilliseconds()
    While *thread\valid
      Delay(1)
      If timeout <> -1 And ElapsedMilliseconds() - time > timeout
        deb("threads:: Timeout reached during thread stop for "+*thread\threadID+" ("+*thread\name$+")")
        ret = #False
        If kill
          KillThread(*thread\threadPB)
          DebuggerWarning("Thread "+*thread\threadID+" ("+*thread\name$+") killed")
          *thread\valid = #False
        EndIf
        Break
      EndIf
    Wend
    ProcedureReturn ret
  EndProcedure
  
  Procedure.b IsStopRequested(threadID=-1)
    Protected *thread.threadData
    If threadID = -1
      threadID = GetCurrentThreadID()
    EndIf
    *thread = GetThreadByThreadID(threadID)
    If *thread
      ProcedureReturn *thread\requestStop
    EndIf
  EndProcedure
  
  ;-
  
  Procedure GetCurrentThreadID()
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        ProcedureReturn GetCurrentThreadId_()
      CompilerCase #PB_OS_Linux
        ProcedureReturn pthread_self_()
      CompilerDefault
        DebuggerError("Not implemented")
    CompilerEndSelect
  EndProcedure
  
  Procedure isMainThread()
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        ProcedureReturn Bool(GetCurrentThreadId_() = *_root\threadID)
      CompilerCase #PB_OS_Linux
        ProcedureReturn Bool(pthread_self_() = *_root\threadID)
    CompilerEndSelect
  EndProcedure
  
EndModule


CompilerIf #PB_Compiler_IsMainFile
  
  Procedure layer2A(*dummy)
    While Not threads::IsStopRequested()
      ; do some amazing stuff
      Delay(10)
    Wend
    Debug "shutdown of thread "+threads::GetCurrentThreadID()
  EndProcedure
  
  Procedure layer2B(*dummy)
    Delay(300)
  EndProcedure
  
  Procedure layer1A(*dummy)
    threads::NewThread(@layer2A(), 0, "layer2A")
    threads::NewThread(@layer2B(), 0, "layer2B")
    Delay(50)
  EndProcedure
  
  Procedure layer1B(*dummy)
    threads::NewThread(@layer2A(), 0, "layer2A")
    Delay(200)
  EndProcedure
  
  ;- 
  threads::NewThread(@layer1A(), 0, "layer1A")
  threads::NewThread(@layer1B(), 0, "layer1B")
  Delay(10)
  For i = 1 To 5
    Debug Str(threads::CountActiveThreads())+" threads active"
    Debug threads::GetTreeString()+#LF$
    Delay(100)
  Next
  Debug "request to stop all threads"
  threads::StopAll(250)
  
  Debug #LF$+threads::GetTreeString()+#LF$
  
  Debug "Goodbye!"
  End
  
CompilerEndIf
