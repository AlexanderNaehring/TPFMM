DeclareModule images
  Global NewMap Images()  
  Declare LoadImages()
EndDeclareModule

Module images
  EnableExplicit
  
  Procedure LoadImages()
    debugger::Add("images::loadImages()")
    Images("headermain")  = CatchImage(#PB_Any, ?DataImageHeader,   ?DataImageHeaderEnd - ?DataImageHeader)
    Images("headerinfo")  = CatchImage(#PB_Any, ?DataImageHeader,   ?DataImageHeaderEnd - ?DataImageHeader)
    Images("yes")         = CatchImage(#PB_Any, ?DataImageYes,      ?DataImageYesEnd - ?DataImageYes)
    Images("no")          = CatchImage(#PB_Any, ?DataImageNo,       ?DataImageNoEnd - ?DataImageNo)
    Images("backup")      = CatchImage(#PB_Any, ?DataImageBackup,   ?DataImageBackupEnd - ?DataImageBackup)
    Images("logo")        = CatchImage(#PB_Any, ?DataImageLogo,     ?DataImageLogoEnd - ?DataImageLogo)
    Images("steam")       = CatchImage(#PB_Any, ?DataImageSteam,    ?DataImageSteamEnd - ?DataImageSteam)
    Images("tpfnet")      = CatchImage(#PB_Any, ?DataImageTPFnet,   ?DataImageTPFnetEnd - ?DataImageTPFnet)
    Images("mod")         = CatchImage(#PB_Any, ?DataImageMod,      ?DataImageModEnd - ?DataImageMod)
    Images("icon_mod_official")    = CatchImage(#PB_Any, ?DataImageTpf,      ?DataImageTpfEnd - ?DataImageTpf)
    
    ResizeImage(Images("headerinfo"), 360, #PB_Ignore, #PB_Image_Raw)
    
    Images("icon_backup")   = CopyImage(Images("backup"), #PB_Any)
    Images("icon_workshop") = CopyImage(Images("steam"), #PB_Any)
    Images("icon_mod")      = CopyImage(Images("mod"), #PB_Any)
    Images("icon_tpfnet")   = CopyImage(Images("tpfnet"), #PB_Any)
    
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux Or #True
      ResizeImage(Images("yes"), 16, 16, #PB_Image_Raw)
      ResizeImage(Images("no"), 16, 16, #PB_Image_Raw)
      ResizeImage(Images("icon_backup"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_workshop"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_tpfnet"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_mod"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_mod_official"), 16, 16, #PB_Image_Smooth)
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
    
    DataImageBackup:
    IncludeBinary "images/backup.png"
    DataImageBackupEnd:
    
    DataImageLogo:
    IncludeBinary "images/logo.png"
    DataImageLogoEnd:
    
    DataImageSteam:
    IncludeBinary "images/steam.png"
    DataImageSteamEnd:
    
    DataImageTPFnet:
    IncludeBinary "images/TPFnet.png"
    DataImageTPFnetEnd:
    
    DataImageMod:
    IncludeBinary "images/mod.png"
    DataImageModEnd:
    
    DataImageTpf:
    IncludeBinary "images/mod_official.png"
    DataImageTpfEnd:
    
  EndDataSection
EndModule