XIncludeFile "module_mods.h.pbi"

DeclareModule windowInformation
  EnableExplicit
  
  Global id
  
  Global ImageGadgetInformationHeader, ModInformationTextName, ModInformationTextVersion, ModInformationTextAuthors, ModInformationTextCategory, ModInformationTextDownload, ModInformationDisplayName, ModInformationDisplayVersion, ModInformationDisplayDownload, ModInformationChangeName, ModInformationChangeVersion, ModInformationChangeDownload, ModInformationChangeCategory, ModInformationButtonSave, ModInformationButtonClose, ModInformationButtonChange, ModInformationDisplayCategory
  
  Declare create(parentWindow)
  Declare setMod(*mod.mods::mod)
  Declare events(event)
  
EndDeclareModule


Module windowInformation
  Structure authorGadget
    display.i
    changeName.i
    changeID.i
  EndStructure
  
  Global NewList InformationGadgetAuthor.authorGadget() ; list of Gadget IDs for Author links
  
  Global parent
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure resize()
    Protected FormWindowWidth, FormWindowHeight
    FormWindowWidth = WindowWidth(id)
    FormWindowHeight = WindowHeight(id)
    ResizeGadget(ModInformationTextCategory, FormWindowWidth - 350, FormWindowHeight - 120, 70, 20)
    ResizeGadget(ModInformationTextDownload, FormWindowWidth - 350, FormWindowHeight - 90, 70, 20)
    ResizeGadget(ModInformationDisplayDownload, FormWindowWidth - 270, FormWindowHeight - 90, 260, 20)
    ResizeGadget(ModInformationChangeDownload, FormWindowWidth - 270, FormWindowHeight - 90, 260, 20)
    ResizeGadget(ModInformationChangeCategory, FormWindowWidth - 270, FormWindowHeight - 120, 260, 20)
    ResizeGadget(ModInformationButtonSave, FormWindowWidth - 350, FormWindowHeight - 60, 100, 25)
    ResizeGadget(ModInformationButtonClose, FormWindowWidth - 110, FormWindowHeight - 60, 100, 25)
    ResizeGadget(ModInformationButtonChange, FormWindowWidth - 350, FormWindowHeight - 60, 100, 25)
    ResizeGadget(ModInformationDisplayCategory, FormWindowWidth - 270, FormWindowHeight - 120, 260, 20)
  EndProcedure
  
  Procedure ModInformationShowChangeGadgets(show = #True) ; #true = show change gadgets, #false = show display gadgets
    debugger::Add("Show Change Gadgets = "+Str(show))
    show = Bool(show)
    
    HideGadget(ModInformationButtonSave, 1 - show)
    HideGadget(ModInformationChangeName, 1 - show)
    HideGadget(ModInformationChangeVersion, 1 - show)
    HideGadget(ModInformationChangeCategory, 1 - show)
    HideGadget(ModInformationChangeDownload, 1 - show)
    
    HideGadget(ModInformationButtonChange, show)
    HideGadget(ModInformationDisplayName, show)
    HideGadget(ModInformationDisplayVersion, show)
    HideGadget(ModInformationDisplayCategory, show)
    HideGadget(ModInformationDisplayDownload, show)
    
    ForEach InformationGadgetAuthor()
      HideGadget(InformationGadgetAuthor()\changeName, 1-show)
      HideGadget(InformationGadgetAuthor()\changeID, 1-show)
      HideGadget(InformationGadgetAuthor()\display, show)
    Next
  EndProcedure
  
  Procedure GadgetButtonInformationClose(event)
    ClearList(InformationGadgetAuthor())
    HideWindow(id, #True)
    DisableWindow(parent, #False)
    CloseWindow(id)
  EndProcedure
  
  Procedure GadgetButtonInformationChange(event)
    ModInformationShowChangeGadgets()
  EndProcedure
  
  Procedure GadgetButtonInformationSave(event)
    ModInformationShowChangeGadgets(#False)
  EndProcedure
  
  Procedure GadgetInformationLinkTFNET(event)
    Protected link$
    link$ = GetGadgetText(ModInformationDisplayDownload)
    
    If link$ = ""
      ProcedureReturn #False
    EndIf
    
    If Left(LCase(link$), 6) <> "http://" And Left(LCase(link$), 7) <> "https://"
      link$ = URLEncoder("http://"+link$)
    EndIf
    
    misc::openLink(link$)
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(parentWindow)
    parent = parentWindow
    
    Protected width, height
    width = 360
    height = 230
    
    UseModule locale
    
    id = OpenWindow(#PB_Any, 0, 0, width, height, "Mod Information", #PB_Window_SystemMenu | #PB_Window_Invisible | #PB_Window_Tool, WindowID(parent))
    CreateStatusBar(0, WindowID(id))
    AddStatusBarField(300)
    StatusBarText(0, 0, "Label")
    ImageGadgetInformationHeader = ImageGadget(#PB_Any, 0, 0, 360, 8, 0)
    ModInformationTextName = TextGadget(#PB_Any, 10, 20, 70, 20, l("information","name"), #PB_Text_Right)
    ModInformationTextVersion = TextGadget(#PB_Any, 10, 50, 70, 20, l("information","version"), #PB_Text_Right)
    ModInformationTextAuthors = TextGadget(#PB_Any, 10, 80, 70, 20, l("information","author"), #PB_Text_Right)
    ModInformationTextCategory = TextGadget(#PB_Any, 10, 110, 70, 20, l("information","category"), #PB_Text_Right)
    ModInformationTextDownload = TextGadget(#PB_Any, 10, 140, 70, 20, l("information","download"), #PB_Text_Right)
    ModInformationDisplayName = StringGadget(#PB_Any, 90, 20, 260, 20, "", #PB_String_ReadOnly)
    ModInformationDisplayVersion = StringGadget(#PB_Any, 90, 50, 260, 20, "", #PB_String_ReadOnly)
    ModInformationDisplayDownload = HyperLinkGadget(#PB_Any, 90, 140, 260, 20, "http://www.train-fever.net", 0, #PB_HyperLink_Underline)
    SetGadgetColor(ModInformationDisplayDownload, #PB_Gadget_FrontColor,RGB(131,21,85))
    ModInformationChangeName = StringGadget(#PB_Any, 90, 20, 260, 20, "TFMM")
    ModInformationChangeVersion = StringGadget(#PB_Any, 90, 50, 260, 20, "")
    ModInformationChangeDownload = StringGadget(#PB_Any, 90, 140, 260, 20, "http://www.train-fever.net")
    ModInformationChangeCategory = ComboBoxGadget(#PB_Any, 90, 110, 260, 20)
    ModInformationButtonSave = ButtonGadget(#PB_Any, 10, 170, 100, 25, l("information","save"))
    ModInformationButtonClose = ButtonGadget(#PB_Any, 250, 170, 100, 25, l("information","close"))
    ModInformationButtonChange = ButtonGadget(#PB_Any, 10, 170, 100, 25, l("information","change"))
    DisableGadget(ModInformationButtonChange, 1)
    ModInformationDisplayCategory = StringGadget(#PB_Any, 90, 110, 260, 20, "Category", #PB_String_ReadOnly)
    
    BindEvent(#PB_Event_SizeWindow, @resize(), id)
    SetGadgetState(ImageGadgetInformationheader, ImageID(images::Images("headerinfo")))
    
    UnuseModule locale 
  EndProcedure
  
  Procedure setMod(*mod.mods::mod)
    Protected tfnet_mod_url$
    Protected i
    
    ; fill in values for mod
    With *mod
      If \tfnetId
        tfnet_mod_url$ = "train-fever.net/filebase/index.php/Entry/"+Str(\tfnetId)
      EndIf
      
      SetWindowTitle(id, \name$)
      
      SetGadgetText(ModInformationChangeName, \name$)
      SetGadgetText(ModInformationChangeVersion, \aux\version$)
      SetGadgetText(ModInformationChangeCategory, \aux\tags$)
      SetGadgetText(ModInformationChangeDownload, \url$)
      
      SetGadgetText(ModInformationDisplayName, \name$)
      SetGadgetText(ModInformationDisplayVersion, \aux\version$)
      SetGadgetText(ModInformationDisplayCategory, \aux\tags$)
      SetGadgetText(ModInformationDisplayDownload, tfnet_mod_url$)
      
      i = 0
      ResetList(\authors())
      ForEach \authors()
        i + 1
        UseGadgetList(WindowID(id))
        If \authors()\tfnetId
          AddElement(InformationGadgetAuthor())
          InformationGadgetAuthor()\changeName  = StringGadget(#PB_Any, 90, 50 + i*30, 200, 20, \authors()\name$)
          InformationGadgetAuthor()\changeID    = StringGadget(#PB_Any, 300, 50 + i*30, 50, 20, Str(\authors()\tfnetId), #PB_String_Numeric)
          InformationGadgetAuthor()\display     = HyperLinkGadget(#PB_Any, 90, 50 + i*30, 260, 20, \authors()\name$, 0, #PB_HyperLink_Underline)
          SetGadgetData(InformationGadgetAuthor()\display, \authors()\tfnetId)
          SetGadgetColor(InformationGadgetAuthor()\display, #PB_Gadget_FrontColor, RGB(131,21,85))
        Else
          TextGadget(#PB_Any, 90, 50 + i*30, 260, 20, \authors()\name$)
        EndIf
        If i > 1
          ResizeWindow(id, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowHeight(id) + 30)
        EndIf
      Next
      
      StatusBarText(0, 0, \tf_id$ + " " + "(" + misc::Bytes(FileSize(misc::Path(main::tf$+"TFMM/library/"+\tf_id$+"/") + \archive\name$)) + ")")
      
    EndWith
    
    
    ; show correct gadgets
    ModInformationShowChangeGadgets(#False)
      
    DisableWindow(parent, #True)
    HideWindow(id, #False, #PB_Window_WindowCentered)
  EndProcedure
  
  Procedure events(event)
    Select event
      Case #PB_Event_SizeWindow
        ; resize()
      Case #PB_Event_CloseWindow
        GadgetButtonInformationClose(#PB_EventType_LeftClick)
      
      Case #PB_Event_Menu
        Select EventMenu()
        EndSelect
      
      Case #PB_Event_Gadget
        Select EventGadget()
          Case ModInformationDisplayDownload
            GadgetInformationLinkTFNET(EventType())          
          Case ModInformationButtonSave
            GadgetButtonInformationSave(EventType())          
          Case ModInformationButtonClose
            GadgetButtonInformationClose(EventType())          
          Case ModInformationButtonChange
            GadgetButtonInformationChange(EventType())          
        EndSelect
        ForEach InformationGadgetAuthor()
          If EventGadget() = InformationGadgetAuthor()\display
            If EventType() = #PB_EventType_LeftClick
              If GetGadgetData(InformationGadgetAuthor()\display)
                misc::openLink("http://www.train-fever.net/index.php/User/" + Str(GetGadgetData(InformationGadgetAuthor()\display)))
              EndIf
            EndIf
          EndIf
        Next
    EndSelect
    
    ProcedureReturn #True
  EndProcedure
  
EndModule
