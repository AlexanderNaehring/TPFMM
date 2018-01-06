; TODO drag&drop mod pack files on pack window to open

DeclareModule windowPack
  EnableExplicit
  
  Declare show(parentWindow)
  Declare packOpen(file$ = "")
  Declare addSelectedMods()
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_pack.pbi"
XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_windowMain.pbi"
XIncludeFile "module_locale.pbi"
XIncludeFile "module_repository.pbi"

Module windowPack
  
  Global window, dialog, parent
  Global *pack
  Global NewList items.pack::packItem()
  
  Enumeration
    #MenuItem_CtrlA
    #MenuItem_Del
  EndEnumeration
  
  Macro gadget(name)
    DialogGadget(dialog, name)
  EndMacro
  
  Declare close()
  
  ; actions
  
  Procedure displayItem(index)
    Protected packItem.pack::packItem
    Protected text$
    Protected gadget = gadget("items")
    
    SelectElement(items(), index)
    packItem = items()
    
    
    AddGadgetItem(gadget, index, packItem\name$)
    SetGadgetItemData(gadget, index, @items())
    
    If mods::isInstalled(packItem\id$)
      SetGadgetItemText(gadget, index, "["+locale::l("pack","installed")+"] "+packItem\name$)
    Else
      ; not installed, check if download link available
      If packItem\download$
        If repository::findModByID(StringField(packItem\download$, 1, "/"), Val(StringField(packItem\download$, 2, "/")))
          ; download link found :-)
          SetGadgetItemText(gadget, index, packItem\name$)
        Else
          ; not found (may also be if repo not yet loaded)
          SetGadgetItemText(gadget, index, "["+locale::l("pack","not_available")+"] "+packItem\name$)
        EndIf
      Else
        SetGadgetItemText(gadget, index, "["+locale::l("pack","not_defined")+"] "+packItem\name$)
      EndIf
    EndIf
    
    
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
  
  Procedure packOpen(file$ = "")
    debugger::add("windowPack::packOpen()")
    Protected pattern$
    
    If file$ = ""
      pattern$ = locale::l("pack","pack_file")+"|*."+pack::#EXTENSION+"|"+locale::l("management","files_all")+"|*.*"
      file$ = OpenFileRequester(locale::l("pack","open"), settings::getString("pack","lastFile"), pattern$, 0)
      If file$ = ""
        ProcedureReturn #False
      EndIf
    EndIf
    
    settings::setString("pack","lastFile",file$)
    
    If pack::isPack(*pack)
      pack::free(*pack)
    EndIf
    ; TODO : revise handling of open packs etc...
    
    *pack = pack::open(file$)
    
    If pack::isPack(*pack)
      SetGadgetText(gadget("name"), pack::getName(*pack))
      SetGadgetText(gadget("author"), pack::getAuthor(*pack))
      
      displayPackItems()
    Else
      *pack = pack::create()
    EndIf
    
    ProcedureReturn *pack
  EndProcedure
  
  Procedure packSave()
    Protected file$
    Protected name$, author$
    
    name$ = pack::getName(*pack)
    author$ = pack::getAuthor(*pack)
    
    file$ = GetPathPart(settings::getString("pack","lastFile")) + name$ + "." + pack::#EXTENSION
    
    file$ = SaveFileRequester(locale::l("pack","save"), file$, locale::l("pack","pack_file")+"|*."+pack::#EXTENSION, 0)
    If file$
      If FileSize(file$) > 0
        If MessageRequester(locale::l("management","overwrite_file"), locale::l("management","overwrite_file"), #PB_MessageRequester_YesNo) <> #PB_MessageRequester_Yes
          ProcedureReturn #False
        EndIf
      EndIf
      
      settings::setString("pack","lastFile",file$)
      settings::setString("pack","author",author$)
      
      If pack::save(*pack, file$)
        close()
      EndIf
    EndIf
  EndProcedure
  
  Procedure addModToPack(*pack, *mod.mods::mod)
    debugger::add("windowPack::addModToPack()")
    
    Protected packItem.pack::packItem
    
    packItem\name$ = *mod\name$
    packItem\id$ = *mod\tpf_id$
    packItem\download$ = mods::getDownloadLink(*mod)
    
    If pack::addItem(*pack, packItem)
      displayNewPackItem(packItem)
    EndIf
  EndProcedure
  
  Procedure addSelectedMods()
    Protected NewList *mods()
    windowMain::getSelectedMods(*mods())
    ForEach *mods()
      addModToPack(*pack, *mods())
    Next
  EndProcedure
  
  ; events
  
  Procedure close()
    debugger::add("windowPack::close()")
    HideWindow(window, #True)
    
    If pack::isPack(*pack)
      pack::free(*pack)
    EndIf
    ClearList(items())
    CloseWindow(window)
  EndProcedure
  
  Procedure itemsDrop()
    If EventDropPrivate() = main::#DRAG_MOD
      addSelectedMods()
    EndIf
  EndProcedure
  
  Procedure changeName()
    pack::setName(*pack, GetGadgetText(gadget("name")))
  EndProcedure
  
  Procedure changeAuthor()
    pack::setAuthor(*pack, GetGadgetText(gadget("author")))
  EndProcedure
  
  Procedure gadgetItems()
    
  EndProcedure
  
  Procedure selectAll()
    Protected i
    If GetActiveGadget() = gadget("items")
      For i = 0 To CountGadgetItems(gadget("items"))-1
        SetGadgetItemState(gadget("items"), i, 1)
      Next
    EndIf
  EndProcedure
  
  Procedure remove()
    Protected i, id$, *packItem.pack::packItem
    For i = CountGadgetItems(gadget("items"))-1 To 0 Step -1
      If GetGadgetItemState(gadget("items"), i)
        SelectElement(items(), i)
        If items() <> GetGadgetItemData(gadget("items"), i)
          debugger::add("windowPack::remove() - address missmatch")
        EndIf
        ChangeCurrentElement(items(), GetGadgetItemData(gadget("items"), i))
        *packItem = items()
        id$ = *packItem\id$
        pack::removeItem(*pack, id$)
        DeleteElement(items())
        RemoveGadgetItem(gadget("items"), i)
      EndIf
    Next
  EndProcedure
  
  Procedure download()
    Protected source$, id.q, fileid.q
    debugger::add("windowPack::dowload()")
    ForEach items()
      If Not mods::isInstalled(items()\id$)
        ; TODO: also set folder name -> used during install to apply identical folder name as during export...
        
        source$ =     StringField(items()\download$, 1, "/")
        id      = Val(StringField(items()\download$, 2, "/"))
        fileID  = Val(StringField(items()\download$, 3, "/"))
        
        debugger::add("windowPack::dowload() - start download of mod "+items()\name$+": "+items()\download$)
        repository::downloadMod(source$, id, fileid)
      EndIf
    Next
  EndProcedure
  
  ; public
  
  Procedure show(parentWindow)
    debugger::add("packWindow::show()")
    
    If IsWindow(window)
      debugger::add("packWindow::show() - window already open - cancel")
      ProcedureReturn #False
    EndIf
    
    parent = parentWindow
    
    
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
    SetGadgetText(gadget("download"), l("pack","download"))
    SetGadgetText(gadget("author"), settings::getString("pack","author"))
    GadgetToolTip(gadget("items"), l("pack","tip"))
    
    BindGadgetEvent(gadget("save"), @packSave())
    BindGadgetEvent(gadget("name"), @changeName(), #PB_EventType_Change)
    BindGadgetEvent(gadget("author"), @changeAuthor(), #PB_EventType_Change)
    BindGadgetEvent(gadget("download"), @download())
    
    Protected menu
    menu = CreateMenu(#PB_Any, WindowID(window))
    BindMenuEvent(menu, #MenuItem_CtrlA, @selectAll())
    BindMenuEvent(menu, #MenuItem_Del, @remove())
    
    AddKeyboardShortcut(window, #PB_Shortcut_Control | #PB_Shortcut_A, #MenuItem_CtrlA)
    AddKeyboardShortcut(window, #PB_Shortcut_Delete, #MenuItem_Del)
    
    ; enable mods to be dropped in the pack item list
    EnableGadgetDrop(gadget("items"), #PB_Drop_Private, #PB_Drag_Copy, main::#DRAG_MOD)
    BindEvent(#PB_Event_GadgetDrop, @itemsDrop(), window, gadget("items"))
    
    ; close event
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    
    
    ; finish window
    RefreshDialog(dialog)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    
    
    ; init package
    *pack = pack::create()
    
    SetActiveGadget(gadget("name"))
    
    ProcedureReturn #True
  EndProcedure
  
  
EndModule
