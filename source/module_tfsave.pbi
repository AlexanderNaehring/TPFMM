DeclareModule tfsave
  EnableExplicit
  
  Declare readInfo(file$)
  
  Structure mod
    id$
    name$
    unknown1.l
    unknown2.l
    
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
    money.l
    List mods.mod()
    achievements.b
    List settings.setting()
    
    fileSize.q
    fileSizeUncompressed.q
  EndStructure
  
EndDeclareModule

XIncludeFile "module_misc.pbi"
XIncludeFile "module_debugger.pbi"

Module tfsave
  UseModule debugger
  
  #lz4$ = "lz4/lz4_v1_8_2_win64/lz4.exe"
  misc::useBinary(#lz4$)
  
  Procedure readInfo(file$)
    deb("tfsave:: readInfo("+file$+")")
    Protected p, file
    Protected pos, numMods, i, len, numSettings
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
        If ReadString(file, #PB_Ascii, 4) = "tf**"
          *info = AllocateStructure(tfsave)
          
          *info\fileSize = FileSize(file$)
          *info\fileSizeUncompressed = FileSize(tmpFile2$)
          
          *info\version     = ReadLong(file)
          If *info\version = 103
            *info\difficulty  = ReadLong(file)
            *info\startYear   = ReadLong(file)
            *info\numTilesX   = ReadLong(file)
            *info\numTilesY   = ReadLong(file)
            ReadLong(file) ; unknown
            *info\money       = ReadLong(file) ; unknown
            ReadLong(file) ; unknown
            
            ; num mods
            numMods = ReadLong(file)
            ClearList(*info\mods())
            If numMods > 0
  ;             ReDim *info\mods(numMods-1)
              ; mod names
              For i = 0 To numMods-1
                AddElement(*info\mods())
                len = ReadLong(file)
                pos = Loc(file)
                *buffer = AllocateMemory(len)
                ReadData(file, *buffer, len) ; do not directly read string, as readString might not read exactly "len" bytes
                *info\mods()\name$ = PeekS(*buffer, Len, #PB_UTF8)
                FreeMemory(*buffer)
                *info\mods()\unknown1 = ReadLong(file) ; (?)
              Next
            EndIf
            
            *info\achievements = ReadByte(file)
            
            ; mod folder names
            
            numMods = ReadLong(file)
            If numMods > 0
              If numMods <> ListSize(*info\mods())
                Debug "error: "+numMods+" <> "+Str(ListSize(*info\mods()))
              EndIf
              
              ; mod names
              For i = 0 To ListSize(*info\mods())-1
                SelectElement(*info\mods(), i)
                len = ReadLong(file)
                *buffer = AllocateMemory(len)
                ReadData(file, *buffer, len)
                *info\mods()\id$ = PeekS(*buffer, Len, #PB_UTF8)
                FreeMemory(*buffer)
                *info\mods()\unknown2 = ReadLong(file); mod location (workshop, staging, etc...?)
              Next
            EndIf
            
            ; game settings
            numSettings = ReadLong(file)
            ClearList(*info\settings())
            If numSettings > 0
  ;             ReDim *info\settings(numSettings-1)
              For i = 0 To numSettings-1
                AddElement(*info\settings())
                len = ReadLong(file)
                *buffer = AllocateMemory(len)
                ReadData(file, *buffer, len) ; do not directly read string, as readString might not read exactly "len" bytes
                *info\settings()\key$ = PeekS(*buffer, Len, #PB_UTF8)
                FreeMemory(*buffer)
                len = ReadLong(file)
                *buffer = AllocateMemory(len)
                ReadData(file, *buffer, len) ; do not directly read string, as readString might not read exactly "len" bytes
                *info\settings()\value$ = PeekS(*buffer, Len, #PB_UTF8)
                FreeMemory(*buffer)
              Next
            EndIf
          Else
            deb("tfsave:: TF save version "+*info\version+" unknown. Abort.")
          EndIf
        Else
          deb("tfsave:: no TF save recognized. Abort.")
        EndIf
        
        CloseFile(file)
      EndIf
      
      DeleteFile(tmpFile1$)
      DeleteFile(tmpFile2$)
    EndIf
    
    ProcedureReturn *info
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
        For i = 0 To ArraySize(*info\mods()) -1
          Debug ~"\t\t"+*info\mods(i)\id$+~"\t("+*info\mods(i)\name$+")"
        Next
        Debug ~"\tsettings:"
        For i = 0 To ArraySize(*info\settings()) -1
          Debug ~"\t\t"+*info\settings(i)\key$+~"\t= "+*info\settings(i)\value$
        Next
      Else
        Debug "could not read savegame"
      EndIf
      Debug "extracted savegame information in "+StrF(time/1000, 2)+" seconds"
    Wend
  EndIf
      
  
  
  
CompilerEndIf
