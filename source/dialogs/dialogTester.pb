EnableExplicit

Define dialog$ = "main"
Define dialog, xml

xml = LoadXML(#PB_Any, dialog$+".xml")
If xml And XMLStatus(xml) = #PB_XML_Success
  dialog = CreateDialog(#PB_Any)
 
  If OpenXMLDialog(dialog, xml, dialog$)
    
    CreateMenu(0, WindowID(DialogWindow(dialog)))
    MenuTitle("File")
    MenuItem(1, "Item 1")
    MenuItem(2, "Item 2")
    
    CreateStatusBar(0, WindowID(DialogWindow(dialog)))
    AddStatusBarField(#PB_Ignore)
    AddStatusBarField(220)
    StatusBarProgress(0, 0, 50)
    StatusBarText(0, 1, "Version")
    
    Repeat
      
    Until WaitWindowEvent() = #PB_Event_CloseWindow
    
  Else
    Debug "Dialog creation error: " + DialogError(dialog)
  EndIf
  
Else
  Debug "XML error on line " + XMLErrorLine(xml) + ": " + XMLError(xml)
EndIf
