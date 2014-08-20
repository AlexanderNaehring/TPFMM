Procedure.s Registry_GetString(hKey, subKey$, valueName$)
  Protected errorCode = #ERROR_SUCCESS, result$, hKey1, bufferSize, type, value.q
  errorCode = RegOpenKeyEx_(hKey, subKey$, 0, #KEY_READ, @hKey1)
  If errorCode = #ERROR_SUCCESS
    If hKey1
      errorCode = RegQueryValueEx_(hKey1, valueName$, 0, @type, 0, @bufferSize)
      If errorCode = #ERROR_SUCCESS 
        If bufferSize
          value = AllocateMemory(buffersize)
          If value
            errorCode = RegQueryValueEx_(hKey1, valueName$, 0, 0, value, @bufferSize)
            If errorCode = #ERROR_SUCCESS
              result$ = PeekS(value)
            EndIf
            FreeMemory(value)
          Else
            errorCode = #ERROR_NOT_ENOUGH_MEMORY
            Debug "Not enough memory for value"
          EndIf
        EndIf
      EndIf
      RegCloseKey_(hKey1)
    Else
      Debug "Error getting key reference"
    EndIf
  Else
    Debug "Error opening registry key"
  EndIf
  ProcedureReturn result$  
EndProcedure
; IDE Options = PureBasic 5.30 (Windows - x64)
; CursorPosition = 29
; Folding = -
; EnableUnicode
; EnableXP