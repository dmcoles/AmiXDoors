/*
Global Last Callers Updater
*/
OPT OSVERSION=37

  MODULE 'dos/dos','*jsonParser','*stringlist'
  MODULE	'socket'
  MODULE	'net/netdb'
  MODULE	'net/in'
  MODULE  'devices/timer'

CONST FIONBIO=$8004667e
CONST ERR_FDSRANGE=$80000001

CONST BUFSIZE = 8192
DEF serverHost[255]:STRING
DEF serverPort=1541
DEF fds=NIL:PTR TO LONG

PROC setSingleFDS(socketVal)
  DEF i,n
  
  n:=(socketVal/32)
  IF (n<0) OR (n>=32) THEN Raise(ERR_FDSRANGE)
  
  FOR i:=0 TO 31 DO fds[i]:=0
  fds[n]:=fds[n] OR (Shl(1,socketVal AND 31))
ENDPROC

PROC httpRequest(timeout,requestdata:PTR TO CHAR, tempFile:PTR TO CHAR)
 DEF i,p,s
  DEF sa=0:PTR TO sockaddr_in
  DEF addr: LONG
  DEF hostEnt: PTR TO hostent
  DEF buf
  DEF fh=0
  DEF first=TRUE
  DEF result[20]:STRING
  DEF rescode=0
  DEF n
  DEF tv:timeval

	buf:=String(BUFSIZE+4)
  NEW sa

	socketbase:=OpenLibrary('bsdsocket.library',2)
	IF (socketbase)
    SetErrnoPtr({errno},4)

    hostEnt:=GetHostByName(serverHost)
    IF hostEnt=NIL
      CloseLibrary(socketbase)
      DisposeLink(buf)
      END sa
      RETURN FALSE
    ENDIF
    addr:=Long(hostEnt.h_addr_list)
    addr:=Long(addr)

    sa.sin_len:=SIZEOF sockaddr_in
    sa.sin_family:=2
    sa.sin_port:=serverPort
    sa.sin_addr:=addr

    s:=Socket(2,1,0)
    IF (s>=0)
    
        IoctlSocket(s,FIONBIO,[1])
        setSingleFDS(s)

        Connect(s,sa,SIZEOF sockaddr_in)
        
        tv.secs:=timeout
        tv.micro:=0
        
        n:=WaitSelect(s+1,NIL,fds,NIL,tv,NIL)
       
        IoctlSocket(s,FIONBIO,[0])

        IF n<=0
            CloseSocket(s)
        CloseLibrary(socketbase)
        DisposeLink(buf)
        END sa
        RETURN FALSE
        ENDIF

        Send(s,requestdata,StrLen(requestdata),0)

        i:=0

        IF tempFile<>NIL
          fh:=Open(tempFile,MODE_NEWFILE)
          IF fh=0 THEN RETURN FALSE
        ENDIF
                
        REPEAT
            i:=Recv(s,buf,BUFSIZE-1,0)
            IF first 
              first:=FALSE
              StrCopy(result,buf,20)
              p:=InStr(result,' ')
              IF p>=0 THEN rescode:=Val(result+p+1)
            ENDIF
            IF (i>0) AND (fh<>0)
              Write(fh,buf,i)
            ENDIF
        UNTIL i<=0
        CloseSocket(s)
        Close(fh)
    ENDIF
    CloseLibrary(socketbase)
	ENDIF
  DisposeLink(buf)
  END sa
ENDPROC rescode=200

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

PROC cleanstr(sourcestring)
  replacestr(sourcestring,'\\','\\\\')
  replacestr(sourcestring,'"','\\"')
ENDPROC

