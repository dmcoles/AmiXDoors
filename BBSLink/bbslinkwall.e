/*
** bbslink door - requires /X 5.4
** Amiga E version
*/

  MODULE 'AEDoor'                 /* Include libcalls & constants */
  MODULE	'socket'
  MODULE	'net/netdb'
  MODULE	'net/in'
  MODULE  'dos/dos'
  MODULE  'devices/timer'

  MODULE  '*stringlist'
  MODULE  '*md5'

CONST BUFSIZE=8192

CONST ERR_FDSRANGE=$80000001

CONST FIONBIO=$8004667e

CONST TELNET_CONNECT=706

DEF serverHost[255]:STRING
DEF httpPort=80
DEF telnetPort=23
DEF timeout=10
DEF fds=NIL:PTR TO LONG

DEF syscode[255]:STRING
DEF authcode[255]:STRING
DEF schemecode[255]:STRING
DEF doorcode[255]:STRING
DEF scripttype[20]:STRING
DEF scriptver[20]:STRING
DEF userid

DEF diface=0
DEF strfield=0

PROC replacestr(sourcestring,searchtext,replacetext)
  DEF newstring,tempstring,oldpos, pos,len
  newstring:=String(255)
  tempstring:=String(255)
  len:=StrLen(searchtext) /* not estrlen since this is likely to be a hard coded constant */
  pos:=InStr(sourcestring,searchtext)
  IF pos<>-1
    oldpos:=0
    WHILE pos<>-1
      IF pos<>oldpos
        MidStr(tempstring,sourcestring,oldpos,pos-oldpos)
        StrAdd(newstring,tempstring)
      ENDIF
      StrAdd(newstring,replacetext)
      pos:=pos+len
      oldpos:=pos
      pos:=InStr(sourcestring,searchtext,oldpos)
    ENDWHILE
    pos:=EstrLen(sourcestring)
    IF pos<>oldpos
      MidStr(tempstring,sourcestring,oldpos,pos-oldpos)
      StrAdd(newstring,tempstring)
    ENDIF
    StrCopy(sourcestring,newstring)
  ENDIF
  DisposeLink(newstring)
  DisposeLink(tempstring)
ENDPROC

