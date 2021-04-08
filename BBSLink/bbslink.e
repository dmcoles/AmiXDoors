/*
** bbslink door - requires /X 5.4 and amissl.library
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
DEF xkey[6]:STRING
DEF scripttype[20]:STRING
DEF scriptver[20]:STRING

DEF authcodemd5[255]:STRING
DEF schemecodemd5[255]:STRING

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

PROC main() HANDLE
  DEF diface=0
  DEF strfield=0
  DEF response[255]:STRING
  DEF token[255]:STRING
  DEF userid=0
  DEF rows=0
  DEF p,i
  DEF configNames:PTR TO stringlist
  DEF configValues:PTR TO stringlist
  DEF tempstr[255]:STRING
  DEF commandLine[100]:STRING

  ->initialise random seed from scanline position and system time
  p:=$dff006
  i:=Eor(Shl(p[0],8)+p[0],getSystemTime()) AND $FFFF
  Rnd((Shl(i,16)+i) OR $80000000)
  
  
  StrCopy(scripttype,'ami-express')
  StrCopy(scriptver,'0.1.beta')
  randomString(6,xkey)
  
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

  GetDT(diface,BB_MAINLINE,0)        /* no string input here, so use 0 as last parameter */
  StrCopy(commandLine,strfield)
  IF (p:=InStr(commandLine,' '))>=0
    SetStr(commandLine,p)
    UpperStr(commandLine)
  ENDIF

  configNames:=NEW configNames.stringlist(9)
  configNames.add('SERVERHOST')
  configNames.add('TELNETPORT')
  configNames.add('HTTPPORT')
  configNames.add('TIMEOUT')
  configNames.add('SYSCODE')
  configNames.add('AUTHCODE')
  configNames.add('SCHEMECODE')
  configNames.add('DOORCODE')
  configNames.add(commandLine)
    
  configValues:=NEW configValues.stringlist(9)
  configValues.add('')
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
  IF StrLen(configValues.item(8))>0 THEN StrCopy(doorcode,configValues.item(8))


  GetDT(diface,BB_MAINLINE,0)        /* no string input here, so use 0 as last parameter */
  StrCopy(commandLine,strfield)
  IF (p:=InStr(commandLine,' '))>=0
    IF StrLen(commandLine+p+1)>0 THEN StrCopy(doorcode,commandLine+p+1)
  ENDIF
  
  IF StrLen(doorcode)=0 THEN StrCopy(doorcode,'MENU')

  IF StrLen(syscode)=0 THEN Raise('syscode entry missing from bbslink.cfg')
  IF StrLen(authcode)=0 THEN Raise('authcode entry missing from bbslink.cfg')
  IF StrLen(schemecode)=0 THEN Raise('schemecode entry missing from bbslink.cfg')
  IF StrLen(doorcode)=0 THEN Raise('doorcode entry missing from bbslink.cfg')

  LowerStr(doorcode)

  StringF(tempstr,'/token.php?key=\s',xkey)
  httpGet(tempstr,response)

  StrCopy(token,response)

  GetDT(diface,DT_SLOTNUMBER,0)        /* no string input here, so use 0 as last parameter */
  userid:=Val(strfield)

  GetDT(diface,DT_LINELENGTH,0)        /* no string input here, so use 0 as last parameter */
  rows:=Val(strfield)
  
  
  StrAdd(authcode,token)
  getMD5string(authcode,authcodemd5)

  StrAdd(schemecode,token)
  getMD5string(schemecode,schemecodemd5)

  StringF(tempstr,'/auth.php?key=\s&user=\d&system=\s&auth=\s&scheme=\s&rows=\d&door=\s&token=\s&type=\s&version=\s',xkey,userid,syscode,authcodemd5,schemecodemd5,rows,doorcode,token,scripttype,scriptver)
  httpGet(tempstr,response)

  SendStrDataCmd(diface,TELNET_CONNECT,serverHost,telnetPort)

EXCEPT DO
  IF exception 
    IF diface THEN WriteStr(diface,exception,LF) ELSE WriteF('\s\n',exception)
  ENDIF
  
  END fds[32]
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC

PROC httpRequest(requestdata:PTR TO CHAR, outTextBuffer)
  DEF i,s,n,p
  DEF sa=0:PTR TO sockaddr_in
  DEF addr: PTR TO LONG
  DEF hostEnt: PTR TO hostent
  DEF buf:PTR TO CHAR
  DEF adding=FALSE
  DEF tv:timeval

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

      i:=0
      StrCopy(outTextBuffer,'')
      REPEAT
        i:=Recv(s,buf,BUFSIZE-1,0)
        buf[i]:=0
        IF adding
          StrAdd(outTextBuffer,buf,i)
        ELSEIF (p:=InStr(buf,'\b\n\b\n'))>=0
          StrAdd(outTextBuffer,buf+p+4,i-p-4)
          adding:=TRUE
        ENDIF
      UNTIL i<=0
      CloseSocket(s)
      Dispose(buf)
    ENDIF
    END sa
    CloseLibrary(socketbase)
  ELSE
    RETURN FALSE
	ENDIF
ENDPROC TRUE

PROC httpGet(url:PTR TO CHAR, outTextBuffer)
  DEF getcmd[255]:STRING

  StringF(getcmd,'GET \s HTTP/1.0\b\nHost:\s\b\n\b\n',url,serverHost)
  httpRequest(getcmd,outTextBuffer)
ENDPROC 

