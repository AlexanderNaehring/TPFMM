XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"

DeclareModule updater
  EnableExplicit
  
  Global CHANNEL$ = "Stable"
  Global VERSION$ = "Version 1.0." + #PB_Editor_BuildCount + " Build " + #PB_Editor_CompileCount + " (" + CHANNEL$ + ")"
  
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      #OS$ = "win"
    CompilerCase #PB_OS_Linux
      #OS$ = "lin"
      #Red = 200 ; color constants not defined in PB for Linux
    CompilerCase #PB_OS_MacOS
      #OS$ = "osx"
      #Red = 200
  CompilerEndSelect
  
  Structure channel
    build.i
    version$
    filename$
    date$
  EndStructure
  
  Global window
  Global NewMap gadgets()
  
  Declare create(parent = -1)
  Declare checkUpdate(auto)
  Declare updateWindow()
  Declare windowEvents(event)
  
EndDeclareModule


Module updater
  Global NewMap gadgets()
  Global NewMap channel.channel()
  Global parentWindow, showWindow = 500
  InitNetwork()
  
  Procedure create(parent = -1)
    parentWindow = parent
    If parent = -1
      window = OpenWindow(#PB_Any, 0, 0, 360, 215, locale::l("updater","title"), #PB_Window_SystemMenu | #PB_Window_Invisible | #PB_Window_ScreenCentered)
    Else
      window = OpenWindow(#PB_Any, 0, 0, 360, 215, locale::l("updater","title"), #PB_Window_SystemMenu | #PB_Window_Invisible | #PB_Window_Tool | #PB_Window_WindowCentered, WindowID(parent))
    EndIf
    
    FrameGadget(#PB_Any, 5, 5, 350, 45, locale::l("updater", "channel")) 
    gadgets("channel")  = ComboBoxGadget(#PB_Any, 10, 20, 85, 25)
    gadgets("status")   = TextGadget(#PB_Any, 100, 25, 250, 20, "", #PB_Text_Center); |#PB_Text_Border
    
    FrameGadget(#PB_Any, 5, 50, 350, 40, locale::l("updater", "current"))
    TextGadget(#PB_Any, 10, 67, 340, 20, VERSION$, #PB_Text_Center)
    
    FrameGadget(#PB_Any, 5, 90, 350, 90, locale::l("updater", "information"))
    TextGadget(#PB_Any, 10, 105, 155, 20, locale::l("updater", "version"),  #PB_Text_Right); |#PB_Text_Border 
    TextGadget(#PB_Any, 10, 130, 155, 20, locale::l("updater", "filename"),  #PB_Text_Right)
    TextGadget(#PB_Any, 10, 155, 155, 20, locale::l("updater", "date"),  #PB_Text_Right)
    gadgets("version")  = StringGadget(#PB_Any, 170, 105, 180, 20, "", #PB_String_ReadOnly)
    gadgets("filename") = StringGadget(#PB_Any, 170, 130, 180, 20, "", #PB_String_ReadOnly)
    gadgets("date")     = StringGadget(#PB_Any, 170, 155, 180, 20, "", #PB_String_ReadOnly)
    
    gadgets("warning")  = TextGadget(#PB_Any, 5, 190, 220, 20, "Testing versions may have bugs", #PB_Text_Center); |#PB_Text_Border
    SetGadgetColor(gadgets("warning"), #PB_Gadget_FrontColor, #Red)
    gadgets("download") = ButtonGadget(#PB_Any, 230, 185, 125, 25, locale::l("updater", "download"), #PB_Button_Default)
    DisableGadget(gadgets("download"), #True)
    
    ProcedureReturn window
  EndProcedure
  
  Procedure checkUpdate(auto)
    debugger::Add("updater::checkUpdate("+Str(auto)+")")
    Protected URL$, json, *value
    Protected channel$
    
    SetGadgetText(gadgets("status"), locale::l("updater", "checking"))
    SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, -1)
    ;DeleteFile("update.json")
    URL$ = URLEncoder("http://update.tfmm.xanos.eu/?build="+Str(#PB_Editor_CompileCount)+"&os="+#OS$+"&auto="+Str(auto))
    debugger::Add("updater::checkUpdate() - " + URL$)
    
    ClearMap(channel())
    ClearGadgetItems(gadgets("channel"))
    updateWindow() ; clean window
    
    If ReceiveHTTPFile(URL$, "update.json")
      json = LoadJSON(#PB_Any, "update.json")
      If json
        *value = JSONValue(json)
        If JSONType(*value) = #PB_JSON_Object
          *value = GetJSONMember(*value, #OS$)
          If *value And JSONType(*value) = #PB_JSON_Object
            ExtractJSONMap(*value, channel())
            ; if channels are found
            If MapSize(channel())
              ; add channels to select gadget (first letter upper case)
              ForEach channel()
                channel$ = MapKey(channel())
                AddGadgetItem(gadgets("channel"), -1, UCase(Left(channel$, 1)) + Mid(channel$, 2))
              Next
              SetGadgetText(gadgets("status"), locale::l("updater", "retrieved"))
              SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, -1)
              If GetGadgetText(gadgets("channel")) = ""
                ; if no channel is selected, switch to current channel
                If FindMapElement(channel(), LCase(CHANNEL$))
                  SetGadgetText(gadgets("channel"), CHANNEL$)
                Else
                  SetGadgetText(gadgets("channel"), "Stable")
                EndIf
              EndIf
              
              ; update window content (version, filename, etc)
              updateWindow()
            Else
              debugger::add("updater::checkUpdate() - ERROR: no channels found")
              SetGadgetText(gadgets("status"), locale::l("updater", "errorchannel"))
              SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, #Red)
            EndIf
          Else ; "os" element should be of type "object"
            debugger::add("updater::checkUpdate() - ERROR: expected JSON Object")
            SetGadgetText(gadgets("status"), locale::l("updater", "errorjson"))
            SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, #Red)
          EndIf
        Else ; root value should be of type "object"
          debugger::add("updater::checkUpdate() - ERROR: expected JSON Object")
          SetGadgetText(gadgets("status"), locale::l("updater", "errorjson"))
          SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, #Red)
        EndIf
      Else ; could not load json file
        debugger::add("updater::checkUpdate() - ERROR: "+JSONErrorMessage())
        SetGadgetText(gadgets("status"), locale::l("updater", "errorjson"))
        SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, #Red)
      EndIf
    Else
      debugger::add("updater::checkUpdate() - ERROR: downloading version information")
      SetGadgetText(gadgets("status"), locale::l("updater", "errordownload"))
      SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, #Red)
    EndIf
    
    If channel(LCase(CHANNEL$))\build > #PB_Editor_CompileCount Or channel("stable")\build > #PB_Editor_CompileCount
      If channel(LCase(CHANNEL$))\build > #PB_Editor_CompileCount 
        SetGadgetText(gadgets("channel"), CHANNEL$)
      ElseIf channel("stable")\build > #PB_Editor_CompileCount
        SetGadgetText(gadgets("channel"), "Stable")
      EndIf
      ; newer version from current or stable channel found > show update window
      ; Linux: cannot unhide window from thread
      ; Workaround: add timer and handle timer in main thread
      AddWindowTimer(window, showWindow, 10)
    ElseIf Not auto
      ; manual update request, display window
      AddWindowTimer(window, showWindow, 10)
    EndIf
  EndProcedure
  
  Procedure updateWindow()
    Protected channel$
    channel$ = LCase(GetGadgetText(gadgets("channel")))
    
    SetGadgetText(gadgets("version"), "")
    SetGadgetText(gadgets("filename"), "")
    SetGadgetText(gadgets("date"), "")
    SetGadgetText(gadgets("warning"), "")
    DisableGadget(gadgets("download"), #True)
    If FindMapElement(channel(), channel$)
      ; initially select stable release channel
      With channel()
        SetGadgetText(gadgets("version"), ""+\version$+" (Build "+Str(\build)+")")
        SetGadgetText(gadgets("filename"), \filename$)
        SetGadgetText(gadgets("date"), \date$)
        If \build > #PB_Editor_CompileCount
          Debug Str(\build) + " > " + #PB_Editor_CompileCount
          SetGadgetText(gadgets("status"), locale::l("updater", "newversion"))
          SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, RGB(0, 100, 0))
        Else
          SetGadgetText(gadgets("status"), locale::l("updater", "nonewversion"))
          SetGadgetColor(gadgets("status"), #PB_Gadget_FrontColor, -1)
        EndIf
        
      EndWith
      If MapKey(channel()) = "testing"
        SetGadgetText(gadgets("warning"), locale::l("updater", "warningtesting"))
      EndIf
      DisableGadget(gadgets("download"), #False)
    EndIf
  EndProcedure
  
  Procedure windowEvents(event)
    Select event
      Case #PB_Event_SizeWindow
        
      Case #PB_Event_Timer
        RemoveWindowTimer(window, showWindow)
        HideWindow(window, #False, #PB_Window_NoActivate)
        If parentWindow <> -1
          DisableWindow(parentWindow, #True)
        EndIf
        
      Case #PB_Event_CloseWindow
        HideWindow(window, #True)
        If parentWindow <> -1
          DisableWindow(parentWindow, #False)
          SetActiveWindow(parentWindow)
        EndIf
        
      Case #PB_Event_Menu
        Select EventMenu()
            
        EndSelect
  
      Case #PB_Event_Gadget
        Select EventGadget()
          Case gadgets("check")
            CreateThread(updater::@checkUpdate(), 1)
          Case gadgets("channel")
            updater::updateWindow()    
          Case gadgets("download")
            ; http://www.train-fever.net/filebase/index.php/Entry/5-Train-Fever-Beta-Mod-Manager/
            misc::openLink("http://goo.gl/utB3xn")
            HideWindow(window, #True)
            If parentWindow <> -1
              DisableWindow(parentWindow, #False)
              SetActiveWindow(parentWindow)
            EndIf
        EndSelect
    EndSelect
  ProcedureReturn #True
  EndProcedure
  
EndModule


CompilerIf #PB_Compiler_IsMainFile
  Define event
  
  If updater::createWindow()
    CreateThread(updater::@checkUpdate(), 1)
    HideWindow(updater::window, #False)
    Repeat
      event = WaitWindowEvent()
      Select event
        Case #PB_Event_Gadget
          Select EventGadget()
            Case updater::gadgets("checkUpdate")
              CreateThread(updater::@checkUpdate(), 1)
            Case updater::gadgets("channel")
              updater::updateWindow()
          EndSelect
      EndSelect
    Until event = #PB_Event_CloseWindow
  EndIf
  
CompilerEndIf

; EnableBuildCount = 0