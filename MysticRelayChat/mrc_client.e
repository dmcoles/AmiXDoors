->!/usr/bin/python
-> ::::: __________________________________________________________________ :::::
-> : ____\ ._ ____ _____ __. ____ ___ _______ .__ ______ .__ _____ .__ _. /____ :
-> __\ .___! _\__/__    / _|__   / _/_____  __|  \ gRK __|_ \  __  |_ \ !___. /__
-> \   ! ___/  |/  /___/  |   \__\ ._/  __\/  \   \___/  |/  \/  \_./  \___ !   /
-> /__  (___   /\____\____|\   ____|   /  /___|\   ______.    ____\|\   ___)  __\
->   /____  \_/ ___________ \_/ __ |__/ _______ \_/ ____ |___/ _____ \_/  ____\
-> :     /________________________________________________________________\     :
-> :::::       +  p  H  E  N  O  M  p  R  O  D  U  C  T  I  O  N  S  +      :::::
-> ==============================================================================
->
-> -----------------------------------------
-> - modName: mrc_client multiplexer       -
-> - majorVersion: 1.2                     -
-> - minorVersion: 9                       -
-> - author: Stackfault                    -
-> - publisher: Phenom Productions         -
-> - website: https://www.phenomprod.com   -
-> - email: stackfault@bottomlessabyss.net -
-> - bbs: bbs.bottomlessabyss.net:2023     -
-> -----------------------------------------
->
-> v1.2.9
-> - Improved handling of incomplete and invalid packets
-> - Implemented client stats transfer
-> - Increased tcp buffer size
-> - Improved the stats reporting
-> - Rebased the message serialization
->
-> Make sure to use the new mrc_config.py so you can take advantage of some new
-> features.
->
MODULE 'dos/dos','dos/dosasl','dos/datetime','socket','net/netdb','net/in','net/socket'
CONST ERR_EXCEPT=1

CONST EAGAIN=35
CONST ECONNRESET=54
CONST FIONBIO=$8004667e
CONST LISTENQ=100
CONST CHAR_BACKSPACE=8

OBJECT userConnection
  userName[255]:ARRAY OF CHAR
  socket
ENDOBJECT

DEF delay
DEF mrcserver
DEF host[255]:STRING
DEF port

DEF clients:PTR TO LONG

DEF version[10]:STRING
DEF platform_name[100]:STRING
DEF system_name[100]:STRING
DEF machine_arch[100]:STRING
DEF debugflag=TRUE
DEF version_string[255]:STRING
DEF client_version[255]:STRING

DEF bbsName[255]:STRING
DEF info_Web[255]:STRING
DEF info_Telnet[255]:STRING
DEF info_SSH[255]:STRING
DEF info_Sysop[255]:STRING
DEF info_Desc[255]:STRING

DEF mrcstats[255]:STRING

PROC strip(src:PTR TO CHAR,dest:PTR TO CHAR)
  DEF n,v=0
  StrCopy(dest,TrimStr(src))
  n:=EstrLen(dest)
  IF n>0 THEN v:=dest[n-1]
  WHILE (n>0) AND (v=" ")
    SetStr(dest,n-1)
    n:=EstrLen(dest)
    IF n>0 THEN v:=dest[n-1]
  ENDWHILE
ENDPROC
  
PROC openListenSocket(port)
  DEF server_s
  DEF servaddr=0:PTR TO sockaddr_in

  NEW servaddr

	IF((server_s:=Socket(AF_INET, SOCK_STREAM, 0)) < 0)
		WriteF('ECHOSERV: Error creating listening socket. (\d)\b\n',Errno())
    END servaddr
		RETURN FALSE,-1
	ENDIF
  
  servaddr.sin_len:=SIZEOF sockaddr_in
  servaddr.sin_family:=AF_INET
  servaddr.sin_port:=port
  servaddr.sin_addr:=INADDR_ANY

	->WriteF('listening to port \d...\b\n', port)

	IF(Bind(server_s, servaddr, SIZEOF sockaddr_in) < 0)
		WriteF('ECHOSERV: Error calling bind() for port \d, error=\d\b\n',port,Errno());
    CloseSocket(server_s)
    END servaddr
		RETURN FALSE,-1
	ENDIF

	IF(Listen(server_s, LISTENQ) < 0)
		WriteF('ECHOSERV: Error calling listen()\b\n')
    CloseSocket(server_s)
    END servaddr
    RETURN FALSE,-1
	ENDIF

  IoctlSocket(server_s,FIONBIO,[1])

  END servaddr
