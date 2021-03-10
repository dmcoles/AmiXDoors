->MRC stats door

  MODULE 'AEDoor'                 /* Include libcalls & constants */
  MODULE 'dos/dos'

DEF diface

PROC splitBuffer(buffer,sep)
  DEF count=1
  DEF s=-1,l
  DEF tdat: PTR TO LONG
  
  l:=StrLen(buffer)
  WHILE(s:=InStr(buffer,sep,s+1))<>-1
    IF (s+1)<>l THEN count++
  ENDWHILE

  tdat:=List(count)
  
  ListAdd(tdat,[buffer])
  s:=-1
  WHILE(s:=InStr(buffer,sep,s+1))<>-1
    buffer[s]:=0
    IF (s+1)<>l THEN ListAdd(tdat,[buffer+s+1])
  ENDWHILE
  
ENDPROC tdat


PROC main() HANDLE
  DEF fh,n
  DEF stats[255]:STRING
  DEF tdat:PTR TO LONG
  DEF tempstr[255]:STRING
  DEF activity[10]:STRING
  
  IF aedoorbase:=OpenLibrary('AEDoor.library',1)
    diface:=CreateComm(arg[])     /* Establish Link   */
  ENDIF
  
  fh:=Open('env:mrcstats.dat',MODE_OLDFILE)
  StrCopy(stats,'0 0 0 0')
  IF fh<>0
    ReadStr(fh,stats)
    Close(fh)
  ENDIF
  tdat:=splitBuffer(stats,' ')

  WriteStr(diface,'[32m.-----------------------.',LF)
  WriteStr(diface,'|    [0mMRC Chat Status    [32m|',LF)
  IF Val(tdat[0])>0
    n:=Val(tdat[3])+1
    WriteStr(diface,'|        ON-LINE        |',LF)
  ELSE
    n:=0
    WriteStr(diface,'|        OFFLINE        |',LF)
  ENDIF
  WriteStr(diface,'| [37mBBS [32m| [37mRms [32m| [37mUsr [32m| [37mAct [32m|',LF)
  
  StrCopy(activity,'[32mNUL')
  SELECT n
    CASE 0
      StrCopy(activity,'[32mNUL')
    CASE 1
      StrCopy(activity,'[32mLOW')
    CASE 2
      StrCopy(activity,'[33mMED')
    CASE 3
      StrCopy(activity,'[31m HI')
  ENDSELECT
  StringF(tempstr,'| \s[3] | \s[3] | \s[3] | \s [32m|',tdat[0],tdat[1],tdat[2],activity)
  WriteStr(diface,tempstr,LF)
  WriteStr(diface,'`-----------------------''',LF)
  WriteStr(diface,'[0m',LF)
  DisposeLink(tdat)

EXCEPT DO
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC