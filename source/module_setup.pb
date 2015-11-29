EnableExplicit
DeclareModule firstStart
  Declare create()
  
  ; Event Procedures
  Declare eShowInstallation(event)
  Declare eFinish(event)
EndDeclareModule

Module firstStart
  Global xml, dialogMain
  
  Procedure create()
    xml = CatchXML(-1, ?dialog_xml, ?dialog_xml_end - ?dialog_xml)
    If xml And XMLStatus(xml) = #PB_XML_Success
      dialogMain = CreateDialog(-1)
      
      If dialogMain And OpenXMLDialog(dialogMain, xml, "first_start")
        If LoadFont(0, "", 18)
          SetGadgetFont(DialogGadget(dialogMain, "head"), FontID(0))   ; Set the loaded Arial 16 font as new standard
        EndIf
        RefreshDialog(dialogMain)
        
        Protected event
        Repeat
          event = WaitWindowEvent()
          Select event
            Case #PB_Event_Gadget
              Select EventGadget()
                  
              EndSelect
          EndSelect
        Until event = #PB_Event_CloseWindow 
      Else  
        Debug "Dialog error: " + DialogError(dialogMain)
      EndIf
    Else
      Debug "XML error: " + XMLError(xml) + " (Line: " + XMLErrorLine(xml) + ")"
    EndIf
  EndProcedure
  
  ;TextGadget(
  
  ; Events
  Runtime Procedure eShowInstallation(event)
    HideGadget(DialogGadget(dialogMain, "welcome"), #True)
    HideGadget(DialogGadget(dialogMain, "installation"), #False)
  EndProcedure
  
  Runtime Procedure eFinish(event)
    End
  EndProcedure
  
  DataSection
    dialog_xml:
    IncludeBinary "dialogs/start.xml"
    dialog_xml_end:
  EndDataSection
EndModule

firstStart::create()
