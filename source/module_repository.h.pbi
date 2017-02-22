DeclareModule repository
  EnableExplicit
  
  Macro StopWindowUpdate(_winID_)
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
;         SendMessage_(_winID_,#WM_SETREDRAW,0,0)
      CompilerCase #PB_OS_Linux
        
      CompilerCase #PB_OS_MacOS
        CocoaMessage(0,_winID_,"disableFlushWindow")
    CompilerEndSelect
  EndMacro
  Macro ContinueWindowUpdate(_winID_, _redrawBackground_ = 0)
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
;         SendMessage_(_winID_,#WM_SETREDRAW,1,0)
;         InvalidateRect_(_winID_,0,_redrawBackground_)
;         UpdateWindow_(_winID_)
      CompilerCase #PB_OS_Linux
        
      CompilerCase #PB_OS_MacOS
        CocoaMessage(0,_winID_,"enableFlushWindow")
    CompilerEndSelect
  EndMacro
  
  Structure repo_info
    name$
    source$
    description$
    maintainer$
    url$
    info_url$
    changed.i
  EndStructure
  
  Structure repo_link
    url$
    age.i
    enc$
  EndStructure
  
  ; main (root level) repository
  Structure repo_main
    repository.repo_info
    build.i
    List mods.repo_link() ; multiple mod repositories may be linked from a single root repsitory
  EndStructure
  
  Structure file
    filename$
    url$
  EndStructure
  
  Structure mod
    id.i
    source$
    remote_id.i
    name$
    author$
    authorid.i
    version$
    type$
    url$
    thumbnail$
    views.i
    timecreated.i
    timechanged.i
    lastscan.i
    List files.file()
    List tags$()
    List tagsLocalized$()
  EndStructure
  
  ; repository for mods
  Structure repo_mods
    repo_info.repo_info
    mod_base_url$
    file_base_url$
    thumbnail_base_url$
    List mods.mod()
  EndStructure
  
  ; public column identifier
  Structure column
    name$
    width.i
  EndStructure
  
  Structure download
    ; each mod can have multiple files
    ;-> reference mod info AND the specific file to be downloaded
    *mod.mod
    *file.file
  EndStructure
  
  Declare loadRepository(url$)
  Declare loadRepositoryList()
  
  Declare registerWindow(windowID)
  Declare registerListGadget(gadgetID, Array columns.column(1))
  Declare registerThumbGadget(gadgetID)
  Declare registerTypeGadget(gadgetID)
  Declare registerSourceGadget(gadgetID)
  Declare registerFilterGadget(gadgetID)
  Declare displayMods(search$, source$ = "", type$="")
  Declare displayThumbnail(url$)
  Declare downloadMod(*download.download)
  
EndDeclareModule