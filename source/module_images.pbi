DeclareModule images
  Global NewMap Images()
  
  Declare ImageFilterGrayscale(x, y, SourceColor, TargetColor)
  Declare ImageFilterApplyColorToNonWhite(x, y, SourceColor, TargetColor)
EndDeclareModule

XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"

Module images
  EnableExplicit
  UseModule debugger
  
  Macro IncludeAndLoadImage(name, file)
    DataSection
      _image#MacroExpandedCount#Start:
      IncludeBinary file
      _image#MacroExpandedCount#End:
    EndDataSection
    
    Images(name) = CatchImage(#PB_Any, ?_image#MacroExpandedCount#Start, ?_image#MacroExpandedCount#End - ?_image#MacroExpandedCount#Start)
  EndMacro
  
  Macro makeIcons(image)
    images(image+"Hover") = MakeHoverIcon(images(image))
    images(image+"Disabled") = MakeDisabledIcon(images(image))
  EndMacro
  
  Procedure MakeDisabledIcon(icon)
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
  
  Procedure MakeHoverIcon(icon)
    Protected width, height, newIcon
    width   = ImageWidth(icon) 
    height  = ImageHeight(icon) 
    newIcon = CreateImage(#PB_Any, width, height, 32, #PB_Image_Transparent)
    If StartDrawing(ImageOutput(newIcon)) 
      DrawingMode(#PB_2DDrawing_AlphaBlend) 
      Box(0, 0, width, height, RGBA(255, 255, 255, 255)) 
      Box(0, 0, width, height, RGBA(00, $7B, $EE, $30))
      DrawImage(ImageID(icon), 0, 0)
      StopDrawing()
    EndIf
    ProcedureReturn newIcon
  EndProcedure
  
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
    IncludeAndLoadImage("headermain",   "images/header.png")
    IncludeAndLoadImage("headerinfo",   "images/header.png")
    IncludeAndLoadImage("logo",         "images/logo.png")
    IncludeAndLoadImage("avatar",       "images/avatar.png")
    
    ; main window nav buttons
    IncludeAndLoadImage("navMods",      "images/nav-btn/mods.png")
    IncludeAndLoadImage("navMaps",      "images/nav-btn/maps.png")
    IncludeAndLoadImage("navOnline",    "images/nav-btn/online.png")
    IncludeAndLoadImage("navSaves",      "images/nav-btn/saves.png")
    IncludeAndLoadImage("navBackups",   "images/nav-btn/backups.png")
    IncludeAndLoadImage("navSettings",  "images/nav-btn/settings.png")
    IncludeAndLoadImage("navHelp",      "images/nav-btn/help.png")
    
    ; list sort / filter buttons
    IncludeAndLoadImage("btnSort",      "images/btn/16/sort.png")
    IncludeAndLoadImage("btnFilter",    "images/btn/16/filter.png")
    
    ; main window buttons right side
    IncludeAndLoadImage("btnInfo",      "images/btn/32/info.png")
    IncludeAndLoadImage("btnUpdate",    "images/btn/32/update.png")
    IncludeAndLoadImage("btnShare",     "images/btn/32/share.png")
    IncludeAndLoadImage("btnBackup",    "images/btn/32/backup.png")
    IncludeAndLoadImage("btnUninstall", "images/btn/32/uninstall.png")
    IncludeAndLoadImage("btnRestore",   "images/btn/32/restore.png")
    IncludeAndLoadImage("btnUpdateAll", "images/btn/32/update_all.png")
    IncludeAndLoadImage("btnDownload",  "images/btn/32/download.png")
    IncludeAndLoadImage("btnWebsite",   "images/btn/32/website.png")
    IncludeAndLoadImage("btnOpen",      "images/btn/32/open.png")
    IncludeAndLoadImage("btnFolder",    "images/btn/32/folder.png")
    
    ; in-item buttons
    IncludeAndLoadImage("itemBtnFolder",    "images/item-btn/folder.png")
    IncludeAndLoadImage("itemBtnInfo",      "images/item-btn/info.png")
    IncludeAndLoadImage("itemBtnSettings",  "images/item-btn/settings.png")
    IncludeAndLoadImage("itemBtnWebsite",   "images/item-btn/website.png")
    IncludeAndLoadImage("itemBtnDownload",  "images/item-btn/download.png")
    IncludeAndLoadImage("itemBtnUpdate",    "images/item-btn/update.png")
    IncludeAndLoadImage("itemBtnRestore",   "images/item-btn/restore.png")
    IncludeAndLoadImage("itemBtnDelete",    "images/item-btn/delete.png")
    
    ; item icons
    IncludeAndLoadImage("itemIcon_blank",     "images/icon/blank.png")
    IncludeAndLoadImage("itemIcon_mod",       "images/icon/mod.png")
    IncludeAndLoadImage("itemIcon_settings",  "images/icon/settings.png")
    IncludeAndLoadImage("itemIcon_vanilla",   "images/icon/mod_official.png")
    IncludeAndLoadImage("itemIcon_workshop",  "images/icon/steam.png")
    IncludeAndLoadImage("itemIcon_tpfnet",    "images/icon/tpfnet.png")
    IncludeAndLoadImage("itemIcon_updateAvailable",    "images/icon/updateAvailable.png")
    IncludeAndLoadImage("itemIcon_up2date",    "images/icon/up2date.png")
    IncludeAndLoadImage("itemIcon_installed",           "images/icon/installed.png")
    IncludeAndLoadImage("itemIcon_notInstalled",        "images/icon/notInstalled.png")
    IncludeAndLoadImage("itemIcon_availableOnline",     "images/icon/availableOnline.png")
    IncludeAndLoadImage("itemIcon_notAvailableOnline",  "images/icon/notAvailableOnline.png")
    
    
    ResizeImage(Images("headerinfo"), 360, #PB_Ignore, #PB_Image_Raw)
    
    makeIcons("itemBtnFolder")
    makeIcons("itemBtnInfo")
    makeIcons("itemBtnInfo")
    makeIcons("itemBtnSettings")
    makeIcons("itemBtnWebsite")
    makeIcons("itemBtnDownload")
    makeIcons("itemBtnUpdate")
    makeIcons("itemBtnRestore")
    makeIcons("itemBtnDelete")
    
    ; also extract animation file here
    
    misc::useBinary("images/logo/logo.ani", #False)
    
  EndProcedure
  
  ; init
  If Not UsePNGImageDecoder() Or
     Not UsePNGImageEncoder() Or 
     Not UseJPEGImageDecoder() Or
     Not UseTGAImageDecoder()
    deb("ERROR: ImageDecoder fail")
    MessageRequester("Error", "Could not initialize Image Decoder.")
    End
  EndIf
  
  LoadImages()
EndModule