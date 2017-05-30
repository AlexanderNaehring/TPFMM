
DeclareModule modInformation
  EnableExplicit
  
  Declare modInfoShow(*mod.mods::mod, xml, parentWindowID=0)
  
EndDeclareModule

Module modInformation
  
  ; mod info window
  Structure modInfoGadget
    id.i
    name$
  EndStructure
  Structure modInfoAuthor
    gadgetContainer.modInfoGadget
    gadgetImage.modInfoGadget
    gadgetAuthor.modInfoGadget
    gadgetRole.modInfoGadget
    name$
    role$
    url$
    tfnetId.i
    steamId.i
    image.i
    thread.i
  EndStructure
  Structure modInfoSource Extends modInfoGadget
    url$
  EndStructure
  Structure modInfoTag Extends modInfoGadget
    tag$
  EndStructure
  Structure modInfoWindow
    dialog.i
    window.i
    Map gadgets.i() ; standard gadgets
    ; dynamic gadgets:
    List authors.modInfoAuthor()
    List sources.modInfoSource()
    List tags.modInfoTag()
    ; other data
    modFolder$
  EndStructure
  
  
  
  Procedure modInfoClose()
    Protected *data.modInfoWindow
    *data = GetWindowData(EventWindow())
    If *data
      HideWindow(*data\window, #True)
      ForEach *data\authors()
        If *data\authors()\image And IsImage(*data\authors()\image)
          FreeImage(*data\authors()\image)
        EndIf
        If *data\authors()\thread And IsThread(*data\authors()\thread)
          KillThread(*data\authors()\thread)
        EndIf
      Next
      CloseWindow(*data\window)
      FreeDialog(*data\dialog)
      FreeStructure(*data)
    EndIf
  EndProcedure
  
  Procedure modInfoAuthor()
    
  EndProcedure
  
  Procedure modInfoFolder()
    Protected *data.modInfoWindow
    *data = GetWindowData(EventWindow())
    If *data
      misc::openLink(*data\modFolder$)
    EndIf
  EndProcedure
  
  Procedure modInfoSource()
    Protected *data.modInfoWindow
    *data = GetWindowData(EventWindow())
    If *data
      ForEach *data\sources()
        If EventGadget() = *data\sources()\id
          If *data\sources()\url$
            misc::openLink(*data\sources()\url$)
            ProcedureReturn #True
          EndIf
        EndIf
      Next
    EndIf
  EndProcedure
  
  Procedure modInfoAuthorImage(*author.modInfoAuthor)
    ; download avatar and set in imagegadget
    Protected gadget = *author\gadgetImage\id
    Protected *buffer, image
    Protected scale.d
    Static mutex, avatarDefault
    
    If Not gadget Or Not IsGadget(gadget)
      ProcedureReturn #False
    EndIf
    
    If Not mutex
      mutex = CreateMutex()
    EndIf
    
    LockMutex(mutex)
    ; 1st: set to loading
    If Not avatarDefault Or Not IsImage(avatarDefault)
      avatarDefault = CopyImage(images::Images("avatar"), #PB_Any)
      ResizeImage(avatarDefault, GadgetWidth(gadget), GadgetHeight(gadget), #PB_Image_Smooth)
    EndIf
    UnlockMutex(mutex)
    
    SetGadgetState(gadget, ImageID(avatarDefault))
    
    ; check if author has an avatar
    If *author\tfnetId Or *author\steamId
      ; get avatar from transportfever.net
      *buffer = ReceiveHTTPMemory(URLEncoder("https://www.transportfevermods.com/repository/avatar/?tfnetId="+*author\tfnetId+"&steamId="+*author\steamId))
      If *buffer
        image = CatchImage(#PB_Any, *buffer, MemorySize(*buffer))
        FreeMemory(*buffer)
      Else
        ProcedureReturn #False
      EndIf
    EndIf
    
    If image And IsImage(image)
      If ImageWidth(image) > GadgetWidth(gadget)
        scale = GadgetWidth(gadget) / ImageWidth(image)
      EndIf
      If ImageHeight(image)*scale > GadgetHeight(gadget)
        scale = GadgetHeight(gadget) / ImageHeight(image)
      EndIf
      ResizeImage(image, ImageWidth(image)*scale, ImageHeight(image)*scale)
      SetGadgetState(gadget, ImageID(image))
      *author\image = image
    EndIf
    
  EndProcedure
  
  Procedure modInfoShow(*mod.mods::mod, xml, parentWindowID=0)
    If Not *mod
      ProcedureReturn #False
    EndIf
    debugger::add("windowMain::modInfoShow()")
    
    Protected *data.modInfoWindow
    *data = AllocateStructure(modInfoWindow)
    
    *data\modFolder$ = mods::getModFolder(*mod\tpf_id$, *mod\aux\type$)
    
    ; manipulate xml before opening dialog
    Protected *nodeBase, *node, *nodeBox
    If IsXML(xml)
      ; fill authors
      Protected count, i, author.mods::author
      debugger::add("windowMain::modInfoShow() - create author gadgets...")
      *nodeBase = XMLNodeFromID(xml, "infoBoxAuthors")
      If *nodeBase
        misc::clearXMLchildren(*nodeBase)
        count = mods::modCountAuthors(*mod)
        For i = 0 To count-1
          If Not mods::modGetAuthor(*mod, i, @author)
            Continue
          EndIf
          AddElement(*data\authors())
          *data\authors()\name$ = author\name$
          *data\authors()\role$ = author\role$
          *data\authors()\tfnetId = author\tfnetId
          *data\authors()\steamId = author\steamId
          
          *node = *nodeBase
          ; new container
;           *node = CreateXMLNode(*node, "container", -1)
;           *data\authors()\gadgetContainer\name$ = Str(*node)
;           SetXMLAttribute(*node, "name", Str(*node))
;           SetXMLAttribute(*node, "width", "300")
;           SetXMLAttribute(*node, "flags", "#PB_Container_Single")
          
          *nodeBox = CreateXMLNode(*node, "hbox", -1)
          SetXMLAttribute(*nodeBox, "expand", "item:2")
          SetXMLAttribute(*nodeBox, "spacing", "10")
          SetXMLAttribute(*nodeBox, "width", "200")
          
          *node = CreateXMLNode(*nodeBox, "image", -1)
          *data\authors()\gadgetImage\name$ = "image-"+Str(*data\authors())
          SetXMLAttribute(*node, "name", "image-"+Str(*data\authors()))
          SetXMLAttribute(*node, "width", "60")
          SetXMLAttribute(*node, "height", "60")
          
          *nodeBox = CreateXMLNode(*nodeBox, "vbox", -1)
          SetXMLAttribute(*nodeBox, "expand", "no")
          SetXMLAttribute(*nodeBox, "align", "center,left")
          
          *node = CreateXMLNode(*nodeBox, "text", -1)
          *data\authors()\gadgetAuthor\name$ = "author-"+Str(*data\authors())
          SetXMLAttribute(*node, "name", "author-"+Str(*data\authors()))
          SetXMLAttribute(*node, "text", author\name$)
          
          *node = CreateXMLNode(*nodeBox, "text", -1)
          *data\authors()\gadgetRole\name$ = "role-"+Str(*data\authors())
          SetXMLAttribute(*node, "name", "role-"+Str(*data\authors()))
          SetXMLAttribute(*node, "text", author\role$)
          
          
          If author\tfnetId
            *data\authors()\url$      = "https://www.transportfever.net/index.php/User/"+Str(author\tfnetId)+"/"
          ElseIf author\steamId
            *data\authors()\url$      = "http://steamcommunity.com/profiles/"+Str(author\steamId)+"/"
          EndIf
        Next
      EndIf
      
      ; tags
      
      ; sources
      debugger::add("windowMain::modInfoShow() - sources...")
      *nodeBase = XMLNodeFromID(xml, "infoBoxSources")
      If *nodeBase
        misc::clearXMLchildren(*nodeBase)
        If *mod\aux\tfnetID
          *node = CreateXMLNode(*nodeBase, "hyperlink", -1)
          SetXMLAttribute(*node, "name", "source-tpfnet")
          SetXMLAttribute(*node, "text", "TransportFever.net")
          AddElement(*data\sources())
          *data\sources()\name$ = "source-tpfnet"
          *data\sources()\url$  = "https://www.transportfever.net/filebase/index.php/Entry/"+*mod\aux\tfnetID+"/"
        EndIf
        If *mod\aux\workshopID
          *node = CreateXMLNode(*nodeBase, "hyperlink", -1)
          SetXMLAttribute(*node, "name", "source-workshop")
          SetXMLAttribute(*node, "text", "Workshop")
          AddElement(*data\sources())
          *data\sources()\name$ = "source-workshop"
          *data\sources()\url$  = "http://steamcommunity.com/sharedfiles/filedetails/?id="+*mod\aux\workshopID
        EndIf
      EndIf
      
      
      
      
      ; show window
      debugger::add("windowMain::modInfoShow() - open window...")
      *data\dialog = CreateDialog(#PB_Any)
      If *data\dialog And OpenXMLDialog(*data\dialog, xml, "modInfo", #PB_Ignore, #PB_Ignore, #PB_Ignore, #PB_Ignore, parentWindowID)
        *data\window = DialogWindow(*data\dialog)
        
        ; get gadgets
        Macro getGadget(gadget)
          *data\gadgets(gadget) = DialogGadget(*data\dialog, gadget)
          If *data\gadgets(gadget) = -1
            debugger::add("windowMain::modInfoShow() - Error: could not get gadget '"+gadget+"'")
          EndIf
        EndMacro
        
        getGadget("top")
        getGadget("bar")
        getGadget("name")
        getGadget("descriptionLabel")
        getGadget("description")
        getGadget("info")
;         getGadget("uuidLabel")
;         getGadget("uuid")
        getGadget("folderLabel")
        getGadget("folder")
        getGadget("tagsLabel")
        getGadget("tags")
        getGadget("dependenciesLabel")
;         getGadget("filesLabel")
;         getGadget("files")
        getGadget("sizeLabel")
        getGadget("size")
        getGadget("sourcesLabel")
        
        UndefineMacro getGadget
        
        ; set text
        SetWindowTitle(*data\window, locale::l("info","title"))
        SetGadgetText(*data\gadgets("descriptionLabel"),  locale::l("info", "description"))
        SetGadgetText(*data\gadgets("info"),              locale::l("info", "info"))
;         SetGadgetText(*data\gadgets("uuidLabel"),         locale::l("info", "uuid"))
        SetGadgetText(*data\gadgets("folderLabel"),       locale::l("info", "folder"))
        SetGadgetText(*data\gadgets("tagsLabel"),         locale::l("info", "tags"))
        SetGadgetText(*data\gadgets("dependenciesLabel"), locale::l("info", "dependencies"))
;         SetGadgetText(*data\gadgets("filesLabel"),        locale::l("info", "files"))
        SetGadgetText(*data\gadgets("sizeLabel"),         locale::l("info", "size"))
        SetGadgetText(*data\gadgets("sourcesLabel"),      locale::l("info", "sources"))
        
        
        SetGadgetText(*data\gadgets("name"),              *mod\name$+" (v"+*mod\version$+")")
        SetGadgetText(*data\gadgets("description"),       *mod\description$)
;         SetGadgetText(*data\gadgets("uuid"),              *mod\uuid$)
        SetGadgetText(*data\gadgets("folder"),            *mod\tpf_id$)
        SetGadgetText(*data\gadgets("tags"),              mods::modGetTags(*mod))
        SetGadgetText(*data\gadgets("size"),              misc::printSize(misc::getDirectorySize(*data\modFolder$)))
        
        
        
        Static fontHeader, fontBigger
        If Not fontHeader
          fontHeader = LoadFont(#PB_Any, misc::getDefaultFontName(), Round(misc::getDefaultFontSize()*1.8, #PB_Round_Nearest), #PB_Font_Bold)
        EndIf
        If Not fontBigger
          fontBigger = LoadFont(#PB_Any, misc::getDefaultFontName(), Round(misc::getDefaultFontSize()*1.4, #PB_Round_Nearest), #PB_Font_Bold)
        EndIf
        
        SetGadgetFont(*data\gadgets("name"), FontID(fontHeader))
        SetGadgetColor(*data\gadgets("name"), #PB_Gadget_FrontColor, RGB($FF, $FF, $FF))
        SetGadgetColor(*data\gadgets("name"), #PB_Gadget_BackColor, RGB(47, 71, 99))
        
        
        ; bind events
        BindEvent(#PB_Event_CloseWindow, @ModInfoClose(), *data\window)
        AddKeyboardShortcut(*data\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
        BindEvent(#PB_Event_Menu, @ModInfoClose(), *data\window, #PB_Event_CloseWindow)
        BindGadgetEvent(*data\gadgets("folder"), @modInfoFolder(), #PB_EventType_LeftClick)
        
        ; get dynamic gadgets for event binding...
        ForEach *data\authors()
;           *data\authors()\gadgetContainer\id  = DialogGadget(*data\dialog, *data\authors()\gadgetContainer\name$)
          *data\authors()\gadgetImage\id      = DialogGadget(*data\dialog, *data\authors()\gadgetImage\name$)
          *data\authors()\gadgetAuthor\id     = DialogGadget(*data\dialog, *data\authors()\gadgetAuthor\name$)
          *data\authors()\gadgetRole\id       = DialogGadget(*data\dialog, *data\authors()\gadgetRole\name$)
;           SetGadgetData(*data\authors()\gadgetContainer\id, *data\authors())
          SetGadgetFont(*data\authors()\gadgetAuthor\id, FontID(fontBigger))
          ;BindGadgetEvent(, @modInfoAuthor())
          *data\authors()\thread = CreateThread(@modInfoAuthorImage(), *data\authors())
        Next
        
        ForEach *data\sources()
          *data\sources()\id = DialogGadget(*data\dialog, *data\sources()\name$)
          BindGadgetEvent(*data\sources()\id, @modInfoSource())
        Next
        
        
        ; store all information attached to the window:
        ; todo - create structure for modInfoWindow
        SetWindowData(*data\window, *data)
        
        
        ;show
        ; DisableWindow(window, #True)
        RefreshDialog(*data\dialog)
        
        If StartDrawing(CanvasOutput(*data\gadgets("top")))
          FillArea(1, 1, -1, RGB(47, 71, 99))
          StopDrawing()
        EndIf
        If StartDrawing(CanvasOutput(*data\gadgets("bar")))
          FillArea(1, 1, -1, RGB(47, 71, 99))
          Box(0, GadgetHeight(*data\gadgets("bar"))-3, GadgetWidth(*data\gadgets("bar")), 3, RGB(130, 155, 175))
          StopDrawing()
        EndIf
        
        HideWindow(*data\window, #False, #PB_Window_WindowCentered)
        
        ProcedureReturn #True
      Else
        debugger::add("windowMain::modInfoShow() - Error: "+DialogError(*data\dialog))
      EndIf
    EndIf
    ; failed to open window -> free data
    FreeStructure(*data)
  EndProcedure
  
  
EndModule