ENDPROC TRUE,server_s

PROC clientAccept(socket)
  DEF csock
  DEF userConn:PTR TO userConnection
  csock:=Accept(socket,NIL,NIL)
  IF csock=-1 THEN RETURN
  userConn:=NEW userConn
  StrCopy(userConn.userName,'')
  userConn.socket:=csock
  ListAdd(clients,[userConn])
ENDPROC

PROC removeClient(socket)
  DEF tempList:PTR TO LONG
  DEF userConn:PTR TO userConnection
  DEF i
  tempList:=List(ListLen(clients)-1)
  FOR i:=0 TO ListLen(clients)-1
    userConn:=clients[i]
    IF userConn.socket<>socket
      ListAdd(tempList,[userConn]) 
    ELSE
      Dispose(userConn)
    ENDIF
  ENDFOR
  SetList(clients,0)
  ListAdd(clients,tempList)
  Dispose(tempList)
ENDPROC

PROC setDefaults()

-> Platform information
  StrCopy(version,'1.2.9')
  StrCopy(platform_name,'AMIEXPRESS')
  StrCopy(system_name,'Amiga')
  StrCopy(machine_arch,'68K')

  debugflag:=TRUE
  StringF(version_string,'\s/\s.\s/\s',platform_name, system_name, machine_arch, version)
  StringF(client_version,'Multi Relay Chat Client v\s [sf]',version)

ENDPROC

PROC readConfiguration()
  DEF f
  DEF cfgLine[255]:STRING
  DEF cfgData:PTR TO LONG
  DEF cfgKey[255]:STRING
  DEF cfgValue[255]:STRING
  
  StrCopy(bbsName,'Unconfigured BBS')
  StrCopy(info_Web,'Unconfigured BBS')
  StrCopy(info_Telnet,'Unconfigured BBS')
  StrCopy(info_SSH,'Unconfigured BBS')
  StrCopy(info_Sysop,'Unconfigured BBS')
  StrCopy(info_Desc,'Unconfigured BBS')

  f:=Open('mrc_client.cfg',MODE_OLDFILE)
  IF f>0
    WHILE ReadStr(f,cfgLine)<>-1
      cfgData:=splitBuffer(cfgLine,'=')
      IF ListLen(cfgData)=2
        strip(cfgData[0],cfgKey)
        strip(cfgData[1],cfgValue)
        UpperStr(cfgKey)
        IF StrCmp(cfgKey,'BBSNAME')
          StrCopy(bbsName,cfgValue)
        ELSEIF StrCmp(cfgKey,'INFO_WEB')
          StrCopy(info_Web,cfgValue)
        ELSEIF StrCmp(cfgKey,'INFO_TELNET')
          StrCopy(info_Telnet,cfgValue)
        ELSEIF StrCmp(cfgKey,'INFO_SSH')
          StrCopy(info_SSH,cfgValue)
        ELSEIF StrCmp(cfgKey,'INFO_SYSOP')
          StrCopy(info_Sysop,cfgValue)
        ELSEIF StrCmp(cfgKey,'INFO_DESC')
          StrCopy(info_Desc,cfgValue)
        ENDIF
      ENDIF
      Dispose(cfgData)
    ENDWHILE
    Close(f)
  ENDIF
ENDPROC

/*
-> Strip MCI color codes
def stripmci(text):
    return re.sub('\|[0-9]{2}', '', text)
*/
-> User chatlog for DLCHATLOG
PROC chatlog(data)
  DEF tempstr[255]:STRING
  DEF packet:PTR TO LONG
  DEF ltime[255]:STRING
  DEF message
  DEF clogfile[30]:STRING
  DEF data2,f
  DEF currDate: datetime
    
  IF (InStr(data,'CLIENT~')=-1) AND (InStr(data,'SERVER~')=-1)
    DateStamp(currDate.stamp)
    formatLongDate(currDate,ltime)

    data2:=String(StrLen(data))
    StrCopy(data2,data)
    packet:=splitBuffer(data2,'~')
    IF ListLen(packet)>6
      message:=packet[6]

      StrCopy(clogfile,'mrcchat.log')
      f:=Open(clogfile,MODE_READWRITE)
      IF f>0
        Seek(f,0,OFFSET_END)
        StringF(tempstr,'\s \s\n',ltime,message)
        Write(f,tempstr,StrLen(tempstr))
        Close(f)
      ENDIF
    ENDIF
    Dispose(packet)
    Dispose(data2)
  ENDIF
