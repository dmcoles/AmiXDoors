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
  DEF activity[20]:STRING
  DEF status[20]:STRING
  
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

  
  IF Val(tdat[0])>0
    n:=Val(tdat[3])+1
    StrCopy(status,'ON-LINE')
  ELSE
    n:=0
    StrCopy(status,'OFFLINE')
  ENDIF
  
  StrCopy(activity,'[32mNUL')
  SELECT n
    CASE 0
      StrCopy(activity,'[32mNUL[0m')
    CASE 1
      StrCopy(activity,'[32mLOW[0m')
    CASE 2
      StrCopy(activity,'[33mMED[0m')
    CASE 3
      StrCopy(activity,'[31m HI[0m')
  ENDSELECT
  StringF(tempstr,'[0mM[36mRC[0m[\s] BBS[\s[3]] Rms[\s[3]] Usr[\s[3]] Act[\s][0m',status,tdat[0],tdat[1],tdat[2],activity)
  WriteStr(diface,tempstr,LF)
  DisposeLink(tdat)

EXCEPT DO
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC