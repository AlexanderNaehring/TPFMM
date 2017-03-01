XIncludeFile "module_debugger.pbi"
XIncludeFile "module_main.pbi"

DeclareModule misc
  EnableExplicit
  
  Macro Min(a,b)
    (Bool((a)<=(b)) * (a) + Bool((b)<(a)) * (b))
  EndMacro
  Macro Max(a,b)
   (Bool((a)>=(b)) * (a) + Bool((b)>(a)) * (b))
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
  
  Declare.s path(path$, delimiter$ = "")
  Declare.s getDirectoryName(path$)
  Declare.s bytes(bytes.d)
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
  Declare checkGameDirectory(Dir$)
  Declare examineDirectoryRecusrive(root$, List files$(), path$="")
  Declare SortStructuredPointerList(List *pointerlist(), options, offset, type, low=0, high=-1)
  Declare.s getOSVersion()
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
        debugger::Add("misc::CreateDirectory("+dir_total$+")")
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
  
  Procedure.s Bytes(bytes.d)
    If bytes > 1024*1024*1024
      ProcedureReturn StrD(bytes/1024/1024/1024,2) + " GiB"
    ElseIf bytes > 1024*1024
      ProcedureReturn StrD(bytes/1024/1024,2) + " MiB"
    ElseIf bytes > 1024
      ProcedureReturn StrD(bytes/1024,0) + " KiB"
    ElseIf bytes > 0
      ProcedureReturn StrD(bytes,0) + " Byte"
    Else
      ProcedureReturn ""
    EndIf
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
    If IsImage(im)
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
    debugger::Add("misc::HexStrToMem("+hex$+")")
    Protected strlen.i, memlen.i, pos.i, *memory
    strlen = Len(hex$)
    If strlen % 2 = 1 Or strlen = 0
      ProcedureReturn #False
    EndIf
    memlen = strlen / 2
    *memory = AllocateMemory(memlen, #PB_Memory_NoClear)
    If Not *memory
      debugger::Add("misc::HexStrToMem() - Error allocating memory")
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
    debugger::Add("misc::MemToHexStr("+Str(*mem)+", "+Str(memlen)+")")
    Protected hex$ = ""
    Protected pos.i
    For pos = 0 To memlen-1
      hex$ + RSet(Hex(PeekB(*mem+pos), #PB_Byte), 2, "0")
    Next pos
    ProcedureReturn hex$
  EndProcedure
  
  Procedure.s FileToHexStr(file$)
    debugger::Add("misc::FileToHexStr("+file$+")")
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
    debugger::Add("misc::HexStrToFile("+hex$+")")
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
      debugger::Add("misc::encodeTGA() - ERROR - image {"+Str(image)+"} is no valid image")
      ProcedureReturn #False
    EndIf
    
    If Not StartDrawing(ImageOutput(image))
      debugger::Add("misc::encodeTGA() - ERROR - drawing on image failed")
      ProcedureReturn #False
    EndIf
    
    file = CreateFile(#PB_Any, file$)
    If Not file
      debugger::Add("misc::encodeTGA() - ERROR - failed to create {"+file$+"}")
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
  
  Procedure checkGameDirectory(Dir$)
    ; 0   = path okay, executable found and writing possible
    ; 1   = path okay, executable found but cannot write
    ; 2   = path not okay
    If Dir$
      If FileSize(Dir$) = -2
        Dir$ = Path(Dir$)
        If main::_TESTMODE
          ; in testmode, do not check if directory is correct
          ProcedureReturn 0
        EndIf
        If FileSize(Dir$ + "res") <> -2
          ; required diretories not found -> wrong path
          ProcedureReturn 2
        EndIf
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          If FileSize(Dir$ + "TransportFever.exe") > 1 Or FileSize(Dir$ + "TransportFeverLauncher.exe") > 1
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
      debugger::Add("          ERROR: could not examine directory "+path(root$ + path$))
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
  
  Procedure SortStructuredPointerList_Quicksort(List *pointerlist(), options, offset, type, low, high, level=0)
    Protected *midElement, *highElement, *iElement, *wallElement
    Protected wall, i
    
    If high - low < 1
      ProcedureReturn
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
      If compareIsGreater(*highElement, *iElement, options, offset, type)
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
    SortStructuredPointerList_Quicksort(*pointerlist(), options, offset, type, low, wall-1, level+1)
    
    ; sort above wall
    SortStructuredPointerList_Quicksort(*pointerlist(), options, offset, type, wall+1, high, level+1)
    
  EndProcedure
  
  Procedure SortStructuredPointerList_SimpleSort(List *pointerlist(), options, offset, type)
    Protected finished, doSwap
    Protected *currentListElement, *pointer1, *pointer2
    Protected val1, val2, str1$, str2$
    
    Repeat
      finished = #True
      ForEach *pointerlist()
        *currentListElement = @*pointerlist()
        While NextElement(*pointerlist())
          ;compare the current element with others in the list and swap if required
          
          If compareIsGreater(*currentListElement, @*pointerlist(), options, offset, type)
            SwapElements(*pointerList(), *currentListElement, @*pointerlist())
            finished = #False
          EndIf
        Wend
        ChangeCurrentElement(*pointerlist(), *currentListElement)
      Next
    Until finished
    ProcedureReturn #True
  EndProcedure
  
  Procedure SortStructuredPointerList(List *pointerlist(), options, offset, type, low=0, high=-1)
    ; options = #PB_Sort_Ascending = 0 (default) | #PB_Sort_Descending = 1 | #PB_Sort_NoCase = 2
    
;     ; simple sorting algorithm for small lists?
;     If #False
;       ProcedureReturn SortStructuredPointerList_SimpleSort(*pointerlist(), options, offset, type)
;     EndIf
    
    If high = -1
      high = ListSize(*pointerlist()) -1
    EndIf
    ProcedureReturn SortStructuredPointerList_Quicksort(*pointerlist(), options, offset, type, low, high)
    
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
  
EndModule