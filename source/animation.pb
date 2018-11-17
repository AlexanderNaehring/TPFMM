DeclareModule animation
  EnableExplicit
  
  ; use simple image sequences for animation on a canvas gadget
  ; 2018, Alexander Nähring
  
  ;- interface
  Interface animation
    free(timeout=1000)
    draw(frame.l=-1)
    
    loadImageSequence(filePattern$) ; format e.g. "image-%03d.png" for sequence image-000.png, image-001.png, image-002.png ...
    loadAni(aniFile$)
    play()
    pause()
    
    setCanvas(canvas)
    setInterval(interval)
    setReverse(reverse.b)
    setBackgroundColor(color.l)
    
    getCanvas()
    getInterval()
    getReverse.b()
    getBackgroundColor.l()
    getFrameCount.u()
    isPaused.b()
  EndInterface
  
  ;- static
  Declare new()
  
  Declare packFileSequenceToAni(filePattern$, aniFile$)
  
  ;- methods
  Declare free(*ani.animation, timeout=1000)
  Declare draw(*ani.animation, frame.l=-1)
  
  Declare loadImageSequence(*ani.animation, filePattern$)
  Declare loadAni(*ani.animation, aniFile$)
  Declare play(*ani.animation)
  Declare pause(*ani.animation)
  
  Declare setCanvas(*ani.animation, canvas)
  Declare setInterval(*ani.animation, interval)
  Declare setReverse(*ani.animation, reverse.b)
  Declare setBackgroundColor(*ani.animation, color.l)
  
  Declare getCanvas(*ani.animation)
  Declare getInterval(*ani.animation)
  Declare.b getReverse(*ani.animation)
  Declare.l getBackgroundColor(*ani.animation)
  Declare.u getFrameCount(*ani.animation)
  Declare.b isPaused(*ani.animation)
  
  
EndDeclareModule

