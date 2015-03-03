XIncludeFile "module_mods_h.pbi"

DeclareModule queue
  EnableExplicit
  
  Enumeration
    #QueueActionLoad
    #QueueActionConvert
    
    #QueueActionNew
    #QueueActionDelete
    
    #QueueActionInstall
    #QueueActionRemove
  EndEnumeration
  
  Structure dat
    tf$
    id$
  EndStructure
  
  Declare add(action, val$)
  Declare update(TF$)
  
;   Declare busy(busy = -1)
  
EndDeclareModule

Module queue
  
  Structure queue
    action.i
    val$
  EndStructure
  
  Global mQueue.i
  Global NewList queue.queue()
  
  debugger::Add("updateQueue() - MutexQueue = CreateMutex()")
  mQueue = CreateMutex()
  
  Procedure add(action, val$)
    debugger::Add("queue::add("+Str(action)+", "+val$+")")
    If val$ = ""
      ProcedureReturn #False
    EndIf
    
    LockMutex(mQueue)
    LastElement(queue())
    AddElement(queue())
    queue()\action = action
    queue()\val$ = val$
    UnlockMutex(mQueue)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure update(TF$)
    Protected element.queue
    Static *thread, dat.dat
    
    LockMutex(mQueue) ; lock even bevore InstallInProgress is checked!
    If *thread
      If Not IsThread(*thread) ; thread finished
        *thread = #False
      EndIf
    EndIf
    
    If TF$ And Not *thread
      If ListSize(queue()) > 0
        debugger::Add("updateQueue() - handle next element")
        ; pop first element
        FirstElement(queue())
        element = queue()
        DeleteElement(queue(),1)
        
        Select element\action
          Case #QueueActionInstall
            debugger::Add("updateQueue() - #QueueActionInstall")
            If element\val$
              dat\id$ = element\val$
              dat\tf$ = TF$
              *thread = CreateThread(mods::@install(), dat)
            EndIf
            
          Case #QueueActionRemove
            debugger::Add("updateQueue() - #QueueActionRemove")
            If element\val$
              dat\id$ = element\val$
              dat\tf$ = TF$
              *thread = CreateThread(mods::@remove(), dat)
            EndIf
            
          Case #QueueActionNew
            debugger::Add("updateQueue() - #QueueActionNew")
            If element\val$
              mods::new(element\val$, TF$)
            EndIf
            
          Case #QueueActionDelete
            debugger::Add("updateQueue() - #QueueActionDelete")
            If element\val$
              dat\id$ = element\val$
              dat\tf$ = TF$
              *thread = CreateThread(mods::@delete(), dat)
            EndIf
            
          Case #QueueActionLoad
            debugger::Add("updateQueue() - #QueueActionLoad")
            If element\val$
              dat\id$ = element\val$
              dat\tf$ = TF$
              *thread = CreateThread(mods::@load(), dat)
            EndIf
            
          Case #QueueActionConvert
            debugger::Add("updateQueue() - #QueueActionConvert")
            If element\val$
              dat\id$ = element\val$
              dat\tf$ = TF$
              *thread = CreateThread(mods::@convert(), dat)
            EndIf
            
        EndSelect
      EndIf
    EndIf
    
    UnlockMutex(mQueue) ; unlock at the very end
    ProcedureReturn #True
  EndProcedure
  
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 118
; FirstLine = 72
; Folding = 8
; EnableUnicode
; EnableXP