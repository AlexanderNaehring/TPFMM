DeclareModule images
  Global NewMap Images()  
  Declare LoadImages()
EndDeclareModule

Module images
  EnableExplicit
  
  Procedure LoadImages()
    debugger::Add("images::loadImages()")
    Images("headermain")  = CatchImage(#PB_Any, ?DataImageHeader, ?DataImageHeaderEnd - ?DataImageHeader)
    Images("headerinfo")  = CatchImage(#PB_Any, ?DataImageHeader, ?DataImageHeaderEnd - ?DataImageHeader)
    Images("yes")         = CatchImage(#PB_Any, ?DataImageYes,    ?DataImageYesEnd - ?DataImageYes)
    Images("no")          = CatchImage(#PB_Any, ?DataImageNo,     ?DataImageNoEnd - ?DataImageNo)
    Images("logo")        = CatchImage(#PB_Any, ?DataImageLogo,   ?DataImageLogoEnd - ?DataImageLogo)
    
    ResizeImage(Images("headerinfo"), 360, #PB_Ignore, #PB_Image_Raw)
    
    
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux Or #True ; TODO ----------------
      ResizeImage(Images("yes"), 16, 16, #PB_Image_Raw)
      ResizeImage(Images("no"), 16, 16, #PB_Image_Raw)
    CompilerEndIf
  EndProcedure
  
  
  DataSection
    DataImageHeader:
    IncludeBinary "images/header.png"
    DataImageHeaderEnd:
    
    DataImageYes:
    IncludeBinary "images/yes.png"
    DataImageYesEnd:
    
    DataImageNo:
    IncludeBinary "images/no.png"
    DataImageNoEnd:
    
    DataImageLogo:
    IncludeBinary "images/logo.png"
    DataImageLogoEnd:
  EndDataSection
EndModule