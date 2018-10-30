EnableExplicit
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"

DeclareModule locale
  EnableExplicit
  
  Macro l(g,s)
    locale::get(g,s)
  EndMacro
  
  Declare listAvailable(ComboBoxGadget, current_locale$)
  Declare use(new_locale$)
  Declare.s getEx(group$, string$, Map var$())
  Declare.s get(group$, string$)
  Declare getFlag(locale$)
  Declare.s getCurrentLocale()
EndDeclareModule

Module locale
  UseModule debugger
  
  Global init.i, RegExpAlpha.i
  Global path$, current_locale$
  Global NewMap locale$()
  Global NewMap localeEN$()
  
  Procedure loadLocale(locale$, Map locale$())
    If OpenPreferences(path$ + locale$ + ".locale")
      ExaminePreferenceGroups()
      While NextPreferenceGroup()
        ExaminePreferenceKeys()
        While NextPreferenceKey()
          locale$(PreferenceGroupName()+"/"+PreferenceKeyName()) = PreferenceKeyValue()
        Wend
      Wend
      ClosePreferences()
      ProcedureReturn #True
    EndIf
    ProcedureReturn #False
  EndProcedure
  
  Procedure init()
    Protected file.i
    If Not init
      deb("locale::init()")
      If path$ = ""
        path$ = misc::Path("locale")
      EndIf
      If Not RegExpAlpha
;         CreateRegularExpression(0, "[^A-Za-z0-9]") ; match non-alphanumeric characters
        RegExpAlpha = CreateRegularExpression(#PB_Any, "^[A-Za-z]+$") ; only alpha in string!
      EndIf
      
      ; create locale files
      misc::CreateDirectoryAll(path$)
      misc::extractBinary(path$ + "en.locale", ?DataLocaleEnglish, ?DataLocaleEnglishEnd - ?DataLocaleEnglish, #True)
      misc::extractBinary(path$ + "de.locale", ?DataLocaleGerman, ?DataLocaleGermanEnd - ?DataLocaleGerman, #True)
      misc::extractBinary(path$ + "en.png", ?DataFlagEnglish, ?DataFlagEnglishEnd - ?DataFlagEnglish, #True)
      misc::extractBinary(path$ + "de.png", ?DataFlagGerman, ?DataFlagGermanEnd - ?DataFlagGerman, #True)
      
      ; load fallback (EN)
      ClearMap(localeEN$())
      loadLocale("en", localeEN$())
      
      init = #True
    EndIf
  EndProcedure
  
  Procedure listAvailable(ComboBoxGadget, current_locale$)
    Protected dir.i, count.i
    Protected file$, locale$, name$
    
    ClearGadgetItems(ComboBoxGadget)
    
    dir = ExamineDirectory(#PB_Any, "locale", "*.locale")
    If dir
      count = 0
      While NextDirectoryEntry(dir)
        file$ = DirectoryEntryName(dir)
        locale$ = GetFilePart(file$, #PB_FileSystem_NoExtension)
        If Not MatchRegularExpression(RegExpAlpha, locale$)
          Continue
        EndIf
        If OpenPreferences(misc::Path("locale")+file$)
          name$ = ReadPreferenceString("locale", "")
          ClosePreferences()
          If name$ <> ""
            AddGadgetItem(ComboBoxGadget, -1, "<"+locale$+">"+" "+name$, getFlag(locale$))
            If current_locale$ = locale$
              SetGadgetState(ComboBoxGadget, count)
            EndIf
            count + 1
          EndIf
        EndIf
      Wend
      ProcedureReturn #True
    Else
      deb("error examine directory 'localisation'")
      ProcedureReturn #False
    EndIf
  EndProcedure
    
  Procedure use(locale$)
    current_locale$ = locale$
    ClearMap(locale$())
    
    If locale$ = "en"
      ; no need to load en, as fallback = en
      CopyMap(localeEN$(), locale$())
      ProcedureReturn #True
    EndIf
    
    If OpenPreferences(path$ + locale$ + ".locale")
      
      ; load complete locale into map! otherwise: problems with multiple preference files :(
      ExaminePreferenceGroups()
      While NextPreferenceGroup()
        ExaminePreferenceKeys()
        While NextPreferenceKey()
          locale$(PreferenceGroupName()+"/"+PreferenceKeyName()) = PreferenceKeyValue()
        Wend
      Wend
      ClosePreferences()
      ProcedureReturn #True
    Else
      deb("locale:: locale '" + locale$ + "' can not be opened! use fallback locale (en)")
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure.s getEx(group$, string$, Map var$())
    Protected out$, key$
    
    If group$ = "" Or string$ = ""
      ProcedureReturn ""
    EndIf
    
    If group$ = "category"
      group$ = "tags"
    EndIf
    
    
    
    key$ = LCase(group$+"/"+string$)
    key$ = ReplaceString(key$, " ", "_")
    out$ = locale$(key$)
    If out$ = ""
      If group$ <> "tags"
        deb("locale:: failed to load '"+key$+"' from '"+current_locale$+"'")
      EndIf
      
      out$ = localeEN$(key$)
      If out$ = ""
        If group$ = "tags"
          ; deb("locale::getEx() - cannot find tag '"+string$+"'")
          out$ = string$
        Else
          deb("locale:: failed to load fallback for '"+key$+"'")
          out$ = "<"+key$+">"
        EndIf
      EndIf
    EndIf
    
    out$ = ReplaceString(out$, "\n", #CRLF$)
    
    ForEach var$()
      out$ = ReplaceString(out$, "{"+MapKey(var$())+"}", var$())
    Next
    
    ProcedureReturn out$
  EndProcedure
  
  Procedure.s get(group$, string$)
    Protected NewMap var$()
    ProcedureReturn getEx(group$, string$, var$())
  EndProcedure
  
  Procedure getFlag(locale$)
    Protected im.i
    Protected max_w.i, max_h.i, factor_w.d, factor_h.d, factor.d, im_w.i, im_h.i
    Protected flag$, *image
    Static NewMap flag()
    
    If flag(locale$)
      ProcedureReturn ImageID(flag(locale$))
    EndIf
    
    OpenPreferences(path$ + locale$ + ".locale")
    flag$ = ReadPreferenceString("flag", "")
    If flag$ ; TODO remove flag from locale file ?
      *image = misc::HexStrToMem(flag$)
      im = CatchImage(#PB_Any, *image, MemorySize(*image))
      FreeMemory(*image)
    Else
      If FileSize(path$ + locale$ + ".png") > 0
        im = LoadImage(#PB_Any, path$ + locale$ + ".png")
      EndIf
    EndIf
    ClosePreferences()
    
    If im And IsImage(im)
      flag(locale$) = misc::ResizeCenterImage(im, 20, 20)
      ProcedureReturn ImageID(flag(locale$))
    Else
      deb("locale::getFlag() - could not load image")
    EndIf
    ProcedureReturn 0
  EndProcedure
  
  Procedure.s getCurrentLocale()
    ProcedureReturn current_locale$
  EndProcedure
  
  init()
  
  DataSection
    DataLocaleEnglish:
    IncludeBinary "locale/en.locale"
    DataLocaleEnglishEnd:
    
    DataLocaleGerman:
    IncludeBinary "locale/de.locale"
    DataLocaleGermanEnd:
    
    DataFlagEnglish:
    IncludeBinary "locale/en.png"
    DataFlagEnglishEnd:
    
    DataFlagGerman:
    IncludeBinary "locale/de.png"
    DataFlagGermanEnd:
  EndDataSection
EndModule