DeclareModule images
  Global ImageHeader, ImageYes, ImageNo, ImageLogo
  
  Declare LoadImages()
EndDeclareModule

Module images
  EnableExplicit
  
  Procedure LoadImages()
    ImageHeader = CatchImage(#PB_Any, ?ImageHeaderD)
    ImageYes    = CatchImage(#PB_Any, ?ImageYesD)
    ImageNo     = CatchImage(#PB_Any, ?ImageNoD)
    ImageLogo   = CatchImage(#PB_Any, ?ImageLogoD)
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
; CursorPosition = 12
; Folding = -
; EnableUnicode
; EnableXP