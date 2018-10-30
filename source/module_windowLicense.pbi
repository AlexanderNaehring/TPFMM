
DeclareModule windowLicense
  EnableExplicit
  
  Prototype callback()
  
  Declare Show(title$, text$, OnAgree.callback, OnDecline.callback)
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_locale.pbi"

Module windowLicense
  
  Structure windowData
    dialog.i
    window.i
    OnAgree.callback
    OnDecline.callback
  EndStructure
  
  Global xml
  
  misc::IncludeAndLoadXML(xml, "dialogs/license.xml")
  
  
  ; private
  
  Procedure close(*data.windowData)
    CloseWindow(*data\window)
    FreeDialog(*data\dialog)
    FreeStructure(*data)
  EndProcedure
  
  Procedure agree()
    Protected *data.windowData
    Protected cb.callback
    *data = GetWindowData(EventWindow())
    cb = *data\OnAgree
    close(*data)
    cb()
  EndProcedure
  
  Procedure decline()
    Protected *data.windowData
    Protected cb.callback
    *data = GetWindowData(EventWindow())
    cb = *data\OnDecline
    close(*data)
    cb()
  EndProcedure
  
  ; public
  
  Procedure Show(title$, text$, OnAgree.callback, OnDecline.callback)
    Protected *data.windowData
    *data = AllocateStructure(windowData)
    *data\dialog = CreateDialog(#PB_Any)
    If Not *data\dialog Or Not OpenXMLDialog(*data\dialog, xml, "license")
      DebuggerError("Could not open dialog: "+DialogError(*data\dialog))
    EndIf
    
    *data\window = DialogWindow(*data\dialog)
    
    BindEvent(#PB_Event_CloseWindow, @decline(), *data\window)
    BindGadgetEvent(DialogGadget(*data\dialog, "btnAgree"), @agree())
    BindGadgetEvent(DialogGadget(*data\dialog, "btnDecline"), @decline())
    
    SetWindowTitle(*data\window, title$)
    SetGadgetText(DialogGadget(*data\dialog, "text"), text$)
    
    SetActiveGadget(DialogGadget(*data\dialog, "btnAgree"))
    
    *data\OnAgree = OnAgree
    *data\OnDecline = OnDecline
    
    SetWindowData(*data\window, *data)
    
    HideWindow(*data\window, #False, #PB_Window_ScreenCentered)
    ProcedureReturn #True
  EndProcedure
  
EndModule