DeclareModule images
  Global NewMap Images()  
  
  Declare ImageFilterGrayscale(x, y, SourceColor, TargetColor)
  Declare ImageFilterApplyColorToNonWhite(x, y, SourceColor, TargetColor)
EndDeclareModule

Module images
  EnableExplicit
  
  Macro IncludeAndLoadImage(name, file)
    DataSection
      _image#MacroExpandedCount#Start:
      IncludeBinary file
      _image#MacroExpandedCount#End:
    EndDataSection
    
    Images(name) = CatchImage(#PB_Any, ?_image#MacroExpandedCount#Start, ?_image#MacroExpandedCount#End - ?_image#MacroExpandedCount#Start)
  EndMacro
  
  Procedure ImageFilterGrayscale(x, y, SourceColor, TargetColor)
    Protected gray = 0.2989 * Red(SourceColor) + 0.5870 * Green(SourceColor) + 0.1140 * Blue(SourceColor)
    ProcedureReturn RGBA(gray, gray, gray, Alpha(SourceColor))
  EndProcedure
    
  Procedure ImageFilterApplyColorToNonWhite(x, y, SourceColor, TargetColor)
    If Red(TargetColor) = 255 And Green(TargetColor) = 255 And Blue(TargetColor) = 255
      ; target is white
      ProcedureReturn TargetColor
    EndIf
    ProcedureReturn RGBA(Red(SourceColor), Green(SourceColor), Blue(SourceColor), Alpha(TargetColor))
  EndProcedure
  
  
  Procedure LoadImages()
    debugger::Add("images::loadImages()")
    IncludeAndLoadImage("headermain",   "images/header.png")
    IncludeAndLoadImage("headerinfo",   "images/header.png")
    IncludeAndLoadImage("yes",          "images/yes.png")
    IncludeAndLoadImage("no",           "images/no.png")
    IncludeAndLoadImage("backup",       "images/backup.png")
    IncludeAndLoadImage("logo",         "images/logo.png")
    IncludeAndLoadImage("steam",        "images/steam.png")
    IncludeAndLoadImage("tpfnet",       "images/TPFnet.png")
    IncludeAndLoadImage("mod",          "images/mod.png")
    IncludeAndLoadImage("icon_mod_official",  "images/mod_official.png")
    IncludeAndLoadImage("avatar",       "images/avatar.png")
    IncludeAndLoadImage("share",        "images/share.png")
    
    IncludeAndLoadImage("navMods",      "images/nav/mods.png")
    IncludeAndLoadImage("navMaps",      "images/nav/maps.png")
    IncludeAndLoadImage("navOnline",    "images/nav/online.png")
    IncludeAndLoadImage("navBackups",   "images/nav/backups.png")
    IncludeAndLoadImage("navSettings",  "images/nav/settings.png")
    
    IncludeAndLoadImage("btnSort",      "images/btn/sort.png")
    IncludeAndLoadImage("btnFilter",    "images/btn/filter.png")
    
    IncludeAndLoadImage("btnInfo",      "images/btn/info.png")
    IncludeAndLoadImage("btnUpdate",    "images/btn/update.png")
    IncludeAndLoadImage("btnShare",     "images/btn/share.png")
    IncludeAndLoadImage("btnBackup",    "images/btn/backup.png")
    IncludeAndLoadImage("btnUninstall", "images/btn/uninstall.png")
    IncludeAndLoadImage("btnUpdateAll", "images/btn/update_all.png")
    
    IncludeAndLoadImage("iconFolder",   "images/icons/folder.png")
    IncludeAndLoadImage("iconInfo",     "images/icons/info.png")
    IncludeAndLoadImage("iconSettings", "images/icons/settings.png")
    IncludeAndLoadImage("iconWebsite",  "images/icons/website.png")
    
    IncludeAndLoadImage("modDefault",   "images/mod_default.png")
    
    
    ResizeImage(Images("headerinfo"), 360, #PB_Ignore, #PB_Image_Raw)
    
    Images("icon_backup")   = CopyImage(Images("backup"), #PB_Any)
    Images("icon_workshop") = CopyImage(Images("steam"), #PB_Any)
    Images("icon_mod")      = CopyImage(Images("mod"), #PB_Any)
    Images("icon_tpfnet")   = CopyImage(Images("tpfnet"), #PB_Any)
    
    
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux Or #True
      ResizeImage(Images("yes"), 16, 16, #PB_Image_Raw)
      ResizeImage(Images("no"), 16, 16, #PB_Image_Raw)
      ResizeImage(Images("share"), 16, 16, #PB_Image_Raw)
      ResizeImage(Images("icon_backup"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_workshop"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_tpfnet"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_mod"), 16, 16, #PB_Image_Smooth)
      ResizeImage(Images("icon_mod_official"), 16, 16, #PB_Image_Smooth)
    CompilerEndIf
  EndProcedure
  
  ; init
  If Not UsePNGImageDecoder() Or
     Not UsePNGImageEncoder() Or 
     Not UseJPEGImageDecoder() Or
     Not UseTGAImageDecoder()
    debugger::Add("ERROR: ImageDecoder")
    MessageRequester("Error", "Could not initialize Image Decoder.")
    End
  EndIf
  LoadImages()
EndModule