﻿
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
  UseModule debugger
  
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
    Protected installed$, download$
    
    SelectElement(items(), index)
    packItem = items()
    
    
    If mods::isInstalled(packItem\id$)
      installed$ = locale::l("pack","yes")
    Else
      ; not installed, check if download link available
      installed$ = locale::l("pack","no")
    EndIf
    
    Protected *mod.repository::RepositoryMod
    *mod = repository::getModByFoldername(packItem\id$)
    download$ = *mod\getLink()
    
    If download$ = ""
      download$ = packItem\download$
    EndIf
    
    If download$
      If repository::getModByLink(download$)
        ; download link found :-)
        download$ = locale::l("pack","available")
      Else
        ; mod not found (may also be if repo not yet loaded)
        download$ = locale::l("pack","invalid")
      EndIf
    Else
      download$ = locale::l("pack","undefined")
    EndIf
    
    AddGadgetItem(gadget, index, packItem\name$+#LF$+installed$+#LF$+download$)
    SetGadgetItemData(gadget, index, @items())
    
  EndProcedure
  
  Procedure displayNewPackItem(*packItem.pack::packItem)
    LastElement(items())
    AddElement(items())
    CopyStructure(*packItem, items(), pack::packItem)
    displayItem(ListIndex(items()))
  EndProcedure
  
  Procedure displayPackItems()
    ClearGadgetItems(gadget("items"))
    ClearList(items())
    pack::getItems(*pack, items())
    
    Protected i
    For i = 0 To ListSize(items())-1
      displayItem(i)
    Next
  EndProcedure
  
  Procedure packOpen(file$ = "")
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
    
    file$ = GetPathPart(settings::getString("pack","lastFile")) + name$
    file$ = SaveFileRequester(locale::l("pack","save"), file$, locale::l("pack","pack_file")+"|*."+pack::#EXTENSION, 0)
    If file$
      If LCase(GetExtensionPart(file$)) <> pack::#EXTENSION
        file$ + "." + pack::#EXTENSION
      EndIf
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
  
  Procedure addModToPack(*pack, *mod.mods::LocalMod)
    Protected packItem.pack::packItem
    
    packItem\name$ = *mod\getName()
    packItem\id$ = *mod\getID()
    
    Protected *modRepo.repository::RepositoryMod
    *modRepo = repository::getModByFoldername(packItem\id$)
    packItem\download$ = *modRepo\getLink()
    
    If packItem\download$ = ""
      packItem\download$ = *mod\getDownloadLink()
    EndIf
    
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
    HideWindow(window, #True)
    
    If pack::isPack(*pack)
      pack::free(*pack)
    EndIf
    ClearList(items())
    CloseWindow(window)
  EndProcedure
  
  Procedure itemsDrop()
    Protected files$, file$, i
    If EventDropType() = #PB_Drop_Private
      If EventDropPrivate() = main::#DRAG_MOD
        addSelectedMods()
      EndIf
    Else
      files$ = EventDropFiles()
      
      For i = 1 To CountString(files$, Chr(10)) + 1
        file$ = StringField(files$, i, Chr(10))
        
        If LCase(GetExtensionPart(file$)) = pack::#EXTENSION
          windowPack::packOpen(file$)
        Else
          ; also add other file types?
          ; not for now...
        EndIf
      Next i
    EndIf
  EndProcedure
  
  Procedure changeName()
    pack::setName(*pack, GetGadgetText(gadget("name")))
  EndProcedure
  
  Procedure changeAuthor()
    pack::setAuthor(*pack, GetGadgetText(gadget("author")))
  EndProcedure
  
  Procedure gadgetItems()
    If EventType() = #PB_EventType_LeftDoubleClick
      ; download currently selected mod
      Protected *packItem.pack::packItem
      *packItem = GetGadgetItemData(gadget("items"), GetGadgetState(gadget("items")))
      If *packitem
        If Not mods::isInstalled(*packitem\id$)
          ; TODO: also set folder name -> used during install to apply identical folder name as during export...
          
          ;repository::downloadMod(source$, id, fileid)
          windowMain::repoFindModAndDownload(*packitem\download$) ; will display selection dialog if multiple files in mod
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure selectAll()
    Protected i
    If GetActiveGadget() = gadget("items")
      For i = 0 To CountGadgetItems(gadget("items"))-1
        SetGadgetItemState(gadget("items"), i, #PB_ListIcon_Selected)
      Next
    EndIf
  EndProcedure
  
  Procedure remove()
    Protected i, id$, *packItem.pack::packItem
    For i = CountGadgetItems(gadget("items"))-1 To 0 Step -1
      If GetGadgetItemState(gadget("items"), i)
        SelectElement(items(), i)
        If items() <> GetGadgetItemData(gadget("items"), i)
          deb("windowPack:: address missmatch on remove")
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
    Protected link$
    
    ForEach items()
      If Not mods::isInstalled(items()\id$)
        ; TODO: also set folder name -> used during install to apply identical folder name as during export...
        
        
        Protected *modRepo.repository::RepositoryMod
        *modRepo = repository::getModByFoldername(items()\id$)
        link$ = *modRepo\getLink()
        
        If link$ = ""
          link$ = items()\download$
        EndIf
        
        If link$
          windowMain::repoFindModAndDownload(items()\download$) ; will display selection dialog if multiple files in mod
        Else
          deb("windowPack::dowload() - cannot download "+items()\name$)
        EndIf
      EndIf
    Next
    close()
  EndProcedure
  
  ; public
  
  Procedure show(parentWindow)
    If IsWindow(window)
      deb("packWindow:: window already open, cancel")
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
    SetGadgetText(gadget("download"), l("pack","download_all"))
    SetGadgetText(gadget("author"), settings::getString("pack","author"))
    GadgetToolTip(gadget("items"), l("pack","tip"))
    
    SetGadgetItemAttribute(gadget("items"), 0, #PB_ListIcon_ColumnWidth, 300, 0)
    SetGadgetItemText(gadget("items"), -1, l("pack","mod"), 0)
    AddGadgetColumn(gadget("items"), 1, l("pack","installed"), 70)
    AddGadgetColumn(gadget("items"), 2, l("pack","download"), 70)
    
    BindGadgetEvent(gadget("items"), @GadgetItems())
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
    EnableGadgetDrop(gadget("items"), #PB_Drop_Files, #PB_Drag_Copy|#PB_Drag_Move)
    BindEvent(#PB_Event_GadgetDrop, @itemsDrop(), window, gadget("items"))
    
    
    ; close event
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    
    
    ; finish window
    RefreshDialog(dialog)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    
    
    ; init package
    *pack = pack::create()
    changeName()
    changeAuthor()
    
    SetActiveGadget(gadget("name"))
    
    ProcedureReturn #True
  EndProcedure
  
EndModule
