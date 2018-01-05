DeclareModule windowPack
  EnableExplicit
  
  
  Declare show(parentWindow)
  
EndDeclareModule

XIncludeFile "module_debugger.pbi"


Module windowPack
  
  Global window, dialog, parent
  
  Macro gadget(name)
    DialogGadget(dialog, name)
  EndMacro
  
  
  
  Procedure close()
    HideWindow(window, #True)
    CloseWindow(window)
  EndProcedure
  
  
  Procedure show(parentWindow)
    parent = parentWindow
    
    If IsWindow(window)
      debugger::add("packWindow::show() - window already open - cancel")
      ProcedureReturn #False
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
    
    BindEvent(#PB_Event_CloseWindow, @close(), window)
    
    RefreshDialog(dialog)
    HideWindow(window, #False, #PB_Window_WindowCentered)
    
  EndProcedure
  
  
EndModule