ENDPROC

PROC formatLongDate(dts: PTR TO datestamp,outDateStr)
  DEF datestr[10]:STRING
  DEF timestr[10]:STRING
  DEF dt:datetime

  CopyMem(dts,dt.stamp,SIZEOF datestamp)
  dt.format:=FORMAT_DOS
  dt.flags:=0
  dt.strday:=0
  dt.strdate:=datestr
  dt.strtime:=timestr

  IF DateToStr(dt)
    StringF(outDateStr,'\s[3] \s[2] \s[2]\s[2] \s[2]:\s[2]:\s[2]',datestr+3,datestr,IF dt.stamp.days>=8035 THEN '20' ELSE '19',datestr+7,timestr,timestr+3,timestr+6)
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC countsep(fl:PTR TO CHAR,sep)
  DEF c,cnt=0
  FOR c:=0 TO StrLen(fl)-1
    IF fl[c]=sep THEN cnt++
  ENDFOR
ENDPROC cnt

-> Console logger
PROC logger(loginfo:PTR TO CHAR)
  DEF currDate: datetime
  DEF ltime[255]:STRING
  DEF tempstr

  DateStamp(currDate.stamp)
  formatLongDate(currDate,ltime)
  tempstr:=String(StrLen(loginfo))
  strip(loginfo,tempstr)
  ->ltime = time.asctime(time.localtime(time.time()))
  WriteF('\s  \s\n',ltime,tempstr)
  Dispose(tempstr)
ENDPROC

-> Socket sender to server
PROC send_server(data:PTR TO CHAR)
  DEF r
  DEF tempstr[255]:STRING
  DEF data2
  
  IF data
    data2:=String(StrLen(data)+1)
    StrCopy(data2,data)
    IF data2[StrLen(data2)-1]<>'\n' THEN StrAdd(data2,'\n')
    r:=Send(mrcserver,data2,StrLen(data2),0)
    Dispose(data2)
    IF r=-1
      StringF(tempstr,'Connection error \d',Errno())
      logger(tempstr)
      Shutdown(mrcserver,2)
      CloseSocket(mrcserver)
    ENDIF
    Dispose(data2)
  ENDIF
ENDPROC
/*

-> Temp files cleaning routine
def clean_files():
    mrcfiles = os.listdir( mrcdir )
    for file in mrcfiles:
        if fnmatch.fnmatch(file,'*.mrc'):
            mrcfile = "%s%s%s" % (mrcdir,os.sep,file)
            os.remove(mrcfile)
*/
-> Read queued file from MRC, ignoring stale files older than 10s
PROC send_mrc(userConn:PTR TO userConnection)
  DEF buf2:PTR TO CHAR
  DEF tempstr[255]:STRING
  DEF mline:PTR TO LONG
  DEF fromuser[255]:STRING
  DEF frombbs[255]:STRING
  DEF touser[255]:STRING
  DEF message[255]:STRING
  DEF b,e,i,data,readBuffer
  DEF tdat:PTR TO LONG
  DEF sep[2]:STRING

  readBuffer:=New(8193)
  b:=Recv(userConn.socket,readBuffer,8192,0)
  IF b<=0
    e:=Errno()
    IF e<>EAGAIN
      StringF(tempstr,'unexpected=\d',e)
      logger(tempstr)
    ENDIF
    IF (e=ECONNRESET) OR (e=53)
      logger('connection disconnect')
      IF StrLen(userConn.userName)>0
        StringF(tempstr,'\s~~~SERVER~~~LOGOFF~\n',userConn.userName)
        logger(tempstr)
        deliver_mrc(tempstr)
        send_server(tempstr)
      ENDIF
      removeClient(userConn.socket)
    ENDIF
    Dispose(readBuffer)
    RETURN
  ENDIF
  IF b>0
    check_separator(readBuffer,sep)
    tdat:=splitBuffer(readBuffer,sep)
    i:=0
    WHILE (i<ListLen(tdat))
      data:=tdat[i]
      IF data
        IF countsep(data,"~")>5
          buf2:=String(StrLen(data))
          StrCopy(buf2,data)
          mline:=splitBuffer(buf2,'~')
          IF ListLen(mline)>0 THEN StrCopy(fromuser,mline[0])
          IF ListLen(mline)>1 THEN StrCopy(frombbs,mline[1])
          IF ListLen(mline)>3 THEN StrCopy(touser,mline[3])
          IF ListLen(mline)>6 THEN StrCopy(message,mline[6])
          
          IF StrLen(userConn.userName)=0 THEN AstrCopy(userConn.userName,fromuser,255)
          
          Dispose(mline)
          Dispose(buf2)
          IF StrCmp(message,'VERSION')
            StringF(tempstr,'CLIENT~~~\s~\s~~|07- \s~\n',fromuser,frombbs,client_version)
            deliver_mrc(tempstr)
            send_server(data)
          ELSEIF StrCmp(touser,'CLIENT') AND (StrCmp(message,'STATS'))
            StringF(tempstr,'SERVER~~~CLIENT~\s~~STATS:\s~\n',frombbs,mrcstats)
            deliver_mrc(tempstr)
          ELSE
            send_server(data)
          ENDIF

          IF debugflag
            StringF(tempstr,'OUT: \s',data)
            logger(tempstr)
          ENDIF
        ELSE
          IF debugflag 
            StringF(tempstr,'invalid packet received')
            logger(tempstr)
          ENDIF
        ENDIF  
      ENDIF
      i++
    ENDWHILE
    Dispose(tdat)

  ENDIF
  Dispose(readBuffer)
