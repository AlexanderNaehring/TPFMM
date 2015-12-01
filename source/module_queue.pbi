XIncludeFile "module_mods.h.pbi"

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
    If IsWindow(progressW)
      HideWindow(progressW, Bool(Not show), #PB_Window_WindowCentered)
    EndIf
  EndProcedure
  
  Procedure progressVal(val, max=-1)
    ;debugger::Add("queue::progressVal("+Str(val)+","+Str(max)+")")
    
    If IsWindow(progressW) And IsGadget(progressG)
      If max <> -1
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
  
  Procedure update() ; periodically called by main window / main loop
    Protected element.queue
    Static dat.dat, conversion.i
    
    LockMutex(mQueue)
    If *thread
      If Not IsThread(*thread) ; thread finished
        *thread = #False
        progressShow(#False)
        If conversion
          conversion = #False
          MessageRequester(locale::l("conversion","title"), locale::l("conversion","finish"))
        EndIf
      EndIf
    EndIf
    
    If main::TF$ And Not *thread
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
              dat\string$ = element\val$
              *thread = CreateThread(mods::@install(), dat)
              progressText(locale::l("progress","install"))
              progressShow()
            EndIf
            
          Case #QueueActionRemove
            debugger::Add("updateQueue() - #QueueActionRemove")
            If element\val$
              dat\string$ = element\val$
              *thread = CreateThread(mods::@remove(), dat)
              progressText(locale::l("progress","remove"))
              progressShow()
            EndIf
            
          Case #QueueActionNew
            debugger::Add("updateQueue() - #QueueActionNew")
            If element\val$
              dat\string$ = element\val$
              *thread = CreateThread(mods::@new(), dat)
              progressText(locale::l("progress","new"))
              progressShow()
            EndIf
            
          Case #QueueActionDelete
            debugger::Add("updateQueue() - #QueueActionDelete")
            If element\val$
              dat\string$ = element\val$
              *thread = CreateThread(mods::@delete(), dat)
              progressText(locale::l("progress","delete"))
              progressShow()
            EndIf
            
          Case #QueueActionLoad
            debugger::Add("updateQueue() - #QueueActionLoad")
            *thread = CreateThread(mods::@loadList(), #Null)
            progressText("") ; text will be set in function
            progressVal(0, 1)
            progressShow()
            
          Case #QueueActionConvert
            debugger::Add("updateQueue() - #QueueActionConvert")
            If element\val$
              If MessageRequester(locale::l("conversion","title"), locale::l("conversion","start"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
                MessageRequester(locale::l("conversion","title"), locale::l("conversion","legacy"))
              Else
                *thread = CreateThread(mods::@convert(), #Null)
                conversion = #True
                progressText(locale::l("progress","convert"))
                progressShow()
              EndIf
            EndIf
            
        EndSelect
      EndIf
    EndIf
    
    UnlockMutex(mQueue)
    ProcedureReturn #True
  EndProcedure
  
  
  Procedure progressWaitThread(*dummy)
    Static val
    progressWaitThreadFlag = #True
    While progressWaitThreadFlag
      progressVal(val, 100)
      val + 3
      If val > 100
        val = 0
      EndIf
      Delay(80)
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
