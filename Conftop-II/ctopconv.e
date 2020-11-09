/*
** conftop data file coverter
*/
  MODULE 'dos/dos'

ENUM ERR_INVALID_PARAMS=1,ERR_INVALID_DIR,ERR_NO_CONFTOP_DATA,ERR_NO_CTOP_DATA

PROC convertToBCD(invalue,outArray: PTR TO CHAR)
  DEF shift,i

  FOR i:=0 TO 7
    outArray[i]:=0
  ENDFOR

  FOR shift:=0 TO 31
    FOR i:=0 TO 7
      IF (outArray[i] AND $F0)>=$50 THEN outArray[i]:=outArray[i]+$30
      IF (outArray[i] AND $F)>=$5 THEN outArray[i]:=outArray[i]+$3
    ENDFOR
    FOR i:=0 TO 6
      outArray[i]:=Shl(outArray[i],1)
      IF outArray[i+1] AND $80
        outArray[i]:=outArray[i] OR 1
      ENDIF
    ENDFOR
    outArray[7]:=Shl(outArray[7],1)
    IF (invalue AND $80000000)
      outArray[7]:=outArray[7] OR 1
    ENDIF
    invalue:=Shl(invalue,1)
  ENDFOR
ENDPROC

PROC main() HANDLE

  DEF myargs:PTR TO LONG,rdargs
  DEF confPathName[255]:STRING
  DEF confLock=0
  DEF oldDir=-1
  DEF oldName[40]:ARRAY OF CHAR
  DEF oldLocation[40]:ARRAY OF CHAR
  DEF oldBytes,oldFiles
  DEF oldBytesBCD[8]:ARRAY OF CHAR
  DEF copyTop=FALSE,copyPeriod=FALSE,copyCurrent=FALSE
  DEF r,i
  
  DEF fh1=0,fh2=0

  WriteF('ConfTop-II data file converter by REbEL/QTX\n\n')

  myargs:=[0,0,0,0]:LONG
  IF rdargs:=ReadArgs('confpath/A,Top/S,Last/S,Current/S',myargs,NIL)
    IF myargs[0]<>NIL
      StrCopy(confPathName,myargs[0],255)
    ENDIF
    IF myargs[1]<>NIL 
      copyTop:=TRUE
    ENDIF
    IF myargs[2]<>NIL 
      copyPeriod:=TRUE
    ENDIF
    IF myargs[3]<>NIL 
      copyCurrent:=TRUE
    ENDIF
    FreeArgs(rdargs)
  ELSE
    Raise(ERR_INVALID_PARAMS)
  ENDIF
  
  confLock:=Lock(confPathName,ACCESS_READ)
  IF confLock=NIL THEN Raise(ERR_INVALID_DIR)
  
  oldDir:=CurrentDir(confLock)
  
  fh1:=Open('conftop.data',MODE_OLDFILE)
  IF fh1=NIL THEN Raise(ERR_NO_CONFTOP_DATA)
  
  IF FileLength('ctop.data')=-1 THEN Raise(ERR_NO_CTOP_DATA)
  
  fh2:=Open('ctop.data',MODE_READWRITE)
  IF fh2=NIL THEN Raise(ERR_NO_CTOP_DATA)

  WriteF('Copying..')

  IF copyTop
    Seek(fh1,214,OFFSET_BEGINNING)
    Read(fh1,oldName,40)
    Read(fh1,{oldBytes},4)
    convertToBCD(oldBytes,oldBytesBCD)
    Read(fh1,{oldFiles},4)
    Seek(fh2,8,OFFSET_BEGINNING)
    Write(fh2,oldName,32)
    Write(fh2,oldBytesBCD,8)
    Write(fh2,{oldFiles},4)
  ENDIF

  IF copyPeriod
    Seek(fh1,166,OFFSET_BEGINNING)
    Read(fh1,oldName,40)
    Read(fh1,{oldBytes},4)
    convertToBCD(oldBytes,oldBytesBCD)
    Read(fh1,{oldFiles},4)
    Seek(fh2,52,OFFSET_BEGINNING)
    Write(fh2,oldName,32)
    Write(fh2,oldBytesBCD,8)
    Write(fh2,{oldFiles},4)
  ENDIF
  
  IF copyCurrent
    Seek(fh1,262,OFFSET_BEGINNING)
    REPEAT
      r:=Read(fh1,oldName,40)
      IF r=40
        r:=r+Read(fh1,oldLocation,40)
        r:=r+Read(fh1,{oldBytes},4)
        r:=r+Read(fh1,{oldFiles},4)
        IF r=88
          FOR i:=1 TO oldFiles
            Write(fh2,oldName,32)
            Write(fh2,oldLocation,30)
            Write(fh2,{oldBytes},4)
            oldBytes:=0
          ENDFOR
        ENDIF
      ENDIF
    UNTIL r<>88
  ENDIF
  WriteF('Done\n')

EXCEPT DO
  IF fh1<>NIL THEN Close(fh1)
  IF fh2<>NIL THEN Close(fh2)
  IF oldDir<>-1 THEN CurrentDir(oldDir)
  IF confLock<>NIL THEN UnLock(confLock)
  SELECT exception
    CASE ERR_INVALID_PARAMS
      WriteF('Incorrect parameters\n')
    CASE ERR_INVALID_DIR
      WriteF('Error specified path does not exist\n')
    CASE ERR_NO_CONFTOP_DATA
      WriteF('Error opening conftop.data\n')
    CASE ERR_NO_CTOP_DATA
      WriteF('Error opening ctop.data\n')
    ENDSELECT
ENDPROC