ENDPROC

-> Send data back to MRC client
PROC deliver_mrc(server_data)
  DEF tempstr[255]:STRING
  DEF i
  DEF packet:PTR TO LONG
  DEF fromuser[255]:STRING
  DEF fromsite[255]:STRING
  DEF fromroom[255]:STRING
  DEF tosite[255]:STRING
  DEF touser[255]:STRING
  DEF toroom[255]:STRING
  DEF message[255]:STRING
  DEF statsfile[255]:STRING
  DEF userConn:PTR TO userConnection
  DEF data2,data3,f
  
  data2:=String(StrLen(server_data))
  StrCopy(data2,server_data)
  packet:=splitBuffer(data2,'~')
  IF ListLen(packet)>6
    StrCopy(fromuser,packet[0])
    StrCopy(fromsite,packet[1])
    StrCopy(fromroom,packet[2])
    StrCopy(touser,packet[3])
    StrCopy(tosite,packet[4])
    StrCopy(toroom,packet[5])
    StrCopy(message,packet[6])
  ELSE
    StringF(tempstr,'Bad packet: \s',server_data)
    logger(tempstr)
  ENDIF
  Dispose(packet)
  Dispose(data2)

  IF debugflag
    StringF(tempstr,'IN: \s',server_data)
    logger(tempstr)
  ENDIF

  StrCopy(tempstr,message)
  LowerStr(tempstr)

  -> Manage server PINGs
  IF (StrCmp(fromuser,'SERVER')) AND (StrCmp(tempstr,'ping')) 
    send_im_alive()
  -> Manage update available notifications
  ELSEIF (StrCmp(fromuser,'SERVER')) AND (StrCmp(message,'NEWUPDATE:',10))
    logger('Upgrade is available, consider upgrading at your earliest convenience')
    StringF(tempstr,'You are using version \s',version)
    logger(tempstr)
    packet:=splitBuffer(message,':')
    IF ListLen(packet)>1
      StringF(tempstr,'Latest version is \s',packet[1])
      logger(tempstr)
    ENDIF
    Dispose(packet)

  -> Manage old clients
  ELSEIF (StrCmp(fromuser,'SERVER')) AND (StrCmp(message,'OLDVERSION:',11))
    logger('Your client is too old and can no longer be used.')
    StringF(tempstr,'You are using version \s',version)
    logger(tempstr)
    packet:=splitBuffer(message,':')
    IF ListLen(packet)>1
      StringF(tempstr,'Latest version is \s',packet[1])
      logger(tempstr)
    ENDIF
    Dispose(packet)
    Raise(ERR_EXCEPT)
  ELSE

    -> Manage server stats
    IF (StrCmp(fromuser,'SERVER')) AND (StrCmp(message,'STATS:',6))
      StrCopy(statsfile,'env:mrcstats.dat')
      f:=Open(statsfile,MODE_NEWFILE)
      IF f>0
        packet:=splitBuffer(message,':')
        IF ListLen(packet)>1
          Write(f,packet[1],StrLen(packet[1]))
        ENDIF
        Close(f)
        StrCopy(mrcstats,packet[1])
        Dispose(packet)
      ELSE
        StringF(tempstr,'Cannot write server stats to \s',statsfile)
        logger(tempstr)
      ENDIF
    ENDIF
    
    chatlog(server_data)
    FOR i:=0 TO ListLen(clients)-1
      userConn:=clients[i]
      StringF(tempstr,'sending to client \d from \s to \s',i,fromuser,touser)
      logger(tempstr)
      IF (StrCmp(touser,'NOTME')=FALSE) OR (StrCmp(fromuser,userConn.userName)=FALSE)
        StringF(tempstr,'Forwarding message to \s',userConn.userName)
        logger(tempstr)
        data2:=String(StrLen(server_data)+1)
        StrCopy(data2,server_data)
        IF data2[StrLen(data2)-1]<>'\n' THEN StrAdd(data2,'\n')
        Send(userConn.socket,data2,StrLen(data2),0)
        Dispose(data2)
      ENDIF    
    ENDFOR               
  ENDIF
