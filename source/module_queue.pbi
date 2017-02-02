XIncludeFile "module_mods.h.pbi"

DeclareModule queue
  EnableExplicit
  
  Enumeration
    #QueueActionLoad
    
    #QueueActionInstall   ; add file from HDD (and install)
    #QueueActionDownload  ; download and install mod from online repository
    #QueueActionUninstall ; remove mods from TPF (delete folder vom HDD)
  EndEnumeration
  
  Structure dat
    string$
  EndStructure
  
  Declare add(action, val$ = "")
  Declare update()
  
  Declare progressRegister(window, gadgetP, gadgetT)
  Declare progressText(string$)
  Declare progressVal(val, max=-1)
  
  Declare progressStartWait()
  Declare progressStopWait()
  
EndDeclareModule

Module queue
  
  Structure queue
    action.i
    val$
  EndStructure
  
  Global mQueue.i
  Global NewList queue.queue()
  Global progressW, progressG, progressT
  Global *thread
  Global *progressWaitThread, progressWaitThreadFlag
  
  debugger::Add("queue::mQueue = CreateMutex()")
  mQueue = CreateMutex()
  
  Procedure progressRegister(window, gadgetP, gadgetT)
    progressW = window
    progressG = gadgetP ; progress gadget
    progressT = gadgetT ; text gadget
  EndProcedure
  
  Procedure progressShow(show = #True)
    If progressW And IsWindow(progressW)
      HideWindow(progressW, Bool(Not show), #PB_Window_WindowCentered)
    Else
      ; if no window is defined, just hide / show the gadgets
      If progressG And IsGadget(progressG)
        HideGadget(progressG, Bool(Not show))
      EndIf
      If progressT And IsGadget(progressT)
        HideGadget(progressT, Bool(Not show))
      EndIf
    EndIf
  EndProcedure
  
  Procedure progressVal(val, max=-1)
    ;debugger::Add("queue::progressVal("+Str(val)+","+Str(max)+")")
    
    If IsGadget(progressG)
      If max <> -1 ; if max is defined, set range to [0, max]
        SetGadgetAttribute(progressG, #PB_ProgressBar_Minimum, 0)
        SetGadgetAttribute(progressG, #PB_ProgressBar_Maximum, max)
      EndIf
      SetGadgetState(progressG, val)
    EndIf
  EndProcedure
  
  Procedure progressText(s$)
    If IsGadget(progressT)
      SetGadgetText(progressT, s$)
    EndIf
  EndProcedure
  
  Procedure add(action, val$ = "") ; add new task to queue
    debugger::Add("queue::add("+Str(action)+", "+val$+")")
    
    LockMutex(mQueue)
    LastElement(queue())
    AddElement(queue())
    queue()\action = action
    queue()\val$ = val$
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
        ;progressShow(#False)
        progressVal(0, 1)
        progressText("")
      EndIf
    EndIf
    
    If main::gameDirectory$ And Not *thread
      If ListSize(queue()) > 0
        debugger::Add("updateQueue() - handle next element")
        ; pop first element
        FirstElement(queue())
        element = queue()
        DeleteElement(queue(),1)
        
        Select element\action
          Case #QueueActionLoad
            debugger::Add("updateQueue() - #QueueActionLoad")
            *thread = CreateThread(mods::@loadList(), #Null)
            progressText("") ; text will be set in function
            progressVal(0, 1)
            progressShow()
            
            
          Case #QueueActionInstall
            debugger::Add("updateQueue() - #QueueActionInstall")
            If element\val$
              dat\string$ = element\val$
              *thread = CreateThread(mods::@install(), dat)
              progressText(locale::l("progress","install"))
              progressShow()
            EndIf
            
          Case #QueueActionDownload
            debugger::Add("updateQueue() - #QueueActionDownload")
            If element\val$
              dat\string$ = element\val$
              *thread = CreateThread(mods::@install(), dat)
              progressText(locale::l("progress","install"))
              progressShow()
            EndIf
            
            
          Case #QueueActionUninstall
            debugger::Add("updateQueue() - #QueueActionUninstall")
            If element\val$
              dat\string$ = element\val$
              *thread = CreateThread(mods::@uninstall(), dat)
              progressText(locale::l("progress","uninstall"))
              progressShow()
            EndIf
            
            
        EndSelect
      EndIf
    EndIf
    
    UnlockMutex(mQueue)
    ProcedureReturn #True
  EndProcedure
  
  ; progress animation for tasks that to not update the progress value themselves
  Procedure progressWaitThread(*dummy)
    Static val
    progressWaitThreadFlag = #True
    While progressWaitThreadFlag
      progressVal(val, 100)
      val + 2
      If val > 100
        val = 0
      EndIf
      Delay(50)
    Wend
    progressVal(0, 1)
  EndProcedure
  
  Procedure progressStartWait()
    If Not IsThread(*progressWaitThread)
      CreateThread(@progressWaitThread(), 0)
    EndIf
  EndProcedure
  
  Procedure progressStopWait()
    progressWaitThreadFlag = #False
    Delay(100)
    If IsThread(*progressWaitThread)
      KillThread(*progressWaitThread)
    EndIf
    *progressWaitThread = 0
  EndProcedure
  
EndModule
