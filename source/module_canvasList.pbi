DeclareModule CanvasList
  EnableExplicit
  
  Enumeration 0
    #AttributePauseDraw
    #AttributeExpandItems
    #AttributeColumnize
    #AttributeDisplayImages
  EndEnumeration
  
  Enumeration 0
    #SortByText
    #SortByUserData
  EndEnumeration
  
  ; prototype for user sort
  Prototype.i compare(*element1, *element2, options)
  
  ; declare public functions
  Declare NewCanvasListGadget(x, y, width, height, useExistingCanvas = -1)
  Declare Free(*gadget)
  
  Declare Resize(*gadget, x, y, width, height)
  Declare AddItem(*gadget, text$, position = -1)
  Declare RemoveItem(*gadget, position)
  Declare SetItemImage(*gadget, position, image)
  Declare SetAttribute(*gadget, attribute, value)
  Declare GetAttribute(*gadget, attribute)
  Declare SetUserData(*gadet, *data)
  Declare GetUserData(*gadget)
  Declare SetItemUserData(*gadget, position, *data)
  Declare GetItemUserData(*gadget, position)
  Declare SetTheme(*gadget, theme$)
  Declare.s GetThemeJSON(*gadget, pretty=#False)
  Declare SortItems(*gadget, mode, *offset=0, options=#PB_Sort_Ascending)
  Declare AddItemButton(*gadget, image, *callback)
  
  ; also make functions available as interface
  Interface CanvasList
    Free()
    Resize(x, y, width, height)
    AddItem(text$, position = -1)
    RemoveItem(position)
    SetItemImage(position, image)
    SetAttribute(attribute, value)
    GetAttribute(attribute)
    SetUserData(*data)
    GetUserData()
    SetItemUserData(position, *data)
    GetItemUserData(position)
    SetTheme(theme$)
    GetThemeJSON.s(pretty=#False)
    SortItems(mode, *offset=0, options=#PB_Sort_Ascending)
    AddItemButton(image, *callback)
  EndInterface
  
EndDeclareModule

Module CanvasList
  
  DataSection
    vt:
    Data.i @Free()
    Data.i @Resize()
    Data.i @AddItem()
    Data.i @RemoveItem()
    Data.i @SetItemImage()
    Data.i @SetAttribute()
    Data.i @GetAttribute()
    Data.i @SetUserData()
    Data.i @GetUserData()
    Data.i @SetItemUserData()
    Data.i @GetItemUserData()
    Data.i @SetTheme()
    Data.i @GetThemeJSON()
    Data.i @SortItems()
    Data.i @AddItemButton()
  EndDataSection
  
  ;- Enumerations
  EnumerationBinary 0
    #SelectionNone
    #SelectionFinal
    #SelectionTemporary
  EndEnumeration
  
  Global mItems = CreateMutex()
  
  ;- Structures
  ;{
  Structure box Extends Point
    width.i
    height.i
  EndStructure
  
  Structure themeColors
    Background$
    ItemBackground$
    ItemBorder$
    ItemText$
    ItemSelected$
    ItemHover$
    SelectionBox$
    Border$
    Scrollbar$
    ScrollbarHover$
    ItemBtnHover$
  EndStructure
  
  Structure themeResponsive
    ExpandItems.b
    Columnize.b
  EndStructure
  
  Structure themeItemLine ; font information
    Font$     ; font name
    Bold.b    ; bold    true/false
    Italic.b  ; italic  true/false
    REM.d     ; scaling factor relative to default font size of OS GUI
    
    FontID.i  ; store font ID after loading the font
    yOffset.i
  EndStructure
  
  Structure themeItemImage
    Display.b
    MinHeight.w
    AspectRatio.d
  EndStructure
  
  Structure themeItem
    Width.w
    Height.w
    Margin.w
    Padding.w
    Image.themeItemImage
    Array Lines.themeItemLine(0) ; one font definition per line!
  EndStructure
  
  Structure theme
    scrollbarWidth.b
    color.themeColors
    responsive.themeResponsive
    item.themeItem
  EndStructure
  
  Structure selectbox
    active.b ; 0 = not active, 1 = init, 2 = active
    box.box
  EndStructure
  
  Structure item
    text$         ; display text
    image.i       ; display image (if any)
    selected.b    ; item selected?
    hover.b       ; mouse over item?
    *userdata     ; userdata
    canvasBox.box ; location on canvas stored for speeding up drawing operation
  EndStructure
  
  Prototype itemBtnCallback(*gadget.CanvasList, item, *userdata)
  Structure itemBtn
    image.i
    imageHover.i
    imageDisabled.i
    callback.itemBtnCallback
    box.box
    hover.b
  EndStructure
  
  Structure scrollbar
    disabled.b
    hover.b
    position.l
    maximum.l
    pagelength.l
    box.box
    dragActive.b
    dragOffset.l
  EndStructure
  
  Structure pendingSort
    sort.b
    mode.i
    *offset
    options.i
  EndStructure
  
  Structure gadget
    ; virtual table for OOP
    *vt.CanvasList
    ; userdata
    *userdata
    ; gadget data:
    gCanvas.i
    scrollbar.scrollbar
    hover.b
    ; parameters
    scrollWheelDelta.i
    fontHeight.i
    ; items
    List items.item()
    List itemButtons.itemBtn() ; same buttons used for all items...
    ; select box
    selectbox.selectbox
    ; theme / color
    theme.theme
    ; other attributes
    pauseDraw.b
    pendingSort.pendingSort
  EndStructure
  ;}
  
  ;- Private Support Functions
  
  Procedure GetWindowBackgroundColor(hwnd=0)
    ; found on https://www.purebasic.fr/english/viewtopic.php?f=12&t=66974
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows  
        Protected color = GetSysColor_(#COLOR_WINDOW)
        If color = $FFFFFF Or color=0
          color = GetSysColor_(#COLOR_BTNFACE)
        EndIf
        ProcedureReturn color
        
      CompilerCase #PB_OS_Linux   ;thanks to uwekel http://www.purebasic.fr/english/viewtopic.php?p=405822
        Protected *style.GtkStyle, *color.GdkColor
        *style = gtk_widget_get_style_(hwnd) ;GadgetID(Gadget))
        *color = *style\bg[0]                ;0=#GtkStateNormal
        ProcedureReturn RGB(*color\red >> 8, *color\green >> 8, *color\blue >> 8)
        
      CompilerCase #PB_OS_MacOS   ;thanks to wilbert http://purebasic.fr/english/viewtopic.php?f=19&t=55719&p=497009
        Protected.i color, Rect.NSRect, Image, NSColor = CocoaMessage(#Null, #Null, "NSColor windowBackgroundColor")
        If NSColor
          Rect\size\width = 1
          Rect\size\height = 1
          Image = CreateImage(#PB_Any, 1, 1)
          StartDrawing(ImageOutput(Image))
          CocoaMessage(#Null, NSColor, "drawSwatchInRect:@", @Rect)
          color = Point(0, 0)
          StopDrawing()
          FreeImage(Image)
          ProcedureReturn color
        Else
          ProcedureReturn -1
        EndIf
    CompilerEndSelect
  EndProcedure  
  
  Procedure.s getDefaultFontName()
    CompilerSelect #PB_Compiler_OS 
      CompilerCase #PB_OS_Windows 
        Protected sysFont.LOGFONT
        GetObject_(GetGadgetFont(#PB_Default), SizeOf(LOGFONT), @sysFont)
        ProcedureReturn PeekS(@sysFont\lfFaceName[0])
        
      CompilerCase #PB_OS_Linux
        Protected gVal.GValue
        Protected font$, size$
        g_value_init_(@gval, #G_TYPE_STRING)
        g_object_get_property(gtk_settings_get_default_(), "gtk-font-name", @gval)
        font$ = PeekS(g_value_get_string_( @gval ), -1, #PB_UTF8)
        g_value_unset_(@gval)
        size$ = StringField(font$, CountString(font$, " ")+1, " ")
        font$ = Left(font$, Len(font$)-Len(size$)-1)
        
        ProcedureReturn font$
    CompilerEndSelect
  EndProcedure
   
  Procedure getDefaultFontSize()
    CompilerSelect #PB_Compiler_OS 
      CompilerCase #PB_OS_Windows 
        Protected sysFont.LOGFONT
        GetObject_(GetGadgetFont(#PB_Default), SizeOf(LOGFONT), @sysFont)
        ProcedureReturn MulDiv_(-sysFont\lfHeight, 72, GetDeviceCaps_(GetDC_(#NUL), #LOGPIXELSY))
        
      CompilerCase #PB_OS_Linux
        Protected gVal.GValue
        Protected font$, size
        g_value_init_(@gval, #G_TYPE_STRING)
        g_object_get_property( gtk_settings_get_default_(), "gtk-font-name", @gval)
        font$ = PeekS(g_value_get_string_(@gval), -1, #PB_UTF8)
        g_value_unset_(@gval)
        size = Val(StringField(font$, CountString(font$, " ")+1, " "))
        ProcedureReturn size
    CompilerEndSelect
  EndProcedure
  
  Procedure getFontHeightPixel(fontID=0)
    Protected im, height
    
    If Not fontID
      fontID = GetGadgetFont(#PB_Default)
    EndIf
    
    im = CreateImage(#PB_Any, 1, 1)
    If im
      If StartDrawing(ImageOutput(im))
        DrawingFont(fontID)
        height = TextHeight("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890!")
        StopDrawing()
      EndIf
      FreeImage(im)
    EndIf
    ProcedureReturn height
  EndProcedure
  
  Procedure validateBox(*box.box)
    If *box\height < 0
      *box\y = *box\y + *box\height
      *box\height = -*box\height
    EndIf
    If *box\width < 0
      *box\x = *box\x + *box\width
      *box\width = -*box\width
    EndIf
  EndProcedure
  
  Procedure PointInBox(*p.point, *b.box, validate=#False)
    Protected b.box
    CopyStructure(*b, @b, box)
    If validate
      validateBox(@b)
    EndIf
    
    ProcedureReturn Bool(b\x < *p\x And
                         b\x + b\width > *p\x And
                         b\y < *p\y And
                         b\y + b\height > *p\y)
  EndProcedure
  
  Procedure BoxCollision(*a.box, *b.box, validate=#False)
    Protected a.box
    Protected b.box
    
    CopyStructure(*a, @a, box)
    CopyStructure(*b, @b, box)
    If validate
      validateBox(@a)
      validateBox(@b)
    EndIf
    
    ; boxes must be valid (positive width and height)
    ProcedureReturn Bool(a\x <= b\x + b\width And
                         b\x <= a\x + a\width And
                         a\y <= b\y + b\height And
                         b\y <= a\y + a\height)
  EndProcedure
  
  Procedure.s TextMaxWidth(text$, maxWidth.i)
    ; shorten text until fits into maxWidth
    If TextWidth(text$) > maxWidth
      If maxWidth < TextWidth("...")
        ProcedureReturn text$
      EndIf
      While TextWidth(text$) > maxWidth
        text$ = Trim(Left(text$, Len(text$)-4)) + "..."
      Wend
    EndIf
    ProcedureReturn text$
  EndProcedure
  
  Procedure.l ColorFromHTML(htmlColor$)
    Protected c.l, c$, tmp$, i.l
    Static NewMap colors$()
    Static NewMap cache()
    
    If FindMapElement(cache(), htmlColor$)
      ProcedureReturn cache()
    EndIf
    
    If MapSize(colors$()) = 0
      colors$("white")  = "#FFFFFF"
      colors$("silver") = "#C0C0C0"
      colors$("gray")   = "#808080"
      colors$("black")  = "#000000"
      colors$("red")    = "#FF0000"
      colors$("maroon") = "#800000"
      colors$("yellow") = "#FFFF00"
      colors$("olive")  = "#808000"
      colors$("lime")   = "#00FF00"
      colors$("green")  = "#008000"
      colors$("aqua")   = "#00FFFF"
      colors$("teal")   = "#008080"
      colors$("blue")   = "#0000FF"
      colors$("navy")   = "#000080"
      colors$("fuchsia") = "#FF00FF"
      colors$("purple") = "#800080"
    EndIf
    
    c$ = UCase(htmlColor$)
    
    ; detect predefined colors
    If FindMapElement(colors$(), c$)
      c$ = colors$(c$)
    EndIf
    
    ; remove #
    If Left(c$, 1) = "#"
      c$ = Mid(c$, 2)
    EndIf
    
    ; short notation (abc = AABBCC)
    If Len(c$) = 3 Or Len(c$) = 4
      ; repeat each character twice
      tmp$ = ""
      For i = 1 To Len(c$)
        tmp$ + Mid(c$, i, 1) + Mid(c$, i, 1)
      Next
      c$ = tmp$
    EndIf
    
    ; w/o alpha channel, add 00
    If Len(c$) = 6
      c$ + "00"
    EndIf
    
    ; if not full notation RRGGBBAA, something went wrong
    If Len(c$) <> 8
      ; RRGGBBAA
      Debug "could not convert color "+htmlColor$
      ProcedureReturn 0
    EndIf
    
    ; get number from hex
    c = Val("$"+c$)
    
    ; from HTML (RGBA) to internal representation (ABGR)
    c = (c & $ff) << 24 + (c & $ff00) << 8 + (c >> 8) & $ff00 + (c >> 24) & $ff
    cache(htmlColor$) = c
    cache(c$) = c
    ProcedureReturn c
  EndProcedure
  
  Procedure MakeDisabledIcon(*this.gadget, icon)
    Protected width, height, newIcon
    width   = ImageWidth(icon) 
    height  = ImageHeight(icon) 
    newIcon = CreateImage(#PB_Any, width, height, 32, #PB_Image_Transparent) 
    If StartDrawing(ImageOutput(newIcon))
      DrawingMode(#PB_2DDrawing_Default)
      Box(0, 0, width, height, #Gray) 
      DrawingMode(#PB_2DDrawing_AlphaChannel) 
      DrawImage(ImageID(icon), 0, 0) 
      StopDrawing()
    EndIf
    ProcedureReturn newIcon
  EndProcedure 
  
  Procedure MakeHoverIcon(*this.gadget, icon)
    Protected width, height, newIcon
    width   = ImageWidth(icon) 
    height  = ImageHeight(icon) 
    newIcon = CreateImage(#PB_Any, width, height, 32, #PB_Image_Transparent) 
    If StartDrawing(ImageOutput(newIcon)) 
      DrawingMode(#PB_2DDrawing_AlphaBlend) 
      Box(0, 0, width, height, RGBA(255, 255, 255, 255)) 
      Box(0, 0, width, height, ColorFromHTML(*this\theme\color\ItemBtnHover$))
      DrawImage(ImageID(icon), 0, 0)
      StopDrawing()
    EndIf
    ProcedureReturn newIcon
  EndProcedure 
  
  Procedure Quicksort(List items.item(), options, comp.compare, low, high, level=0)
    Protected.item *midElement, *highElement, *iElement, *wallElement
    Protected wall, i, sw
    
    If high - low < 1
      ProcedureReturn
    EndIf
    
    ; swap mid element and high element to avoid bad performance with already sorted list
    *midElement = SelectElement(items(), low + (high-low)/2)
    *highElement = SelectElement(items(), high)
    SwapElements(items(), *midElement, *highElement)
    
    ; find split point for array
    wall = low
    *highElement = SelectElement(items(), high)
    For i = low To high -1
      *iElement = SelectElement(items(), i)
      If comp(*highElement\userdata, *iElement\userdata, options)
        *wallElement = SelectElement(items(), wall)
        SwapElements(items(), *iElement, *wallElement)
        wall +1
      EndIf
    Next
    
    ; place last (high) value between the two splits
    
    *wallElement = SelectElement(items(), wall)
    *highElement = SelectElement(items(), high)
    SwapElements(items(), *wallElement, *highElement)
    
    ; sort below wall
    Quicksort(items(), options, comp, low, wall-1, level+1)
    
    ; sort above wall
    Quicksort(items(), options, comp, wall+1, high, level+1)
    
  EndProcedure
  
  ;- Private Functions
  
  Procedure updateScrollbar(*this.gadget)
    Protected totalHeight, numColumns
    
    If *this\pauseDraw
      ProcedureReturn #False
    EndIf
    
    LockMutex(mItems)
    
    *this\scrollbar\pagelength = GadgetHeight(*this\gCanvas)
    
    If *this\theme\responsive\Columnize
      numColumns  = Round((GadgetWidth(*this\gCanvas) - *this\theme\item\margin) / (*this\theme\item\Width + *this\theme\item\Margin), #PB_Round_Down)
      If numColumns < 1 : numColumns = 1 : EndIf
    Else
      numColumns = 1
    EndIf
    
    totalHeight = Round(ListSize(*this\items()) / numColumns, #PB_Round_Up)  * (*this\theme\item\Height + *this\theme\item\Margin) + *this\theme\item\Margin
    
    
    If totalHeight > GadgetHeight(*this\gCanvas)
      *this\scrollbar\disabled = #False
      *this\scrollbar\maximum = totalHeight
    Else
      *this\scrollbar\disabled = #True
    EndIf
    UnlockMutex(mItems)
    ProcedureReturn #True
  EndProcedure
  
  Procedure updateItemPosition(*this.gadget)
    Protected x, y, width, height
    Protected numColumns, columnWidth, r, c
    Protected margin, padding
    
    If *this\pauseDraw
      ProcedureReturn #False
    EndIf
    
    LockMutex(mItems)
    
    ; sanity check
    ; this may also be animated (overshoot and then slide back...)
    ; for all animations: requires timer function
    If *this\scrollbar\position > *this\scrollbar\maximum - *this\scrollbar\pagelength
      *this\scrollbar\position = *this\scrollbar\maximum - *this\scrollbar\pagelength
    EndIf
    If *this\scrollbar\position < 0
      *this\scrollbar\position = 0
    EndIf
    
    
    margin  = *this\theme\item\Margin
    padding = *this\theme\item\Padding
    
    If *this\theme\responsive\Columnize
      numColumns  = Round((GadgetWidth(*this\gCanvas) - margin) / (*this\theme\item\Width + margin), #PB_Round_Down)
      If numColumns < 1 : numColumns = 1 : EndIf
      columnWidth = Round(GadgetWidth(*this\gCanvas) / numColumns, #PB_Round_Down)
    Else
      numColumns  = 1
      columnWidth = GadgetWidth(*this\gCanvas)
    EndIf
    
    height  = *this\theme\Item\Height
    If *this\theme\responsive\ExpandItems
      width = columnWidth - 2*margin
    Else
      width = *this\theme\item\Width
    EndIf
    
    ForEach *this\items()
      c = Mod(ListIndex(*this\items()), numColumns)
      r = ListIndex(*this\items()) / numColumns
      
      x = *this\theme\item\Margin + c*(width + 2*margin)
      y = *this\theme\item\Margin + r*(*this\theme\item\Height + *this\theme\item\Margin) - *this\scrollbar\position
      
      *this\items()\canvasBox\x = x
      *this\items()\canvasBox\y = y
      *this\items()\canvasBox\width = width
      *this\items()\canvasBox\height = height
    Next
    
    Protected iconBtnSize = 24, i
    If ListSize(*this\items())
      ForEach *this\itemButtons()
        i = ListSize(*this\itemButtons()) - ListIndex(*this\itemButtons())
        *this\itemButtons()\box\x       = *this\items()\canvasBox\width - i * padding - i * iconBtnSize - (*this\theme\scrollbarWidth)
        ; scrollbarwidth offset just the scrollbar not covering the icon btn
        *this\itemButtons()\box\y       = *this\items()\canvasBox\height - padding - iconBtnSize
        *this\itemButtons()\box\width   = iconBtnSize
        *this\itemButtons()\box\height  = iconBtnSize
      Next
    EndIf
    
    UnlockMutex(mItems)
    ProcedureReturn #True
  EndProcedure
  
  Procedure updateItemLineFonts(*this.gadget) ; required after setting the font information for theme\item\Lines()
    ; load fonts and calculate item height
    *this\theme\item\Height = *this\theme\item\Padding ; top padding
    Protected i, style
    For i = 0 To ArraySize(*this\theme\item\Lines())
      If *this\theme\item\Lines(i)\font$ = ""
        *this\theme\item\Lines(i)\font$ = getDefaultFontName()
      EndIf
      If Not *this\theme\item\Lines(i)\rem
        *this\theme\item\Lines(i)\rem = 1
      EndIf
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        style = #PB_Font_HighQuality
      CompilerElse
        style = 0
      CompilerEndIf
      If *this\theme\item\Lines(i)\bold   : style | #PB_Font_Bold   : EndIf
      If *this\theme\item\Lines(i)\italic : style | #PB_Font_Italic : EndIf
      
;       Debug "load font "+*this\theme\item\Lines(i)\font$+", "+Str(*this\theme\item\Lines(i)\rem * getDefaultFontSize())+" pt"
      *this\theme\item\Lines(i)\fontID = LoadFont(#PB_Any, *this\theme\item\Lines(i)\font$, *this\theme\item\Lines(i)\rem * getDefaultFontSize(), style)
      
      ; set offset for current line and increase totalItemHeight
      *this\theme\item\Lines(i)\yOffset = *this\theme\item\Height
      *this\theme\item\Height + getFontHeightPixel(FontID(*this\theme\item\Lines(i)\fontID)) + *this\theme\item\Padding
    Next
    
    ; check if image required larger item height
    If *this\theme\item\Image\Display
      If *this\theme\item\Image\MinHeight + 2 * *this\theme\item\Padding > *this\theme\item\Height
        *this\theme\item\Height = *this\theme\item\Image\MinHeight + 2 * *this\theme\item\Padding
      EndIf
    EndIf
    
  EndProcedure
  
  Procedure draw(*this.gadget)
    Protected margin, padding
    Protected i, line$
    Static BackColor
    margin = *this\theme\Item\Margin
    padding = *this\theme\Item\Padding
    
    If *this\pauseDraw
      ProcedureReturn #False
    EndIf
    
    LockMutex(mItems)
    
    If Not BackColor
      BackColor = GetWindowBackgroundColor()
    EndIf
    
    If StartDrawing(CanvasOutput(*this\gCanvas))
      ; blank the canvas
      DrawingMode(#PB_2DDrawing_Default)
      Box(0, 0, GadgetWidth(*this\gCanvas), GadgetHeight(*this\gCanvas), BackColor)
      
      ; draw items
      DrawingFont(GetGadgetFont(#PB_Default))
      ForEach *this\items()
        With *this\items()
          ; only draw if visible
          If \canvasBox\y + *this\theme\item\Height > 0 And \canvasBox\y < GadgetHeight(*this\gCanvas)
            ; background
            DrawingMode(#PB_2DDrawing_Default)
            Box(\canvasBox\x, \canvasBox\y, \canvasBox\width, \canvasBox\height, ColorFromHTML(*this\theme\color\ItemBackground$))
            
            
            ; image
            Protected iH, iW, iOffset
            If *this\theme\item\Image\Display
              iH = *this\theme\item\Height - 2 * padding 
              iW = iH / *this\theme\item\Image\AspectRatio
              iOffset = iW+padding
              If \image And IsImage(\image)
                DrawingMode(#PB_2DDrawing_AlphaBlend)
                DrawImage(ImageID(\image), \canvasBox\x + padding, \canvasBox\y + padding, iW, iH)
              EndIf
            EndIf
            
            
            ; text
            DrawingMode(#PB_2DDrawing_Transparent)
            For i = 0 To ArraySize(*this\theme\item\Lines())
              line$ = StringField(\text$, i+1, #LF$)
              DrawingFont(FontID(*this\theme\item\Lines(i)\fontID))
              DrawText(\canvasBox\x + padding + iOffset, \canvasBox\y + *this\theme\item\Lines(i)\yOffset, TextMaxWidth(line$, \canvasBox\width - 2*padding - iOffset), ColorFromHTML(*this\theme\color\ItemText$))
            Next
            
            
            ; selected?
            If \selected
              DrawingMode(#PB_2DDrawing_AlphaBlend)
              Box(\canvasBox\x, \canvasBox\y, \canvasBox\width, \canvasBox\height, ColorFromHTML(*this\theme\color\ItemSelected$))
            EndIf
            
            
            ; hover?
            If \hover
              DrawingMode(#PB_2DDrawing_AlphaBlend)
              Box(\canvasBox\x, \canvasBox\y, \canvasBox\width, \canvasBox\height, ColorFromHTML(*this\theme\color\ItemHover$))
            EndIf
            
            
            ; buttons
            DrawingMode(#PB_2DDrawing_AlphaBlend)
            If \hover
              Protected x, y, w, h
              ForEach *this\itemButtons()
                x = \canvasBox\x + *this\itemButtons()\box\x
                y = \canvasBox\y + *this\itemButtons()\box\y
                w = *this\itemButtons()\box\width
                h = *this\itemButtons()\box\height
                ; background for each item button
                Box(x, y, w, h, $FFFFFFFF)
                If *this\itemButtons()\callback
                  If *this\itemButtons()\hover
                    DrawImage(ImageID(*this\itemButtons()\imageHover), x, y, w, h)
                  Else
                    DrawImage(ImageID(*this\itemButtons()\image), x, y, w, h)
                  EndIf
                Else ; no callback exists
                  DrawImage(ImageID(*this\itemButtons()\imageDisabled), x, y, w, h)
                EndIf
              Next
            EndIf
            
            
            ; border
            DrawingMode(#PB_2DDrawing_Outlined)
            Box(\canvasBox\x, \canvasBox\y, \canvasBox\width, \canvasBox\height, ColorFromHTML(*this\theme\color\ItemBorder$))
          EndIf
        EndWith
      Next
      
      ; draw selectbox
      If *this\selectbox\active = 2 ; only draw the box when already moved some pixels
        FrontColor(ColorFromHTML(*this\theme\color\SelectionBox$))
        DrawingMode(#PB_2DDrawing_AlphaBlend)
        Box(*this\selectbox\box\x, *this\selectbox\box\y - *this\scrollbar\position, *this\selectbox\box\width, *this\selectbox\box\height)
        DrawingMode(#PB_2DDrawing_Outlined)
        Box(*this\selectbox\box\x, *this\selectbox\box\y - *this\scrollbar\position, *this\selectbox\box\width, *this\selectbox\box\height)
      EndIf
      
            
      ; draw scrollbar
      If *this\hover And Not *this\scrollbar\disabled
        *this\scrollbar\box\x = GadgetWidth(*this\gCanvas) - *this\theme\scrollbarWidth - 2
        *this\scrollbar\box\y = *this\scrollbar\position * (GadgetHeight(*this\gCanvas)-4) / *this\scrollbar\maximum + 2
        *this\scrollbar\box\width = *this\theme\scrollbarWidth
        *this\scrollbar\box\height = *this\scrollbar\pagelength * (GadgetHeight(*this\gCanvas)-4) / *this\scrollbar\maximum
        If *this\scrollbar\box\height < *this\theme\scrollbarWidth*2
          *this\scrollbar\box\height = *this\theme\scrollbarWidth*2
        EndIf
        
        DrawingMode(#PB_2DDrawing_AlphaBlend)
        If *this\scrollbar\hover
          RoundBox(*this\scrollbar\box\x, *this\scrollbar\box\y, *this\scrollbar\box\width, *this\scrollbar\box\height, *this\theme\scrollbarWidth/2, *this\theme\scrollbarWidth/2, ColorFromHTML(*this\theme\color\ScrollbarHover$))
        Else
          RoundBox(*this\scrollbar\box\x, *this\scrollbar\box\y, *this\scrollbar\box\width, *this\scrollbar\box\height, *this\theme\scrollbarWidth/2, *this\theme\scrollbarWidth/2, ColorFromHTML(*this\theme\color\Scrollbar$))
        EndIf
      EndIf
      
      ; draw outer border
      DrawingMode(#PB_2DDrawing_Outlined|#PB_2DDrawing_AlphaBlend)
      Box(0, 0, GadgetWidth(*this\gCanvas), GadgetHeight(*this\gCanvas), ColorFromHTML(*this\theme\color\Border$))
      
      ; finished drawing
      StopDrawing()
      UnlockMutex(mItems)
      ProcedureReturn #False
    Else
      UnlockMutex(mItems)
      Debug "[!] draw failure"
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure EventCanvas()
    Protected *this.gadget
    Protected *item.item
    Protected p.point
    *this = GetGadgetData(EventGadget())
    p\x = GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseX)
    p\y = GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseY)
    
    Select EventType()
      Case #PB_EventType_Resize
        updateScrollbar(*this)
        updateItemPosition(*this)
        draw(*this)
        
      Case #PB_EventType_MouseWheel
        *this\scrollbar\position - (*this\scrollWheelDelta * GetGadgetAttribute(*this\gCanvas, #PB_Canvas_WheelDelta))
        updateItemPosition(*this)
        draw(*this)
        
      Case #PB_EventType_MouseEnter
        ; SetActiveGadget(*this\gCanvas)
        *this\hover = #True
        
      Case #PB_EventType_MouseLeave
        *this\hover = #False
        LockMutex(mItems)
        ForEach *this\items()
          *this\items()\hover = #False
        Next
        UnlockMutex(mItems)
        draw(*this)
        
        
      Case #PB_EventType_LeftClick
        ; left click is same as down & up...
        
      Case #PB_EventType_LeftButtonDown
        ; either drag the scrollbar or draw a selection box for items
        If *this\scrollbar\hover
          ; scrollbar shall move with mouse (in y direction)
          ; store y offset from scrollbar top to mouse position
          *this\scrollbar\dragActive = #True
          *this\scrollbar\dragOffset = p\y - *this\scrollbar\box\y
          
        Else
          *this\selectbox\active = 1
          ; store current x/y (not current display coordinates)
          *this\selectbox\box\x = p\x
          *this\selectbox\box\y = p\y + *this\scrollbar\position
        EndIf
        
      Case #PB_EventType_LeftButtonUp
        If *this\scrollbar\dragActive
          ; end of scrolbar movement
          *this\scrollbar\dragActive = #False
          
          
        ElseIf *this\selectbox\active = 1
          ; single click (no selectionbox)
          
          If GetGadgetAttribute(*this\gCanvas, #PB_Canvas_Modifiers) & #PB_Canvas_Control = #PB_Canvas_Control
            ; CTRL click (toggle item selection under mouse)
            
            LockMutex(mItems)
            ForEach *this\items()
              If *this\items()\hover
                ; toggle this item
                If *this\items()\selected & #SelectionFinal
                  *this\items()\selected = #SelectionNone
                Else
                  *this\items()\selected = #SelectionFinal
                EndIf
              EndIf
            Next
            UnlockMutex(mItems)
            
          Else
            ; normal click (select item under mouse, deselect all other items)
            LockMutex(mItems)
            ForEach *this\items()
              If *this\items()\hover
                ; TODO
                ; integrate callback here?
                Protected click.b = #False
                ForEach *this\itemButtons()
                  If *this\itemButtons()\hover
                    Debug "click on btn for item "+ListIndex(*this\items())
                    If *this\itemButtons()\callback
                      *this\itemButtons()\callback(*this, ListIndex(*this\items()), *this\items()\userdata)
                    EndIf
                    click = #True
                    Break
                  EndIf
                Next
                If Not click
                  *this\items()\selected = #SelectionFinal
                EndIf
              Else
                *this\items()\selected = #SelectionNone
              EndIf
            Next
            UnlockMutex(mItems)
            
          EndIf
          
          
        ElseIf *this\selectbox\active = 2
          ; selectionbox finished
          
          ; also add the current element to the selected items
          LockMutex(mItems)
          ForEach *this\items()
            *item = *this\items()
            If PointInBox(@p, *item\canvasBox)
              *item\selected | #SelectionTemporary
              Break
            EndIf
          Next
          
          ; if ctrl was pressed, add all "new" selections to the "old"
          ; if ctrl not pressed, remove all old selections
          ForEach *this\items()
            If Not GetGadgetAttribute(*this\gCanvas, #PB_Canvas_Modifiers) & #PB_Canvas_Control = #PB_Canvas_Control
              ; CTRL is not active -> remove old selection
              If *this\items()\selected & #SelectionFinal ; if bit set (dont care about other bits)
                *this\items()\selected & ~#SelectionFinal ; remove bit
              EndIf
            EndIf
            ; make new selections permanent
            If *this\items()\selected & #SelectionTemporary
              *this\items()\selected = #SelectionFinal
            EndIf
          Next
          UnlockMutex(mItems)
        EndIf
        
        
        *this\selectbox\active = 0
        draw(*this)
        
        
      Case #PB_EventType_MouseMove
        If *this\scrollbar\dragActive
          ; dragging scrollbar
          
          ;canvasY = *this\scrollbar\position * (GadgetHeight(*this\gCanvas)-4) / *this\scrollbar\maximum + 2
          ;*this\scrollbar\position = (canvasY - 2) * *this\scrollbar\maximum / (GadgetHeight(*this\gCanvas)-4)
          ; canvasY = p\y - *this\scrollbar\dragOffset
          
          *this\scrollbar\position = (p\y - *this\scrollbar\dragOffset - 2) * *this\scrollbar\maximum / (GadgetHeight(*this\gCanvas)-4)
          updateItemPosition(*this)
          draw(*this)
          
          
        ElseIf *this\selectbox\active = 1
          ; if mousedown and moving for some px in either direction, show selectbox (active = 2)
          If Abs(*this\selectbox\box\x - p\x) > 5 Or
             Abs(*this\selectbox\box\y - p\y + *this\scrollbar\position) > 5
            *this\selectbox\active = 2
          EndIf
        ElseIf *this\selectbox\active = 2
          ; problem: only works if mouse moving... maybe need a timer ?
          If GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseY) > GadgetHeight(*this\gCanvas) - 25
            *this\scrollbar\position + *this\scrollWheelDelta
            updateItemPosition(*this)
          ElseIf GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseY) < 25
            *this\scrollbar\position - *this\scrollWheelDelta
            updateItemPosition(*this)
          EndIf
          
          *this\selectbox\box\width   = p\x - *this\selectbox\box\x
          *this\selectbox\box\height  = p\y + *this\scrollbar\position - *this\selectbox\box\y
          
          LockMutex(mItems)
          ForEach *this\items()
            ; check if is selected by selectionBox
            ; convert canvasBox to realBox (!!!scrollbar offset)
            *this\items()\canvasBox\y = *this\items()\canvasBox\y + *this\scrollbar\position
            If BoxCollision(*this\items()\canvasBox, *this\selectbox\box, #True)
              *this\items()\selected | #SelectionTemporary ; set bit
            Else
              *this\items()\selected & ~#SelectionTemporary ; unset bit
            EndIf
            ; convert back to canvasBox
            *this\items()\canvasBox\y = *this\items()\canvasBox\y - *this\scrollbar\position
          Next
          UnlockMutex(mItems)
          
          draw(*this)
          
        Else ; no drawbox active (simple hover)
          ; mouse position
          p\x = GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseX)
          p\y = GetGadgetAttribute(*this\gCanvas, #PB_Canvas_MouseY)
          
          ; check scrollbar hover
          If PointInBox(@p, *this\scrollbar\box)
            *this\scrollbar\hover = #True
          Else
            *this\scrollbar\hover = #False
          EndIf
          
          ; check item hover
          ; idea: as mouse can only hover on one item, use a SINGLE hover variable that stores what the moouse currently hovers over.
          LockMutex(mItems)
          ForEach *this\items()
            *this\items()\hover = #False
          Next
          If Not *this\scrollbar\hover
            ; only hover items if not hover on scrollbar
            ForEach *this\items()
              *item = *this\items()
              If PointInBox(@p, *item\canvasBox)
                *item\hover = #True
                ForEach *this\itemButtons()
                  Protected box.box
                  box\x = *item\canvasBox\x + *this\itemButtons()\box\x
                  box\y = *item\canvasBox\y + *this\itemButtons()\box\y
                  box\width = *this\itemButtons()\box\width
                  box\height = *this\itemButtons()\box\height
                  If PointInBox(@p, @box)
                    *this\itemButtons()\hover = #True
                  Else
                    *this\itemButtons()\hover = #False
                  EndIf
                Next
                Break ; can only hover on one item!
              EndIf
            Next
          EndIf
          UnlockMutex(mItems)
          
          draw(*this)
        EndIf
        
        
      Case #PB_EventType_KeyUp
        Select GetGadgetAttribute(*this\gCanvas, #PB_Canvas_Key)
          Case #PB_Shortcut_A
            If GetGadgetAttribute(*this\gCanvas, #PB_Canvas_Modifiers) & #PB_Canvas_Control = #PB_Canvas_Control
              ; select all
              LockMutex(mItems)
              ForEach *this\items()
                *this\items()\selected | #SelectionFinal
              Next
              UnlockMutex(mItems)
              draw(*this)
            EndIf
        EndSelect
        
      Case #PB_EventType_KeyDown
        Protected key = GetGadgetAttribute(*this\gCanvas, #PB_Canvas_Key)
        Protected redraw.b
        If key = #PB_Shortcut_Up Or
           key = #PB_Shortcut_Down
          Protected selectedItems
          selectedItems = 0
          ; TODO
          ; instead of count selected, save "last selected item" in gadget data
          LockMutex(mItems)
          ForEach *this\items()
            If *this\items()\selected & #SelectionFinal
              selectedItems + 1
              *item = *this\items()
            EndIf
          Next
          UnlockMutex(mItems)
          
          
          If selectedItems = 1
            ; if one item selected, select next/previous item in list
            LockMutex(mItems)
            ChangeCurrentElement(*this\items(), *item)
            If key = #PB_Shortcut_Up
              If ListIndex(*this\items()) > 0
                *this\items()\selected & ~#SelectionFinal
                PreviousElement(*this\items())
                *this\items()\selected | #SelectionFinal
                *item = *this\items()
                redraw = #True
              EndIf
            ElseIf key = #PB_Shortcut_Down
              If ListIndex(*this\items()) < ListSize(*this\items())
                *this\items()\selected & ~#SelectionFinal
                NextElement(*this\items())
                *this\items()\selected | #SelectionFinal
                *item = *this\items()
                redraw = #True
              EndIf
            EndIf
            UnlockMutex(mItems)
            
            If redraw
              ; if selected item out of view, move scrollbar
              If *item\canvasBox\y < 0
                *this\scrollbar\position + (*item\canvasBox\y - *this\theme\item\Margin)
                updateScrollbar(*this)
                updateItemPosition(*this)
              ElseIf *item\canvasBox\y + *item\canvasBox\height > GadgetHeight(*this\gCanvas)
                *this\scrollbar\position + (*item\canvasBox\y + *item\canvasBox\height + *this\theme\item\Margin - GadgetHeight(*this\gCanvas))
                updateScrollbar(*this)
                updateItemPosition(*this)
              EndIf
              
              draw(*this)
            EndIf
          EndIf
        EndIf
    EndSelect
  EndProcedure
  
  ;- Public Functions
  
  Procedure NewCanvasListGadget(x, y, width, height, useExistingCanvas = -1)
    Protected *this.gadget
    *this = AllocateStructure(gadget)
    *this\vt = ?vt ; link interface to function addresses
    
    ; set parameters
    *this\fontHeight = getFontHeightPixel()
    *this\scrollWheelDelta = *this\fontHeight*4
    
    ; theme
    DataSection
      themeStart:
      IncludeBinary "theme/modList.json"
      themeEnd:
    EndDataSection
    SetTheme(*this, PeekS(?themeStart, ?themeEnd-?themeStart, #PB_UTF8))
    
    ; create canvas or use existing
    If useExistingCanvas = -1
      *this\gCanvas = CanvasGadget(#PB_Any, x, y, width, height, #PB_Canvas_Keyboard) ; keyboard focus requried for mouse wheel on windows
    Else
      If Not IsGadget(useExistingCanvas)
        ProcedureReturn #False
      EndIf
      *this\gCanvas = useExistingCanvas
      ResizeGadget(*this\gCanvas, x, y, width, height)
    EndIf
    
    *this\scrollbar\pagelength = height
    *this\scrollbar\disabled = #True
    
    ; set data pointer
    SetGadgetData(*this\gCanvas, *this)
    
    ; bind events on both gadgets
    BindGadgetEvent(*this\gCanvas, @EventCanvas(), #PB_All)
    
    ; initial draw
    draw(*this)
    ProcedureReturn *this
  EndProcedure
  
  Procedure Free(*this.gadget)
    FreeGadget(*this\gCanvas)
    FreeStructure(*this)
  EndProcedure
  
  Procedure Resize(*this.gadget, x, y, width, height)
    ResizeGadget(*this\gCanvas, x, y, width, height)
    
    ; should cause resize callback / TODO: CHECK
    ; not used in this project
;     updateScrollbar(*this)
;     updateItemPosition(*this)
;     draw(*this)
  EndProcedure
    
  Procedure AddItem(*this.gadget, text$, position = -1)
    LockMutex(mItems)
    If ListSize(*this\items()) > 0
      If position = -1
        position = ListSize(*this\items()) - 1
      EndIf
      ; select position to add new element
      If Not SelectElement(*this\items(), position)
        ; if position does not exist: last element
        LastElement(*this\items())
      EndIf
    EndIf
    
    AddElement(*this\items())
    *this\items()\text$ = text$
    position = ListIndex(*this\items())
    
    UnlockMutex(mItems)
    
    updateScrollbar(*this)
    updateItemPosition(*this)
    draw(*this)
    
    ProcedureReturn position
  EndProcedure
  
  Procedure RemoveItem(*this.gadget, position)
    LockMutex(mItems)
    If SelectElement(*this\items(), position)
      DeleteElement(*this\items(), 1)
      UnlockMutex(mItems)
      updateItemPosition(*this)
      updateScrollbar(*this)
      draw(*this)
    Else
      UnlockMutex(mItems)
    EndIf
  EndProcedure
  
  Procedure SetItemImage(*this.gadget, position, image)
    LockMutex(mItems)
    If SelectElement(*this\items(), position)
      *this\items()\image = image
      draw(*this)
    EndIf
    UnlockMutex(mItems)
  EndProcedure
  
  Procedure SetAttribute(*this.gadget, attribute, value)
    Select attribute
      Case #AttributeExpandItems
        *this\theme\responsive\ExpandItems = value
        updateItemPosition(*this)
        draw(*this)
      Case #AttributeColumnize
        *this\theme\responsive\Columnize = value
        updateItemPosition(*this)
        updateScrollbar(*this)
        draw(*this)
      Case #AttributeDisplayImages
        *this\theme\item\image\display = value
        updateItemPosition(*this)
        updateScrollbar(*this)
        draw(*this)
      Case #AttributePauseDraw
        *this\pauseDraw = value
        If Not *this\pauseDraw
          If *this\pendingSort\sort
            Debug "## execute pending sort"
            SortItems(*this, *this\pendingSort\mode, *this\pendingSort\offset, *this\pendingSort\options)
          EndIf
          updateItemPosition(*this)
          updateScrollbar(*this)
          draw(*this)
        EndIf
    EndSelect
  EndProcedure
  
  Procedure GetAttribute(*this.gadget, attribute)
    Select attribute
      Case #AttributeExpandItems
        ProcedureReturn *this\theme\responsive\ExpandItems
      Case #AttributeColumnize
        ProcedureReturn *this\theme\responsive\Columnize
      Case #AttributeDisplayImages
        ProcedureReturn *this\theme\item\image\display
      Case #AttributePauseDraw
        ProcedureReturn *this\pauseDraw
    EndSelect
  EndProcedure
  
  Procedure SetUserData(*this.gadget, *data)
    *this\userdata = *data
  EndProcedure
  
  Procedure GetUserData(*this.gadget)
    ProcedureReturn *this\userdata
  EndProcedure
  
  Procedure SetItemUserData(*this.gadget, position, *data)
    LockMutex(mItems)
    If SelectElement(*this\items(), position)
      *this\items()\userdata = *data
    EndIf
    UnlockMutex(mItems)
  EndProcedure
  
  Procedure GetItemUserData(*this.gadget, position)
    Protected *userdata
    LockMutex(mItems)
    If SelectElement(*this\items(), position)
      *userdata = *this\items()\userdata
    EndIf
    UnlockMutex(mItems)
    ProcedureReturn *userdata
  EndProcedure
  
  Procedure SetTheme(*this.gadget, theme$)
    Protected json, theme.theme, i
    json = ParseJSON(#PB_Any, theme$, #PB_JSON_NoCase)
    If json
      For i = 0 To ArraySize(*this\theme\item\Lines())
        If *this\theme\item\Lines(i)\FontID And 
          IsFont(*this\theme\item\Lines(i)\FontID)
          FreeFont(*this\theme\item\Lines(i)\FontID)
          *this\theme\item\Lines(i)\FontID = 0
        EndIf
      Next
      ExtractJSONStructure(JSONValue(json), @theme, theme)
      CopyStructure(@theme, *this\theme, theme)
      FreeJSON(json)
      updateItemLineFonts(*this)
    Else
      Debug JSONErrorMessage()
    EndIf
    
  EndProcedure
  
  Procedure.s GetThemeJSON(*this.gadget, pretty=#False)
    Protected json, json$
    json = CreateJSON(#PB_Any)
    InsertJSONStructure(JSONValue(json), *this\theme, theme)
    If pretty
      pretty = #PB_JSON_PrettyPrint
    EndIf
    json$ = ComposeJSON(json, pretty)
    FreeJSON(json)
    ProcedureReturn json$
  EndProcedure
  
  Procedure SortItems(*this.gadget, mode, *offset=0, options=#PB_Sort_Ascending)
    ; sort items
    
    If *this\pauseDraw
      *this\pendingSort\sort = #True
      *this\pendingSort\mode = mode
      *this\pendingSort\offset = *offset
      *this\pendingSort\options = options
      ProcedureReturn #True
    Else
      *this\pendingSort\sort = #False
    EndIf
    
    Select mode
      Case #SortByText
        ; offset  = line to use for sorting the items
        ;
        ; offset (line number) not yet working (must extract individual lines for sorting...)
        LockMutex(mItems)
        SortStructuredList(*this\items(), options, OffsetOf(item\text$), #PB_String)
        UnlockMutex(mItems)
        
      Case #SortByUserData
        ; offset  = compare function
        LockMutex(mItems)
        Debug "############## >>>>>>>>>>>>>"
        Quicksort(*this\items(), options, *offset, 0, ListSize(*this\items())-1)
        Debug "############## <<<<<<<<<<<<<"
        UnlockMutex(mItems)
        
      Default
        Debug "unknown sort mode"
        
    EndSelect
    
    updateItemPosition(*this)
    draw(*this)
  EndProcedure
  
  Procedure AddItemButton(*this.gadget, image, *callback)
    AddElement(*this\itemButtons())
    *this\itemButtons()\image = image
    *this\itemButtons()\imageHover = MakeHoverIcon(*this, image)
    *this\itemButtons()\imageDisabled = MakeDisabledIcon(*this, image)
    *this\itemButtons()\callback = *callback
  EndProcedure
  
EndModule
