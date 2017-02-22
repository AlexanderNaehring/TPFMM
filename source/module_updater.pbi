XIncludeFile "module_debugger.pbi"
XIncludeFile "module_locale.pbi"

DeclareModule updater
  EnableExplicit
  
  Global VERSION$ = "TPFMM 1.0." + #PB_Editor_BuildCount
  
EndDeclareModule


Module updater
  Global NewMap gadgets()
  InitNetwork()
  
EndModule


CompilerIf #PB_Compiler_IsMainFile
  Define event
  
    CreateThread(updater::@checkUpdate(), 1)
    HideWindow(updater::window, #False)
   
CompilerEndIf
