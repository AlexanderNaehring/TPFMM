XIncludeFile "module_mods.h.pbi"

DeclareModule repository
  EnableExplicit
  
  #OFFICIAL_REPOSITORY$ = "https://www.transportfevermods.com/repository/"
  
  
  ; mod strucutres
  
  Structure file
    fileid.q
    filename$         ; 
    url$              ; url to download this file
    timechanged.i     ; last time this file was changed
  EndStructure
  
  Structure mod
    source$
    id.q
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
    
    installed.i
  EndStructure
  
  
  ; repository structres
  
  Structure tpfmm
    build.i
    version$
    url$
  EndStructure
  
  Structure repo_info     ; information about any repository
    name$                 ; name
    source$
    description$
    maintainer$
    url$
    info_url$
    changed.i
  EndStructure
  
  Structure repo_link     ; link to a sub-repository (e.g. a mod repo)
    url$                  ; location of repo
    age.i                 ; age in seconds
    enc$                  ; encoding scheme
  EndStructure
  
  Structure main_json     ; main (root level) repository json data
    repository.repo_info  ; information about this repository
    TPFMM.tpfmm           ; TPFMM update information (if official repository)
    List mods.repo_link() ; list of mod repos linked by this repository
  EndStructure
  
  Structure repository    ; lowest level: list of "repository"
    url$                  ; location
    main_json.main_json   ; data from json
  EndStructure
  
  Structure repo_mods     ; repository for mods
    repo_info.repo_info
    mod_base_url$
    file_base_url$
    thumbnail_base_url$
    List mods.mod()
  EndStructure
  
  
  Structure column         ; public column identifier
    name$
    width.i
  EndStructure
  
  Structure download
    source$   ; online repository source
    id.q      ; mod ID in this source
    fileID.q  ; if a mod has multiple files, specify fileID
  EndStructure
  
  ; start repository loading
  Declare init()
  
  ; register functions
  Declare registerWindow(windowID)
  Declare registerListGadget(gadgetID, Array columns.column(1))
  Declare registerThumbGadget(gadgetID)
  Declare registerFilterGadgets(gadgetString, gadgetType, gadgetSource, gadgetInstalled)
  
  ; display fucntions
  Declare displayMods()
  Declare displayThumbnail(url$)
  Declare selectModInList(*mod.mod)
  Declare searchMod(name$, author$="")
  
  ; check functions
  Declare getModByID(source$, id.q)
  Declare getFileByID(*repoMod.mod, fileID.q)
  Declare canDownloadModByID(source$, id.q, fileID.q = 0)
  Declare canDownloadMod(*repoMod.mod)
  Declare canDownloadFile(*file.file)
  Declare downloadMod(source$, id.q, fileID.q = 0)
  Declare findModOnline(*mod.mods::mod)
  Declare findModByID(source$, id.q)
  
  ; other
  Declare refresh()
  Declare clearCache()
  Declare listRepositories(Map gadgets()) ; used by settings window
  
  Global TPFMM_UPDATE.tpfmm
  Global _READY
  
EndDeclareModule