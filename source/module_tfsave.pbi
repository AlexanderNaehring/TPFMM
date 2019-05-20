DeclareModule tfsave
  EnableExplicit
  
  Enumeration
    #ErrorNoError = 0
    #ErrorVersionUnknown
    #ErrorNotSaveFile
    #ErrorModNumberError
    #ErrorMemoryError
  EndEnumeration
  
  Structure mod
    id$
    name$
    unknown1.l
    
    *localmod
    *repofile
  EndStructure
  
  Structure setting
    key$
    value$
  EndStructure
  
  Structure tfsave
    version.l
    difficulty.l
    startYear.l
    numTilesX.l
    numTilesY.l
    unknown1.l
    money.q
    List mods.mod()
    achievements.b
    List settings.setting()
    
    error.b
    fileSize.q
    fileSizeUncompressed.q
  EndStructure
  
  Declare readInfo(file$)
  Declare freeInfo(*info.tfsave)
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"

Module tfsave
  UseModule debugger
  
  #lz4$ = "lz4/lz4_v1_8_2_win64/lz4.exe"
  misc::useBinary(#lz4$, #False)
  
  Procedure readInfo(file$)
    deb("tfsave:: readInfo("+file$+")")
    Protected p, file
    Protected pos, numMods, i, len, numSettings, version
    Protected *info.tfsave, *buffer
    Protected tmpFile1$, tmpFile2$
    *info = #Null
    
    If FileSize(file$) > 0
      tmpFile1$ = GetCurrentDirectory()+"/save.tmp1"
      tmpFile2$ = GetCurrentDirectory()+"/save.tmp2"
      
      DeleteFile(tmpFile1$) 
      DeleteFile(tmpFile2$)
      
      ; #PB_Program_Open|#PB_Program_Read|#PB_Program_Error
      p = RunProgram(#lz4$, "-d "+#DQUOTE$+file$+#DQUOTE$+" "+#DQUOTE$+tmpFile1$+#DQUOTE$, GetCurrentDirectory(), #PB_Program_Wait|#PB_Program_Hide)
      p = RunProgram(#lz4$, "--rm -d "+#DQUOTE$+tmpFile1$+#DQUOTE$+" "+#DQUOTE$+tmpFile2$+#DQUOTE$, GetCurrentDirectory(), #PB_Program_Wait|#PB_Program_Hide)
      
      file = OpenFile(#PB_Any, tmpFile2$)
      If file
        *info = AllocateStructure(tfsave)
        If ReadString(file, #PB_Ascii, 4) = "tf**"
          *info\error = #ErrorNoError ; init with no error
          *info\fileSize = FileSize(file$)
          *info\fileSizeUncompressed = FileSize(tmpFile2$)
          
          *info\version     = ReadLong(file)
          If *info\version = 103 Or 
             *info\version = 168 Or
             *info\version = 172
            *info\difficulty  = ReadLong(file)
            *info\startYear   = ReadLong(file)
            *info\numTilesX   = ReadLong(file)
            *info\numTilesY   = ReadLong(file)
            *info\unknown1    = ReadLong(file) ; unknown
            *info\money       = ReadQuad(file) ; ?
            
            ; num mods
            numMods = ReadLong(file)
            ClearList(*info\mods())
            If numMods > 0
              ; mod names
              For i = 0 To numMods-1
                AddElement(*info\mods())
                len = ReadLong(file)
                If len
                  *buffer = AllocateMemory(len)
                  If *buffer
                    ReadData(file, *buffer, len) ; do not directly read string, as readString might not read exactly "len" bytes
                    *info\mods()\name$ = PeekS(*buffer, Len, #PB_UTF8|#PB_ByteLength)
                    FreeMemory(*buffer)
                  Else
                    FileSeek(file, len, #PB_Relative)
                    *info\error = #ErrorMemoryError
                    deb("tfsave:: could not allocate memory ("+len+") for mod "+i)
                  EndIf
                Else
                  Debug "zero-string for name in mod "+i
                EndIf
                *info\mods()\unknown1 = ReadLong(file) ; (?)
              Next
            EndIf
            
            *info\achievements = ReadByte(file)
            
            ; mod folder names (id + version)
            numMods = ReadLong(file)
            If numMods > 0
              If numMods <> ListSize(*info\mods())
                *info\error = #ErrorModNumberError
                Debug "error: "+numMods+" <> "+Str(ListSize(*info\mods()))
              EndIf
              
              ; mod names
              For i = 0 To ListSize(*info\mods())-1
                SelectElement(*info\mods(), i)
                len = ReadLong(file)
                If len
                  *buffer = AllocateMemory(len)
                  If *buffer
                    ReadData(file, *buffer, len)
                    *info\mods()\id$ = PeekS(*buffer, Len, #PB_UTF8|#PB_ByteLength)
                    FreeMemory(*buffer)
                  Else
                    FileSeek(file, len, #PB_Relative)
                    *info\error = #ErrorMemoryError
                    deb("tfsave:: could not allocate memory ("+len+") for mod "+i)
                  EndIf
                Else
                  Debug "zero-string for id in mod "+i
                EndIf
                
                version = ReadLong(file)
                If version <> -1
                  *info\mods()\id$ + "_"+Str(version) ; version
                Else
                  Debug "mod "+*info\mods()\id$+" is deprecated"
                EndIf
              Next
            EndIf
            
            ; game settings
            numSettings = ReadLong(file)
            ClearList(*info\settings())
            If numSettings > 0
              For i = 0 To numSettings-1
                AddElement(*info\settings())
                len = ReadLong(file)
                *buffer = AllocateMemory(len)
                ReadData(file, *buffer, len) ; do not directly read string, as readString might not read exactly "len" bytes
                *info\settings()\key$ = PeekS(*buffer, Len, #PB_UTF8|#PB_ByteLength)
                FreeMemory(*buffer)
                len = ReadLong(file)
                *buffer = AllocateMemory(len)
                ReadData(file, *buffer, len) ; do not directly read string, as readString might not read exactly "len" bytes
                *info\settings()\value$ = PeekS(*buffer, Len, #PB_UTF8|#PB_ByteLength)
                FreeMemory(*buffer)
              Next
            EndIf
          Else
            *info\error = #ErrorVersionUnknown
            deb("tfsave:: TF save version "+*info\version+" unknown. Abort.")
          EndIf
        Else
          *info\error = #ErrorNotSaveFile
          deb("tfsave:: no TF save recognized. Abort.")
        EndIf
        
        CloseFile(file)
      EndIf
      
      DeleteFile(tmpFile1$)
      DeleteFile(tmpFile2$)
    EndIf
    
    ProcedureReturn *info
  EndProcedure
  
  Procedure freeInfo(*info.tfsave)
    FreeStructure(*info)
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  EnableExplicit
  
  Global path$ = "C:\Steam\userdata\34682574\446800\local\save"
  Global dir, file$, i
  Global *info.tfsave::tfsave
  Global time
  
  dir = ExamineDirectory(#PB_Any, path$, "*.sav")
  If IsDirectory(dir)
    While NextDirectoryEntry(dir)
      file$ = path$ + "\" + DirectoryEntryName(dir)
      Debug file$
      time = ElapsedMilliseconds()
      *info = tfsave::readInfo(file$)
      Debug "---------------------"
      time = ElapsedMilliseconds()-time
      
      If *info
        Debug ~"\tversion:\t"+*info\version
        Debug ~"\tdifficulty:\t"+*info\difficulty
        Debug ~"\tstartYear:\t"+*info\startYear
        Debug ~"\ttiles:\t"+*info\numTilesX+"x"+*info\numTilesY
        Debug ~"\tachievements:\t"+*info\achievements
        Debug ~"\tmods:"
        ForEach *info\mods()
          Debug ~"\t\t"+*info\mods()\id$+~"\t("+*info\mods()\name$+")"
        Next
        Debug ~"\tsettings:"
        ForEach *info\settings()
          Debug ~"\t\t"+*info\settings()\key$+~"\t= "+*info\settings()\value$
        Next
      Else
        Debug "could not read savegame"
      EndIf
      Debug "extracted savegame information in "+StrF(time/1000, 2)+" seconds"
    Wend
  EndIf
CompilerEndIf
