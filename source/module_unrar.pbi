; modified from http://www.purebasic.fr/english/viewtopic.php?f=40&t=56876

XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"
XIncludeFile "module_mods.h.pbi"
XIncludeFile "module_aes.pbi"

DeclareModule unrar
  #ERAR_SUCCESS             = 0
  #ERAR_END_ARCHIVE         = 10
  #ERAR_NO_MEMORY           = 11
  #ERAR_BAD_DATA            = 12
  #ERAR_BAD_ARCHIVE         = 13
  #ERAR_UNKNOWN_FORMAT      = 14
  #ERAR_EOPEN               = 15
  #ERAR_ECREATE             = 16
  #ERAR_ECLOSE              = 17
  #ERAR_EREAD               = 18
  #ERAR_EWRITE              = 19
  #ERAR_SMALL_BUF           = 20
  #ERAR_UNKNOWN             = 21
  #ERAR_MISSING_PASSWORD    = 22
  
  #RAR_OM_LIST              = 0
  #RAR_OM_EXTRACT           = 1
  #RAR_OM_LIST_INCSPLIT     = 2
  
  #RAR_SKIP                 = 0
  #RAR_TEST                 = 1
  #RAR_EXTRACT              = 2
  
  #RAR_VOL_ASK              = 0
  #RAR_VOL_NOTIFY           = 1
  
  #RAR_DLL_VERSION          = 6
  
  #RAR_HASH_NONE            = 0
  #RAR_HASH_CRC32           = 1
  #RAR_HASH_BLAKE2          = 2
  
  #RHDF_SPLITBEFORE         = $01
  #RHDF_SPLITAFTER          = $02
  #RHDF_ENCRYPTED           = $04
  #RHDF_SOLID               = $10
  #RHDF_DIRECTORY           = $20

  Enumeration
    #UCM_CHANGEVOLUME
    #UCM_PROCESSDATA
    #UCM_NEEDPASSWORD
    #UCM_CHANGEVOLUMEW
    #UCM_NEEDPASSWORDW
  EndEnumeration
  
  Structure RARHeaderDataEx
    ArcName.b[1024]
    ArcNameW.w[1024]
    FileName.b[1024]
    FileNameW.w[1024]
    Flags.l
    PackSize.q
    UnpSize.q
    HostOS.l
    FileCRC.l
    FileTime.l
    UnpVer.l
    Method.l
    FileAttr.l
    *CmtBuf
    CmtBufSize.l
    CmtSize.l
    CmtState.l
    DictSize.l
    HashType.l
    Hash.b[32]
    Reserved.l[1014]
  EndStructure
  
  Structure RAROpenArchiveDataEx
    *ArcName
    *ArcNameW
    OpenMode.l
    OpenResult.l
    *CmtBuf
    CmtBufSize.l
    CmtSize.l
    CmtState.l
    Flags.l
    *Callback
    UserData.i
    Reserved.l[28]
  EndStructure

  Prototype UNRARCALLBACK(msg, UserData, P1, P2)
  Prototype CHANGEVOLPROC(ArcName.s, Mode)
  Prototype PROCESSDATAPROC(*Addr, Size)
  Prototype RAROpenArchive(*ArchiveData.RAROpenArchiveDataEx)
  Prototype RARCloseArchive(hArcData)
  Prototype RARReadHeader(hArcData, *HeaderData.RARHeaderDataEx)
  Prototype RARProcessFile(hArcData, Operation, DestPath.s, DestName.s)
  Prototype RARSetCallback(hArcData, *Callback.UNRARCALLBACK, UserData)
  Prototype RARSetChangeVolProc(hArcData, *ChangeVolProc.CHANGEVOLPROC)
  Prototype RARSetProcessDataProc(hArcData, *ProcessDataProc.PROCESSDATAPROC)
  Prototype RARSetPassword(hArcData, Password.p-ascii)
  Prototype RARGetDllVersion()
  
  Global RAROpenArchive.RAROpenArchive
  Global RARProcessFile.RARProcessFile
  Global RAROpenArchive.RAROpenArchive
  Global RARProcessFile.RARProcessFile
  Global RARReadHeader.RARReadHeader
  Global RARCloseArchive.RARCloseArchive
  Global RARSetCallback.RARSetCallback
  Global RARSetChangeVolProc.RARSetChangeVolProc
  Global RARSetProcessDataProc.RARSetProcessDataProc
  Global RARSetPassword.RARSetPassword
  Global RARGetDllVersion.RARGetDllVersion
  
  Declare OpenRar(File$, *mod, mode = #RAR_OM_EXTRACT)
EndDeclareModule

Module unrar
  EnableExplicit
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    
    Define DLL
    
    CompilerIf #PB_Compiler_Processor = #PB_Processor_x64
      DLL = OpenLibrary(#PB_Any, "unrar64.dll") ; windows will automatically search the system folders, current path and program path
    CompilerElse
      DataSection
        DataUnrar:
        IncludeBinary "unrar.dll"
        DataUnrarEnd:
      EndDataSection
      misc::extractBinary("unrar.dll", ?DataUnrar, ?DataUnrarEnd - ?DataUnrar, #False)
      
      DLL = OpenLibrary(#PB_Any, "unrar.dll")
    CompilerEndIf
    
    If DLL
      RAROpenArchive        = GetFunction(DLL, "RAROpenArchiveEx")
      CompilerIf #PB_Compiler_Unicode
      RARProcessFile        = GetFunction(DLL, "RARProcessFileW")
      CompilerElse
      RARProcessFile        = GetFunction(DLL, "RARProcessFile")
      CompilerEndIf
      RARReadHeader         = GetFunction(DLL, "RARReadHeaderEx")
      RARCloseArchive       = GetFunction(DLL, "RARCloseArchive")
      RARSetCallback        = GetFunction(DLL, "RARSetCallback")
      RARSetChangeVolProc   = GetFunction(DLL, "RARSetChangeVolProc")
      RARSetProcessDataProc = GetFunction(DLL, "RARSetProcessDataProc")
      RARSetPassword        = GetFunction(DLL, "RARSetPassword")
      RARGetDllVersion      = GetFunction(DLL, "RARGetDllVersion")
    Else
      MessageRequester("Error", "unrar.dll not found! RAR Files cannot be opened.")
    EndIf
    
    
    
    Structure userdata
      pwRequired.b
      password$
    EndStructure
    
    Procedure Callback(msg, *UserData.userdata, *P1, *P2)
      Protected pw$
      Select msg
        Case #UCM_NEEDPASSWORDW ; unicode password callback
          *UserData\pwRequired = #True
          pw$ = *UserData\password$
          If pw$ = ""
            ProcedureReturn -1
          EndIf
          If Len(pw$) > *P2
            pw$ = Left(pw$, *P2)
          EndIf
          PokeS(*P1, pw$) ; push password to password buffer of RAR library
          ProcedureReturn 1 ; signal to rar library to try this password
      EndSelect
    EndProcedure
    
    Procedure OpenRar(File$, *mod.mods::mod, mode = #RAR_OM_EXTRACT)
      debugger::add("unrar::OpenRar("+File$+", "+Str(mode)+")")
      Protected raropen.RAROpenArchiveDataEx
      Protected hRAR
      Protected NewMap passwords(), password$, passwordFile
      
      CompilerIf #PB_Compiler_Unicode
        raropen\ArcNameW = @File$
      CompilerElse
        raropen\ArcName = @File$
      CompilerEndIf
      
      
      ; try to open the archive without password first
      Protected userdata.userdata
      userdata\pwRequired = 0
      userdata\password$  = ""
      raropen\OpenMode = mode
      raropen\Callback = @Callback()
      raropen\UserData = @userdata
      
      hRAR = RAROpenArchive(raropen)
      
      If Not hRAR And Not userdata\pwRequired
        debugger::add("          ERROR: Cannot open file!")
        ProcedureReturn #False
      EndIf
      
      If Not hRAR And userdata\pwRequired
        debugger::add("          Password required")
        ; password required, add passwords to try to a list
        ; try password stored in mod info if available
        If *mod\archive\password$
          passwords(*mod\archive\password$) = 1
        EndIf
        
        ; read passwords from password list file
        passwordFile = OpenFile(#PB_Any, "passwords.list")
        If passwordFile
          While Not Eof(passwordFile)
            passwords(ReadString(passwordFile)) = 1
          Wend
          CloseFile(passwordFile)
        EndIf
        *mod\archive\password$ = "" ; reset stored PW
        
        ; pre-defined passwords:
        ; Nordic DLC:
        passwords("E9sLDEP87impfL7PPIDSY4AH+Ym6LQ==") = 1
        
        ; try different passwords now
        ForEach passwords()
          userdata\password$ = aes::decryptString(MapKey(passwords()))
          hRAR = RAROpenArchive(raropen)
          If hRAR
            Break
          EndIf
        Next
        
        If Not hRAR
          debugger::add("          Ask user for password to open file")
          ; ask user for password
          Repeat
            password$ = InputRequester("Archive password", "Please specify the password to open the archive", "", #PB_InputRequester_Password)
            If password$ = ""
              Break
            EndIf
            
            userdata\password$ = password$
            hRAR = RAROpenArchive(raropen)
            If hRAR
              Break
            EndIf
          Until hRAR Or password$ = ""
        EndIf
        
        If hRAR
          ; open successfull, store pw in mod info
          *mod\archive\password$ = aes::encryptString(userdata\password$)
          passwords(*mod\archive\password$) = 1
          passwordFile = CreateFile(#PB_Any, "passwords.list")
          If passwordFile
            ForEach passwords()
              WriteStringN(passwordFile, MapKey(passwords()))
            Next
            CloseFile(passwordFile)
          EndIf
        EndIf
        
        ProcedureReturn hRAR
      EndIf
      
      ProcedureReturn hRAR
    EndProcedure
    
    
  CompilerElse ; Linux / Mac
    
    Procedure OpenRar(File$, *mod, mode = #RAR_OM_EXTRACT)
      ProcedureReturn #False
    EndProcedure
    
  CompilerEndIf
EndModule