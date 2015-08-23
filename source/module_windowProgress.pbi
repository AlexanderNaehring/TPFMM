DeclareModule windowProgress
  EnableExplicit
  
  Enumeration
    #AnswerNone
    #AnswerYes
    #AnswerNo
    #AnswerYesAll
    #AnswerNoAll
    #AnswerOk
  EndEnumeration
  
  Global id
  Global ModProgressAnswer = #AnswerNone
  
  Declare create(parentWindow)
  Declare events(event)
EndDeclareModule

XIncludeFile "module_locale.pbi"
XIncludeFile "module_queue.pbi"

Module windowProgress
  Global parent
  Global GadgetProgressText, GadgetProgress
  
  Global GadgetModNo, GadgetModNoAll, GadgetModOK, GadgetModProgress, GadgetModText, GadgetModYes, GadgetModYesAll
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure GadgetModYes(event)
    ModProgressAnswer = #AnswerYes
  EndProcedure
  
  Procedure GadgetModNo(event)
    ModProgressAnswer = #AnswerNo
  EndProcedure
  
  Procedure GadgetModYesAll(event)
    ModProgressAnswer = #AnswerYesAll
  EndProcedure
  
  Procedure GadgetModNoAll(event)
    ModProgressAnswer = #AnswerNoAll
  EndProcedure
  
  Procedure GadgetModOk(event)
    ModProgressAnswer = #AnswerOk
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(parentWindow)
    parent = parentWindow
    
    Protected width, height
    width = 400
    height = 70
    id = OpenWindow(#PB_Any, 0, 0, width, height, locale::l("progress","title"), #PB_Window_SystemMenu | #PB_Window_Invisible | #PB_Window_Tool | #PB_Window_WindowCentered, WindowID(parent))
    GadgetProgressText = TextGadget(#PB_Any, 0, 10, 400, 25, "", #PB_Text_Center)
    GadgetProgress = ProgressBarGadget(#PB_Any, -10, 40, 410, 30, 0, 100, #PB_ProgressBar_Smooth)
    
    queue::progressRegister(id, GadgetProgress, GadgetProgressText)
    
  EndProcedure
  
  Procedure events(event)
    Select event
      Case #PB_Event_CloseWindow
        ProcedureReturn #False
  
      Case #PB_Event_Menu
        Select EventMenu()
            
        EndSelect
  
      Case #PB_Event_Gadget
        Select EventGadget()
            
        EndSelect
    EndSelect
    ProcedureReturn #True
  EndProcedure
  
EndModule

; EnableXP