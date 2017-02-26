DeclareModule repository
  EnableExplicit
  
  #OFFICIAL_REPOSITORY$ = "https://www.transportfevermods.com/repository/"
  
  Structure tpfmm
    build.i
    version$
  EndStructure
  
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
    TPFMM.tpfmm
    List mods.repo_link() ; multiple mod repositories may be linked from a single root repsitory
  EndStructure
  
  Structure file
    filename$
    url$
  EndStructure
  
  Structure mod
    source$
    id.i
    name$
    author$
    authorid.i
    version$
    type$
    url$
    thumbnail$
    timecreated.i
    timechanged.i
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
  Declare canDownload(*repoMod.mod)
  Declare downloadMod(*download.download)
  
EndDeclareModule