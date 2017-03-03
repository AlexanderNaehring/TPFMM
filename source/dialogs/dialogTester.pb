EnableExplicit

CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  #G_TYPE_STRING = 64
  
  ImportC ""
    g_object_get_property(*widget.GtkWidget, property.p-utf8, *gval)
  EndImport
CompilerEndIf

Procedure.S FontName( FontID )
  CompilerSelect #PB_Compiler_OS 
    CompilerCase #PB_OS_Windows 
      Protected sysFont.LOGFONT
      GetObject_(FontID, SizeOf(LOGFONT), @sysFont)
      ProcedureReturn PeekS(@sysFont\lfFaceName[0])
      
    CompilerCase #PB_OS_Linux
      Protected gVal.GValue
      Protected StdFnt$
      g_value_init_(@gval, #G_TYPE_STRING)
      g_object_get_property(gtk_settings_get_default_(), "gtk-font-name", @gval)
      StdFnt$ = PeekS(g_value_get_string_( @gval ), -1, #PB_UTF8)
      g_value_unset_(@gval)
      ProcedureReturn StdFnt 
      
  CompilerEndSelect
EndProcedure
  
Procedure FontSize( FontID )
  CompilerSelect #PB_Compiler_OS 
    CompilerCase #PB_OS_Windows 
      Protected sysFont.LOGFONT
      GetObject_(FontID, SizeOf(LOGFONT), @sysFont)
      ProcedureReturn MulDiv_(-sysFont\lfHeight, 72, GetDeviceCaps_(GetDC_(#NUL), #LOGPIXELSY))
      
    CompilerCase #PB_OS_Linux
      Protected gVal.GValue
      Protected StdFnt$
      g_value_init_(@gval, #G_TYPE_STRING)
      g_object_get_property( gtk_settings_get_default_(), "gtk-font-name", @gval)
      StdFnt$ = PeekS(g_value_get_string_(@gval), -1, #PB_UTF8)
      g_value_unset_(@gval)
      ProcedureReturn Val(StringField((StdFnt$), 2, " "))
  CompilerEndSelect
EndProcedure
  
  

Define file$   = "main"
Define dialog$ = "modInfo"
Define dialog, xml
#MENU = #False
#STATUSBAR = #False
#FONTBIG$ = "infoName"


xml = LoadXML(#PB_Any, file$+".xml")
If xml And XMLStatus(xml) = #PB_XML_Success
  dialog = CreateDialog(#PB_Any)
 
  If OpenXMLDialog(dialog, xml, dialog$)
    
    CompilerIf #MENU
      CreateMenu(0, WindowID(DialogWindow(dialog)))
      MenuTitle("File")
      MenuItem(1, "Item 1")
      MenuItem(2, "Item 2")
    CompilerEndIf
    
    CompilerIf #STATUSBAR
      CreateStatusBar(0, WindowID(DialogWindow(dialog)))
      AddStatusBarField(#PB_Ignore)
      AddStatusBarField(220)
      StatusBarProgress(0, 0, 50)
      StatusBarText(0, 1, "Version")
    CompilerEndIf
    
    CompilerIf #FONTBIG$ <> ""
      Define font
      font = LoadFont(#PB_Any, FontName(GetGadgetFont(#PB_Default)), Round(FontSize(GetGadgetFont(#PB_Default))*1.5, #PB_Round_Nearest), #PB_Font_Bold)
      SetGadgetFont(DialogGadget(dialog, #FONTBIG$), FontID(font))
      RefreshDialog(dialog)
    CompilerEndIf
    
    HideWindow(DialogWindow(dialog), #False, #PB_Window_ScreenCentered)
    
    Repeat
      
    Until WaitWindowEvent() = #PB_Event_CloseWindow
    
  Else
    Debug "Dialog creation error: " + DialogError(dialog)
  EndIf
  
Else
  Debug "XML error on line " + XMLErrorLine(xml) + ": " + XMLError(xml)
EndIf
