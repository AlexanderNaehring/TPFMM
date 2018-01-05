
DeclareModule pack
  EnableExplicit
  
  Declare create()
  Declare free(*pack)
  Declare open(file$)
  Declare save(*pack, file$)
  
  Declare getMods(*pack)
  Declare addMod(*pack, mod$)
  
  
EndDeclareModule



Module pack
  
  
  ;----------------------------------------------------------------------------
  ;---------------------------------- PUBLIC ----------------------------------
  ;----------------------------------------------------------------------------
  
  Procedure create(file$)
    ; create new (empty) *pack
    
  EndProcedure
  
  Procedure free(*pack)
    ; free up memory of pack file
    
  EndProcedure
  
  Procedure open(file$)
    ; open a pack file (json), return *pack
    
  EndProcedure
  
  Procedure save(*pack, file$)
    ; save list of mods/maps to a pack file
    
  EndProcedure
  
  Procedure getMods(*pack)
    ; get list of mods in pack
    
  EndProcedure
  
  Procedure addMod(*pack, mod$)
    ; add mod to specified *pack
    
  EndProcedure
  
  
EndModule
