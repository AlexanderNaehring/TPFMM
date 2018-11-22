DeclareModule misc
  EnableExplicit
  
  ImportC ""
    time(*tloc = #Null)
  EndImport
  
  Macro timezone()
    ((Date() - misc::time())/3600)
  EndMacro
  
  Macro Min(a,b)
    (Bool((a)<=(b)) * (a) + Bool((b)<(a)) * (b))
  EndMacro
  Macro Max(a,b)
   (Bool((a)>=(b)) * (a) + Bool((b)>(a)) * (b))
  EndMacro
  
  Macro BinaryAsString(file, var)
    DataSection
      _str#MacroExpandedCount#Start:
      IncludeBinary file
      _str#MacroExpandedCount#End:
    EndDataSection
    var = PeekS(?_str#MacroExpandedCount#Start, ?_str#MacroExpandedCount#End - ?_str#MacroExpandedCount#Start-1, #PB_UTF8)
  EndMacro
  
  Macro IncludeAndLoadXML(xml, file)
    DataSection
      _xml#MacroExpandedCount#Start:
      IncludeBinary file
      _xml#MacroExpandedCount#End:
    EndDataSection
    
    xml = CatchXML(#PB_Any, ?_xml#MacroExpandedCount#Start, ?_xml#MacroExpandedCount#End - ?_xml#MacroExpandedCount#Start)
    If Not xml Or XMLStatus(xml) <> #PB_XML_Success
      DebuggerError("Could not open XML "+file+": "+XMLError(xml))
    EndIf
  EndMacro
  
  Macro openLink(link)
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        RunProgram(link)
      CompilerCase #PB_OS_Linux
        RunProgram("xdg-open", #DQUOTE$+link+#DQUOTE$, "")
      CompilerCase #PB_OS_MacOS
        RunProgram("open", link, "")
    CompilerEndSelect
  EndMacro
  
  Macro StopWindowUpdate(_winID_)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        SendMessage_(_winID_,#WM_SETREDRAW,0,0)
    CompilerEndIf
  EndMacro
  Macro ContinueWindowUpdate(_winID_, _redrawBackground_ = 0)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        SendMessage_(_winID_,#WM_SETREDRAW,1,0)
        InvalidateRect_(_winID_,0,_redrawBackground_)
        UpdateWindow_(_winID_)
    CompilerEndIf
  EndMacro
  
  Macro useBinary(file, overwrite)
    DataSection
      _bin#MacroExpandedCount#Start:
      IncludeBinary file
      _bin#MacroExpandedCount#End:
    EndDataSection
    
    misc::extractBinary(file, ?_bin#MacroExpandedCount#Start, ?_bin#MacroExpandedCount#End - ?_bin#MacroExpandedCount#Start, overwrite)
  EndMacro
  
  Declare.s path(path$, delimiter$ = "")
  Declare.s getDirectoryName(path$)
  Declare VersionCheck(current$, required$)
  Declare CreateDirectoryAll(dir$, delimiter$ = "")
  Declare extractBinary(filename$, *adress, len.i, overwrite = #True)
  Declare ResizeCenterImage(im, width, height, mode = #PB_Image_Smooth)
  Declare HexStrToMem(hex$, *memlen = 0)
  Declare.s MemToHexStr(*mem, memlen.i)
  Declare.s FileToHexStr(file$)
  Declare HexStrToFile(hex$, file$)
  Declare.s luaEscape(s$)
  Declare encodeTGA(image, file$, depth =24)
  Declare checkGameDirectory(Dir$, testmode=#False)
  Declare examineDirectoryRecusrive(root$, List files$(), path$="")
  Declare.s printSize(bytes.q)
  Declare.q getDirectorySize(path$)
  Declare SortStructuredPointerList(List *pointerlist(), options, offset, type, *compareFunction=0, low=0, high=-1)
  Declare.s getOSVersion()
  Declare.s getDefaultFontName()
  Declare getDefaultFontSize()
  Declare clearXMLchildren(*node)
  Declare registerProtocolHandler(protocol$, program$, description$="")
;   Declare time(*tloc = #Null)
  Declare getRowHeight(gadget)
  Declare getScrollbarWidth(gadget)
  Declare getDefaultRowHeight(type=#PB_GadgetType_ListView)
  Declare GetWindowBackgroundColor(hwnd=0)
EndDeclareModule

Module misc
 
  Procedure.s path(path$, delimiter$ = "")
    path$ + "/"                             ; add a / delimiter to the end
    path$ = ReplaceString(path$, "\", "/")  ; replace all \ with /
    While FindString(path$, "//")           ; strip multiple /
      path$ = ReplaceString(path$, "//", "/")
    Wend
    If delimiter$ = ""
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        delimiter$ = "\"
      CompilerElse
        delimiter$ = "/"
      CompilerEndIf
    EndIf
    If delimiter$ <> "/"
      path$ = ReplaceString(path$, "/", delimiter$)
    EndIf
    ProcedureReturn path$  
  EndProcedure
  
  Procedure CreateDirectoryAll(dir$, delimiter$ = "")
    Protected result, dir_sub$, dir_total$, count
    If delimiter$ = ""
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        delimiter$ = "\"
      CompilerElse
        delimiter$ = "/"
      CompilerEndIf
    EndIf
    
    dir$ = Path(dir$, delimiter$)
    
    If FileSize(dir$) = -2
      ProcedureReturn #True
    EndIf
    
    count = 1
    dir_sub$ = StringField(dir$, count, delimiter$) + delimiter$
    dir_total$ = dir_sub$
    
    While dir_sub$ <> ""
      If Not FileSize(dir_total$) = -2
        CreateDirectory(dir_total$)
      EndIf
      count + 1
      dir_sub$ = StringField(dir$, count, delimiter$)
      dir_total$ + dir_sub$ + delimiter$
    Wend
    
    
    If FileSize(dir$) = -2
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure.s getDirectoryName(path$)
    path$ = path(path$)
    path$ = Left(path$, Len(path$)-1)
    path$ = GetFilePart(path$)
    ProcedureReturn path$
  EndProcedure
  
  Procedure VersionCheck(current$, required$)
  If current$ >= required$
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
  EndProcedure
  
  Procedure extractBinary(filename$, *adress, len.i, overwrite = #True)
    Protected file.i, written.i
    If len <= 0
      ProcedureReturn #False
    EndIf
    If Not overwrite And FileSize(filename$) >= 0
      ProcedureReturn #False
    EndIf
    CreateDirectoryAll(GetPathPart(filename$))
    file = CreateFile(#PB_Any, filename$)
    If Not file
      ProcedureReturn #False
    EndIf
    written = WriteData(file, *adress, len)
    CloseFile(file)
    If written = len
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure ResizeCenterImage(im, width, height, mode = #PB_Image_Smooth)
    If im
      Protected image.i, factor_w.d, factor_h.d, factor.d, im_w.i, im_h.i
      im_w = ImageWidth(im)
      im_h = ImageHeight(im)
      factor_w = width / im_w
      factor_h = width / im_h
      factor = Min(factor_w, factor_h)
      im_w * factor
      im_h * factor
      
      ResizeImage(im, im_w, im_h, mode)
      
      image = CreateImage(#PB_Any, width, height, 32, #PB_Image_Transparent)
      If StartDrawing(ImageOutput(image))
        DrawingMode(#PB_2DDrawing_AlphaBlend)
        DrawAlphaImage(ImageID(im), (width - im_w)/2, (height - im_h)/2) ; center the image onto a new image
        StopDrawing()
      EndIf
      FreeImage(im)
      ProcedureReturn image
    EndIf
  EndProcedure
  
  Procedure HexStrToMem(hex$, *memlen = 0)
    Protected strlen.i, memlen.i, pos.i, *memory
    strlen = Len(hex$)
    If strlen % 2 = 1 Or strlen = 0
      ProcedureReturn #False
    EndIf
    memlen = strlen / 2
    *memory = AllocateMemory(memlen, #PB_Memory_NoClear)
    If Not *memory
      Debug "misc::HexStrToMem() - Error allocating memory"
      ProcedureReturn #False
    EndIf
    For pos = 0 To memlen-1
      PokeB(*memory+pos, Val("$"+Mid(hex$, 1+pos*2, 2)))
    Next pos
    If *memlen
      PokeI(*memlen, memlen)
    EndIf
    ProcedureReturn *memory
  EndProcedure
  
  Procedure.s MemToHexStr(*mem, memlen.i)
    Protected hex$ = ""
    Protected pos.i
    For pos = 0 To memlen-1
      hex$ + RSet(Hex(PeekB(*mem+pos), #PB_Byte), 2, "0")
    Next pos
    ProcedureReturn hex$
  EndProcedure
  
  Procedure.s FileToHexStr(file$)
    Protected hex$ = ""
    Protected file.i, *memory, size.i
    
    size = FileSize(file$)
    If size > 0
      *memory = AllocateMemory(FileSize(file$))
      If *memory
        file = ReadFile(#PB_Any, file$)
        If file
          ReadData(file, *memory, FileSize(file$))
          CloseFile(file)
          hex$ = MemToHexStr(*memory, size)
          FreeMemory(*memory)
          ProcedureReturn hex$
        EndIf
      EndIf
    EndIf
  EndProcedure
  
  Procedure HexStrToFile(hex$, file$)
    Protected file.i, *memory, memlen.i
    *memory = HexStrToMem(hex$, @memlen)
    file = CreateFile(#PB_Any, file$)
    If file
      WriteData(file, *memory, memlen)
      CloseFile(file)
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure.s luaEscape(s$)
    s$ = ReplaceString(s$, #DQUOTE$, "\"+#DQUOTE$)
    ProcedureReturn s$
  EndProcedure
  
  Procedure encodeTGA(image, file$, depth = 24)
    ; depth = 24 or 32
    Protected file.i, color.i, x.i, y.i
    
    If Not IsImage(image)
      ProcedureReturn #False
    EndIf
    
    If Not StartDrawing(ImageOutput(image))
      ProcedureReturn #False
    EndIf
    
    file = CreateFile(#PB_Any, file$)
    If Not file
      StopDrawing()
      ProcedureReturn #False
    EndIf
    
    If depth <> 24 And depth <> 32
      depth = 24
    EndIf
    
    ; 18 Bytes Header
    ; Field 1 (1 Byte) ID length
    WriteByte(file, 0)
    ; Field 2 (1 Byte) Color map type
    WriteByte(file, 0)
    ; Field 3 (1 Byte) Image Type
    WriteByte(file, 2) ; 2 = uncompressed true-color
    ; Field 4 (5 Bytes) Color Map
    WriteByte(file, 0)
    WriteByte(file, 0)
    WriteByte(file, 0)
    WriteByte(file, 0)
    WriteByte(file, 0) ; bits per pixel
    ; Field 6 (10 Bytes) Image specification
    WriteWord(file, 0) ; X-Origin (2 Byte)
    WriteWord(file, 0) ; X-Origin (2 Byte)
    WriteWord(file, ImageWidth(image))  ; Width (2 Byte)
    WriteWord(file, ImageHeight(image)) ; Height (2 Byte)
    WriteByte(file, depth)  ; Depth (1 Byte)
    WriteByte(file, 0)      ; Image descriptor (1 byte): bits 3-0 give the alpha channel depth, bits 5-4 give direction
                            ; 32 = flipped
    
    For y = ImageHeight(image) - 1 To 0 Step -1
      For x = 0 To ImageWidth(image) - 1
        color = Point(x, y)
        WriteByte(file, Blue(color))
        WriteByte(file, Green(color))
        WriteByte(file, Red(color))
        If depth = 32 ; Write Alpha Channel
          If ImageDepth(image) = 32
            WriteByte(file, 255-Alpha(color))
          Else
            WriteByte(file, 0)
          EndIf
        EndIf
      Next
    Next
    
    CloseFile(file)
    StopDrawing()
    ProcedureReturn #True
  EndProcedure
  
  Procedure checkGameDirectory(Dir$, testmode=#False)
    ; 0   = path okay, executable found and writing possible
    ; 1   = path okay, executable found but cannot write
    ; 2   = path not okay
    If Dir$
      If FileSize(Dir$) = -2
        Dir$ = Path(Dir$)
        If testmode
          ; in testmode, do not check if directory is correct
          ProcedureReturn 0
        EndIf
        If FileSize(Dir$ + "res") <> -2
          ; required diretories not found -> wrong path
          ProcedureReturn 2
        EndIf
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          If FileSize(Dir$ + "TransportFever.exe") > 1 Or FileSize(Dir$ + "TransportFeverLauncher.exe") > 1 Or FileSize(Dir$ + "TransportFever") > 1
            ; TrainFever.exe is located in this path!
            ; seems to be valid
            
            ; check if able to write to path
            If CreateFile(0, Dir$ + "TPFMM.tmp")
              CloseFile(0)
              DeleteFile(Dir$ + "TPFMM.tmp")
              ProcedureReturn 0
            EndIf
            ProcedureReturn 1
          EndIf
        CompilerElse
          If FileSize(Dir$ + "TransportFever") > 1
            If CreateFile(0, Dir$ + "TPFMM.tmp")
              CloseFile(0)
              DeleteFile(Dir$ + "TPFMM.tmp")
              ProcedureReturn 0
            EndIf
            ProcedureReturn 1
          EndIf
        CompilerEndIf
      EndIf
    EndIf
    ProcedureReturn 2
  EndProcedure
  
  Procedure examineDirectoryRecusrive(root$, List files$(), path$="")
    Protected dir, name$
    root$ = path(root$)
    path$ = path(path$)
    dir = ExamineDirectory(#PB_Any, path(root$ + path$), "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          AddElement(files$())
          files$() = path$ + DirectoryEntryName(dir)
        Else
          name$ = DirectoryEntryName(dir)
          If name$ = "." Or name$ = ".."
            Continue
          EndIf
          examineDirectoryRecusrive(root$, files$(), path(path$ + name$))
        EndIf
      Wend
      FinishDirectory(dir)
      ProcedureReturn #True
    Else
      Debug "could not examine"
    EndIf
    ProcedureReturn #False
  EndProcedure
    
  Procedure.s printSize(bytes.q)
    Protected k.q = 1024
    Protected M.q = k*1024
    Protected G.q = M*1024
    Protected T.q = G*1024
    
    If bytes > T
      ProcedureReturn StrD(bytes/T, 2)+" TIB"
    ElseIf bytes > G
      ProcedureReturn StrD(bytes/G, 2)+" GiB"
    ElseIf bytes > M
      ProcedureReturn StrD(bytes/M, 2)+" MiB"
    ElseIf bytes > k
      ProcedureReturn StrD(bytes/k, 2)+" kiB"
    Else
      ProcedureReturn Str(bytes)+" B"
    EndIf
    
  EndProcedure
  
  Procedure.q getDirectorySize(path$)
    Protected dir, size
    Protected name$
    
    path$ = path(path$)
    dir = ExamineDirectory(#PB_Any, path(path$), "")
    If dir
      While NextDirectoryEntry(dir)
        If DirectoryEntryType(dir) = #PB_DirectoryEntry_File
          size + FileSize(path$ + DirectoryEntryName(dir))
        Else
          name$ = DirectoryEntryName(dir)
          If name$ = "." Or name$ = ".."
            Continue
          EndIf
          size + getDirectorySize(path$ + name$)
        EndIf
      Wend
      FinishDirectory(dir)
      ProcedureReturn size
    Else
      Debug "could not examine"
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure compareIsGreater(*element1, *element2, options, offset, type)
    Protected doSwap = #False
    Protected *pointer1, *pointer2
    
    *pointer1 = PeekI(*element1) + offset
    *pointer2 = PeekI(*element2) + offset
          
    Select type
      Case #PB_Byte
        doSwap = Bool(PeekB(*pointer1) > PeekB(*pointer2))
      Case #PB_Word
        doSwap = Bool(PeekW(*pointer1) > PeekW(*pointer2))
      Case #PB_Long
        doSwap = Bool(PeekL(*pointer1) > PeekL(*pointer2))
      Case #PB_String
        If options & #PB_Sort_NoCase
          doSwap = Bool(CompareMemoryString(PeekI(*pointer1), PeekI(*pointer2), #PB_String_NoCase) = #PB_String_Greater)
        Else
          doSwap = Bool(CompareMemoryString(PeekI(*pointer1), PeekI(*pointer2), #PB_String_CaseSensitive) = #PB_String_Greater)
        EndIf
        If doSwap
        EndIf
      Case #PB_Float
        doSwap = Bool(PeekF(*pointer1) > PeekF(*pointer2))
      Case #PB_Double
        doSwap = Bool(PeekD(*pointer1) > PeekD(*pointer2))
      Case #PB_Quad
        doSwap = Bool(PeekQ(*pointer1) > PeekQ(*pointer2))
      Case #PB_Character
        doSwap = Bool(PeekC(*pointer1) > PeekC(*pointer2))
      Case #PB_Integer
        doSwap = Bool(PeekI(*pointer1) > PeekI(*pointer2))
      Case #PB_Ascii
        doSwap = Bool(PeekA(*pointer1) > PeekA(*pointer2))
      Case #PB_Unicode
        doSwap = Bool(PeekU(*pointer1) > PeekU(*pointer2))
      Default
        DebuggerError("Sort Type not known")
    EndSelect
    If options & #PB_Sort_Descending
      doSwap = Bool(Not doSwap)
    EndIf
    ProcedureReturn doSwap
  EndProcedure
  
  Prototype.i compare(*element1, *element2, options, offset, type)
  
  Procedure SortStructuredPointerList_Quicksort(List *pointerlist(), options, offset, type, *compare, low, high, level=0)
    Protected *midElement, *highElement, *iElement, *wallElement
    Protected wall, i, sw
    Protected comp.compare
    
    If high - low < 1
      ProcedureReturn
    EndIf
    
    ; use user function or simpler compare by offset function
    If *compare
      comp = *compare
    Else
      comp = @compareIsGreater()
    EndIf
    
    ; swap mid element and high element to avoid bad performance with already sorted list
    *midElement = SelectElement(*pointerlist(), low + (high-low)/2)
    *highElement = SelectElement(*pointerlist(), high)
    SwapElements(*pointerlist(), *midElement, *highElement)
    
    ; find split point for array
    wall = low
    *highElement = SelectElement(*pointerlist(), high)
    For i = low To high -1
      *iElement = SelectElement(*pointerlist(), i)
      If comp(*highElement, *iElement, options, offset, type)
        *wallElement = SelectElement(*pointerlist(), wall)
        SwapElements(*pointerlist(), *iElement, *wallElement)
        wall +1
      EndIf
    Next
    
    ; place last (high) value between the two splits
    
    *wallElement = SelectElement(*pointerlist(), wall)
    *highElement = SelectElement(*pointerlist(), high)
    SwapElements(*pointerlist(), *wallElement, *highElement)
    
    ; sort below wall
    SortStructuredPointerList_Quicksort(*pointerlist(), options, offset, type, *compare, low, wall-1, level+1)
    
    ; sort above wall
    SortStructuredPointerList_Quicksort(*pointerlist(), options, offset, type, *compare, wall+1, high, level+1)
    
  EndProcedure
  
  Procedure SortStructuredPointerList(List *pointerlist(), options, offset, type, *compare=0, low=0, high=-1)
    ; options = #PB_Sort_Ascending = 0 (default) | #PB_Sort_Descending = 1 | #PB_Sort_NoCase = 2
    
    If high = -1
      high = ListSize(*pointerlist()) -1
    EndIf
    ProcedureReturn SortStructuredPointerList_Quicksort(*pointerlist(), options, offset, type, *compare, low, high)
    
  EndProcedure
  
  Procedure.s getOSVersion()
    Protected os$
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        Select OSVersion()
          Case #PB_OS_Windows_XP
            os$ = "Windows XP"
          Case #PB_OS_Windows_Server_2003
            os$ = "Windows Server 2003"
          Case #PB_OS_Windows_Vista
            os$ = "Windows Vista"
          Case #PB_OS_Windows_Server_2008
            os$ = "Windows Server 2008"
          Case #PB_OS_Windows_7
            os$ = "Windows 7"
          Case #PB_OS_Windows_Server_2008_R2
            os$ = "Windows Server 2008 R2"
          Case #PB_OS_Windows_8
            os$ = "Windows 8"
          Case #PB_OS_Windows_Server_2012
            os$ = "Windows Server 2012"
          Case #PB_OS_Windows_8_1
            os$ = "Windows 8.1"
          Case #PB_OS_Windows_Server_2012_R2
            os$ = "Windows Server 2012 R2"
          Case #PB_OS_Windows_10
            os$ = "Windows 10"
          Default 
            os$ = "Windows"
        EndSelect
      CompilerCase #PB_OS_Linux
        Select OSVersion()
          Case #PB_OS_Linux_2_2
            os$ = "Linux 2.2"
          Case #PB_OS_Linux_2_4
            os$ = "Linux 2.4"
          Case #PB_OS_Linux_2_6
            os$ = "Linux 2.6"
          Default
            os$ = "Linux"
        EndSelect
      CompilerCase #PB_OS_MacOS
        Select OSVersion()
          Default 
            os$ = "Mac OSX"
        EndSelect
    CompilerEndSelect
    ProcedureReturn os$
  EndProcedure
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    #G_TYPE_STRING = 64
    
    ImportC ""
      g_object_get_property(*widget.GtkWidget, property.p-utf8, *gval)
    EndImport
  CompilerEndIf
  
  Procedure.S getDefaultFontName()
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
        Debug "'"+font$+"'"
        
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
  
  Procedure clearXMLchildren(*node)
    Protected *child
    *child = ChildXMLNode(*node)
    While *child
      DeleteXMLNode(*child)
      *child = ChildXMLNode(*node)
    Wend
  EndProcedure
  
  Procedure getRowHeight(gadget)
    ; ListIconGadget get/set row height: http://www.purebasic.fr/english/viewtopic.php?f=13&t=54533&start=7
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
      
        If GadgetType(gadget) = #PB_GadgetType_ListView
          ProcedureReturn SendMessage_(GadgetID(gadget), #LB_GETITEMHEIGHT, 0, 0)
          
        ElseIf GadgetType(gadget) = #PB_GadgetType_ListIcon
          Protected rectangle.RECT
          rectangle\left = #LVIR_BOUNDS
          SendMessage_(GadgetID(gadget), #LVM_GETITEMRECT, 0, rectangle)
          ProcedureReturn rectangle\bottom - rectangle\top - 1
          
        EndIf
        
        
      CompilerCase #PB_OS_Linux
        Protected height, yOffset
        Protected *tree, *tree_column
        If GadgetType(gadget) = #PB_GadgetType_ListIcon Or
           GadgetType(gadget) = #PB_GadgetType_ListView
          
          *tree = GadgetID(gadget)
          
          ; https://developer.gnome.org/gtk3/stable/GtkTreeView.html#gtk-tree-view-get-column
          *tree_column = gtk_tree_view_get_column_(*tree, 0)
          
          ; https://developer.gnome.org/gtk3/stable/GtkTreeViewColumn.html#gtk-tree-view-column-cell-get-size
          gtk_tree_view_column_cell_get_size_(*tree_column, #Null, #Null, @yOffset, #Null, @height)
          
          ProcedureReturn height
        EndIf
    CompilerEndSelect
  EndProcedure
  
  Procedure getDefaultRowHeight(type=#PB_GadgetType_ListView)
    Static heightLV, heightLI
    Protected window, gadgetLV, gadgetLI
    
    If Not heightLV Or Not heightLI
      window = OpenWindow(#PB_Any, 0, 0, 100, 100, "", #PB_Window_Invisible)
      If window
        gadgetLV = ListViewGadget(#PB_Any, 0, 0, 50, 100)
        gadgetLI = ListIconGadget(#PB_Any, 50, 0, 50, 100, "test", 80)
        AddGadgetItem(gadgetLV, -1, "test")
        AddGadgetItem(gadgetLI, -1, "test")
        
        heightLV = getRowHeight(gadgetLV)
        heightLI = getRowHeight(gadgetLI)
        CloseWindow(window)
      EndIf
    EndIf
    
    If type = #PB_GadgetType_ListView
      ProcedureReturn heightLV
    ElseIf type = #PB_GadgetType_ListIcon
      ProcedureReturn heightLI
    EndIf
    
  EndProcedure
  
  Procedure getScrollbarWidth(gadget)
    Protected oldWidth, oldHeight, oldScrollX, oldScrollY, viewWidth, scrollbarWidth
    oldWidth  = GetGadgetAttribute(gadget, #PB_ScrollArea_InnerWidth)
    oldHeight = GetGadgetAttribute(gadget, #PB_ScrollArea_InnerHeight)
    oldScrollX = GetGadgetAttribute(gadget, #PB_ScrollArea_X)
    oldScrollY = GetGadgetAttribute(gadget, #PB_ScrollArea_Y)
    ; enlarge inner size to force scrollbars
    SetGadgetAttribute(gadget, #PB_ScrollArea_InnerWidth, oldWidth + GadgetWidth(gadget))
    SetGadgetAttribute(gadget, #PB_ScrollArea_InnerHeight, oldHeight + GadgetHeight(gadget))
    ; move scroll location to far end
    SetGadgetAttribute(gadget, #PB_ScrollArea_X, GetGadgetAttribute(gadget, #PB_ScrollArea_InnerWidth))
    ; get scroll position and innerWidth to calculate viewport width
    viewWidth = GetGadgetAttribute(gadget,#PB_ScrollArea_InnerWidth) - GetGadgetAttribute(gadget,#PB_ScrollArea_X)
    scrollbarWidth = GadgetWidth(gadget, #PB_Gadget_ActualSize) - viewWidth
    ; return to old state
    SetGadgetAttribute(gadget, #PB_ScrollArea_InnerWidth, oldWidth)
    SetGadgetAttribute(gadget, #PB_ScrollArea_InnerHeight, oldHeight)
    SetGadgetAttribute(gadget, #PB_ScrollArea_X, oldScrollX)
    SetGadgetAttribute(gadget, #PB_ScrollArea_Y, oldScrollY)
    
    ProcedureReturn scrollbarWidth
  EndProcedure
  
  Procedure registerProtocolHandler(protocol$, program$, description$="")
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        ; Windows: Protocol Handlers are registered in the registry under HKEY_CURRENT_USER\Software\Classes (not HKEY_CLASSES_ROOT)
        ; HKEY_CURRENT_USER\Software\Classes
        ;   tpfmm
        ;     (Default) = "Description"
        ;     URL Protocol = ""
        ;     DefaultIcon
        ;       (Default) = "alert.exe,1"
        ;     shell
        ;       open
        ;         command
        ;           (Default) = "TPFMM.exe" "%1"
        
        Protected regFile$, string$, file, program, exitcode
        
        regFile$ = "register.reg"
        
        
        If program$
          string$ = "Windows Registry Editor Version 5.00" + #CRLF$ +
                    #CRLF$ +
                    "[HKEY_CURRENT_USER\Software\Classes\"+protocol$+"]" + #CRLF$ +
                    "@="+#DQUOTE$+"URL:"+description$+#DQUOTE$ + #CRLF$ +
                    #DQUOTE$+"URL Protocol"+#DQUOTE$+"="+#DQUOTE$+#DQUOTE$ + #CRLF$ +
                    #DQUOTE$+"DefaultIcon"+#DQUOTE$+"="+#DQUOTE$+"\"+#DQUOTE$+ReplaceString(program$, "\", "\\")+"\"+#DQUOTE$+",1"+#DQUOTE$ + #CRLF$ + 
                    #CRLF$ +
                    "[HKEY_CURRENT_USER\Software\Classes\"+protocol$+"\shell]" + #CRLF$ +
                    #CRLF$ +
                    "[HKEY_CURRENT_USER\Software\Classes\"+protocol$+"\shell\open]" + #CRLF$ +
                    #CRLF$ +
                    "[HKEY_CURRENT_USER\Software\Classes\"+protocol$+"\shell\open\command]"+ #CRLF$ +
                    "@="+#DQUOTE$+"\"+#DQUOTE$+ReplaceString(program$, "\", "\\")+"\"+#DQUOTE$+" \"+#DQUOTE$+"%1\"+#DQUOTE$+#DQUOTE$ + #CRLF$
          
        Else
          ; unregister
          string$ = "Windows Registry Editor Version 5.00" + #CRLF$ +
                    #CRLF$ +
                    "[-HKEY_CURRENT_USER\Software\Classes\"+protocol$+"]" + #CRLF$
          
        EndIf
        
        
        file = CreateFile(#PB_Any, regFile$, #PB_UTF8)
        If file
          WriteString(file, string$)
          CloseFile(file)
          
          program = RunProgram("reg", "import "+regFile$, GetCurrentDirectory(), #PB_Program_Open|#PB_Program_Wait|#PB_Program_Hide)
          exitcode = ProgramExitCode(program)
          CloseProgram(program)
          
          DeleteFile(regFile$)
          
          If exitcode = 0
            ProcedureReturn #True
          Else
            ProcedureReturn #False
          EndIf
        Else
          ProcedureReturn #False
        EndIf
        
      CompilerCase #PB_OS_Linux
        ; Linux: use XDG with x-scheme-handler
        ; create a tpfmm.desktop file and install using "xdg-desktop-menu install tpfmm.desktop"
        ; or place manually in "~/.local/share/applications" and run "sudo update-desktop-database"
        ;
        ; [Desktop Entry]
        ; Name=TPFMM
        ; Exec=/path/to/tpfmm %u
        ; Icon=/path/to/icon
        ; Type=Application
        ; Terminal=false
        ; MimeType=x-scheme-handler/tpfmm;
        ;
        ; It may be required to open ~/.local/share/applications/mimeapps.list and add a line unter [Default Applications]
        ; x-scheme-handler/tpfmm=tpfmm.desktop
        
      CompilerDefault
        CompilerError "No protocol handler registration defined for this OS"
    CompilerEndSelect
  EndProcedure
  
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
        If Not hwnd
          DebuggerError("hwnd must be specified")
        EndIf
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
  
EndModule
