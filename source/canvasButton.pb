DeclareModule CanvasButton
  EnableExplicit
  
  Enumeration ; Attributes
    #AttributeAllowToggle
    #AttributeTextAlignHorizontal
    #AttributeTextAlignVertical
    #AttributeFontID
    #AttributeCornerRadius
  EndEnumeration
  
  Enumeration ; Styles
    #StyleDefault
    #StyleHighlight       ; hover
    #StyleActive          ; toggled or click
    #StyleActiveHighlight ; toggled with hover
  EndEnumeration
  #NStyles = #PB_Compiler_EnumerationValue - 1
  #StyleAll = -1
  
  Enumeration ; Align
    #AlignCenter
    #AlignLeft
    #AlignRight
    #AlignTop
    #AlignBottom
  EndEnumeration
  
  ; prototypes
  Prototype callback()
  
  ;- Interfaces
  Interface CanvasButton
    Free()
    Redraw()
    Resize(x, y, width, height)
    SetAttribute(attribute, value)
    GetAttribute(attribute)
    SetUserData(*data)
    GetUserData()
    SetText(text$)
    GetText.s()
    SetImage(image.i, style.b = #StyleAll)
    GetImage(style.b = #StyleDefault)
    SetButtonState(state.b) ; toggle
    GetButtonState.b()
    SetEventCallback(callback.callback)
    GetEventCallback()
    PauseDraw(pause.b)
  EndInterface
  
  ; declare public functions
  Declare NewCanvasButtonGadget(x, y, width, height, text$, callback.callback = #Null, useExistingCanvas = -1)
  Declare Free(*gadget)
  
  ; gadget functions
  Declare draw(*gadget)
  Declare Resize(*gadget, x, y, width, height)
  Declare SetAttribute(*gadget, attribute, value)
  Declare GetAttribute(*gadget, attribute)
  Declare SetUserData(*gadget, *data)
  Declare GetUserData(*gadget)
  Declare SetText(*gadget, text$)
  Declare.s GetText(*gadget)
  Declare SetImage(*gadget, image.i, style.b = #StyleAll)
  Declare GetImage(*gadget, style.b = #StyleDefault)
  Declare SetButtonState(*gadget, state.b)
  Declare.b GetButtonState(*gadget)
  Declare SetEventCallback(*gadget, callback.callback)
  Declare.callback GetEventCallback(*gadget)
  Declare PauseDraw(*gadget, pause.b)
  
EndDeclareModule

CompilerIf #PB_Compiler_IsIncludeFile
  XIncludeFile "module_debugger.pbi"
CompilerEndIf

Module CanvasButton
  
  ;{ VT
  DataSection
    vt:
    Data.i @Free()
    Data.i @draw()
    Data.i @Resize()
    Data.i @SetAttribute()
    Data.i @GetAttribute()
    Data.i @SetUserData()
    Data.i @GetUserData()
    Data.i @SetText()
    Data.i @GetText()
    Data.i @SetImage()
    Data.i @GetImage()
    Data.i @SetButtonState()
    Data.i @GetButtonState()
    Data.i @pauseDraw()
  EndDataSection
  ;}
  
  ;{ Enumerations
  
  ;}
  
  ;{ Structures
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    Structure Point
      x.i
      y.i
    EndStructure
  CompilerEndIf
  
  Structure box Extends Point
    w.i
    h.i
  EndStructure
  
  ; gadget
  Structure style
    colorBack.l
    colorText.l
    colorBorder.l
    image.i
  EndStructure
  
  Structure gadget
    *vt.CanvasList
    *userdata
    ; gadget data:
    gCanvas.i
    window.i
    winColor.l
    pauseDraw.b
    hover.b
    toggle.b
    active.b
    text$
    textDraw$
    callback.callback
    ; styles
    Array style.style(#NStyles)
    *currentStyle.style ; current style
    ; attributes
    fontID.i
    textAlignHor.i
    textAlignVer.i
    toggleAllow.b
    cornerRadius.b
    ; layout
    margin.b
    padding.b
    fitImageSize.b
    
    bOuter.box
    bInner.box
    bText.box
    bImage.box
  EndStructure
  ;}
  
  ; debug function
  
  CompilerIf Defined(debugger, #PB_Module)
    ; in bigger project, use custom module (writes debug messages to log file)
    UseModule debugger
  CompilerElse
    ; if module not available, just print message
    Macro deb(s)
      Debug s
    EndMacro
  CompilerEndIf
  
  ;- Private Functions
  
  Procedure GetWindowBackgroundColor(window)
    ; found on https://www.purebasic.fr/english/viewtopic.php?f=12&t=66974
    Protected color, hwnd
    color = GetWindowColor(window)
    If color <> -1
      ProcedureReturn color
    EndIf
    hwnd = WindowID(window)
    
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        color = GetSysColor_(#COLOR_WINDOW)
        If color = $FFFFFF Or color=0
          color = GetSysColor_(#COLOR_BTNFACE)
        EndIf
        
      CompilerCase #PB_OS_Linux   ;thanks to uwekel http://www.purebasic.fr/english/viewtopic.php?p=405822
        Protected *style.GtkStyle, *color.GdkColor
        *style = gtk_widget_get_style_(hwnd) ;GadgetID(Gadget))
        *color = *style\bg[0]                ;0=#GtkStateNormal
        color = RGB(*color\red >> 8, *color\green >> 8, *color\blue >> 8)
        
      CompilerCase #PB_OS_MacOS   ;thanks to wilbert http://purebasic.fr/english/viewtopic.php?f=19&t=55719&p=497009
        Protected Rect.NSRect, Image, NSColor = CocoaMessage(#Null, #Null, "NSColor windowBackgroundColor")
        If NSColor
          Rect\size\width = 1
          Rect\size\height = 1
          Image = CreateImage(#PB_Any, 1, 1)
          StartDrawing(ImageOutput(Image))
          CocoaMessage(#Null, NSColor, "drawSwatchInRect:@", @Rect)
          color = Point(0, 0)
          StopDrawing()
          FreeImage(Image)
        Else
          ProcedureReturn -1
        EndIf
    CompilerEndSelect
    ProcedureReturn color
  EndProcedure
  
  Procedure refreshCurrentStyle(*this.gadget)
    Protected active, highlight
    active = Bool(*this\active Or *this\toggle)
    highlight = Bool(*this\hover)
    If active And highlight
      *this\currentStyle = *this\style(#StyleActiveHighlight)
    ElseIf active
      *this\currentStyle = *this\style(#StyleActive)
    ElseIf highlight
      *this\currentStyle = *this\style(#StyleHighlight)
    Else
      *this\currentStyle = *this\style(#StyleDefault)
    EndIf
  EndProcedure
  
  Procedure refreshDrawingDimensions(*this.gadget)
    Protected f.d
    With *this
      If StartDrawing(CanvasOutput(\gCanvas))
        ; gadget dimensions
        \bOuter\x = *this\margin
        \bOuter\y = *this\margin
        \bOuter\w = GadgetWidth(*this\gCanvas) - 2*\margin
        \bOuter\h = GadgetHeight(*this\gCanvas) - 2*\margin
        ; inner dimensions
        \bInner\x = \bOuter\x + \padding
        \bInner\y = \bOuter\y + \padding
        \bInner\w = \bOuter\w - 2*\padding
        \bInner\h = \bOuter\h - 2*\padding
        ; text dimensions
        \textDraw$ = \text$
        DrawingFont(\fontID)
        \bText\w = TextWidth(\text$)
        While \bText\w > \bInner\w
          \textDraw$ = Left(\textDraw$, Len(\textDraw$)-1)
          \bText\w = TextWidth(\textDraw$)
        Wend
        Select \textAlignHor
          Case #AlignLeft
            \bText\x = \bInner\x
          Case #AlignRight
            \bText\x = \bInner\x + \bInner\w - \bText\w
          Default ; center
            \bText\x = \bInner\x + (\bInner\w - \bText\w)/2
        EndSelect
        \bText\h = TextHeight(\textDraw$)
        Select \textAlignVer
          Case #AlignTop
            \bText\y = \bInner\y
          Case #AlignBottom
            \bText\y = \bInner\y + \bInner\h - \bText\h
          Default
            \bText\y = \bInner\y + (\bInner\h - \bText\h)/2
        EndSelect
        ; image dimensions
        If \currentStyle\image And IsImage(\currentStyle\image)
          DrawingMode(#PB_2DDrawing_AlphaBlend)
          \bImage\w = ImageWidth(\currentStyle\image)
          \bImage\h = ImageHeight(\currentStyle\image)
          If \fitImageSize
            f = 1
            If \bImage\w > \bInner\w
              f = \bInner\w / \bImage\w
            EndIf
            If \bImage\h*f > \bInner\h
              f = \bInner\h / \bImage\h
            EndIf
            If f < 1
              \bImage\w * f
              \bImage\h * f
            EndIf
          EndIf
          \bImage\x  = \bInner\x + (\bInner\w - \bImage\w)/2
          \bImage\y  = \bInner\y + (\bInner\h - \bImage\h)/2
          ;TODO image always centered?
          ;TODO image + text
        Else
          
        EndIf
        StopDrawing()
      EndIf
    EndWith
  EndProcedure
  
  Procedure draw(*this.gadget)
    If *this\pauseDraw
      ProcedureReturn #False
    EndIf
    
    If StartDrawing(CanvasOutput(*this\gCanvas))
      With *this
        ; blank the canvas
        DrawingMode(#PB_2DDrawing_Default)
        Box(0, 0, GadgetWidth(\gCanvas), GadgetHeight(\gCanvas), \winColor)
        
        ; background
        DrawingMode(#PB_2DDrawing_Default)
        RoundBox(\bOuter\x, \bOuter\y, \bOuter\w, \bOuter\h, \cornerRadius, \cornerRadius, \currentStyle\colorBack)
        
        If \currentStyle\image And IsImage(\currentStyle\image)
          ; draw image
          DrawingMode(#PB_2DDrawing_AlphaBlend)
          DrawImage(ImageID(\currentStyle\image), \bImage\x, \bImage\y, \bImage\w, \bImage\h)
        Else
          ; draw text
          DrawingMode(#PB_2DDrawing_Transparent)
          DrawingFont(\fontID)
          DrawText(\bText\x, \bText\y, \textDraw$, \currentStyle\colorText)
        EndIf
        
        ; border
        DrawingMode(#PB_2DDrawing_Outlined)
        RoundBox(\bOuter\x, \bOuter\y, \bOuter\w, \bOuter\h, \cornerRadius, \cornerRadius, \currentStyle\colorBorder)
        
        ; finished drawing
        StopDrawing()
        
        ProcedureReturn #True
      EndWith
    Else
      Debug "[!] draw failure"
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure EventCanvas()
    Protected *this.gadget
    Protected p.point
    *this = GetGadgetData(EventGadget())
    p\x = GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseX)
    p\y = GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseY)
    *this\window = EventWindow()
    *this\winColor = GetWindowBackgroundColor(*this\window)
    Select EventType()
      Case #PB_EventType_Resize
        refreshDrawingDimensions(*this)
        draw(*this)
        
      Case #PB_EventType_MouseWheel
        
      Case #PB_EventType_MouseEnter
        *this\hover = #True
        refreshCurrentStyle(*this)
        draw(*this)
        
      Case #PB_EventType_MouseLeave
        *this\hover = #False
        refreshCurrentStyle(*this)
        draw(*this)
        
      Case #PB_EventType_LeftClick
        If *this\toggleAllow
          *this\toggle = 1 - *this\toggle
          refreshCurrentStyle(*this)
          draw(*this) 
        EndIf
        If *this\callback
          *this\callback()
        EndIf
        
      Case #PB_EventType_LeftDoubleClick
        
      Case #PB_EventType_LeftButtonDown
        *this\active = #True
        refreshCurrentStyle(*this)
        draw(*this)
        
      Case #PB_EventType_LeftButtonUp
        *this\active = #False
        refreshCurrentStyle(*this)
        draw(*this)
        
      Case #PB_EventType_MouseMove
        
      Case #PB_EventType_KeyDown
        Select GetGadgetAttribute(EventGadget(), #PB_Canvas_Key)
          Case #PB_Shortcut_Space
            *this\active = #True
            refreshCurrentStyle(*this)
            draw(*this)
        EndSelect
        
      Case #PB_EventType_KeyUp
        Select GetGadgetAttribute(EventGadget(), #PB_Canvas_Key)
          Case #PB_Shortcut_Space
            *this\active = #False
            refreshCurrentStyle(*this)
            draw(*this)
            If *this\callback
              *this\callback()
            EndIf
        EndSelect
          
    EndSelect
    
  EndProcedure
  
  ;- Public Gadget Functions
  
  Procedure NewCanvasButtonGadget(x, y, width, height, text$, callback.callback = #Null, useExistingCanvas = -1)
    Protected *this.gadget
    *this = AllocateStructure(gadget)
    *this\vt = ?vt
    
    ; create canvas or use existing
    If useExistingCanvas = -1
      *this\gCanvas = CanvasGadget(#PB_Any, x, y, width, height, #PB_Canvas_Keyboard) ; keyboard focus requried for mouse wheel on windows
    Else
      If Not IsGadget(useExistingCanvas)
        deb("canvasButton:: cannot use existing canvas, #"+useExistingCanvas+" not a valid gadget")
        FreeStructure(*this)
        ProcedureReturn #False
      EndIf
      If Not CanvasOutput(useExistingCanvas)
        deb("canvasButton:: cannot use existing canvas, #"+useExistingCanvas+" not a valid canvas")
        FreeStructure(*this)
        ProcedureReturn #False
      EndIf
      *this\gCanvas = useExistingCanvas
      ResizeGadget(*this\gCanvas, x, y, width, height)
    EndIf
    
    ; default values
    *this\fontID        = GetGadgetFont(#PB_Default)
    *this\textAlignHor  = #AlignCenter
    *this\textAlignVer  = #AlignCenter
    *this\toggleAllow   = #False
    *this\text$         = text$
    *this\margin        = 1
    *this\padding       = 4
    *this\cornerRadius  = 0
    *this\callback      = callback
    *this\fitImageSize  = #True
    
    *this\currentStyle = *this\style(#StyleDefault)
    ; Default
    *this\style(#StyleDefault)\colorBack    = GetSysColor_(#COLOR_3DLIGHT)
    *this\style(#StyleDefault)\colorText    = GetSysColor_(#COLOR_BTNTEXT)
    *this\style(#StyleDefault)\colorBorder  = GetSysColor_(#COLOR_BTNSHADOW)
    ; Highlight (hover)
    CopyStructure(*this\style(#StyleDefault), *this\style(#StyleHighlight), style)
    *this\style(#StyleHighlight)\colorBack  = $fbf1e5
    ; Active (toggle or click)
    CopyStructure(*this\style(#StyleHighlight), *this\style(#StyleActive), style)
    *this\style(#StyleActive)\colorBack     = $f7e4cc
    *this\style(#StyleActive)\colorBorder   = GetSysColor_(#COLOR_HOTLIGHT)
    ; ActiveHighlight (toggled and hover)
    CopyStructure(*this\style(#StyleActive), *this\style(#StyleActiveHighlight), style)
    
    ; set data pointer
    SetGadgetData(*this\gCanvas, *this)
    
    ; bind events
    BindGadgetEvent(*this\gCanvas, @EventCanvas(), #PB_All)
    
    ; initial draw
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      *this\window = GetProp_(GetAncestor_(GadgetID(*this\gCanvas), #GA_ROOT), "PB_WINDOWID") - 1
      *this\winColor = GetWindowBackgroundColor(*this\window)
    CompilerEndIf
    
    refreshDrawingDimensions(*this)
    draw(*this)
    
    ProcedureReturn *this
  EndProcedure
  
  Procedure Free(*this.gadget)
    FreeGadget(*this\gCanvas)
    FreeStructure(*this)
  EndProcedure
  
  Procedure Resize(*this.gadget, x, y, width, height)
    ResizeGadget(*this\gCanvas, x, y, width, height)
  EndProcedure
  
  Procedure SetAttribute(*this.gadget, attribute, value)
    Select attribute
      Case #AttributeAllowToggle
        *this\toggleAllow = Bool(value)
        If Not *this\toggleAllow And *this\toggle
          *this\toggle = #False
        EndIf
        
      Case #AttributeTextAlignHorizontal
        *this\textAlignHor = value
        
      Case #AttributeTextAlignVertical
        *this\textAlignVer = value
        
      Case #AttributeFontID
        If value = #PB_Ignore Or IsFont(value)
          *this\fontID = value
        Else
          *this\fontID = GetGadgetFont(#PB_Default)
        EndIf
        
      Case #AttributeCornerRadius
        *this\cornerRadius = value
        
    EndSelect
    refreshDrawingDimensions(*this)
    draw(*this)
  EndProcedure
  
  Procedure GetAttribute(*this.gadget, attribute)
    Select attribute
        
    EndSelect
  EndProcedure
  
  Procedure SetUserData(*this.gadget, *data)
    *this\userdata = *data
  EndProcedure
  
  Procedure GetUserData(*this.gadget)
    ProcedureReturn *this\userdata
  EndProcedure
  
  Procedure SetText(*this.gadget, text$)
    *this\text$ = text$
    refreshDrawingDimensions(*this)
    draw(*this)
  EndProcedure
  
  Procedure.s GetText(*this.gadget)
    ProcedureReturn *this\text$
  EndProcedure
  
  Procedure SetImage(*this.gadget, image.i, style.b = #StyleAll)
    Protected i
    If style = #StyleAll
      For i = 0 To ArraySize(*this\style())
        *this\style(i)\image = image
      Next
    Else
      If style < 0 Or style > #NStyles
        deb("canvasButton:: style index "+style+" out of bound")
      Else
        *this\style(style)\image = image
      EndIf
    EndIf
    refreshDrawingDimensions(*this)
    draw(*this)
  EndProcedure
  
  Procedure GetImage(*this.gadget, style.b = #StyleDefault)
    ProcedureReturn *this\style(style)\image
  EndProcedure
  
  Procedure SetButtonState(*this.gadget, state.b)
    If *this\toggleAllow
      *this\toggle = Bool(state)
    EndIf
  EndProcedure
  
  Procedure.b GetButtonState(*this.gadget)
    ProcedureReturn *this\toggle
  EndProcedure
  
  Procedure SetEventCallback(*this.gadget, callback.callback)
    *this\callback = callback
  EndProcedure
  
  Procedure.callback GetEventCallback(*this.gadget)
    ProcedureReturn *this\callback
  EndProcedure
  
  Procedure pauseDraw(*this.gadget, pause.b)
    *this\pauseDraw = Bool(pause)
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  EnableExplicit
  Global window
  Global *btn1.CanvasButton::CanvasButton
  Global *btn2.CanvasButton::CanvasButton
  Global *btn3.CanvasButton::CanvasButton
  Global *btn4.CanvasButton::CanvasButton
  Global im.i
  
  Procedure button()
    ; click or state change
  EndProcedure
  
  im = CreateImage(#PB_Any, 40, 40, 32, #PB_Image_Transparent)
  If StartDrawing(ImageOutput(im))
    DrawingMode(#PB_2DDrawing_AlphaBlend|#PB_2DDrawing_Outlined)
    Circle(20, 20, 20, $FF0000AA)
    StopDrawing()
  EndIf
  
  window = OpenWindow(#PB_Any, 0, 0, 425, 115, "CanvasButtonTest", #PB_Window_SystemMenu|#PB_Window_ScreenCentered)
  SetWindowColor(window, #Yellow)
  *btn1 = CanvasButton::NewCanvasButtonGadget(5, 5, 100, 50, "Btn Test", @button())
  *btn2 = CanvasButton::NewCanvasButtonGadget(110, 5, 100, 50, "Toggle Test", @button())
  *btn3 = CanvasButton::NewCanvasButtonGadget(215, 5, 100, 50, "Image Test", @button())
  *btn4 = CanvasButton::NewCanvasButtonGadget(320, 5, 100, 50, "Image Test", @button())
  *btn2\SetAttribute(CanvasButton::#AttributeAllowToggle, #True)
  *btn3\SetImage(im)
  *btn4\SetAttribute(CanvasButton::#AttributeAllowToggle, #True)
  *btn4\SetImage(im)
  ButtonGadget(#PB_Any, 5, 60, 100, 50, "Btn Test")
  ButtonGadget(#PB_Any, 110, 60, 100, 50, "Toggle Test", #PB_Button_Toggle)
  ButtonImageGadget(#PB_Any, 215, 60, 100, 50, ImageID(im))
  ButtonImageGadget(#PB_Any, 320, 60, 100, 50, ImageID(im), #PB_Button_Toggle)
  
  While WaitWindowEvent() <> #PB_Event_CloseWindow : Wend
CompilerEndIf
