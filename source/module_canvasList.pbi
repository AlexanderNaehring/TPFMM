DeclareModule CanvasList
  EnableExplicit
  
  Enumeration 0
    #AttributePauseDraw
    #AttributeExpandItems
    #AttributeColumnize
    #AttributeDisplayImages
  EndEnumeration
  
  ; Custom Item Events on top of #PB_EventType_LeftClick etc...
  Enumeration -1 Step -1 ; use negative numbers for events as "EventType()" values are positive
    #OnItemVisible
    #OnItemInvisible
    #OnItemFirstVisible
  EndEnumeration
  
  Enumeration 0
    #SortByText
    #SortByUser
  EndEnumeration
  
  Enumeration 0
    #AlignLeft
    #AlignRight
  EndEnumeration
  
  ; prototype for user sort
  Prototype.i pCompare(*item1, *item2, options)
  ; prototype for user filter
  Prototype.i pFilter(*item, options)
  
  ;- Interfaces
  Interface CanvasListItem
    SetImage(image)
    GetImage()
    SetUserData(*data)
    GetUserData()
    SetSelected(selected)
    GetSelected()
    Hide(hidden.b)
    IsHidden()
    AddIcon(image, align=#AlignRight)
    ClearIcons()
    AddButton(*callback, image, imageHover=0)
    ClearButtons()
  EndInterface
  
  Interface CanvasList
    Free()
    Resize(x, y, width, height)
    Redraw()
    AddItem(text$, *userdata=#Null, position = -1)
    RemoveItem(*item)
    ClearItems()
    SetAttribute(attribute, value)
    GetAttribute(attribute)
    SetUserData(*data)
    GetUserData()
    SetSelectedItem(*item)
    GetSelectedItem()
    GetAllSelectedItems(List *items.CanvasListItem())
    GetAllVisibleItems(List *items.CanvasListItem())
    GetAllItems(List *items.CanvasListItem())
    GetItemCount()
    SetTheme(theme$)
    GetThemeJSON.s(pretty=#False)
    SortItems(mode, *sortFun=0, options=#PB_Sort_Ascending, persistent.b=#False)
    FilterItems(filterFun.pFilter, options=0, persistent.b=#False)
    BindItemEvent(event, *callback)
    SetEmptyScreen(textOnEmpty$, textOnFilter$)
  EndInterface
  
  ; declare public functions
  Declare NewCanvasListGadget(x, y, width, height, useExistingCanvas = -1)
  Declare Free(*gadget)
  
  ; gadget functions
  Declare Redraw(*gadget)
  Declare Resize(*gadget, x, y, width, height)
  Declare AddItem(*gadget, text$, *userdata=#Null, position = -1)
  Declare RemoveItem(*gadget, *item)
  Declare ClearItems(*gadget)
  Declare SetAttribute(*gadget, attribute, value)
  Declare GetAttribute(*gadget, attribute)
  Declare SetUserData(*gadet, *data)
  Declare GetUserData(*gadget)
  Declare SetSelectedItem(*gadget, *item)
  Declare GetSelectedItem(*gadget)
  Declare GetAllSelectedItems(*gadget, List *items.CanvasListItem())
  Declare GetAllVisibleItems(*gadget, List *items.CanvasListItem())
  Declare GetAllItems(*gadget, List *item.CanvasListItem())
  Declare GetItemCount(*gadget)
  Declare SetTheme(*gadget, theme$)
  Declare.s GetThemeJSON(*gadget, pretty=#False)
  Declare SortItems(*gadget, mode, *sortFun=0, options=#PB_Sort_Ascending, persistent.b=#False)
  Declare FilterItems(*gadget, filterFun.pFilter, options=0, persistent.b=#False)
  Declare BindItemEvent(*gadget, event, *callback)
  Declare SetEmptyScreen(*gadget, textOnEmpty$, textOnFilter$) ; set some welcome information that is shown when no item is visible
  
  ; item functions
  Declare ItemSetImage(*item, image)
  Declare ItemGetImage(*item)
  Declare ItemSetUserData(*item, *userdata)
  Declare ItemGetUserData(*item)
  Declare ItemSetSelected(*item, selected)
  Declare ItemGetSelected(*item)
  Declare ItemHide(*item, hidden.b)
  Declare ItemIsHidden(*item)
  Declare ItemAddIcon(*item, image, align=#AlignRight)
  Declare ItemClearIcons(*item)
  Declare ItemAddButton(*item, *callback, image, imageHover=0)
  Declare ItemClearButtons(*item)
  
  
EndDeclareModule

CompilerIf #PB_Compiler_IsIncludeFile
  XIncludeFile "module_debugger.pbi"
CompilerEndIf

Module CanvasList
  
  ;{ VT
  DataSection
    vt:
    Data.i @Free()
    Data.i @Resize()
    Data.i @Redraw()
    Data.i @AddItem()
    Data.i @RemoveItem()
    Data.i @ClearItems()
    Data.i @SetAttribute()
    Data.i @GetAttribute()
    Data.i @SetUserData()
    Data.i @GetUserData()
    Data.i @SetSelectedItem()
    Data.i @GetSelectedItem()
    Data.i @GetAllSelectedItems()
    Data.i @GetAllVisibleItems()
    Data.i @GetAllItems()
    Data.i @GetItemCount()
    Data.i @SetTheme()
    Data.i @GetThemeJSON()
    Data.i @SortItems()
    Data.i @FilterItems()
    Data.i @BindItemEvent()
    Data.i @SetEmptyScreen()
    
    vtItem:
    Data.i @ItemSetImage()
    Data.i @ItemGetImage()
    Data.i @ItemSetUserData()
    Data.i @ItemGetUserData()
    Data.i @ItemSetSelected()
    Data.i @ItemGetSelected()
    Data.i @ItemHide()
    Data.i @ItemIsHidden()
    Data.i @ItemAddIcon()
    Data.i @ItemClearIcons()
    Data.i @ItemAddButton()
    Data.i @ItemClearButtons()
  EndDataSection
  ;}
  
  ;{ Enumerations
  EnumerationBinary 0
    #SelectionNone
    #SelectionFinal
    #SelectionTemporary
  EndEnumeration
  ;}
  
  ;{ Structures
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    Structure Point
      x.i
      y.i
    EndStructure
  CompilerEndIf
  
  Structure box Extends Point
    width.i
    height.i
  EndStructure
  
  ; theme
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
    
    ; internal information, not supplied by json:
    FontID.i
    yOffset.i
    Array tabX.w(10)
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
    TabAlign$
  EndStructure
  
  Structure theme
    scrollbarWidth.b
    color.themeColors
    responsive.themeResponsive
    item.themeItem
  EndStructure
  
  ; selectbox
  Structure selectbox
    active.b ; 0 = not active, 1 = init, 2 = active
    box.box
  EndStructure
  
  ; scrollbar
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
  
  ; sort & filter
  Structure pendingSort
    pending.b
    persistent.b
    mode.i
    *sortFun
    options.i
  EndStructure
  
  Structure filter
    filterFun.pFilter
    options.i
  EndStructure
  
  ; item
  Prototype itemBtnCallback(*item)
  Structure itemBtn
    image.i
    imageHover.i
    callback.itemBtnCallback
    box.box
    hover.b
  EndStructure
  
  Structure itemIcon
    image.i
    align.b
  EndStructure
  
  Structure item
    *vt.CanvasListItem
    *parent       ; gadget pointer
    text$         ; display text
    image.i       ; user image per item (optional)
    selected.b    ; item selected?
    hover.b       ; mouse over item?
    hidden.b      ; item currently not displayed
    isOnCanvas.b  ; item is currently visible on the canvas
    wasVisible.b  ; item was visible at some point in the past (used for event "onFirstVisible")
    List icons.itemIcon() ; multiple (optional) user icons displayed on the item
    List buttons.itemBtn() ; same buttons used for all items...
    *userdata     ; userdata
    canvasBox.box ; location on canvas stored for speeding up drawing operation
  EndStructure
  
  Prototype itemEventCallback(*item.CanvasListItem, event)
  Structure itemEvent
    event.i
    callback.itemEventCallback
  EndStructure
  
  ; gadget
  Structure gadget
    *vt.CanvasList
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
    List itemEvents.itemEvent()
    ; select box
    selectbox.selectbox
    ; theme / color
    theme.theme
    ; other attributes
    pauseDraw.b
    pendingSort.pendingSort
    filter.filter
    mItems.i
    mItemAddRemove.i
    winColor.i
    textOnEmpty$
    textOnFilter$
  EndStructure
  ;}
  
  ;- debug output
  
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
  
  Procedure GetWindowBackgroundColor(hwnd)
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
        If Not hwnd
          DebuggerError("hwnd required")
        EndIf
        Static color
        If Not color
          *style = gtk_widget_get_style_(hwnd) ;GadgetID(Gadget))
          *color = *style\bg[0]                ;0=#GtkStateNormal
          color = RGB(*color\red >> 8, *color\green >> 8, *color\blue >> 8)
        EndIf
        ProcedureReturn color
        
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
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    #G_TYPE_STRING = 64
    
    ImportC ""
      g_object_get_property(*widget.GtkWidget, property.p-utf8, *gval)
    EndImport
  CompilerEndIf
  
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
        g_object_get_property_( gtk_settings_get_default_(), "gtk-font-name", @gval)
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
  
  Procedure Quicksort(List items.item(), options, comp.pCompare, low, high, level=0)
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
      If comp(*highElement, *iElement, options)
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
  
  
  Procedure countVisibleItems(*this.gadget)
    Protected count
    LockMutex(*this\mItems)
    ForEach *this\items()
      If Not *this\items()\hidden
        count + 1
      EndIf
    Next
    UnlockMutex(*this\mItems)
    ProcedureReturn count
  EndProcedure
  
  Procedure updateScrollbar(*this.gadget)
    Protected totalHeight, numColumns, numItems
    
    If *this\pauseDraw
      ProcedureReturn #False
    EndIf
    
    numItems = countVisibleItems(*this)
    
    LockMutex(*this\mItems)
    
    *this\scrollbar\pagelength = GadgetHeight(*this\gCanvas)
    
    If *this\theme\responsive\Columnize
      numColumns  = Round((GadgetWidth(*this\gCanvas) - *this\theme\item\margin) / (*this\theme\item\Width + *this\theme\item\Margin), #PB_Round_Down)
      If numColumns < 1 : numColumns = 1 : EndIf
    Else
      numColumns = 1
    EndIf
    
    
    totalHeight = Round(numItems / numColumns, #PB_Round_Up)  * (*this\theme\item\Height + *this\theme\item\Margin) + *this\theme\item\Margin
    
    
    If totalHeight > GadgetHeight(*this\gCanvas)
      *this\scrollbar\disabled = #False
      *this\scrollbar\maximum = totalHeight
    Else
      *this\scrollbar\disabled = #True
      *this\scrollbar\maximum = 0
      *this\scrollbar\position = 0
    EndIf
    UnlockMutex(*this\mItems)
    ProcedureReturn #True
  EndProcedure
  
  Procedure updateItemPosition(*this.gadget)
    Protected x, y, width, height
    Protected numColumns, columnWidth, r, c, i, k
    Protected margin, padding
    
    If *this\pauseDraw
      ProcedureReturn #False
    EndIf
    
    LockMutex(*this\mItems)
    
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
    
    i = 0
    ForEach *this\items()
      If *this\items()\hidden
        *this\items()\isOnCanvas = #False
        Continue
      EndIf
      c = Mod(i, numColumns)
      r = i / numColumns
      
      x = *this\theme\item\Margin + c*(width + 2*margin)
      y = *this\theme\item\Margin + r*(*this\theme\item\Height + *this\theme\item\Margin) - *this\scrollbar\position
      
      *this\items()\canvasBox\x = x
      *this\items()\canvasBox\y = y
      *this\items()\canvasBox\width = width
      *this\items()\canvasBox\height = height
      
      If *this\items()\canvasBox\y + *this\theme\item\Height > 0 And *this\items()\canvasBox\y < GadgetHeight(*this\gCanvas)
        ; item is visible
        If Not *this\items()\isOnCanvas
          ; was not visible before
          ; execute callback if exists
          ForEach *this\itemEvents()
            If *this\itemEvents()\event = #OnItemVisible
              *this\itemEvents()\callback(*this\items(), #OnItemVisible)
            ElseIf Not *this\items()\wasVisible And *this\itemEvents()\event = #OnItemFirstVisible
              *this\itemEvents()\callback(*this\items(), #OnItemFirstVisible)
            EndIf
          Next
        EndIf
        *this\items()\isOnCanvas = #True
        *this\items()\wasVisible = #True
      Else
        ; item not visible
        If *this\items()\isOnCanvas
          ; was visible before
          ; execute callback if exists
          ForEach *this\itemEvents()
            If *this\itemEvents()\event = #OnItemInvisible
              *this\itemEvents()\callback(*this\items(), #OnItemInvisible)
            EndIf
          Next
        EndIf
        *this\items()\isOnCanvas = #False
      EndIf
      
      
      Protected iconBtnSize = 24
      ForEach *this\items()\buttons()
        ; position relative to item!
        k = ListSize(*this\items()\buttons()) - ListIndex(*this\items()\buttons())
        *this\items()\buttons()\box\x       = *this\items()\canvasBox\width - k * padding - k * iconBtnSize - (*this\theme\scrollbarWidth)
        ; scrollbarwidth offset just the scrollbar not covering the icon btn
        *this\items()\buttons()\box\y       = *this\items()\canvasBox\height - padding - iconBtnSize
        *this\items()\buttons()\box\width   = iconBtnSize
        *this\items()\buttons()\box\height  = iconBtnSize
      Next
      
      i + 1
    Next
    
    
    UnlockMutex(*this\mItems)
    ProcedureReturn #True
  EndProcedure
  
  Procedure updateItemLineFonts(*this.gadget) ; required after setting the font information for theme\item\Lines()
    ; load fonts and calculate item height
    Protected i, style
    *this\theme\item\Height = *this\theme\item\Padding ; top padding
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
    Protected k, nextX, str$
    Protected x, y, w, h
    Protected redraw.b
    margin = *this\theme\Item\Margin
    padding = *this\theme\Item\Padding
    
    If *this\pauseDraw
      ProcedureReturn #False
    EndIf
    
    LockMutex(*this\mItems)
    
    If StartDrawing(CanvasOutput(*this\gCanvas))
      ; blank the canvas
      DrawingMode(#PB_2DDrawing_Default)
      Box(0, 0, GadgetWidth(*this\gCanvas), GadgetHeight(*this\gCanvas), *this\winColor)
      
      ; draw items
      DrawingFont(GetGadgetFont(#PB_Default))
      ForEach *this\items()
        With *this\items()
          If \hidden
            Continue
          EndIf
          
          ; only draw if visible
          If \isOnCanvas
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
            
            
            ; icons
            If ListSize(\icons()) > 0
              DrawingMode(#PB_2DDrawing_AlphaBlend)
              ; draw icons in "first line", use same size as text in first line
              Protected size = *this\theme\item\Lines(0)\REM * *this\fontHeight
              Protected nl, nr
              Protected iconOffsetL, iconOffsetR
              nl = 0 : nr = 0 
              iconOffsetL = 0 : iconOffsetR = 0
              ForEach \icons()
                ; left overlay, ignore other objects: x = \canvasBox\x + nl * size + padding
                If \icons()\align = #AlignLeft
                  x = \canvasBox\x + iOffset + nl * (size + padding) + padding
                  iconOffsetL = (nl+1) * (size + padding) + padding
                  nl + 1
                ElseIf \icons()\align = #AlignRight
                  x = \canvasBox\x + \canvasBox\width - ((nr+1) * (size + padding) + *this\theme\scrollbarWidth )
                  iconOffsetR = (nr+2) * (size + padding) + *this\theme\scrollbarWidth
                  nr + 1
                EndIf
                y = \canvasBox\y + padding
                w = size
                h = size
                DrawImage(ImageID(\icons()\image), x, y, w, h)
              Next
            EndIf
            
            
            ; text
            DrawingMode(#PB_2DDrawing_Transparent)
            For i = 0 To ArraySize(*this\theme\item\Lines())
              line$ = StringField(\text$, i+1, #LF$)
              DrawingFont(FontID(*this\theme\item\Lines(i)\fontID))
              x = \canvasBox\x + padding + iOffset
              y = \canvasBox\y + *this\theme\item\Lines(i)\yOffset
              w = \canvasBox\width - 2*padding - iOffset
              If i = 0 ; icon offset only in first line
                x + iconOffsetL
                w - iconOffsetL - iconOffsetR
              EndIf
              
              If Not CountString(line$, Chr(9))
                DrawText(x, y, TextMaxWidth(line$, w), ColorFromHTML(*this\theme\color\ItemText$))
              Else ; if using tab, split string and draw multiple text boxes
                For k = 1 To CountString(line$, Chr(9))+1
                  str$ = StringField(line$, k, Chr(9))
                  
                  If k > 1 ; check if tab align is active and if saved tab location is further right tha current tab location
                    If *this\theme\item\TabAlign$ = "line" And x < *this\theme\item\lines(i)\tabX(k-1)
                      ; TODO if tabAlign causes other text to move out of visible area, move back?
                      w - (*this\theme\item\lines(i)\tabX(k-1) - x)
                      x = *this\theme\item\lines(i)\tabX(k-1)
                    ElseIf *this\theme\item\TabAlign$ = "list" And x < *this\theme\item\lines(0)\tabX(k-1)
                      w - (*this\theme\item\lines(0)\tabX(k-1) - x)
                      x = *this\theme\item\lines(0)\tabX(k-1)
                    EndIf
                  EndIf
                  
                  ; draw text, result is cursor position
                  nextX = DrawText(x, y, TextMaxWidth(str$, w), ColorFromHTML(*this\theme\color\ItemText$))
                  ; align nextX to defined steps
                  #TabPx = 25
                  nextX = (Round((nextX+8)/#TabPx, #PB_Round_Up))*#TabPx
                  w - (nextX - x)
                  x = nextX
                  
                  If *this\theme\item\TabAlign$ = "line" And *this\theme\item\lines(i)\tabX(k) < x
                    *this\theme\item\lines(i)\tabX(k) = x
                    redraw = #True
                  ElseIf *this\theme\item\TabAlign$ = "list" And *this\theme\item\lines(0)\tabX(k) < x
                    *this\theme\item\lines(0)\tabX(k) = x
                    redraw = #True
                  EndIf
                Next
              EndIf
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
            If \hover
              DrawingMode(#PB_2DDrawing_AlphaBlend)
              ForEach \buttons()
                x = \canvasBox\x + \buttons()\box\x
                y = \canvasBox\y + \buttons()\box\y
                w = \buttons()\box\width
                h = \buttons()\box\height
                ; background for each item button
                Box(x, y, w, h, $FFFFFFFF)
                If \buttons()\callback And \buttons()\hover And \buttons()\imageHover
                  DrawImage(ImageID(\buttons()\imageHover), x, y, w, h)
                Else
                  DrawImage(ImageID(\buttons()\image), x, y, w, h)
                EndIf
              Next
            EndIf
            
            
            ; border
            DrawingMode(#PB_2DDrawing_Outlined)
            Box(\canvasBox\x, \canvasBox\y, \canvasBox\width, \canvasBox\height, ColorFromHTML(*this\theme\color\ItemBorder$))
          EndIf
        EndWith
      Next
      
      
      ; show text if no items is visible
      Protected visibleItems, text$
      visibleItems = 0
      ForEach *this\items()
        If Not *this\items()\hidden
          visibleItems + 1
        EndIf
      Next
      
      If ListSize(*this\items()) = 0
        ; list empty
        text$ = *this\textOnEmpty$
      ElseIf visibleItems = 0
        ; no item matches filter
        text$ = *this\textOnFilter$
      Else
        text$ = ""
      EndIf
      If text$
        FrontColor(RGBA($0, $0, $0, $FF))
        w = TextWidth(text$)
        h = TextHeight(text$)
        DrawingMode(#PB_2DDrawing_AlphaBlend|#PB_2DDrawing_Transparent)
        DrawingFont(GetGadgetFont(#PB_Default))
        DrawText((GadgetWidth(*this\gCanvas) - w)/2, (GadgetHeight(*this\gCanvas) - h)/2, text$)
      EndIf
      
      
      ; draw selectbox
      If ListSize(*this\items()) > 0
        If *this\selectbox\active = 2 ; only draw the box when already moved some pixels
          FrontColor(ColorFromHTML(*this\theme\color\SelectionBox$))
          DrawingMode(#PB_2DDrawing_AlphaBlend)
          Box(*this\selectbox\box\x, *this\selectbox\box\y - *this\scrollbar\position, *this\selectbox\box\width, *this\selectbox\box\height)
          DrawingMode(#PB_2DDrawing_Outlined)
          Box(*this\selectbox\box\x, *this\selectbox\box\y - *this\scrollbar\position, *this\selectbox\box\width, *this\selectbox\box\height)
        EndIf
      EndIf
      
      
      ; draw "x/N items visible" information in bottem right
      If *this\hover
        ; TODO only english, add more options here
        If visibleItems < ListSize(*this\items())
          text$ = "Showing "+visibleItems+"/"+ListSize(*this\items())+" items"
          DrawingMode(#PB_2DDrawing_AlphaBlend|#PB_2DDrawing_Transparent)
          DrawingFont(GetGadgetFont(#PB_Default))
          
          FrontColor(RGBA($80, $80, $80, $40))
          w = TextWidth(text$)
          h = TextHeight(text$)
          RoundBox(GadgetWidth(*this\gCanvas) - *this\theme\scrollbarWidth - margin - padding - w - padding,
                   GadgetHeight(*this\gCanvas) - margin - padding - h - padding,
                   w + 2*padding,
                   2*h, ; go out of canvas
                   h/2, h/2)
          FrontColor(RGBA(0, 0, 0, $80))
          DrawText(GadgetWidth(*this\gCanvas) - *this\theme\scrollbarWidth - margin - padding - w,
                   GadgetHeight(*this\gCanvas) - margin - padding - h,
                   text$)
        EndIf
      EndIf
      
            
      ; draw scrollbar
      If *this\hover And Not *this\scrollbar\disabled
        ; 2 px margin to outer gadget borders
        *this\scrollbar\box\x = GadgetWidth(*this\gCanvas) - *this\theme\scrollbarWidth - 2
        *this\scrollbar\box\y = *this\scrollbar\position * (GadgetHeight(*this\gCanvas)-4) / *this\scrollbar\maximum + 2 ; pagelength = gadgetheight!
        *this\scrollbar\box\width = *this\theme\scrollbarWidth
        *this\scrollbar\box\height = *this\scrollbar\pagelength * (GadgetHeight(*this\gCanvas)-4) / *this\scrollbar\maximum ; pagelength = gadgetheight!
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
      UnlockMutex(*this\mItems)
      
      
      If Redraw
        draw(*this)
      EndIf
      
      ProcedureReturn #False
    Else
      UnlockMutex(*this\mItems)
      Debug "[!] draw failure"
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure EventCanvas()
    Protected *this.gadget
    Protected *item.item
    Protected p.point
    Protected MyEvent
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
        LockMutex(*this\mItems)
        ForEach *this\items()
          *this\items()\hover = #False
        Next
        UnlockMutex(*this\mItems)
        draw(*this)
        
        
      Case #PB_EventType_LeftClick
        ; left click is same as down & up...
        
      Case #PB_EventType_LeftDoubleClick
        *this\selectbox\active = 0
        
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
            MyEvent = #PB_EventType_Change
            
            LockMutex(*this\mItems)
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
            UnlockMutex(*this\mItems)
            
          Else
            ; normal click
            LockMutex(*this\mItems)
            Protected btnClick.b = #False
            ; check if item button was clicked
            ForEach *this\items()
              If *this\items()\hover
                ForEach *this\items()\buttons()
                  If *this\items()\buttons()\hover
                    If *this\items()\buttons()\callback
                      *this\items()\buttons()\callback(*this\items())
                    EndIf
                    btnClick = #True
                    Break
                  EndIf
                Next
                Break
              EndIf
            Next
            ; if no item btn was clicked, select item and deselect all other items
            If Not btnClick
              MyEvent = #PB_EventType_Change
              ForEach *this\items()
                If *this\items()\hover
                  *this\items()\selected = #SelectionFinal
                Else
                  *this\items()\selected = #SelectionNone
                EndIf
              Next
            EndIf
            UnlockMutex(*this\mItems)
          EndIf
          
        ElseIf *this\selectbox\active = 2
          ; selectionbox finished
          MyEvent = #PB_EventType_Change
          
          ; also add the current element to the selected items
          LockMutex(*this\mItems)
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
          UnlockMutex(*this\mItems)
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
          
          LockMutex(*this\mItems)
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
          UnlockMutex(*this\mItems)
          
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
          LockMutex(*this\mItems)
          ForEach *this\items()
            *this\items()\hover = #False
          Next
          If Not *this\scrollbar\hover
            ; only hover items if not hover on scrollbar
            ForEach *this\items()
              *item = *this\items()
              If *item\hidden ; cannot hover on hidden items
                *item\hover = #False
                Continue
              EndIf
              If PointInBox(@p, *item\canvasBox)
                *item\hover = #True
                ForEach *this\items()\buttons()
                  Protected box.box
                  box\x = *item\canvasBox\x + *this\items()\buttons()\box\x
                  box\y = *item\canvasBox\y + *this\items()\buttons()\box\y
                  box\width = *this\items()\buttons()\box\width
                  box\height = *this\items()\buttons()\box\height
                  If PointInBox(@p, @box)
                    *this\items()\buttons()\hover = #True
                  Else
                    *this\items()\buttons()\hover = #False
                  EndIf
                Next
                Break ; can only hover on one item!
              EndIf
            Next
          EndIf
          UnlockMutex(*this\mItems)
          
          draw(*this)
        EndIf
        
        
      Case #PB_EventType_KeyUp
        Select GetGadgetAttribute(*this\gCanvas, #PB_Canvas_Key)
          Case #PB_Shortcut_A
            If GetGadgetAttribute(*this\gCanvas, #PB_Canvas_Modifiers) & #PB_Canvas_Control = #PB_Canvas_Control
              ; select all
              MyEvent = #PB_EventType_Change
              LockMutex(*this\mItems)
              ForEach *this\items()
                If Not *this\items()\hidden
                  *this\items()\selected | #SelectionFinal
                Else
                  *this\items()\selected = #SelectionNone
                EndIf
              Next
              UnlockMutex(*this\mItems)
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
          ; TODO instead of count selected, save "last selected item" in gadget data
          LockMutex(*this\mItems)
          ForEach *this\items()
            If *this\items()\selected & #SelectionFinal
              selectedItems + 1
              *item = *this\items()
            EndIf
          Next
          UnlockMutex(*this\mItems)
          
          
          If selectedItems = 1
            ; if one item selected, select next/previous item in list
            LockMutex(*this\mItems)
            ChangeCurrentElement(*this\items(), *item)
            If key = #PB_Shortcut_Up
              If ListIndex(*this\items()) > 0
                ; items can be hidden -> do not simply select previous/next item but test for next visible item
                ; old item: *item
                While PreviousElement(*this\items())
                  If Not *this\items()\hidden
                    ; item is visible. use this!
                    *this\items()\selected | #SelectionFinal
                    ; unselect "old" item
                    *item\selected & ~#SelectionFinal
                    ; schedule redraw and store new item for position test
                    redraw = #True
                    *item = *this\items()
                    Break
                  EndIf
                Wend
              EndIf
            ElseIf key = #PB_Shortcut_Down
              If ListIndex(*this\items()) < ListSize(*this\items())
                While NextElement(*this\items())
                  If Not *this\items()\hidden
                    *this\items()\selected | #SelectionFinal
                    *item\selected & ~#SelectionFinal
                    redraw = #True
                    *item = *this\items()
                    Break
                  EndIf
                Wend
              EndIf
            EndIf
            UnlockMutex(*this\mItems)
            
            If redraw ; item changed, redraw gadget
              MyEvent = #PB_EventType_Change
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
          
        ElseIf key = #PB_Shortcut_Home
          LockMutex(*this\mItems)
          ForEach *this\items()
            *this\items()\selected = #SelectionNone
          Next
          *item = FirstElement(*this\items())
          *item\selected | #SelectionFinal
          UnlockMutex(*this\mItems)
          *this\scrollbar\position = 0
          updateScrollbar(*this)
          updateItemPosition(*this)
          draw(*this)
          
        ElseIf key = #PB_Shortcut_End
          LockMutex(*this\mItems)
          ForEach *this\items()
            *this\items()\selected = #SelectionNone
          Next
          *item = LastElement(*this\items())
          *item\selected | #SelectionFinal
          UnlockMutex(*this\mItems)
          *this\scrollbar\position = *this\scrollbar\maximum
          updateScrollbar(*this)
          updateItemPosition(*this)
          draw(*this)
          
          
        EndIf
    EndSelect
    
    
    ; execute event binds
    Protected itemEvent
    LockMutex(*this\mItems)
    ForEach *this\itemEvents()
      ; look for bound "item events"
      If EventType() = *this\itemEvents()\event Or ; standard event
         (MyEvent And *this\itemEvents()\event = MyEvent) ; manual event triggered e.g. by selecting different item
        itemEvent = #False
        ForEach *this\items()
          ; check if the event happens while hovering over an item
          If *this\items()\hover
            *this\itemEvents()\callback(*this\items(), *this\itemEvents()\event)
            itemEvent = #True
            Break
          EndIf
        Next
        If Not itemEvent
          ; event not happend on item, call with item = 0
          *this\itemEvents()\callback(#Null, *this\itemEvents()\event)
        EndIf
      EndIf
    Next
    UnlockMutex(*this\mItems)
    
  EndProcedure
  
  ;- Public Gadget Functions
  
  Procedure NewCanvasListGadget(x, y, width, height, useExistingCanvas = -1)
    Protected *this.gadget
    *this = AllocateStructure(gadget)
    *this\vt = ?vt
    
    ; Mutex creation
    *this\mItems = CreateMutex()
    *this\mItemAddRemove = CreateMutex()
    
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
    
    *this\textOnEmpty$ = "The list is empty."
    *this\textOnFilter$ = "No item matches the current filter."
    
    ; window color
    Protected w
    w = OpenWindow(#PB_Any, 0, 0, 10, 10, "", #PB_Window_Invisible)
    *this\winColor = GetWindowBackgroundColor(WindowID(w))
    CloseWindow(w)
    
    ; set data pointer
    SetGadgetData(*this\gCanvas, *this)
    
    ; bind events on both gadgets
    BindGadgetEvent(*this\gCanvas, @EventCanvas(), #PB_All)
    
    ; initial draw
    draw(*this)
    ProcedureReturn *this
  EndProcedure
  
  Procedure Free(*this.gadget)
    LockMutex(*this\mItemAddRemove)
    LockMutex(*this\mItems)
    ForEach *this\items()
      ; free items!
      ; TODO free all item related memory
      
    Next
    ClearList(*this\items())
    UnlockMutex(*this\mItems)
    FreeMutex(*this\mItems)
    UnlockMutex(*this\mItemAddRemove)
    FreeMutex(*this\mItemAddRemove)
    
    FreeGadget(*this\gCanvas)
    FreeStructure(*this)
  EndProcedure
  
  Procedure Resize(*this.gadget, x, y, width, height)
    ResizeGadget(*this\gCanvas, x, y, width, height)
    
    ; TODO CHECK should cause resize callback
    ; not used in this project
;     updateScrollbar(*this)
;     updateItemPosition(*this)
;     draw(*this)
  EndProcedure
  
  Procedure Redraw(*this.gadget)
    updateScrollbar(*this)
    updateItemPosition(*this)
    draw(*this)
  EndProcedure
  
  Procedure AddItem(*this.gadget, text$, *userdata=#Null, position = -1)
    Protected *item.item
    LockMutex(*this\mItemAddRemove) ; do not create / destroy items in parallel to keep thread safe!
    LockMutex(*this\mItems) ; generic item access (as looping through items etc)
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
    
    ; add element to internal item list
    *item = AddElement(*this\items())
    UnlockMutex(*this\mItems)
    
    *item\vt = ?vtItem
    *item\parent = *this
    *item\text$ = text$
    *item\userdata = *userdata ; must store userdata before filter and sort
    
    ; if persistent filter is active, apply filter to new item
    If *this\filter\filterFun
      *item\hidden = Bool(Not *this\filter\filterFun(*item, *this\filter\options))
    EndIf
    
    ; with persistent sorting active, sort when new element is added
    If *this\pendingSort\persistent
      SortItems(*this, *this\pendingSort\mode, *this\pendingSort\sortFun, *this\pendingSort\options, *this\pendingSort\persistent)
    EndIf
    
    ; update gadget and redraw
    updateScrollbar(*this)
    updateItemPosition(*this)
    draw(*this)
    UnlockMutex(*this\mItemAddRemove)
    ProcedureReturn *item
  EndProcedure
  
  Procedure RemoveItem(*this.gadget, *item)
    LockMutex(*this\mItems)
    ChangeCurrentElement(*this\items(), *item) ; no error check, may cause IMA
    DeleteElement(*this\items(), 1)
    UnlockMutex(*this\mItems)
    
    Protected i, k ; each item removal potentially resets "tabAlign"
    For i = 0 To ArraySize(*this\theme\item\Lines())
      For k = 0 To ArraySize(*this\theme\item\Lines(i)\tabX())
        *this\theme\item\Lines(i)\tabX(k) = 0
      Next
    Next
    
    updateScrollbar(*this)
    updateItemPosition(*this)
    draw(*this)
  EndProcedure
  
  Procedure ClearItems(*this.gadget)
    LockMutex(*this\mItems)
    ClearList(*this\items())
    UnlockMutex(*this\mItems)
    
    Protected i, k ; reset "tabAlign"
    For i = 0 To ArraySize(*this\theme\item\Lines())
      For k = 0 To ArraySize(*this\theme\item\Lines(i)\tabX())
        *this\theme\item\Lines(i)\tabX(k) = 0
      Next
    Next
    
    updateScrollbar(*this)
    updateItemPosition(*this)
    draw(*this)
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
        If Not *this\pauseDraw ; when drawing is "unpaused", execute pending sort, calculate positions and scrollbar and redraw
          If *this\pendingSort\pending
            SortItems(*this, *this\pendingSort\mode, *this\pendingSort\sortFun, *this\pendingSort\options, *this\pendingSort\persistent)
          EndIf
          redraw(*this)
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
  
  Procedure SetSelectedItem(*this.gadget, *item.item)
    LockMutex(*this\mItems)
    ForEach *this\items()
      *this\items()\selected = #SelectionNone
      If *this\items() = *item
        *item\selected = #SelectionFinal
      EndIf
    Next
    UnlockMutex(*this\mItems)
    
    draw(*this)
  EndProcedure
  
  Procedure GetSelectedItem(*this.gadget)
    ; if multiple items are selected, only get first selected item
    Protected *item.item
    LockMutex(*this\mItems)
    ForEach *this\items()
      If *this\items()\selected & #SelectionFinal
        *item = *this\items()
        Break
      EndIf
    Next
    UnlockMutex(*this\mItems)
    ProcedureReturn *item
  EndProcedure
  
  Procedure GetAllSelectedItems(*this.gadget, List *items.item())
    Protected i
    LockMutex(*this\mItems)
    ; get number of selected items
    ClearList(*items())
    ForEach *this\items()
      If *this\items()\selected & #SelectionFinal
        AddElement(*items())
        *items() = *this\items()
        i + 1
      EndIf
    Next
    
    UnlockMutex(*this\mItems)
    If i > 0
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure GetAllVisibleItems(*this.gadget, List *items.item())
    Protected i
    LockMutex(*this\mItems)
    ClearList(*items())
    ForEach *this\items()
      If Not *this\items()\hidden
        AddElement(*items())
        *items() = *this\items()
        i + 1
      EndIf
    Next
    UnlockMutex(*this\mItems)
    ProcedureReturn Bool(i > 0)
  EndProcedure
  
  Procedure GetAllItems(*this.gadget, List *items.item())
    LockMutex(*this\mItems)
    ClearList(*items())
    If ListSize(*this\items())
      ForEach *this\items()
        AddElement(*items())
        *items() = *this\items()
      Next
    EndIf
    UnlockMutex(*this\mItems)
    ProcedureReturn ListSize(*items())
  EndProcedure
  
  Procedure GetItemCount(*this.gadget)
    Protected count
    LockMutex(*this\mItems)
    count = ListSize(*this\items())
    UnlockMutex(*this\mItems)
    ProcedureReturn count
  EndProcedure
  
  Procedure SetTheme(*this.gadget, theme$)
    Protected json, theme.theme, i
    json = ParseJSON(#PB_Any, theme$, #PB_JSON_NoCase)
    If json
      For i = 0 To ArraySize(*this\theme\item\Lines())
        If *this\theme\item\Lines(i)\FontID And IsFont(*this\theme\item\Lines(i)\FontID)
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
  
  Procedure SortItems(*this.gadget, mode, *sortFun=0, options=#PB_Sort_Ascending, persistent.b=#False)
    ; sort items
    
    ; always overwrite the internal "pendingSort" status information
    ; first: keep for "pending sort" if drawing is paused (speed up)
    ; second: keep for persistent sorting (automatically sort when adding new items)
    *this\pendingSort\mode = mode
    *this\pendingSort\sortFun = *sortFun
    *this\pendingSort\options = options
    *this\pendingSort\persistent = persistent
    
    If *this\pauseDraw
      ; if sort is not executed now, activate the pending sort
      *this\pendingSort\pending = #True
      ProcedureReturn #True
    Else
      *this\pendingSort\pending = #False
    EndIf
    
    Select mode
      Case #SortByText
        ; offset  = line to use for sorting the items (not yet working)
        LockMutex(*this\mItems)
        SortStructuredList(*this\items(), options, OffsetOf(item\text$), #PB_String)
        UnlockMutex(*this\mItems)
        
      Case #SortByUser
        ; offset  = compare function
        LockMutex(*this\mItems)
        Quicksort(*this\items(), options, *sortFun, 0, ListSize(*this\items())-1)
        UnlockMutex(*this\mItems)
        
      Default
        Debug "unknown sort mode"
        
    EndSelect
    
    updateItemPosition(*this)
    draw(*this)
  EndProcedure
  
  Procedure FilterItems(*this.gadget, filterFun.pFilter, options=0, persistent.b=#False)
    ; apply filterFun to all items in gadget and hide is filterFun returns false
    
    ; save persistent filter
    If persistent
      *this\filter\filterFun = filterFun
    Else
      *this\filter\filterFun = #Null
    EndIf
    
    ; apply filter for all items
    If filterFun
      LockMutex(*this\mItems)
      ForEach *this\items()
        *this\items()\hidden = Bool(Not filterFun(*this\items(), options))
      Next
      UnlockMutex(*this\mItems)
    EndIf
    
    updateScrollbar(*this)
    updateItemPosition(*this)
    draw(*this)
  EndProcedure
  
  Procedure BindItemEvent(*this.gadget, event, *callback)
    Protected *el.itemEvent
    *el = AddElement(*this\itemEvents())
    *el\event = event
    *el\callback = *callback
  EndProcedure
  
  Procedure SetEmptyScreen(*this.gadget, textOnEmpty$, textOnFilter$)
    *this\textOnEmpty$ = textOnEmpty$
    *this\textOnFilter$ = textOnFilter$
  EndProcedure
  
  ;- Public Item Functions
  
  Procedure ItemSetImage(*this.item, image)
    *this\image = image
    
    draw(*this\parent)
  EndProcedure
  
  Procedure ItemGetImage(*this.item)
    ProcedureReturn *this\image
  EndProcedure
  
  Procedure ItemSetUserData(*this.item, *data)
    *this\userdata = *data
  EndProcedure
  
  Procedure ItemGetUserData(*this.item)
    ProcedureReturn *this\userdata
  EndProcedure
  
  Procedure ItemSetSelected(*this.item, selected)
    If selected
      *this\selected | #SelectionFinal
    Else
      *this\selected = #SelectionNone
    EndIf
  EndProcedure
  
  Procedure ItemGetSelected(*this.item)
    ProcedureReturn Bool(*this\selected & #SelectionFinal)
  EndProcedure
  
  Procedure ItemHide(*this.item, hidden.b)
    *this\hidden = hidden
    
    updateScrollbar(*this\parent)
    updateItemPosition(*this\parent)
    draw(*this\parent)
  EndProcedure
  
  Procedure ItemIsHidden(*this.item)
    ProcedureReturn *this\hidden
  EndProcedure
  
  Procedure ItemAddIcon(*this.item, image, align=#AlignRight)
    ; todo use mutex just for item icons?
    ; must adjust mutex lock in "add", "clear", "draw", init mutex on item creation, free mutex on item deletion
    Protected *gadget.gadget
    Protected *icon.itemIcon
    If IsImage(image)
      *gadget.gadget = *this\parent
      LockMutex(*gadget\mItems)
      LastElement(*this\icons())
      *icon = AddElement(*this\icons())
      *icon\image = image
      *icon\align = align
      UnlockMutex(*gadget\mItems)
    Else
      deb("CanvasList:: image not valid")
    EndIf
  EndProcedure
  
  Procedure ItemClearIcons(*this.item)
    Protected *gadget.gadget
    Protected *icon.itemIcon
    *gadget.gadget = *this\parent
    LockMutex(*gadget\mItems)
    ClearList(*this\icons())
    UnlockMutex(*gadget\mItems)
  EndProcedure
  
  Procedure ItemAddButton(*this.item, *callback, image, imageHover=0)
    ; TODO mutex lock!
    If IsImage(image)
      AddElement(*this\buttons())
      *this\buttons()\image = image
      *this\buttons()\imageHover = imageHover
      *this\buttons()\callback = *callback
    EndIf
  EndProcedure
  
  Procedure ItemClearButtons(*this.item)
    ClearList(*this\buttons())
  EndProcedure
  
  
  
  
EndModule