PROC urlencode(sourcestring)
  replacestr(sourcestring,'%','%25')

  replacestr(sourcestring,' ','%20')
  replacestr(sourcestring,'"','%22')
  replacestr(sourcestring,'#','%23')
  replacestr(sourcestring,'$','%24')
  replacestr(sourcestring,'&','%26')
  replacestr(sourcestring,'''','%27')
  replacestr(sourcestring,'(','%28')
  replacestr(sourcestring,')','%29')
  replacestr(sourcestring,'*','%2A')
  replacestr(sourcestring,'+','%2B')
  replacestr(sourcestring,',','%2C')
  replacestr(sourcestring,'-','%2D')
  replacestr(sourcestring,'.','%2E')
  replacestr(sourcestring,'/','%2F')
  replacestr(sourcestring,':','%3A')
  replacestr(sourcestring,';','%3B')
  replacestr(sourcestring,'<','%3C')
  replacestr(sourcestring,'=','%3D')
  replacestr(sourcestring,'>','%3E')
  replacestr(sourcestring,'?','%3F')
  replacestr(sourcestring,'@','%40')
  replacestr(sourcestring,'[','%5B')
  replacestr(sourcestring,'\\','%5C')
  replacestr(sourcestring,']','%5D')
  replacestr(sourcestring,'^','%5E')
  replacestr(sourcestring,'_','%5F')
  replacestr(sourcestring,'`','%60')
  replacestr(sourcestring,'{','%7B')  
  replacestr(sourcestring,'|','%7C')  
  replacestr(sourcestring,'}','%7D')  
  replacestr(sourcestring,'~','%7E')  
ENDPROC

PROC setSingleFDS(socketVal)
  DEF i,n
  
  n:=(socketVal/32)
  IF (n<0) OR (n>=32) THEN Raise(ERR_FDSRANGE)
  
  FOR i:=0 TO 31 DO fds[i]:=0
  fds[n]:=fds[n] OR (Shl(1,socketVal AND 31))
ENDPROC

/* trim spaces from both ends of a string and puts it back in the source estring*/
PROC fullTrim(src:PTR TO CHAR)
  DEF n,v=0
  DEF tempStr:PTR TO CHAR
  
  tempStr:=String(StrLen(src))
  
  StrCopy(tempStr,TrimStr(src))
  n:=EstrLen(tempStr)
  IF n>0 THEN v:=tempStr[n-1]
  WHILE (n>0) AND (v=" ")
    SetStr(tempStr,n-1)
    n:=EstrLen(tempStr)
    IF n>0 THEN v:=tempStr[n-1]
  ENDWHILE
  StrCopy(src,tempStr)
  DisposeLink(tempStr)
ENDPROC

PROC randomString(len,output:PTR TO CHAR)
  DEF i,s,r
  
  s:='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  StrCopy(output,'')
  FOR i:=1 TO len
   r:=Rnd(62)
   StrAdd(output,s+r,1)
  ENDFOR
ENDPROC

PROC parseConfigFile(configFileName:PTR TO CHAR, configNames:PTR TO stringlist, configValues:PTR TO stringlist)
  DEF fh,p,i
  DEF tempStr[255]:STRING
  DEF tempName[255]:STRING
  DEF tempValue[255]:STRING
  
  fh:=Open(configFileName,MODE_OLDFILE)
  IF fh<>0
    WHILE (ReadStr(fh,tempStr)>0) OR (StrLen(tempStr)>0)
      IF ((p:=InStr(tempStr,'='))>=0)
        StrCopy(tempName,tempStr,p)
        fullTrim(tempName)
        UpperStr(tempName)
        StrCopy(tempValue,tempStr+p+1)
        fullTrim(tempValue)
        FOR i:=0 TO configNames.count()-1
          IF StrCmp(tempName,configNames.item(i))
            configValues.setItem(i,tempValue)
          ENDIF
        ENDFOR
      ENDIF
    ENDWHILE
    Close(fh)
  ENDIF
ENDPROC

->returns system time converted to c time format
PROC getSystemTime()
  DEF currDate: datestamp
  DEF startds:PTR TO datestamp

  startds:=DateStamp(currDate)
  ->2922 days between 1/1/70 and 1/1/78

ENDPROC (Mul(Mul(startds.days+2922,1440),60)+(startds.minute*60)+(startds.tick/50))+21600,Mod(startds.tick,50)

PROC writeText(msg:PTR TO CHAR)
  IF diface THEN WriteStr(diface,msg,0)
ENDPROC

PROC cls()
  DEF temp[1]:STRING
  StringF(temp,'\c',12)
  writeText(temp)
ENDPROC

PROC yesNo()
  DEF strBuff[255]:STRING
  DEF key
  REPEAT
    IF diface
      key:=HotKey(diface,'')
      IF key=-1 THEN RETURN FALSE
    ENDIF
  UNTIL (key="Y") OR (key="y") OR (key="N") OR (key="n")
  IF (key="Y") OR (key="y")
    writeText('Y\b\n')
    RETURN TRUE
  ENDIF
  writeText('N\b\n')
ENDPROC FALSE

PROC showWall()
  DEF tempfile[20]:STRING
  DEF wallText
  DEF l,fh
  
  StrCopy(tempfile,'t:wall.txt')
  httpGet('/wall.php?action=show',tempfile)
  IF (l:=FileLength(tempfile))>0
    wallText:=String(l)
    fh:=Open(tempfile,MODE_OLDFILE)
    Read(fh,wallText,l)
    SetStr(wallText,l)
    Close(fh)
  ENDIF
  DeleteFile(tempfile)

  cls()
  writeText(wallText)
  DisposeLink(wallText)
  writeText('[0m\b\n')
ENDPROC

PROC sendToServer(action,data,result)
  DEF tempfile[20]:STRING
  DEF tempstr[500]:STRING
  DEF authcodemd5[255]:STRING
  DEF schemecodemd5[255]:STRING
  DEF token[255]:STRING
  DEF l,fh
  DEF xkey[6]:STRING
  DEF dataencoded[255]:STRING
  
  randomString(6,xkey)
  
  StrCopy(tempfile,'t:wall.txt')
  
  StringF(tempstr,'/token.php?key=\s',xkey)
  httpGet(tempstr,tempfile)
  l:=FileLength(tempfile)
  IF l>255 THEN l:=255
  fh:=Open(tempfile,MODE_OLDFILE)
  IF fh<>0
    Read(fh,token,l)
    SetStr(token,l)
    Close(fh)
  ENDIF
  DeleteFile(tempfile)

 
  StringF(tempstr,'\s\s',authcode,token)
  getMD5string(tempstr,authcodemd5)

  StringF(tempstr,'\s\s',schemecode,token)
  getMD5string(tempstr,schemecodemd5)

  
  StrCopy(dataencoded,data)
  urlencode(dataencoded)

  StringF(tempstr,'/wall.php?action=\s&key=\s&user=\d&system=\s&auth=\s&scheme=\s&token=\s&type=\s&version=\s&data=\s',action,xkey,userid,syscode,authcodemd5,schemecodemd5,token,scripttype,scriptver,dataencoded) 
  httpGet(tempstr,tempfile)

  l:=FileLength(tempfile)
  IF l>StrMax(result) THEN l:=StrMax(result)
  fh:=Open(tempfile,MODE_OLDFILE)
  IF fh<>0
    Read(fh,result,l)
    SetStr(result,l)
    Close(fh)
  ENDIF
  DeleteFile(tempfile)
ENDPROC

PROC getInput(prompt,maxlen,output)
  DEF res
  IF diface
    res:=Prompt(diface,maxlen,prompt)
		StrCopy(output,res,maxlen)
  ENDIF
ENDPROC res<>0

PROC pause()
  DEF strBuff[255]:STRING
  writeText('press RETURN to continue: ')
  IF diface
    HotKey(diface,'')
  ENDIF
  writeText('\b\n')
 
ENDPROC

PROC main() HANDLE
  DEF token[255]:STRING
  DEF p,i
  DEF configNames:PTR TO stringlist
  DEF configValues:PTR TO stringlist
  DEF tempstr[255]:STRING
  DEF tempfile[255]:STRING
  DEF key
  DEF username[255]:STRING
  DEF loop
  DEF getnewusername[255]:STRING
  DEF nuresult[255]:STRING
  DEF getwallpost[255]:STRING
  DEF postresult[255]:STRING

  ->initialise random seed from scanline position and system time
  p:=$dff006
  i:=Eor(Shl(p[0],8)+p[0],getSystemTime()) AND $FFFF
  Rnd((Shl(i,16)+i) OR $80000000)
  
  
  StrCopy(scripttype,'ami-express')
  StrCopy(scriptver,'0.1.beta')
  
  StrCopy(serverHost,'games.bbslink.net')
  fds:=NEW [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]:LONG

  IF aedoorbase:=OpenLibrary('AEDoor.library',1)
    diface:=CreateComm(arg[])     /* Establish Link   */
    IF diface<>0
      strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
    ELSE
      Raise('unable to open aedoor.library')
    ENDIF
  ENDIF

  configNames:=NEW configNames.stringlist(7)
  configNames.add('SERVERHOST')
  configNames.add('TELNETPORT')
  configNames.add('HTTPPORT')
  configNames.add('TIMEOUT')
  configNames.add('SYSCODE')
  configNames.add('AUTHCODE')
  configNames.add('SCHEMECODE')
  configNames.add('DOORCODE')
    
  configValues:=NEW configValues.stringlist(8)
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')

  parseConfigFile('PROGDIR:bbslink.cfg',configNames,configValues)
  parseConfigFile('bbslink.cfg',configNames,configValues)
  IF StrLen(configValues.item(0))>0 THEN StrCopy(serverHost,configValues.item(0))
  IF StrLen(configValues.item(1))>0 THEN telnetPort:=Val(configValues.item(1))
  IF StrLen(configValues.item(2))>0 THEN httpPort:=Val(configValues.item(2))
  IF StrLen(configValues.item(3))>0 THEN timeout:=Val(configValues.item(3))
  IF StrLen(configValues.item(4))>0 THEN StrCopy(syscode,configValues.item(4))
  IF StrLen(configValues.item(5))>0 THEN StrCopy(authcode,configValues.item(5))
  IF StrLen(configValues.item(6))>0 THEN StrCopy(schemecode,configValues.item(6))
  IF StrLen(configValues.item(7))>0 THEN StrCopy(doorcode,configValues.item(7))

  IF StrLen(syscode)=0 THEN Raise('syscode entry missing from bbslink.cfg')
  IF StrLen(authcode)=0 THEN Raise('authcode entry missing from bbslink.cfg')
  IF StrLen(schemecode)=0 THEN Raise('schemecode entry missing from bbslink.cfg')
  IF StrLen(doorcode)=0 THEN Raise('doorcode entry missing from bbslink.cfg')

  GetDT(diface,DT_SLOTNUMBER,0)        /* no string input here, so use 0 as last parameter */
  userid:=Val(strfield)

  writeText('\b\nReading the wall...')

  showWall()
  writeText('Write on the wall (y/n) ')
  IF yesNo()  
    cls()
    writeText('\b\nLooking for your pen - it''s around here somewhere...\b\n')
    
    sendToServer('username','',username)
    IF StrCmp(username,'*xx',3)
      writeText('\b\nSorry, I looked everywhere.Can''t find it.\b\nOh, and this happened:\b\n    ')
      writeText(username+3)
      writeText('\b\n\b\n')
      Raise()
    ENDIF
    
    IF StrCmp(username,'*notexist')
      writeText('\b\n\b\nSo you''re new here! Choose a name (max 12 characters)\b\n')
      
      loop:=TRUE
      WHILE loop
        IF getInput('\b\n',12,getnewusername)
          writeText('\b\n')
          sendToServer('newuser',getnewusername,nuresult)
          
          IF StrCmp(nuresult,'*created')
            StringF(tempstr,'Welcome to the wall, \s\b\n',getnewusername)
            writeText(tempstr)
            loop:=FALSE
          ELSEIF StrCmp(nuresult,'*inuse')
            writeText('That user name is already in use, choose another!\b\n')
          ELSEIF StrCmp(nuresult,'*inval')
            writeText('That user name is invald, choose another!\b\n')
          ENDIF
        ELSE
          ->lost carrier
          Raise()
        ENDIF
      ENDWHILE
    ENDIF
    
    sendToServer('username','',username)
    IF StrCmp(username,'*',1)
      StringF(tempstr,'\b\nSorry, I can''t find it :-(\b\n(An error occurred [\s])\b\n\n',username)
      writeText(tempstr)
      Raise()
    ENDIF
    
    StringF(tempstr,'\b\n\b\nWhat''s on your mind, \s (max 64 characters)\b\n',username)
    writeText(tempstr)
    getInput('',64,getwallpost)
    
    IF StrLen(getwallpost)>2
      ->sendToServer('post',getwallpost,postresult)
      IF StrCmp(postresult,'*post')
        writeText('Post successful!')
      ELSEIF StrCmp(postresult,'*int')
        writeText('\b\nSorry, you have to wait 10 minutes between posts.')
      ELSEIF StrCmp(postresult,'*inval')
        writeText('\b\nYour post contained too many characters (max length 64 chars).')
      ELSE
        writeText('\b\nPost failed :-(')
      ENDIF
    ELSE
      writeText('\b\nYour post was too short!')
    ENDIF

    writeText('\b\n\b\n')
    pause()
    showWall()
    pause()
    
  ENDIF


EXCEPT DO
  IF exception 
    IF diface THEN WriteStr(diface,exception,LF)
  ENDIF
  
  END fds[32]
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC

PROC httpRequest(requestdata:PTR TO CHAR,tempfile:PTR TO CHAR)
  DEF i,s,n,p
  DEF sa=0:PTR TO sockaddr_in
  DEF addr: PTR TO LONG
  DEF hostEnt: PTR TO hostent
  DEF buf:PTR TO CHAR
  DEF adding=FALSE
  DEF tv:timeval
  DEF fh

	socketbase:=OpenLibrary('bsdsocket.library',2)
	IF (socketbase)
    hostEnt:=GetHostByName(serverHost)
    IF hostEnt=0
      CloseLibrary(socketbase)
      RETURN FALSE
    ENDIF
    
    addr:=hostEnt.h_addr_list[]
    IF addr=0
      CloseLibrary(socketbase)
      RETURN FALSE
    ENDIF
    addr:=addr[]

    NEW sa
    sa.sin_len:=SIZEOF sockaddr_in
    sa.sin_family:=2
    sa.sin_port:=httpPort
    sa.sin_addr:=addr[]

    s:=Socket(2,1,0)
    IF (s>=0)
    
      IoctlSocket(s,FIONBIO,[1])
      setSingleFDS(s)

      Connect(s,sa,SIZEOF sockaddr_in)
      
      tv.secs:=timeout
      tv.micro:=0
      
      n:=WaitSelect(s+1,NIL,fds,NIL,tv,NIL)
      
      IoctlSocket(s,FIONBIO,[0])

      IF (n<=0)
        END sa
        CloseSocket(s)
        CloseLibrary(socketbase)
        RETURN FALSE
      ENDIF

      Send(s,requestdata,StrLen(requestdata),0)
      buf:=New(BUFSIZE+4)

      fh:=Open(tempfile,MODE_NEWFILE)
      IF fh<>0
        i:=0
        REPEAT
          i:=Recv(s,buf,BUFSIZE-1,0)
          buf[i]:=0
          IF adding
            Write(fh,buf,i)
          ELSEIF (p:=InStr(buf,'\b\n\b\n'))>=0
            Write(fh,buf+p+4,i-p-4)
            adding:=TRUE
          ENDIF
        UNTIL i<=0
        Close(fh)
      ENDIF
      CloseSocket(s)
      Dispose(buf)
    ENDIF
    END sa
    CloseLibrary(socketbase)
    IF fh=0 THEN RETURN FALSE
  ELSE
    RETURN FALSE
	ENDIF
ENDPROC TRUE

PROC httpGet(url:PTR TO CHAR, tempfile:PTR TO CHAR)
  DEF getcmd[500]:STRING

  StringF(getcmd,'GET \s HTTP/1.0\b\nHost:\s\b\n\b\n',url,serverHost)
  httpRequest(getcmd,tempfile)
ENDPROC 

