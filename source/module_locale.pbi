EnableExplicit
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"

Macro l(g,s)
  locale::get(g,s)
EndMacro

DeclareModule locale
  EnableExplicit
  
  Declare listAvailable(Map locale())
  Declare use(new_locale$)
  Declare.s getEx(group$, string$, Map var$())
  Declare.s get(group$, string$)
  Declare showFlag(locale$, ImageGadget)
EndDeclareModule

Module locale
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
      debugger::Add("locale::init()")
      If path$ = ""
        path$ = misc::Path("locale")
        debugger::add("locale::path$ = "+path$)
      EndIf
      If Not RegExpAlpha
;         CreateRegularExpression(0, "[^A-Za-z0-9]") ; match non-alphanumeric characters
        RegExpAlpha = CreateRegularExpression(#PB_Any, "^[A-Za-z]+$") ; only alpha in string!
        debugger::add("locale::RegExpAlpha = "+Str(RegExpAlpha))
      EndIf
      
      ; create locale files
      misc::CreateDirectoryAll(path$)
      misc::extractBinary(path$ + "en.locale", ?DataLocaleEnglish, ?DataLocaleEnglishEnd - ?DataLocaleEnglish, #True)
      misc::extractBinary(path$ + "en.png", ?DataLocaleEnglishFlag, ?DataLocaleEnglishFlagEnd - ?DataLocaleEnglishFlag, #False)
      misc::extractBinary(path$ + "de.locale", ?DataLocaleGerman, ?DataLocaleGermanEnd - ?DataLocaleGerman, #True)
      misc::extractBinary(path$ + "de.png", ?DataLocaleGermanFlag, ?DataLocaleGermanFlagEnd - ?DataLocaleGermanFlag, #False)
      
      ; load fallback (EN)
      ClearMap(localeEN$())
      loadLocale("en", localeEN$())
      
      init = #True
    EndIf
  EndProcedure
  
  Procedure listAvailable(Map locale$())
    debugger::Add("locale::listAvailable()")
    Protected dir.i
    Protected file$, lang$, name$
    
    ClearMap(locale$())
    
    dir = ExamineDirectory(#PB_Any, "locale", "*.locale")
    If dir
      While NextDirectoryEntry(dir)
        file$ = DirectoryEntryName(dir)
        lang$ = GetFilePart(file$, #PB_FileSystem_NoExtension)
        debugger::Add("found localisation file "+file$)
        If Not MatchRegularExpression(RegExpAlpha, lang$)
          debugger::Add(lang$ + " does not match convention")
          Continue
        EndIf
        If OpenPreferences(misc::Path("locale")+file$)
          name$ = ReadPreferenceString("locale", "")
          ClosePreferences()
          If name$ <> ""
            debugger::Add("add localisation to list: "+lang$+" = "+name$)
            locale$(lang$) = name$
          EndIf
        EndIf
      Wend
      ProcedureReturn #True
    Else
      debugger::Add("error examine directory 'localisation'")
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure use(locale$)
    debugger::Add("locale::use("+locale$+")")
    
    current_locale$ = locale$
    ClearMap(locale$())
    
    If locale$ = "en"
      ; no need to load en, as fallback = en
      CopyMap(localeEN$(), locale$())
      ProcedureReturn #True
    EndIf
    
    If OpenPreferences(path$ + locale$ + ".locale")
      debugger::Add("locale:: use locale "+locale$+" ("+ReadPreferenceString("locale","")+")")
      
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
      debugger::add("locale:: locale '" + locale$ + "' can not be opened! use fallback locale (en)")
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure.s getEx(group$, string$, Map var$())
    Protected out$, key$
    
    If group$ = "" Or string$ = ""
      ProcedureReturn ""
    EndIf
    
    key$ = group$+"/"+string$
    out$ = locale$(key$)
    If out$ = ""
      debugger::Add("locale:: failed to load '"+group$+"/"+string$+"' from '"+current_locale$+"'")
      out$ = localeEN$(key$)
      If out$ = ""
        debugger::Add("locale:: failed to load fallback for '"+key$+"'")
        out$ = "<"+key$+">"
        If group$ = "category"
          out$ = string$
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
  
  Procedure showFlag(locale$, ImageGadget)
    Static image
    
    SetGadgetState(ImageGadget, 0)
    If image
      FreeImage(image)
      image = 0
    EndIf
    
    image = LoadImage(#PB_Any, path$ + locale$ + ".png")
    If image 
      ResizeImage(image, GadgetWidth(ImageGadget), GadgetHeight(ImageGadget), #PB_Image_Raw)
      SetGadgetState(ImageGadget, ImageID(image))
    EndIf
  EndProcedure
  
  DataSection
    DataLocaleEnglish:
    IncludeBinary "locale/en.locale"
    DataLocaleEnglishEnd:
    DataLocaleEnglishFlag:
    IncludeBinary "locale/en.png"
    DataLocaleEnglishFlagEnd:
    
    DataLocaleGerman:
    IncludeBinary "locale/de.locale"
    DataLocaleGermanEnd:
    DataLocaleGermanFlag:
    IncludeBinary "locale/de.png"
    DataLocaleGermanFlagEnd:
  EndDataSection
  
  init() ; call init when loading module
EndModule


; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 183
; FirstLine = 26
; Folding = P5
; EnableUnicode
; EnableXP