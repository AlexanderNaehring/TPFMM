EnableExplicit

XIncludeFile "module_mods.pbi"



DeclareModule queue
  EnableExplicit
  
  Enumeration
    #QueueActionNew
    #QueueActionActivate
    #QueueActionDeactivate
    #QueueActionDelete
  EndEnumeration
  
  Declare add(action, *mods.mods::mod, file$ = "")
  Declare update(InstallInProgress, TF$)
  
EndDeclareModule

Module queue
  
  Structure queue
    action.i
    *mod.mods::mod
    file$
  EndStructure
  
  Global MutexQueue
  Global NewList queue.queue()
  
  Procedure add(action, *mod.mods::mod, file$="")
    debugger::Add("AddToQueue("+Str(action)+", "+Str(*mod)+", "+file$+")")
    If Not MutexQueue
      debugger::Add("MutexQueue = CreateMutex()")
      MutexQueue = CreateMutex()
    EndIf
    
    Select action
      Case #QueueActionNew
        If File$ = ""
          ProcedureReturn #False
        EndIf
          
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActionNew: " + File$)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\File$ = File$
        UnlockMutex(MutexQueue)
        
      Case #QueueActionActivate
        If Not *mod
          ProcedureReturn #False
        EndIf
        
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActionActivate: " + *mod\name$)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\mod = *mod
        UnlockMutex(MutexQueue)
        
      Case #QueueActionDeactivate
        If Not *mod
          ProcedureReturn #False
        EndIf
        
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActionDeactivate: " + *mod\name$)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\mod = *mod
        UnlockMutex(MutexQueue)
        
      Case #QueueActionDelete
        If Not *mod
          ProcedureReturn #False
        EndIf
        
        LockMutex(MutexQueue)
        debugger::Add("Append to queue: QueueActiondelete: " + *mod\name$)
        LastElement(queue())
        AddElement(queue())
        queue()\action = action
        queue()\mod = *mod
        UnlockMutex(MutexQueue)
        
        
    EndSelect
  EndProcedure
  
  Procedure update(InstallInProgress, TF$)
    Protected *mod.mods::mod, element.queue
    Protected text$, author$
    
    If Not MutexQueue
      debugger::Add("updateQueue() - MutexQueue = CreateMutex()")
      MutexQueue = CreateMutex()
    EndIf
    
    LockMutex(MutexQueue) ; lock even bevore InstallInProgress is checked!
    
    If Not InstallInProgress And TF$
      If ListSize(queue()) > 0
        debugger::Add("updateQueue() - handle next element")
        FirstElement(queue())
        element = queue()
        DeleteElement(queue(),1)
        
        
        Select element\action
          Case #QueueActionActivate
            debugger::Add("updateQueue() - #QueueActionActivate")
            If element\mod
;               ShowProgressWindow(element\mod)
              InstallInProgress = #True ; set true bevore creating thread! -> otherwise may check for next queue entry before this is set!
              CreateThread(mods::@InstallThread(), element\mod)
            EndIf
            
          Case #QueueActionDeactivate
            debugger::Add("updateQueue() - #QueueActionDeactivate")
            If element\mod
;               ShowProgressWindow(element\mod)
              InstallInProgress = #True ; set true bevore creating thread! -> otherwise may check for next queue entry before this is set!
              CreateThread(mods::@RemoveThread(), element\mod)
            EndIf
            
          Case #QueueActionDelete
            debugger::Add("updateQueue() - #QueueActiondelete")
            If element\mod
              mods::delete(element\mod\id$)
            EndIf
            
          Case #QueueActionNew
            debugger::Add("updateQueue() - #QueueActionNew")
            If element\File$
              mods::new(element\File$, TF$)
            EndIf
        EndSelect
        
      EndIf
    EndIf
    
    UnlockMutex(MutexQueue) ; unlock at the very end
  EndProcedure
    
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 141
; FirstLine = 44
; Folding = 8
; EnableUnicode
; EnableXP