ENDPROC

-> Respond to server PING
PROC send_im_alive()
  DEF data[500]:STRING
  StringF(data,'CLIENT~\s~~SERVER~~~IMALIVE:\s~\n',bbsName,bbsName)
  send_server(data)
ENDPROC

-> Send graceful shutdown request to server when exited
PROC send_shutdown()
  DEF data[255]:STRING
  StringF(data,'CLIENT~\s~~SERVER~~~SHUTDOWN~\n',bbsName)
  send_server(data)
ENDPROC

-> Request server stats for applet
PROC request_stats()
  DEF data[255]:STRING
  StringF(data,'CLIENT~\s~~SERVER~~~STATS~\n',bbsName)
  send_server(data)
ENDPROC

-> Send BBS additional info for INFO command
PROC send_bbsinfo()
  DEF prefix[255]:STRING
  DEF part[500]:STRING
  DEF packet[1000]:STRING
  
  StringF(prefix,'CLIENT~\s~~SERVER~ALL~~',bbsName)

  StringF(part,'\sINFOWEB:\s~\n',prefix,info_Web)
  StrAdd(packet,part)
  StringF(part,'\sINFOTEL:\s~\n',prefix,info_Telnet)
  StrAdd(packet,part)
  StringF(part,'\sINFOSSH:\s~\n',prefix,info_SSH)
  StrAdd(packet,part)
  StringF(part,'\sINFOSYS:\s~\n',prefix,info_Sysop)
  StrAdd(packet,part)
  StringF(part,'\sINFODSC:\s~\n',prefix,info_Desc)
  StrAdd(packet,part)
  send_server(packet)
ENDPROC


-> Handle different line separator scenarios
PROC check_separator(data,outSep)
  IF InStr(data,'\b\n')<>-1
    StrCopy(outSep,'\b\n')
  ELSEIF InStr(data,'\n\b')<>-1
    StrCopy(outSep,'\n\b')
  ELSEIF InStr(data,'\b')<>-1
    StrCopy(outSep,'\b')
  ELSE
    StrCopy(outSep,'\n')
  ENDIF
ENDPROC

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


-> Main process loop
PROC mainproc(listenSock)
  DEF restart=0
  DEF tdat:PTR TO LONG
  DEF tempstr[255]:STRING
  DEF sep[2]:STRING
  DEF loop=90
  DEF i,b,e,data,res
  DEF sa=0:PTR TO sockaddr_in
  DEF readBuffer

  DEF addr: PTR TO LONG
  DEF hostEnt: PTR TO hostent
  
  mrcserver:=Socket(AF_INET,SOCK_STREAM,0)

  hostEnt:=GetHostByName(host)
  addr:=hostEnt.h_addr_list[]
  addr:=addr[]
  
  NEW sa
  sa.sin_len:=SIZEOF sockaddr_in
  sa.sin_family:=2
  sa.sin_port:=port
  sa.sin_addr:=addr[]

  res:=Connect(mrcserver,sa,SIZEOF sockaddr_in)
  
  END sa
  
  IF (res<>0) OR (Errno()<>0)
    StringF(tempstr,'Unable to connect to \s:\d',host,port)
    logger(tempstr)
    CloseSocket(mrcserver)
    RETURN
  ENDIF
  
  ->mrcserver.setblocking(0)
  IoctlSocket(mrcserver,FIONBIO,[1])
  
  StringF(tempstr,'\s~\s',bbsName,version_string)
  res:=Send(mrcserver,tempstr,StrLen(tempstr),0)
  IF (res=-1)
    StringF(tempstr,'Unable to connect to \s:\d',host,port)
    logger(tempstr)
    CloseSocket(mrcserver)
    RETURN
  ENDIF
  
  StringF(tempstr,'Connected to Multi Relay Chat host \s port \d',host, port)
  logger(tempstr)
  delay:=0

  send_bbsinfo()
  send_im_alive()
  
  -> Non-blocking socket loop to improve speed
  readBuffer:=New(8193)
  WHILE TRUE
    Delay(10)
  
    clientAccept(listenSock)
    
    FOR i:=0 TO ListLen(clients)-1    
      send_mrc(clients[i])
    ENDFOR

    loop++
    b:=Recv(mrcserver,readBuffer,8192,0)
    IF b<=0
      e:=Errno()
      IF (e=EAGAIN)
        IF loop > 100
          request_stats()
          loop:=0
        ENDIF
        ->continue
      ELSE
        restart:=1
      ENDIF
    ELSE
      IF b>0
        readBuffer[b]:=0
        check_separator(readBuffer,sep)
        tdat:=splitBuffer(readBuffer,sep)
        i:=0
        WHILE (i<ListLen(tdat))
          data:=tdat[i]
          IF data
            IF StrLen(data)>0 THEN deliver_mrc(data)
          ENDIF
          i++
        ENDWHILE
        Dispose(tdat)
      ELSE
        restart:=1
      ENDIF
    ENDIF

    -> Handle socket restarts with socket shutdowns
    IF restart OR CtrlC()
      logger('Lost connection to server\n')
      Shutdown(mrcserver,2)
      CloseSocket(mrcserver)
      Dispose(readBuffer)
      RETURN
    ENDIF
  ENDWHILE