PROC postdata(timeout,userName:PTR TO CHAR,location:PTR TO CHAR,bbsName:PTR TO CHAR,timeZone:PTR TO CHAR,dateOn:PTR TO CHAR,timeOn:PTR TO CHAR,timeOff:PTR TO CHAR,actions:PTR TO CHAR,uploads,downloads,topcps,confNums:PTR TO LONG,confUploads:PTR TO LONG)
  DEF senddata
  DEF linedata
  DEF res
  DEF confNumText[255]:STRING
  DEF confUploadText[255]:STRING
  DEF tmpstr[20]:STRING
  DEF i

  cleanstr(userName)
  cleanstr(bbsName)

  FOR i:=0 TO ListLen(confNums)-1
    IF confUploads[i]>0
      IF EstrLen(confNumText)>0
        StrAdd(confNumText,',')
        StrAdd(confUploadText,',')
      ELSE
        StrCopy(confNumText,'"confnums": [')
        StrCopy(confUploadText,'"confuploads": [')
      ENDIF
      StringF(tmpstr,'\d',confNums[i])
      StrAdd(confNumText,tmpstr)
      StringF(tmpstr,'\d',confUploads[i])
      StrAdd(confUploadText,tmpstr)
    ENDIF
    IF EstrLen(confNumText)>0
      StrAdd(confNumText,'],')
      StrAdd(confUploadText,']')
    ENDIF
  ENDFOR

  linedata:=String(350+StrLen(userName)+StrLen(bbsName)+StrLen(dateOn)+StrLen(timeOn)+StrLen(timeOff)+StrLen(actions))
  StringF(linedata,'\s\d\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\d\s\d\s\d','{"Id": ',0,',"Username": "',userName,'","location": "',location,'","Bbsname": "',bbsName,'","Dateon": "',dateOn,'","TimeOn": "',timeOn,'","TimeOff": "',timeOff,'","Actions": "',actions,'","Upload": ',uploads,',"Download": ',downloads,',"topcps": ',topcps)
  
  IF EstrLen(confNumText)>0
    StrAdd(linedata,',')
    StrAdd(linedata,confNumText)
    StrAdd(linedata,confUploadText)
  ENDIF
    StrAdd(linedata,'}\b\n')
  
  senddata:=String(EstrLen(linedata)+500)
  IF StrLen(timeZone)>0
    replacestr(timeZone,' ','+')
    StringF(senddata,'POST /GlobalLastCallers/api/GlobalLastCallers?tzname=\s HTTP/1.0\b\nHost:\s\b\nContent-Type: application/json\b\nContent-Length: \d\b\n\b\n',timeZone,serverHost,EstrLen(linedata))
  ELSE
    StringF(senddata,'POST /GlobalLastCallers/api/GlobalLastCallers HTTP/1.0\b\nHost:\s\b\nContent-Type: application/json\b\nContent-Length: \d\b\n\b\n',serverHost,EstrLen(linedata))
  ENDIF
  
  StrAdd(senddata,linedata)

  DisposeLink(linedata)

  res:=httpRequest(timeout,senddata,NIL)
  
  DisposeLink(senddata)
ENDPROC res

PROC processTransferLine(logLine:PTR TO CHAR)
  DEF p
  DEF cps=0,kb=0
 
  p:=InStr(logLine,'second(s), ')
  IF p>=0
    cps:=Val(logLine+p+11)
  ENDIF
  
  p:=InStr(logLine,'seconds ')
  IF p>=0
    cps:=Val(logLine+p+8)
  ENDIF

  p:=InStr(logLine,'file(s), ')
  IF p>=0
    kb:=Val(logLine+p+9)
  ENDIF

  p:=InStr(logLine,'files, ')
  IF p>=0
    kb:=Val(logLine+p+7)
  ENDIF
ENDPROC kb,cps

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
  Dispose(tempStr)
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