Module animation
  
  ;{ VT
  DataSection
    vt:
    Data.i @free()
    Data.i @draw()
    Data.i @loadImageSequence()
    Data.i @loadAni()
    Data.i @play()
    Data.i @pause()
    
    Data.i @setCanvas()
    Data.i @setInterval()
    Data.i @setReverse()
    Data.i @setBackgroundColor()
    
    Data.i @getCanvas()
    Data.i @getInterval()
    Data.i @getReverse()
    Data.i @getBackgroundColor()
    Data.i @getFrameCount()
    Data.i @isPaused()
  EndDataSection
  ;}
  
  ;{ struct
  Structure ani
    *vt.animation
    
    canvas.i
    Array frames.i(1)
    frame.l
    background.l
    interval.d
    thread.i
    playing.b
    reverse.b
    exit.b
  EndStructure
  ;}
  
  ;{ required codecs
  ; *.ani files are PNG images in a TAR archive
  UsePNGImageDecoder()
  UsePNGImageEncoder()
  UseTARPacker()
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
  
  ;- private
  
  Procedure freeImages(*this.ani)
    Protected i
    For i = 0 To ArraySize(*this\frames())
      If *this\frames(i)
        FreeImage(*this\frames(i))
        *this\frames(i) = #Null
      EndIf
    Next
    ReDim *this\frames(0) ; single element left (cannot create empty array)
    *this\frame = 0
  EndProcedure
  
  Procedure freeAll(*this.ani)
    freeImages(*this)
    FreeStructure(*this)
  EndProcedure
  
  
  Procedure aniThread(*this.ani)
    Repeat
      If *this\playing
        draw(*this)
        
        ; select next frame
        If *this\reverse
          *this\frame - 1
          If *this\frame < 0
            *this\frame = ArraySize(*this\frames())
          EndIf
        Else
          *this\frame + 1
          If *this\frame > ArraySize(*this\frames())
            *this\frame = 0
          EndIf
        EndIf
    
        Delay(*this\interval)
      Else ; paused
        Delay(1)
      EndIf
    Until *this\exit
    
  EndProcedure
  
  Procedure getImageSequenceFiles(filePattern$, List files$())
    Protected regexp
    Protected pos, len, digits, leadingZero,
              beforeNum$, afterNum$, num$, file$,
              i, first, last, numImages, exit
    
    ClearList(files$())
    
    ; find the number in the filePattern, e.g. image-%03d.png <- the %03d must be replaced by the number with 3 digits and leading zero
    ; for sprintf formatting, see also https://www.purebasic.fr/english/viewtopic.php?t=32026
    regexp = CreateRegularExpression(#PB_Any, "%([0-9]*)d")
    If regexp
      If ExamineRegularExpression(regexp, filePattern$)
        If NextRegularExpressionMatch(regexp)
          pos = RegularExpressionMatchPosition(regexp)
          len = RegularExpressionMatchLength(regexp)
          digits = Val(RegularExpressionGroup(regexp, 1))
          leadingZero = Bool(Left(RegularExpressionGroup(regexp, 1), 1) = "0")
          
          beforeNum$ = Left(filePattern$, pos-1)
          afterNum$  = Mid(filePattern$, pos+len)
        EndIf
      EndIf
    Else
      deb("animation:: "+RegularExpressionError())
    EndIf
    FreeRegularExpression(regexp)
    
    ; check start and end number
    i = 0
    first = -1
    last  = -1
    Repeat
      ; get filename
      num$ = Str(i)
      If Len(num$) < digits
        If leadingZero : num$ = RSet(num$, digits, "0") : Else : num$ = RSet(num$, digits) : EndIf
      EndIf
      file$ = beforeNum$+num$+afterNum$
      
      ; check if file exists
      If first = -1
        ; search for first existsing file
        If FileSize(file$) > 0
          AddElement(files$())
          files$() = file$
          first = i
        Else
          ; file not found
          If i > 100
            deb("animation:: could not find a file matching "+filePattern$+" up to number "+i)
            exit = #True
          EndIf
        EndIf
      Else
        ; search for forst non-existing file
        
        If FileSize(file$) > 0
          AddElement(files$())
          files$() = file$
        Else
          last = i-1
          exit = #True
        EndIf
      EndIf
      
      i + 1
    Until exit
    
    If first <> -1 And last <> -1
      numImages = last - first + 1
      deb("animation:: image sequence "+#DQUOTE$+filePattern$+#DQUOTE$+" has "+numImages+" images: ["+first+" - "+last+"]")
    EndIf
    
    If numImages <> ListSize(files$())
      DebuggerError("numImage missmatch")
    EndIf
    
  EndProcedure
  
  Procedure stringIsInteger(string$)
    Static regexp
    
    If Not regexp
      regexp = CreateRegularExpression(#PB_Any, "^[0-9]+$")
    EndIf
    
    If regexp
      ProcedureReturn MatchRegularExpression(regexp, string$)
    Else
      ProcedureReturn #False 
    EndIf
  EndProcedure
  
  
  ;- public functions
  
  Procedure new()
    Protected *this.ani = AllocateStructure(ani)
    *this\vt = ?vt
    *this\background = $00FFFFFF ; transparent white
    ProcedureReturn *this
  EndProcedure
  
  Procedure packFileSequenceToAni(filePattern$, aniFile$)
    Protected NewList files$()
    Protected pack, i, n, im, *buffer
    Protected time = ElapsedMilliseconds()
    Protected numFiles.u
    
    If LCase(GetExtensionPart(aniFile$)) <> "ani"
      aniFile$ + ".ani"
    EndIf
    
    getImageSequenceFiles(filePattern$, files$())
    
    numFiles = ListSize(files$())
    If numFiles > 0
      ; create a new pack (archive) and add all files
      ; files are numbered from 0 to N (filename = number) in PNG format
      pack = CreatePack(#PB_Any, aniFile$, #PB_PackerPlugin_Tar, 9)
      If pack
        i = 0
        AddPackMemory(pack, @numFiles, SizeOf(numFiles), "numFiles")
        ForEach files$()
          im = LoadImage(#PB_Any, files$())
          If im
            *buffer = EncodeImage(im, #PB_ImagePlugin_PNG)
            If *buffer
              If AddPackMemory(pack, *buffer, MemorySize(*buffer), Str(i))
                n + 1
              EndIf
              FreeMemory(*buffer)
            Else
              deb("animation:: could not encode image "+files$())
            EndIf
            FreeImage(im)
          Else
            deb("animation:: could not load image "+files$())
          EndIf
          i + 1
          
;           Debug "pack ani file: "+Str(i*100/numFiles)+"%"
        Next
        ClosePack(pack)
      Else
        deb("animation:: could not create ani file "+aniFile$)
      EndIf
      deb("animation:: packed ani file in "+Str(ElapsedMilliseconds()-time)+" ms, filesize = "+StrD(FileSize(aniFile$)/1000/1000, 2)+" MB")
      ProcedureReturn n
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  ;- public methods
  
  Procedure free(*this.ani, timeout=1000)
    *this\playing = #False
    *this\exit = #True
    If *this\thread
      WaitThread(*this\thread, timeout)
      If IsThread(*this\thread)
        deb("animation:: WARNING: killing animation thread now!")
        ; thread did not finish!
        KillThread(*this\thread)
      EndIf
    EndIf
    freeAll(*this)
    ProcedureReturn #True
  EndProcedure
  
  Procedure draw(*this.ani, frame.l=-1)
    If frame <> -1
      *this\frame = frame
    EndIf
    
    If *this\frame < 0
      *this\frame = 0
    ElseIf *this\frame > ArraySize(*this\frames())
      *this\frame = ArraySize(*this\frames())
    EndIf
    
    If *this\canvas
      If StartDrawing(CanvasOutput(*this\canvas))
        If *this\frames(*this\frame)
          ; clear canvas
          ; DrawingMode(#PB_2DDrawing_AllChannels)
          ; Box(0, 0, ImageWidth(*this\frames(*this\frame)), ImageHeight(*this\frames(*this\frame)), $00FFFFFF) ; white and transparent
          ; draw background
          DrawingMode(#PB_2DDrawing_AllChannels)
          Box(0, 0,  GadgetWidth(*this\canvas), GadgetHeight(*this\canvas), *this\background)
          ; draw current animation image
          DrawingMode(#PB_2DDrawing_AlphaBlend) ; overwrite (also if frame has alpha channel) ; #PB_2DDrawing_AlphaBlend
          DrawImage(ImageID(*this\frames(*this\frame)), 0, 0, GadgetWidth(*this\canvas), GadgetHeight(*this\canvas))
        EndIf
        ; draw debug info
        CompilerIf 0 And #PB_Compiler_Debugger
          DrawingMode(#PB_2DDrawing_AlphaBlend|#PB_2DDrawing_Transparent)
          DrawText(2, 2, "image "+*this\frame, $C0000080)
        CompilerEndIf
        StopDrawing()
      EndIf
    EndIf
  EndProcedure
  
  Procedure loadImageSequence(*this.ani, filePattern$) ; pattern MUST fullfill (^.*%[0-9]+d.*$) !
    Protected i
    Protected NewList files$()
    Protected time = ElapsedMilliseconds()
    
    pause(*this)
    deb("animation:: load image sequence "+#DQUOTE$+filePattern$+#DQUOTE$)
    
    getImageSequenceFiles(filePattern$, files$())
    
    If ListSize(files$()) > 0
      freeImages(*this)
      ReDim *this\frames(ListSize(files$())-1)
      i = 0
      ForEach files$()
        *this\frames(i) = LoadImage(#PB_Any, files$())
        If Not *this\frames(i)
          deb("animation:: error, could not load file "+files$())
        EndIf
        i + 1
      Next
      deb("animation:: loaded image sequence in "+Str(ElapsedMilliseconds()-time)+" ms")
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure loadAni(*this.ani, aniFile$)
    ; TODO load files from pack
    Protected pack, i, *buffer, size
    Protected numFiles.u
    Protected time = ElapsedMilliseconds()
    
    pause(*this)
    deb("animation:: load ani file "+#DQUOTE$+aniFile$+#DQUOTE$+" #"+*this)
    
    
    pack = OpenPack(#PB_Any, aniFile$, #PB_PackerPlugin_Tar)
    If pack
      If UncompressPackMemory(pack, @numFiles, SizeOf(numFiles), "numFiles")
        deb("animation:: "+numFiles+" frames defined in *.ani file")
        freeImages(*this)
        ReDim *this\frames(numFiles-1)
        
        If ExaminePack(pack)
          While NextPackEntry(pack)
            If stringIsInteger(PackEntryName(pack))
              i = Val(PackEntryName(pack))
              size = PackEntrySize(pack, #PB_Packer_UncompressedSize)
              *buffer = AllocateMemory(size)
              If *buffer
                If UncompressPackMemory(pack, *buffer, size)
                  *this\frames(i) = CatchImage(#PB_Any, *buffer, size)
                  If Not *this\frames(i)
                    Deb("animation:: could not open frame "+i+" from ani pack "+aniFile$)
                  EndIf
                EndIf
                FreeMemory(*buffer)
              Else
                Deb("animation:: could not allocate memory ("+size+" bytes)")
              EndIf
            EndIf
          Wend
        EndIf

      Else
        Deb("animation:: could not read header of "+#DQUOTE$+aniFile$+#DQUOTE$)
      EndIf
      
      ClosePack(pack)
      
      Deb("animation:: loaded ani file in "+Str(ElapsedMilliseconds()-time)+" ms")
      ProcedureReturn #True
    Else
      deb("animation:: could not open ani file "+aniFile$)
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure play(*this.ani)
    *this\playing = #True
    If Not *this\thread
      *this\thread = CreateThread(@aniThread(), *this)
    EndIf
  EndProcedure
  
  Procedure pause(*this.ani)
    *this\playing = #False
  EndProcedure
  
  
  Procedure setCanvas(*this.ani, canvas)
    ; TODO also set coordinates (x,y,w,h) to only draw on certain region?
    *this\canvas = canvas
  EndProcedure
  
  Procedure setInterval(*this.ani, interval)
    *this\interval = interval
  EndProcedure
  
  Procedure setReverse(*this.ani, reverse.b)
    *this\reverse = Bool(reverse)
  EndProcedure
  
  Procedure setBackgroundColor(*this.ani, color.l)
    *this\background = color
  EndProcedure
  
  Procedure getCanvas(*this.ani)
    ProcedureReturn *this\canvas
  EndProcedure
  
  Procedure getInterval(*this.ani)
    ProcedureReturn *this\interval
  EndProcedure
  
  Procedure.b getReverse(*this.ani)
    ProcedureReturn *this\reverse
  EndProcedure
  
  Procedure.l getBackgroundColor(*this.ani)
    ProcedureReturn *this\background
  EndProcedure
  
  Procedure.u getFrameCount(*this.ani)
    ProcedureReturn ArraySize(*this\frames()) + 1
  EndProcedure
  
  Procedure.b isPaused(*this.ani)
    ProcedureReturn Bool(Not *this\playing)
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  EnableExplicit
  
  Global window, canvas, *ani.animation::animation
  UsePNGImageDecoder()
  
  #UseAnimationFile = #True ; <------------------------------ *.ani file (true) or file sequence (false)
  
  Procedure close()
    HideWindow(window, #True)
    *ani\free()
    Debug "goodbye!"
    End
  EndProcedure
  
  Procedure eventTogglePause()
    If *ani\isPaused()
      *ani\play()
    Else
      *ani\pause()
    EndIf
  EndProcedure
  
  Procedure eventToggleReverse()
      *ani\setReverse(Bool(Not *ani\getReverse()))
  EndProcedure
  
  ; ---
  CompilerIf #UseAnimationFile 
    Debug "pack a file sequence to *.ani file"
    animation::packFileSequenceToAni("images/logo/animation/logo_%03d.png", "images/logo/animation/logo.ani")
  CompilerEndIf
  ; ---
  ; 16:9 res: https://pacoup.com/2011/06/12/list-of-true-169-resolutions/
  window = OpenWindow(#PB_Any, 0, 0, 256, 144, "Animation", #PB_Window_SystemMenu|#PB_Window_ScreenCentered)
  canvas = CanvasGadget(#PB_Any, 0, 0, WindowWidth(window), WindowHeight(window))
  BindEvent(#PB_Event_CloseWindow, @close(), window)
  BindGadgetEvent(canvas, @eventTogglePause(), #PB_EventType_LeftClick)
  BindGadgetEvent(canvas, @eventToggleReverse(), #PB_EventType_RightClick)
  ; ---
  *ani = animation::new()
  *ani\setCanvas(canvas)
  *ani\setInterval(1000/60) ; 60 fps
  CompilerIf #UseAnimationFile
    *ani\loadAni("images/logo/animation/logo.ani")
  CompilerElse
    *ani\loadImageSequence("images/logo/animation/logo_%03d.png")
  CompilerEndIf
  Debug StrU(*ani\getFrameCount(), #PB_Unicode)+" frames loaded"
  *ani\play()
  ; ---
  Repeat
    WaitWindowEvent()
  ForEver
CompilerEndIf
