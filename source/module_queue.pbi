XIncludeFile "module_mods_h.pbi"

DeclareModule queue
  EnableExplicit
  
  Enumeration
    #QueueActionNew
    #QueueActionDelete
    
    #QueueActionInstall
    #QueueActionRemove
  EndEnumeration
  
  Declare add(action, val$)
  Declare update(TF$)
  
EndDeclareModule

Module queue
  
  Structure queue
    action.i
    val$
  EndStructure
  
  Global MutexQueue.i, InstallInProgress.i
  Global NewList queue.queue()
  
  Procedure add(action, val$)
    debugger::Add("queue::add("+Str(action)+", "+val$+")")
    If Not MutexQueue
      debugger::Add("queue::add() - MutexQueue created")
      MutexQueue = CreateMutex()
    EndIf
    
    If val$ = ""
      ProcedureReturn #False
    EndIf
    If action <> #QueueActionNew And action <> #QueueActionDelete And action <> #QueueActionInstall And action <> #QueueActionRemove
      ProcedureReturn #False
    EndIf
    
    LockMutex(MutexQueue)
    LastElement(queue())
    AddElement(queue())
    queue()\action = action
    queue()\val$ = val$
    UnlockMutex(MutexQueue)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure update(TF$)
    Protected element.queue, *buffer
    Protected text$, author$
    
    If Not MutexQueue
      debugger::Add("updateQueue() - MutexQueue = CreateMutex()")
      MutexQueue = CreateMutex()
    EndIf
    
    
    LockMutex(MutexQueue) ; lock even bevore InstallInProgress is checked!
    If TF$
      If ListSize(queue()) > 0
        debugger::Add("updateQueue() - handle next element")
        FirstElement(queue())
        element = queue()
        DeleteElement(queue(),1)
        
        If element\val$
          *buffer = AllocateMemory((Len(element\val$)+1) * SizeOf(Character))
          PokeS(*buffer, element\val$)
        Else
          ProcedureReturn #False
        EndIf
        
        Select element\action
          Case #QueueActionInstall
            debugger::Add("updateQueue() - #QueueActionInstall")
            If element\val$
              InstallInProgress = #True ; set true bevore creating thread! -> otherwise may check for next queue entry before this is set!
              CreateThread(mods::@InstallThread(), *buffer)
            EndIf
            
          Case #QueueActionRemove
            debugger::Add("updateQueue() - #QueueActionRemove")
            If element\val$
              InstallInProgress = #True ; set true bevore creating thread! -> otherwise may check for next queue entry before this is set!
              CreateThread(mods::@RemoveThread(), *buffer)
            EndIf
            
          Case #QueueActionNew
            debugger::Add("updateQueue() - #QueueActionNew")
            If element\val$
              mods::new(element\val$, TF$)
            EndIf
            
          Case #QueueActionDelete
            debugger::Add("updateQueue() - #QueueActionDelete")
            If element\val$
              mods::delete(element\val$)
            EndIf
            
        EndSelect
        
      EndIf
    EndIf
    
    UnlockMutex(MutexQueue) ; unlock at the very end
    ProcedureReturn #True
  EndProcedure
    
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 73
; FirstLine = 48
; Folding = -
; EnableUnicode
; EnableXP