DeclareModule images
  Global NewMap Images()  
  Declare LoadImages()
EndDeclareModule

Module images
  EnableExplicit
  
  Procedure LoadImages()
    Images("header")  = CatchImage(#PB_Any, ?ImageHeaderD)
    Images("yes")     = CatchImage(#PB_Any, ?ImageYesD)
    Images("no")      = CatchImage(#PB_Any, ?ImageNoD)
    Images("logo")    = CatchImage(#PB_Any, ?ImageLogoD)
    
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux Or #True ; TODO ----------------
      ResizeImage(Images("yes"), 16, 16, #PB_Image_Raw)
      ResizeImage(Images("no"), 16, 16, #PB_Image_Raw)
    CompilerEndIf
  EndProcedure
  
  
  DataSection
    ImageHeaderD:
    IncludeBinary "images/header.png"
    
    ImageYesD:
    IncludeBinary "images/yes.png"
    
    ImageNoD:
    IncludeBinary "images/no.png"
    
    ImageLogoD:
    IncludeBinary "images/logo.png"
  EndDataSection
EndModule
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 19
; Folding = -
; EnableUnicode
; EnableXP