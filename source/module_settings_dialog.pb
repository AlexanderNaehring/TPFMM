XIncludeFile "module_debugger.pbi"

DeclareModule settings
  EnableExplicit
  Declare create()
  
  ; Event Procedures
  Declare eManage(event)
EndDeclareModule

Module settings
  Global xml, dialogMain, dialogManage
  
  Procedure create()
    xml = CatchXML(-1, ?dialog_settings_xml, ?dialog_settings_xml_end - ?dialog_settings_xml)
    If xml And XMLStatus(xml) = #PB_XML_Success
      dialogMain = CreateDialog(-1)
      If dialogMain And OpenXMLDialog(dialogMain, xml, "settings")
        ProcedureReturn #true
      Else  
        debugger::add("Dialog error: " + DialogError(dialogMain))
      EndIf
    Else
      debugger::add("XML error: " + XMLError(xml) + " (Line: " + XMLErrorLine(xml) + ")")
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Runtime Procedure eManage(event)
    dialogManage = CreateDialog(-1)
    OpenXMLDialog(dialogManage, xml, "settings_manage")
  EndProcedure
  
  DataSection
    dialog_settings_xml:
    IncludeBinary "dialogs/settings.xml"
    dialog_settings_xml_end:
  EndDataSection
EndModule

settings::create()

global event 
Repeat
  event = WaitWindowEvent()
  Select event
    Case #PB_Event_Gadget
      Select EventGadget()
          
      EndSelect
  EndSelect
Until event = #PB_Event_CloseWindow 