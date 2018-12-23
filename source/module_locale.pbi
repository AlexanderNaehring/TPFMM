EnableExplicit
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_misc.pbi"

DeclareModule locale
  EnableExplicit
  #SEP = Chr(23)
  
  Structure info
    locale$
    name$
    flag.i
  EndStructure
  
  Declare LoadLocales()
  Declare getLocales(List locales$())
  Declare setLocale(locale$)
  Declare.s getCurrentLocale()
  Declare logStats()
  Declare.s _(key$, vars$="")
EndDeclareModule

Module locale
  UseModule debugger
  
  ; constants
  #Path$ = "locale/"
  
  ; Struct
  Structure locale
    name$
    author$
    flag.i
    Map strings$()
  EndStructure
  
  ; Globals
  Global l$
  Global NewMap locales.locale()
  
  Global NewMap missingStrings()
  Global NewMap stringCounter()
  
  ; Init
  misc::CreateDirectoryAll(#Path$)
  misc::useBinary(#Path$+"en.locale", #True)
  misc::useBinary(#Path$+"de.locale", #True)
  misc::useBinary(#Path$+"en.png", #True)
  misc::useBinary(#Path$+"de.png", #True)
  
  ;- PRIVATE
  Procedure LoadFlagImage(locale$)
    Protected flag$, im
    flag$ = #Path$+locale$+".png"
    If FileSize(flag$) > 0
      im = LoadImage(#PB_Any, flag$)
      If im And IsImage(im)
        im = misc::ResizeCenterImage(im, 20, 20)
        ProcedureReturn im
      EndIf
    EndIf
    
    deb("locale::getFlag() - could not load flag for "+locale$)
    ProcedureReturn #False
  EndProcedure
  
  ;- PUBLIC
  Procedure LoadLocales()
    Protected dir, file$, locale$
    Static RegExpAlpha
    If Not RegExpAlpha
      RegExpAlpha = CreateRegularExpression(#PB_Any, "^[A-Za-z]+$") ; only alpha in string!
    EndIf
    
    ForEach locales()
      If locales()\flag And IsImage(locales()\flag)
        FreeImage(locales()\flag)
      EndIf
    Next
    ClearMap(locales())
    
    dir = ExamineDirectory(#PB_Any, "locale", "*.locale")
    If dir
      While NextDirectoryEntry(dir)
        file$ = DirectoryEntryName(dir)
        locale$ = GetFilePart(file$, #PB_FileSystem_NoExtension)
        If Not MatchRegularExpression(RegExpAlpha, locale$)
          Continue
        EndIf
        If OpenPreferences(#Path$+file$)
          AddMapElement(locales(), locale$)
          locales(locale$)\name$ = ReadPreferenceString("locale", locale$)
          locales(locale$)\author$ = ReadPreferenceString("translator", "")
          locales(locale$)\flag = LoadFlagImage(locale$)
          
          ExaminePreferenceGroups()
          While NextPreferenceGroup()
            ExaminePreferenceKeys()
            While NextPreferenceKey()
              locales(locale$)\strings$(PreferenceGroupName()+"_"+PreferenceKeyName()) = PreferenceKeyValue()
              stringCounter(PreferenceGroupName()+"_"+PreferenceKeyName()) = 0
            Wend
          Wend
          ClosePreferences()
        EndIf
      Wend
      
      If MapSize(locales()) = 0
        deb("locales:: no localization file loaded!")
      EndIf
      If FindMapElement(locales(), "en")
        ; set default locale to en if available
        l$ = "en"
      EndIf
      
      ProcedureReturn MapSize(locales())
    Else
      deb("locale:: error examine directory '"+#Path$+"'")
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure getLocales(List lo.info())
    ClearList(lo())
    ForEach locales()
      AddElement(lo())
      lo()\locale$ = MapKey(locales())
      lo()\name$ = locales()\name$
      lo()\flag = locales()\flag
    Next
    SortStructuredList(lo(), #PB_Sort_Ascending, OffsetOf(info\locale$), #PB_String)
    ProcedureReturn ListSize(lo())
  EndProcedure
  
  Procedure setLocale(locale$)
    If FindMapElement(locales(), locale$)
      l$ = locale$
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
  Procedure.s getCurrentLocale()
    ProcedureReturn l$
  EndProcedure
  
  Procedure logStats()
    ; print all strings that have not been used during this program execution
    Protected out$
    out$ = "locale:: "
    out$ + "__unused strings__" + #CRLF$
    ForEach stringCounter()
      If stringCounter() = 0
        out$ + #TAB$ + "<"+MapKey(stringCounter())+">" + #CRLF$
      EndIf
    Next
    out$ + #CRLF$ + "__missing strings__" + #CRLF$
    ForEach missingStrings()
      out$ + #TAB$ + "<"+MapKey(missingStrings())+">" + #CRLF$
    Next
    deb(out$)
  EndProcedure
  
  Procedure.s _(key$, vars$="")
    Protected group$, out$
    
    If key$ = ""
      ProcedureReturn ""
    EndIf
    
    stringCounter(key$) + 1
    
    key$ = ReplaceString(key$, " ", "_")
    group$ = StringField(key$, 1, "_")
    
    If group$ = "category"
      group$ = "tags"
    EndIf
    
    out$ = locales(l$)\strings$(key$)
    
    If out$ = ""
      If group$ <> "tags"
        missingStrings(l$+"_"+key$) + 1
        If missingStrings(l$+"_"+key$) <= 1
          deb("locale:: failed to load '"+key$+"' from '"+l$+"'")
        EndIf
      EndIf
      
      out$ = locales("en")\strings$(key$)
      If out$ = ""
        If group$ = "tags"
          ; deb("locale::getEx() - cannot find tag '"+string$+"'")
          out$ = key$
        Else
          missingStrings("en_"+key$) + 1
          If missingStrings("en_"+key$) <= 1
            deb("locale:: failed to load fallback for '"+key$+"'")
          EndIf
          out$ = "<"+key$+">"
        EndIf
      EndIf
    EndIf
    
    out$ = ReplaceString(out$, "\n", #CRLF$)
    
    If vars$ ; replace variable names in the translation string
      Protected var$, i, pos
      For i = 1 To CountString(vars$, #SEP) + 1
        ; multiple vars are separated by #SEP
        var$ = StringField(vars$, i , #SEP)
        ; each var is of form "id=some string"
        ; the string might be any character, so do not use stringfield, but just search for first "=", as it cannot be part of the ID
        pos = FindString(var$, "=")
        out$ = ReplaceString(out$, "{"+Left(var$, pos-1)+"}", Mid(var$, pos+1))
      Next
    EndIf
    
    ProcedureReturn out$
  EndProcedure
  
EndModule