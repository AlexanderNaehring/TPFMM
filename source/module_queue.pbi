XIncludeFile "module_mods.h.pbi"

DeclareModule queue
  EnableExplicit
  
  Enumeration
    #QueueActionLoad
    
    #QueueActionInstall   ; add file from HDD (and install)
    #QueueActionUninstall ; remove mods from TPF (delete folder vom HDD)
    #QueueActionBackup    ; backup mod to given backupFolder
  EndEnumeration
  
  Structure dat
    string$
    option$
  EndStructure
  
  Declare add(action, string$ = "", option$ = "")
  Declare update()
  
EndDeclareModule

Module queue
  
  Structure queue
    action.i
    string$
    option$
  EndStructure
  
  Global mQueue.i
  Global NewList queue.queue()
  Global *_callback
  Global *thread
  Global *progressWaitThread, progressWaitThreadFlag
  
  debugger::Add("queue::mQueue = CreateMutex()")
  mQueue = CreateMutex()
  
  Procedure add(action, string$ = "", option$ = "") ; add new task to queue
    debugger::Add("queue::add("+Str(action)+", "+string$+", "+option$+")")
    
    LockMutex(mQueue)
    LastElement(queue())
    AddElement(queue())
    queue()\action  = action
    queue()\string$ = string$
    queue()\option$ = option$
    UnlockMutex(mQueue)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure update() ; periodically called by main window
    Protected element.queue
    Static dat.dat
    
    LockMutex(mQueue)
    If *thread
      If Not IsThread(*thread) ; thread finished
        *thread = #False
      EndIf
    EndIf
    
    If main::gameDirectory$ And Not *thread
      If ListSize(queue()) > 0
        debugger::Add("queue::update() - handle next element")
        ; pop first element
        FirstElement(queue())
        element = queue()
        DeleteElement(queue(),1)
        
        Select element\action
          Case #QueueActionLoad
            debugger::Add("queue::update() - #QueueActionLoad")
            *thread = CreateThread(mods::@loadList(), #Null)
            
          Case #QueueActionInstall
            debugger::Add("queue::update() - #QueueActionInstall")
            If element\string$
              dat\string$ = element\string$
              *thread = CreateThread(mods::@install(), dat)
            EndIf
            
          Case #QueueActionUninstall
            debugger::Add("queue::update() - #QueueActionUninstall")
            If element\string$
              dat\string$ = element\string$
              *thread = CreateThread(mods::@uninstall(), dat)
            EndIf
            
          Case #QueueActionBackup
            debugger::add("queue::update() - #QueueActionBackup")
            If element\string$
              dat\string$ = element\string$
              *thread = CreateThread(mods::@backup(), dat)
            EndIf
            
        EndSelect
      EndIf
    EndIf
    
    UnlockMutex(mQueue)
    ProcedureReturn #True
  EndProcedure
  
EndModule
