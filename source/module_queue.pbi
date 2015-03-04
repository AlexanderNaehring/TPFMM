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
  
  Declare progressRegister(window, gadgetP, gadgetT)
  Declare progressText(string$)
  Declare progressVal(val, max=-1)
  
;   Declare busy(busy = -1)
  
EndDeclareModule

Module queue
  
  Structure queue
    action.i
    val$
  EndStructure
  
  Global mQueue.i
  Global NewList queue.queue()
  Global progressW, progressG, progressT
  
  debugger::Add("updateQueue() - MutexQueue = CreateMutex()")
  mQueue = CreateMutex()
  
  Procedure progressRegister(window, gadgetP, gadgetT)
    progressW = window
    progressG = gadgetP
    progressT = gadgetT
  EndProcedure
  
  Procedure progressShow(show = #True)
    If IsWindow(progressW)
      HideWindow(progressW, Bool(Not show), #PB_Window_WindowCentered)
    EndIf
  EndProcedure
  
  Procedure progressVal(val, max=-1)
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
    Static *thread, dat.dat, conversion.i
    
    LockMutex(mQueue) ; lock even bevore InstallInProgress is checked!
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
              progressText(locale::l("progress","install"))
              progressShow()
            EndIf
            
          Case #QueueActionRemove
            debugger::Add("updateQueue() - #QueueActionRemove")
            If element\val$
              dat\id$ = element\val$
              dat\tf$ = TF$
              *thread = CreateThread(mods::@remove(), dat)
              progressText(locale::l("progress","remove"))
              progressShow()
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
              progressText(locale::l("progress","delete"))
              progressShow()
            EndIf
            
          Case #QueueActionLoad
            debugger::Add("updateQueue() - #QueueActionLoad")
            If element\val$
              dat\id$ = element\val$
              dat\tf$ = TF$
              *thread = CreateThread(mods::@load(), dat)
              progressText(locale::l("progress","load"))
              progressShow()
            EndIf
            
          Case #QueueActionConvert
            debugger::Add("updateQueue() - #QueueActionConvert")
            If element\val$
              If MessageRequester(locale::l("conversion","title"), locale::l("conversion","start"), #PB_MessageRequester_YesNo) = #PB_MessageRequester_No
                MessageRequester(locale::l("conversion","title"), locale::l("conversion","legacy"))
              Else
                dat\id$ = element\val$
                dat\tf$ = TF$
                *thread = CreateThread(mods::@convert(), dat)
                conversion = #True
                progressText(locale::l("progress","convert"))
                progressShow()
              EndIf
            EndIf
            
        EndSelect
      EndIf
    EndIf
    
    UnlockMutex(mQueue) ; unlock at the very end
    ProcedureReturn #True
  EndProcedure
  
EndModule

; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 171
; FirstLine = 96
; Folding = D+
; EnableUnicode
; EnableXP