PROC main()
  DEF logFname[255]:STRING
  DEF timeZone[255]:STRING
  DEF ignoreLocal=FALSE,ignoreSysop=FALSE,ignoreSysopUser=FALSE,processAll=FALSE,lastChar
  DEF fh
  DEF offset
  DEF callStartFound=FALSE
  DEF logLine[255]:STRING
  DEF previousLine[255]:STRING
  DEF connectLine[255]:STRING
  DEF dateOn[20]:STRING
  DEF timeOn[10]:STRING
  DEF timeOff[10]:STRING
  DEF userName[100]:STRING
  DEF uploads,downloads,topcps
  DEF location[200]:STRING
  DEF bbsName[100]:STRING
  DEF actions[11]:STRING

  DEF lostCarrer=FALSE 
  DEF uploadFail=FALSE
  DEF uploadSuccess=FALSE
  DEF downloadFail=FALSE
  DEF downloadSuccess=FALSE
  DEF opPaged=FALSE
  DEF opChat=FALSE
  DEF bulls=FALSE
  DEF newUser=FALSE
  DEF pwdFail=FALSE
  DEF accountEdit=FALSE
  DEF exRestr=FALSE
  DEF fileScan=FALSE
  DEF pwFailCount=0
  DEF userNum
  DEF skip,kb,cps
  DEF timeout=10
  DEF configNames:PTR TO stringlist
  DEF configValues:PTR TO stringlist 
  
  DEF confNums:PTR TO LONG
  DEF confUploads:PTR TO LONG
  DEF currentConf,newConf

  DEF tempStr[255]:STRING

  DEF callStartPosition,probableStart,foundEnd
  DEF fileLength
  DEF p,p2,tmp,i

  DEF myargs:PTR TO LONG,rdargs
  
  StrCopy(serverHost,'scenewall.bbs.io')

  myargs:=[0,0,0,0,0,0]:LONG
  IF rdargs:=ReadArgs('BBSNAME/A,CALLERSLOG/A,IGNORELOCAL/S,IGNORESYSOP/S,IGNORESYSOPUSER/S,PROCESSALL/S',myargs,NIL)
    IF myargs[0]<>NIL 
      AstrCopy(bbsName,myargs[0],255)
    ENDIF
    IF myargs[1]<>NIL 
      AstrCopy(logFname,myargs[1],255)
    ENDIF
    IF myargs[2]<>NIL 
      ignoreLocal:=myargs[2]
    ENDIF
    IF myargs[3]<>NIL 
      ignoreSysop:=myargs[3]
    ENDIF
    IF myargs[4]<>NIL 
      ignoreSysopUser:=myargs[4]
    ENDIF
    IF myargs[5]<>NIL 
      processAll:=myargs[5]
    ENDIF
    FreeArgs(rdargs)
  ELSE
    RETURN
  ENDIF
  WriteF('Global Last Callers Updater v1.0\n')
  fh:=Open(logFname,MODE_OLDFILE)
  IF fh=0
    WriteF('\nUnable to open callers log: \s\n',logFname)
    RETURN
  ENDIF
  
  fds:=NEW [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]:LONG

  configNames:=NEW configNames.stringlist(4)
  configNames.add('SERVERHOST')
  configNames.add('SERVERPORT')
  configNames.add('TIMEOUT')
  configNames.add('TIMEZONE')
  
  configValues:=NEW configValues.stringlist(4)
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')

  parseConfigFile('PROGDIR:GLCViewer.cfg',configNames,configValues)
  parseConfigFile('GLCViewer.cfg',configNames,configValues)
  IF StrLen(configValues.item(0))>0 THEN StrCopy(serverHost,configValues.item(0))
  IF StrLen(configValues.item(1))>0 THEN serverPort:=Val(configValues.item(1))
  IF StrLen(configValues.item(2))>0 THEN timeout:=Val(configValues.item(2))
  IF StrLen(configValues.item(3))>0 THEN StrCopy(timeZone,configValues.item(3))

  confNums:=List(100)
  confUploads:=List(100)
  currentConf:=0

  IF processAll=FALSE
    offset:=4096
    Seek(fh,0,OFFSET_END)
    fileLength:=Seek(fh,0,OFFSET_CURRENT)
    IF offset>fileLength THEN offset:=fileLength
    
    WHILE(callStartFound=FALSE) AND (offset<=fileLength)
      Seek(fh,-offset,OFFSET_END)
      WHILE(ReadStr(fh,logLine)<>-1) OR (StrLen(logLine)>0)
        IF StrCmp(logLine,'********************',20)
          probableStart:=Seek(fh,0,OFFSET_CURRENT)
          ReadStr(fh,logLine)
          IF (InStr(logLine,'(CONNECT ')>=0) OR (InStr(logLine,'(SYSOP_LOCAL)')>=0) OR (InStr(logLine,'(F2_LOCAL)')>=0)
            callStartFound:=TRUE
            callStartPosition:=probableStart
          ENDIF
        ENDIF
      ENDWHILE
      offset:=offset+4096
    ENDWHILE
  ELSE
    ReadStr(fh,logLine)
    IF StrCmp(logLine,'********************',20)
      callStartFound:=TRUE
      callStartPosition:=Seek(fh,0,OFFSET_CURRENT)
    ELSE
      callStartFound:=TRUE
      callStartPosition:=0
    ENDIF
  ENDIF
  
  
  IF callStartFound
    Seek(fh,callStartPosition,OFFSET_BEGINNING)

    REPEAT
      SetList(confNums,0)
      SetList(confUploads,0)

      ReadStr(fh,logLine)
    
      StringF(dateOn,'\s[2]-\s[2]-\s[2]',logLine+3,logLine,logLine+6)
      StrCopy(timeOn,logLine+10,5)

      lostCarrer:=FALSE 
      uploadFail:=FALSE
      uploadSuccess:=FALSE
      downloadFail:=FALSE
      downloadSuccess:=FALSE
      opPaged:=FALSE
      opChat:=FALSE
      bulls:=FALSE
      newUser:=FALSE
      pwdFail:=FALSE
      accountEdit:=FALSE
      exRestr:=FALSE
      fileScan:=FALSE
      
      uploads:=0
      downloads:=0
      topcps:=0

      p:=InStr(logLine,']')   
      StrCopy(userName,'UNKNOWN')
      IF (p>=0) AND (StrLen(logLine)>(p+2))
        StrCopy(tempStr,logLine+p+2,ALL)
        p:=InStr(tempStr,' (SYSOP_LOCAL) ')
        IF p>=0 
          StrCopy(userName,tempStr,p)
          StrCopy(location,tempStr+p+15)
        ENDIF
        p:=InStr(tempStr,' (F2_LOCAL) ')
        IF p>=0 
          StrCopy(userName,tempStr,p)
          StrCopy(location,tempStr+p+12)
        ENDIF
        p:=InStr(tempStr,' (CONNECT')
        IF p>=0
          StrCopy(userName,tempStr,p)
          p2:=InStr(tempStr+p,') ')
          IF p2>=0
            StrCopy(location,tempStr+p+p2+2)
          ENDIF
        ENDIF
      ENDIF
      IF (StrLen(logLine)>19) AND (StrCmp(logLine+19,' NEW ',5)) THEN newUser:=TRUE
      IF newUser
        userNum:=Val(logLine+25)
      ELSE
        userNum:=Val(logLine+21)
      ENDIF
      StrCopy(connectLine,logLine)

      pwFailCount:=0
      StrCopy(timeOff,'--:--')
      foundEnd:=FALSE
      StrCopy(previousLine,logLine)
      WHILE((ReadStr(fh,logLine)<>-1) OR (StrLen(logLine)>0)) AND (foundEnd=FALSE)
        IF StrCmp(logLine,'********************',20) THEN foundEnd:=TRUE
        StringF(tempStr,' \s Off Normally',userName)
        IF (StrLen(logLine)>19) AND (StrCmp(logLine+19,tempStr))
          StrCopy(timeOff,logLine+10,5)
        ENDIF
        StringF(tempStr,' \s Off Loss Carrier',userName)
        IF (StrLen(logLine)>19) AND (StrCmp(logLine+19,tempStr))
          StrCopy(timeOff,logLine+10,5)
          lostCarrer:=TRUE
        ENDIF

        newConf:=-1
        IF (InStr(logLine,'\tConference ')=0) AND (InStr(logLine,'Auto-ReJoined')>=0)
          newConf:=Val(logLine+12)
        ENDIF
        
        
        IF ((tmp:=InStr(logLine,') Conference Joined'))>=0)
          WHILE (tmp=>0) AND (logLine[tmp]<>'(') DO tmp--
          IF (tmp>=0)
            newConf:=Val(logLine+tmp+1)
          ENDIF
        ENDIF
        
        IF newConf<>-1
          currentConf:=-1
          FOR i:=0 TO ListLen(confNums)-1
            IF confNums[i]=newConf THEN currentConf:=i
          ENDFOR
          IF currentConf=-1
            ListAdd(confNums,[0])
            currentConf:=ListLen(confNums)-1
            confNums[currentConf]:=newConf
            ListAdd(confUploads,[0])
          ENDIF
          newConf:=-1
        ENDIF

        IF (InStr(logLine,' file')>=0) AND (InStr(logLine,' bytes, ')>=0) AND (InStr(logLine,' minute')>=0) AND (InStr(logLine,' second')>=0) AND (InStr(logLine,' cps, ')>=0) AND (InStr(logLine,'% efficiency')>=0) AND (((InStr(previousLine,'Uploading '))>=0) OR ((InStr(previousLine,'Upload moved'))>=0))
          kb,cps:=processTransferLine(logLine)
          IF cps>topcps THEN topcps:=cps
          uploads:=uploads+kb
          confUploads[currentConf]:=confUploads[currentConf]+kb
          uploadSuccess:=TRUE
        ENDIF

        IF (InStr(logLine,' file')>=0) AND (InStr(logLine,' bytes, ')>=0) AND (InStr(logLine,' minute')>=0) AND (InStr(logLine,' second')>=0) AND (InStr(logLine,' cps, ')>=0) AND (InStr(logLine,'% efficiency')>=0) AND (InStr(previousLine,'Downloading ')>=0) 
          kb,cps:=processTransferLine(logLine)
          IF cps>topcps THEN topcps:=cps
          downloads:=downloads+kb
          downloadSuccess:=TRUE
        ENDIF
        
        IF InStr(logLine,'Upload Failed..')>=0 THEN uploadFail:=TRUE
        IF InStr(logLine,'Download Failed..')>=0 THEN downloadFail:=TRUE
        IF InStr(logLine,'Operator Paged At ')>=0 THEN opPaged:=TRUE
        IF InStr(logLine,'Password Failure')>=0 THEN pwFailCount++
        IF InStr(logLine,'Directory Scan ')>=0 THEN fileScan:=TRUE
        IF InStr(logLine,'Conference Scan ')>=0 THEN fileScan:=TRUE
        IF InStr(logLine,'Account Editing')>=0 THEN accountEdit:=TRUE
        IF pwFailCount=2 THEN pwdFail:=TRUE
        StrCopy(previousLine,logLine)
        EXIT foundEnd
      ENDWHILE
      
      StrCopy(actions,'----------')
      IF newUser THEN actions[0]:="*"
      IF uploadFail THEN actions[1]:="u"
      IF uploadSuccess THEN actions[1]:="U"
      IF downloadFail THEN actions[2]:="d"
      IF downloadSuccess THEN actions[2]:="D"
      IF opPaged THEN actions[3]:="o"
      IF opChat THEN actions[3]:="O"
      IF fileScan THEN actions[4]:="F"
      IF bulls THEN actions[5]:="B"    
      IF exRestr THEN actions[6]:="E"
      IF accountEdit THEN actions[7]:="A"
      IF pwdFail THEN actions[8]:="H"
      IF lostCarrer THEN actions[9]:="C"
           
      skip:=TRUE
      IF (InStr(connectLine,'(CONNECT ')>=0) OR ((InStr(connectLine,'(SYSOP_LOCAL)')>=0) AND (ignoreSysop=FALSE)) OR ((InStr(connectLine,'(F2_LOCAL)')>=0) AND (ignoreLocal=FALSE)) THEN skip:=FALSE
      IF ((userNum=1) AND (ignoreSysopUser=TRUE)) THEN skip:=TRUE    

      IF skip=FALSE
        WriteF('Processing call on \s at \s from \s[\d]....',dateOn,timeOn,userName,userNum)
        IF postdata(timeout,userName,location,bbsName,timeZone,dateOn,timeOn,timeOff,actions,uploads,downloads,topcps,confNums,confUploads)=FALSE THEN WriteF('failed\n') ELSE WriteF('success\n')
      ELSE  
        WriteF('Skipping call on \s at \s from \s[\d]\n',dateOn,timeOn,userName,userNum)
      ENDIF
    UNTIL (foundEnd=FALSE) OR (processAll=FALSE) OR (CtrlC())
  ELSE
    WriteF('Unable to locate the last caller entry in the callers log\n')
  ENDIF
  
  END fds[32]
  
ENDPROC


errno: 
	LONG 0,0