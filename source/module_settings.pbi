XIncludeFile "module_debugger.pbi"

DeclareModule settings
  EnableExplicit
  
  Structure window
    x.i
    y.i
    width.i
    height.i
  EndStructure
  
  Structure settings
    TF$
    locale$
    window.window
  EndStructure
  
  Declare load()
  Declare save()
  
EndDeclareModule settings

Module settings
  #SETTINGS_FILE = "TFMM.json"
  
  
  ;----------------------------------------------------------------------------
  ;--------------------------------- PRIVATE ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure load_default()
    debugger::add("settings::load_default()")
    
  EndProcedure
  
  Procedure load_ini(file$)
    debugger::add("settings::load_ini("+file$+")")
    
    OpenPreferences("TFMM.ini")
    
    ClosePreferences()
  EndProcedure
  
  Procedure load_json(file$)
    debugger::add("settings::load_json("+file$+")")
    
    Protected json
    json = LoadJSON(#PB_Any, #SETTINGS_FILE)
    If json
      ExtractJSONStructure(JSONValue(json), @settings, settings)
    Else ; json file not loaded
      ProcedureReturn load_default()
    EndIf
  EndProcedure
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure load()
    debugger::add("settings::load()")
    
    If FileSize("TFMM.ini") >= 0
      If FileSize(#SETTINGS_FILE) >= 0
        debugger::add("settings::load() - TFMM.ini file found but new configuration file already present > delete TFMM.ini")
        DeleteFile("TFMM.ini")
      Else
        debugger::add("settings::load() - TFMM.ini file found > load configuration and translate to new format")
        load_ini("TFMM.ini")
        save() ; save configuration as loaded from TFMM.ini
        DeleteFile("TFMM.ini")
        ProcedureReturn #True
      EndIf
    EndIf
    
    ProcedureReturn load_json(#SETTINGS_FILE)
  EndProcedure
  
  Procedure save()
    debugger::add("settings::save()")
    Protected json
    json = CreateJSON(#PB_Any)
    If json
      InsertJSONStructure(JSONValue(json), @settings, settings)
      If SaveJSON(json, #SETTINGS_FILE, #PB_JSON_PrettyPrint)
        debugger::add("settings::save() - successfull")
        ProcedureReturn #True
      Else
        debugger::add("settings::save() - failed to save to file {"+#SETTINGS_FILE+"}")
        ProcedureReturn #False
      EndIf
    EndIf
  EndProcedure
  
  
EndModule settings
