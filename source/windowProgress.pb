DeclareModule windowProgress
  EnableExplicit
  
  Declare showProgressWindow(text$, PostEventOnClose=-1)
  Declare setProgressPercent(percent.b)
  Declare setProgressText(text$)
  Declare closeProgressWindow()
  
EndDeclareModule

XIncludeFile "animation.pb"

Module windowProgress
  
  Structure progress
    dialog.i
    window.i
    gText.i
    gBar.i
    onClose.i
    *ani.animation::animation
  EndStructure
  
  Global progressDialog.progress
  
  ;#####
  
  Procedure setProgressText(text$)
    If progressDialog\window
      SetGadgetText(progressDialog\gText, text$)
    EndIf
  EndProcedure
  
  Procedure setProgressPercent(percent.b)
    If progressDialog\window
      SetGadgetState(progressDialog\gBar, percent)
    EndIf
  EndProcedure
  
  Procedure progressWindowTimer()
    If EventTimer() = 0
      progressDialog\ani\drawNextFrame()
    EndIf
  EndProcedure
  
  Procedure closeProgressWindowEvent()
    ; cannot close a window from a thread, must be main thread
    If Not misc::isMainThread()
      DebuggerError("main:: closeProgressWindowEvent() must always be called from main thread")
    EndIf
    
    If progressDialog\window
      Debug "close progress window routine starting..."
      progressDialog\ani\free()
      progressDialog\ani = #Null
      FreeDialog(progressDialog\dialog)
      progressDialog\window = #Null
      progressDialog\dialog = #Null
      
      If progressDialog\onClose <> -1
        PostEvent(progressDialog\onClose)
      EndIf
    EndIf
  EndProcedure
  
  Procedure closeProgressWindow()
    Debug "closeProgressWindow()"
    If progressDialog\window
      progressDialog\onClose = -1 ; decativate the "on close event" as close is triggered manually
      progressDialog\ani\pause()  ; if garbage collector closes window before the animation is stopped/freed, animation update will cause IMA
      Delay(progressDialog\ani\getInterval()*2) ; wait for 2 intervals to make sure that no draw call is made after pause()
      
      If misc::isMainThread()
        closeProgressWindowEvent()
      Else
        RemoveWindowTimer(progressDialog\window, 0)
        PostEvent(#PB_Event_CloseWindow, progressDialog\window, 0)
      EndIf
    EndIf
  EndProcedure
  
  Procedure showProgressWindow(title$, PostEventOnClose=-1)
    Protected xml, dialog
    
    ; only single open progress window allowed
    If progressDialog\window
      progressDialog\onClose = PostEventOnClose
      SetWindowTitle(progressDialog\window, title$)
      HideWindow(progressDialog\window, #False, #PB_Window_ScreenCentered)
      ProcedureReturn #True
    EndIf
    
    misc::IncludeAndLoadXML(xml, "dialogs/progress.xml")
    dialog = CreateDialog(#PB_Any)
    OpenXMLDialog(dialog, xml, "progress")
    FreeXML(xml)
    
    progressDialog\dialog = dialog
    progressDialog\window = DialogWindow(dialog)
    progressDialog\gText  = DialogGadget(dialog, "text")
    progressDialog\gBar   = DialogGadget(dialog, "percent")
    progressDialog\onclose = PostEventOnClose
    
    SetWindowTitle(progressDialog\window, title$)
    
    Debug "load progress window animation"
    progressDialog\ani = animation::new()
    progressDialog\ani\loadAni("images/logo/logo.ani")
    progressDialog\ani\setInterval(1000/60)
    progressDialog\ani\setCanvas(DialogGadget(dialog, "logo"))
    
    AddWindowTimer(progressDialog\window, 0, progressDialog\ani\getInterval())
    BindEvent(#PB_Event_Timer, @progressWindowTimer(), progressDialog\window)
    
    SetWindowColor(progressDialog\window, #White)
    SetGadgetColor(progressDialog\gText, #PB_Gadget_BackColor, #White)
    SetGadgetColor(progressDialog\gText, #PB_Gadget_FrontColor, #Black)
    
    RefreshDialog(dialog)
    
    BindEvent(#PB_Event_CloseWindow, @closeProgressWindowEvent(), progressDialog\window)
    
    AddKeyboardShortcut(progressDialog\window, #PB_Shortcut_Escape, #PB_Event_CloseWindow)
    BindEvent(#PB_Event_Menu, @closeProgressWindowEvent(), progressDialog\window, #PB_Event_CloseWindow)
    
    HideWindow(progressDialog\window, #False, #PB_Window_ScreenCentered)
    ProcedureReturn #True
  EndProcedure
  
EndModule
