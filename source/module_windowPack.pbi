DeclareModule windowPack
  EnableExplicit
  
  Declare show(parentWindow, open=#False)
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_pack.pbi"
XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_windowMain.pbi"

Module windowPack
  
  Global window, dialog, parent
  Global *pack
  Global NewList items.pack::packItem()
  
  Macro gadget(name)
    DialogGadget(dialog, name)
  EndMacro
  
  
  ; actions
  
  Procedure displayItem(index)
    SelectElement(items(), index)
    
    AddGadgetItem(gadget("items"), index, items()\name$)
    SetGadgetItemData(gadget("items"), index, items())
  EndProcedure
  
  Procedure displayNewPackItem(*packItem.pack::packItem)
    LastElement(items())
    AddElement(items())
    CopyStructure(*packItem, items(), pack::packItem)
    displayItem(ListIndex(items()))
  EndProcedure
  
  Procedure displayPackItems()
    debugger::add("packWindow::updateItems()")
    
    ClearGadgetItems(gadget("items"))
    ClearList(items())
    pack::getItems(*pack, items())
    
    Protected i
    For i = 0 To ListSize(items())-1
      displayItem(i)
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
  
  Procedure packSave()
    Protected file$
    file$ = SaveFileRequester(locale::l("pack","save"), GetCurrentDirectory(), "Pack File|*."+pack::#EXTENSION, 0)
    If file$
      If FileSize(file$) > 0
        If MessageRequester(locale::l("pack","overwrite"), locale::l("pack","overwrite_text"), #PB_MessageRequester_YesNo) <> #PB_MessageRequester_Yes
          ProcedureReturn #False
        EndIf
      EndIf
      
      pack::save(*pack, file$)
    EndIf
  EndProcedure
  
  
  Procedure addModToPack(*pack, *mod.mods::mod)
    debugger::add("windowPack::addModToPack()")
    
    Protected packItem.pack::packItem
    
    packItem\name$ = *mod\name$
    packItem\folder$ = *mod\tpf_id$
    packItem\download$ = *mod\aux\installSource$
    packItem\required = #True
    
    pack::addItem(*pack, packItem)
    
    displayNewPackItem(packItem)
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
  
  Procedure itemsDrop()
    If EventDropPrivate() = main::#DRAG_MOD
      debugger::add("windowPack::gadgetItems() - mods dropped on pack item list")
      
      Protected NewList *mods()
      windowMain::getSelectedMods(*mods())
      ForEach *mods()
        addModToPack(*pack, *mods())
      Next
    EndIf
  EndProcedure
  
  Procedure gadgetItems()
    
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
    
    ; set text
    SetWindowTitle(window, l("pack","title"))
    SetGadgetText(gadget("nameText"), l("pack","name"))
    SetGadgetText(gadget("authorText"), l("pack","author"))
    SetGadgetText(gadget("save"), l("pack","save"))
    SetGadgetText(gadget("install"), l("pack","install"))
    
    BindGadgetEvent(gadget("save"), @packSave())
    
    ; enable mods to be dropped in the pack item list
    EnableGadgetDrop(gadget("items"), #PB_Drop_Private, #PB_Drag_Copy, main::#DRAG_MOD)
    BindEvent(#PB_Event_GadgetDrop, @itemsDrop(), window, gadget("items"))
    
    ; close event
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    
    ; finish window
    displayPackItems()
    RefreshDialog(dialog)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    
  EndProcedure
  
  
EndModule
