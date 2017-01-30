DeclareModule registry
  Declare.s Registry_GetString(hKey, subKey$, valueName$)
EndDeclareModule

Module registry
  Procedure.s Registry_GetString(hKey, subKey$, valueName$)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      Protected errorCode = #ERROR_SUCCESS, result$, hKey1, bufferSize, type, value.q
      Debug "access "+subKey$
      errorCode = RegOpenKeyEx_(hKey, subKey$, 0, #KEY_READ|#KEY_WOW64_64KEY, @hKey1)
      If errorCode = #ERROR_SUCCESS
        Debug "success"
        If hKey1
          errorCode = RegQueryValueEx_(hKey1, valueName$, 0, @type, 0, @bufferSize)
          If errorCode = #ERROR_SUCCESS 
            If bufferSize
              value = AllocateMemory(buffersize)
              If value
                errorCode = RegQueryValueEx_(hKey1, valueName$, 0, 0, value, @bufferSize)
                If errorCode = #ERROR_SUCCESS
                  result$ = PeekS(value)
                  Debug result$
                EndIf
                FreeMemory(value)
              Else
                errorCode = #ERROR_NOT_ENOUGH_MEMORY
                Debug "Not enough memory for value"
              EndIf
            EndIf
          Else
            Debug "Registry error query value"
          EndIf
          RegCloseKey_(hKey1)
        Else
          Debug "Error getting key reference"
        EndIf
      Else
        Protected error$ = Space(1024)
        FormatMessage_(#FORMAT_MESSAGE_FROM_SYSTEM , 0, ErrorCode, 0, @error$, 1024, #Null)
        Debug "Registry Error "+errorCode+" '"+Trim(error$)+"'"
      EndIf
      ProcedureReturn result$
    CompilerElse
      ProcedureReturn ""
    CompilerEndIf
  EndProcedure
EndModule