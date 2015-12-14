XIncludeFile "module_debugger.pbi"

DeclareModule aes
  EnableExplicit
  
  Declare encrypt(*buffer, length)
  Declare decrypt(*buffer, length)
  
  Declare.s encryptString(string$)
  Declare.s decryptString(string$)
EndDeclareModule

Module aes
  DataSection
    key_aes:  ; 256 bit aes key
    IncludeBinary "key.aes"
  EndDataSection
  
  Procedure encrypt(*buffer, length)
    debugger::add("aes::encrypt()")
    If Not *buffer Or Not length
      ProcedureReturn #False
    EndIf
    
    Protected *out
    
    *out = AllocateMemory(length)
    If Not AESEncoder(*buffer, *out, length, ?key_aes, 256, #Null, #PB_Cipher_ECB)
      debugger::add("          ERROR: failed to encode memory")
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    CopyMemory(*out, *buffer, length)
    FreeMemory(*out)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure decrypt(*buffer, length)
    debugger::add("aes::decrypt()")
    If Not *buffer Or Not length
      ProcedureReturn #False
    EndIf
    
    Protected *out
    
    *out = AllocateMemory(length)
    If Not AESDecoder(*buffer, *out, length, ?key_aes, 256, #Null, #PB_Cipher_ECB)
      debugger::add("          ERROR: failed to decode memory")
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    CopyMemory(*out, *buffer, length)
    FreeMemory(*out)
    
    ProcedureReturn #True
  EndProcedure
  
  
  Procedure.s encryptString(string$)
    debugger::add("aes::encryptString()")
    Protected *buffer, len, *out, out$
    
    len = StringByteLength(string$)
    *buffer = AllocateMemory(len)
    If *buffer
      PokeS(*buffer, string$, len)
      If encrypt(*buffer, len)
        *out = AllocateMemory(len*2)
        If *out
          If Base64Encoder(*buffer, len, *out, len*2)
            out$ = PeekS(*out, len*2, #PB_Ascii)
            FreeMemory(*out)
          Else
            debugger::add("          ERROR: failed to allocate base64 encode memory")
          EndIf
        Else
          debugger::add("          ERROR: failed to allocate output memory")
        EndIf
      Else
        debugger::add("          ERROR: failed to encrypt string")
      EndIf
      FreeMemory(*buffer)
    Else
      debugger::add("          ERROR: failed to allocate input memory")
    EndIf
    ProcedureReturn out$
  EndProcedure
  
  Procedure.s decryptString(string$)
    debugger::add("aes::decryptString()")
    Protected *buffer, len, *out, out$
    
    len = StringByteLength(string$)
    *buffer = AllocateMemory(len)
    If *buffer
      ; write ASCII coded Base64 string to *buffer
      len = PokeS(*buffer, string$, StringByteLength(string$, #PB_Ascii), #PB_Ascii|#PB_String_NoZero)
      *out = AllocateMemory(len)
      If *out
        ; *buffer contains Base64 (ASCII)
        len = Base64Decoder(*buffer, len, *out, len)
        ; *out points to memory area with AES encrypted data
        If decrypt(*out, len)
          out$ = PeekS(*out, len)
        Else
          debugger::add("          ERROR: failed to decrypt string")
        EndIf
        FreeMemory(*out)
      Else
        debugger::add("          ERROR: failed to allocate memory")
      EndIf
      FreeMemory(*buffer)
    Else
      debugger::add("          ERROR: failed to allocate memory")
    EndIf
    ProcedureReturn out$
  EndProcedure
  
EndModule