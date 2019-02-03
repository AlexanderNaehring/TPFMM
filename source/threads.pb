DeclareModule threads
  EnableExplicit
  
  Declare NewThread(*function, *userdata, name$="")
  Declare CountActiveThreads()
  Declare StopAll(timeout=-1, kill=#True)
  Declare.s GetTreeString()
  
  Declare RequestStop(*thread)
  Declare.b WaitStop(*thread, timeout=-1, kill=#True)
  Declare.b IsStopRequested(*thread=-1)
  
  Declare GetCurrentThreadID()
  Declare isMainThread()
  
EndDeclareModule

Module threads
  
  Structure threadData
    threadPB.i    ; return value of CreateThread()
    threadID.i    ; return value of OS specific unique thread ID function
    parentID.i    ; OS specific thread ID that spawned this thread
    requestStop.b ; used to request a graceful stop of a thread
    started.b     ; indicate that the threadStarter started the user function
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
  
  Procedure threadStarter(*thread.threadData)
    ; this is the new thread
    *thread\threadID = GetCurrentThreadID()
    ; mutex is still locked by parent, can access map without locking
    *threadData(Str(*thread\threadID)) = *thread
    *thread\valid   = #True
    *thread\started = #True ; do not rely on valid as it can return to "false" if userfunction returns quickly
    CallFunctionFast(*thread\function, *thread\userdata)
    *thread\valid   = #False
  EndProcedure
  
  ;- Public
  
  Procedure NewThread(*function, *userdata, name$="")
    Protected *thread.threadData
    Protected *parent.threadData
    ; init thread data
    *thread = AllocateStructure(threadData)
    *thread\parentID = GetCurrentThreadID()
    *thread\function = *function
    *thread\userdata = *userdata
    *thread\name$    = name$
    
    ; add thread reference to parent
    *parent = GetThreadByThreadID(*thread\parentID)
    If Not *parent
      DebuggerWarning("threads:: could not find *parent thread ID in map")
      *parent = *_root
    EndIf
    
    LockMutex(mutex) ; lock mutex until thread is valid
    
    AddElement(*parent\threads())
    *parent\threads() = *thread
    
    ; start thread
    *thread\threadPB = CreateThread(@threadStarter(), *thread)
    While Not *thread\started
      Delay(1)
    Wend
    
    UnlockMutex(mutex)
    ProcedureReturn *thread
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
    Protected NewMap *tmp.threadData()
    
    LockMutex(mutex)
    CopyMap(*threadData(), *tmp())
    UnlockMutex(mutex)
    
    ; request stop on all threads
    ; do this before WaitStop() in order to catch potentially nested threads 
    ForEach *tmp()
      If *tmp() <> *_root
        If *tmp()\valid
          If IsThread(*tmp()\threadPB)
            *tmp()\requestStop = #True
          Else
            *tmp()\valid = #False
          EndIf
        EndIf
      EndIf
    Next
    ; wait for all threads
    ForEach *tmp()
      If *tmp() <> *_root
        WaitStop(*tmp(), timeout, kill)
      EndIf
    Next
    
    ProcedureReturn #True
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
      tree$ + " (inactive)"
    EndIf
    ForEach *threads()
      tree$ + TreeRecursive(*threads(), level+1)
    Next
    ProcedureReturn tree$
  EndProcedure
  
  Procedure.s GetTreeString()
    ProcedureReturn TreeRecursive(*_root)
  EndProcedure
  
  Procedure RequestStop(*thread.threadData)
    *thread\requestStop = #True
  EndProcedure
  
  Procedure.b WaitStop(*thread.threadData, timeout=-1, kill=#True)
    Protected time
    Protected ret
    ret = #True
    *thread\requestStop = #True
    time = ElapsedMilliseconds()
    While *thread\valid
      Delay(1)
      If timeout <> -1 And ElapsedMilliseconds() - time > timeout
        DebuggerWarning("Timeout reached during thread stop for "+*thread\threadID)
        ret = #False
        If kill
          KillThread(*thread\threadPB)
          DebuggerWarning("Thread "+*thread\threadID+" killed")
          *thread\valid = #False
        EndIf
        Break
      EndIf
    Wend
    ProcedureReturn ret
  EndProcedure
  
  Procedure.b IsStopRequested(*thread.threadData=-1)
    If *thread = -1
      *thread = GetThreadByThreadID(GetCurrentThreadID())
    EndIf
    
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
