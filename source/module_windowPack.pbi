DeclareModule windowPack
  EnableExplicit
  
  Declare show(parentWindow, open=#False)
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_pack.pbi"

Module windowPack
  
  Global window, dialog, parent
  Global *pack
  Global NewList items.pack::packItem()
  
  Macro gadget(name)
    DialogGadget(dialog, name)
  EndMacro
  
  
  ; actions 
  Procedure updateItems()
    debugger::add("packWindow::updateItems()")
    
    ClearGadgetItems(gadget("items"))
    ClearList(items())
    pack::getItems(*pack, items())
    
    Protected i = 0
    ForEach items()
      AddGadgetItem(gadget("items"), i, items()\name$)
      SetGadgetItemData(gadget("items"), i, items())
      i + 1
    Next
  EndProcedure
  
  Procedure packOpen()
    debugger::add("windowPack::packOpen()")
    Protected file$, pattern$
    pattern$ = "pack|*.tpfp|all|*.*"
    file$ = OpenFileRequester(locale::l("pack","open"), settings::getString("","lastPackFile"), pattern$, 0)
    If file$ = ""
      ProcedureReturn #False
    EndIf
    
    settings::setString("","lastPackFile",file$)
    
    *pack = pack::open(file$)
    
    ProcedureReturn *pack
  EndProcedure
  
  
  
  
  ; events
  
  Procedure close()
    debugger::add("windowPack::close()")
    If pack::isPack(*pack)
      pack::free(*pack)
    EndIf
    HideWindow(window, #True)
    CloseWindow(window)
  EndProcedure
  
  Procedure gadgetItems()
    Select EventType()
      Case #PB_Event_GadgetDrop
        If EventDropPrivate() = main::#DRAG_MOD
          debugger::add("windowPack::gadgetItems() - mods dropped on pack item list")
          
          ; TODO get selected mods from main window and add to current pack
          
        EndIf
    EndSelect
  EndProcedure
  
  ; public
  
  Procedure show(parentWindow, open=#False)
    debugger::add("packWindow::show()")
    
    If IsWindow(window)
      debugger::add("packWindow::show() - window already open - cancel")
      ProcedureReturn #False
    EndIf
    
    parent = parentWindow
    
    ; open a pack file if requested
    If open
      If Not packOpen()
        ; if user aborted open dialog -> exit
        ProcedureReturn #False
      EndIf
    EndIf
    
    ; if no pack open, create new pack
    If Not pack::isPack(*pack)
      *pack = pack::create()
    EndIf
    
    
    UseModule locale ; import namespace "locale" for shorthand "l()" access
    DataSection
      dataDialogXML:
      IncludeBinary "dialogs/pack.xml"
      dataDialogXMLend:
    EndDataSection
    ; open dialog
    Protected xml 
    xml = CatchXML(#PB_Any, ?dataDialogXML, ?dataDialogXMLend - ?dataDialogXML)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      MessageRequester("Critical Error", "Could not read xml!", #PB_MessageRequester_Error)
      End
    EndIf
    dialog = CreateDialog(#PB_Any)
    If Not OpenXMLDialog(dialog, xml, "pack", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, WindowID(parent))
      MessageRequester("Critical Error", "Could not open dialog!"+#CRLF$+DialogError(dialog), #PB_MessageRequester_Error)
      End
    EndIf
    FreeXML(xml)
    window = DialogWindow(dialog)
    
    SetWindowTitle(window, l("pack","title"))
    
    ; enable mods to be dropped in the pack item list
    EnableGadgetDrop(gadget("items"), #PB_Drop_Private, #PB_Drag_Copy, main::#DRAG_MOD)
    
    BindGadgetEvent(gadget("items"), @gadgetItems())
    
    
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    
    updateItems()
    RefreshDialog(dialog)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    
  EndProcedure
  
  
EndModule