ENDPROC

-> Some validation of config to ensure smoother operation
PROC check_startup()
  DEF failed=0
  DEF params:PTR TO LONG,param
  
  params:=[info_Web,info_Telnet,info_SSH,info_Sysop,info_Desc,0]

  IF StrLen(bbsName) < 5
    WriteF('Config: ''bbsname'' should be set to something sensible\n')
    failed:=1
  ENDIF

  IF StrLen(bbsName) > 40
    WriteF('Config: ''bbsname'' cannot be longer than 40 characters after PIPE codes evaluation\n')
    failed:=1
  ENDIF
  
  param:=params[]
  WHILE(param<>0)
  
    IF StrLen(param) > 64
      WriteF('Config: ''\s'' cannot be longer than 64 characters\n',param)
      failed:=1
    ENDIF
    params++
    param:=params[]
    
  ENDWHILE

  IF failed
    WriteF('This must be fixed in mrc_client.cfg\n')
  ENDIF
ENDPROC failed

PROC main() HANDLE
  DEF tempstr[255]:STRING
  DEF myargs:PTR TO LONG,rdargs
  DEF intv:PTR TO LONG
  DEF res,listenSock,i
  DEF userConn:PTR TO userConnection
  
  clients:=List(100)
  
  intv:=[1, 2, 5, 10, 30, 60, 120, 180, 240, 300]   -> Auto-restart intervals

  myargs:=[0,0]:LONG
  IF rdargs:=ReadArgs('HOSTNAME/A,PORT/N/A',myargs,NIL)
    StrCopy(host,myargs[0])
    myargs:=myargs[1]
    port:=myargs[0]
    FreeArgs(rdargs)
  ELSE
    WriteF('run this with your machine hostname, port as a parameter\n')
    WriteF('mrc_client <hostname> <port>\n')
    RETURN
  ENDIF

  setDefaults()
  
  logger(version)

	socketbase:=OpenLibrary('bsdsocket.library',2)
  IF socketbase=NIL
    WriteF('Unable to open bsdsocket.library\n')
    RETURN
  ENDIF

  readConfiguration()
  
  IF check_startup()<>FALSE THEN RETURN
  delay:=0
  
  res,listenSock:=openListenSocket(5000)
  IF res=FALSE
    RETURN
  ENDIF
  
  REPEAT
    mainproc(listenSock)

    -> Incremental auto-restart built-in
    StringF(tempstr,'Reconnecting in \d seconds',intv[delay])
    logger(tempstr)
    
    Delay(intv[delay]*50)
    delay++
    IF delay > 9 THEN delay:=0
  UNTIL CtrlC()
EXCEPT DO
  logger('Shutting down')
  send_shutdown()
  Shutdown(mrcserver,2)
  CloseSocket(mrcserver)
  FOR i:=0 TO ListLen(clients)-1
    userConn:=clients[i]
    CloseSocket(userConn.socket)
    Dispose(userConn)
  ENDFOR
  IF listenSock<>-1 THEN CloseSocket(listenSock)
	CloseLibrary(socketbase)
  Dispose(clients)
ENDPROC
