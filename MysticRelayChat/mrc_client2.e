
MODULE 'dos/dos','dos/dosasl','dos/datetime','socket','net/netdb','net/in','net/socket','intuition/intuition'

CONST ERR_EXCEPT=1

CONST EAGAIN=35
CONST ECONNRESET=54
CONST FIONBIO=$8004667e
CONST CHAR_BACKSPACE=8

DEF userTag[255]:STRING
DEF siteTag[255]:STRING
DEF myRoom[255]:STRING
DEF userName[100]:STRING
DEF namePrompt[255]:STRING
DEF mrcserver=-1
DEF iMaxBuffer=100

PROC strCmpi(s1:PTR TO CHAR,s2:PTR TO CHAR)
  DEF ts1,ts2,r
  ts1:=String(StrLen(s1))
  ts2:=String(StrLen(s2))
  LowerStr(ts1)
  LowerStr(ts2)
  r:=StrCmp(ts1,ts2)
  Dispose(ts1)
  Dispose(ts2)
ENDPROC r

PROC replaceStr(source:PTR TO CHAR, search:PTR TO CHAR, replace:PTR TO CHAR)
  DEF workStr[255]:STRING
  DEF s
  WHILE (s:=InStr(source,search))<>-1
    StrCopy(workStr,source,s)
    StrAdd(workStr,replace)
    StrAdd(workStr,source+s+StrLen(search))
    StrCopy(source,workStr)
  ENDWHILE
ENDPROC

PROC add2Chat(s:PTR TO CHAR)
  DEF tempstr[255]:STRING
  StrCopy(tempstr,s)
  replaceStr(tempstr,'|00','[30m')
  replaceStr(tempstr,'|01','[31m')
  replaceStr(tempstr,'|02','[32m')
  replaceStr(tempstr,'|03','[33m')
  replaceStr(tempstr,'|04','[34m')
  replaceStr(tempstr,'|05','[35m')
  replaceStr(tempstr,'|06','[36m')
  replaceStr(tempstr,'|07','[31m')
  replaceStr(tempstr,'|08','[32m')
  replaceStr(tempstr,'|09','[33m')
  replaceStr(tempstr,'|10','[34m')
  replaceStr(tempstr,'|11','[35m')
  replaceStr(tempstr,'|12','[36m')
  replaceStr(tempstr,'|13','[31m')
  replaceStr(tempstr,'|14','[32m')
  replaceStr(tempstr,'|15','[37m')

  replaceStr(tempstr,'|16','[40m')
  replaceStr(tempstr,'|17','[41m')
  replaceStr(tempstr,'|18','[42m')
  replaceStr(tempstr,'|19','[43m')
  replaceStr(tempstr,'|20','[44m')
  replaceStr(tempstr,'|21','[45m')
  replaceStr(tempstr,'|22','[46m')
  replaceStr(tempstr,'|23','[47m')
  replaceStr(tempstr,'|24','[40m')
  replaceStr(tempstr,'|25','[41m')
  replaceStr(tempstr,'|26','[42m')
  replaceStr(tempstr,'|27','[43m')
  replaceStr(tempstr,'|28','[44m')
  replaceStr(tempstr,'|29','[45m')
  replaceStr(tempstr,'|30','[46m')
  replaceStr(tempstr,'|31','[47m')

  WriteF('\s\n',tempstr)
ENDPROC

-> Display error message to chat window [sf]
PROC showError(s:PTR TO CHAR)
  DEF tempstr[255]:STRING
  StringF(tempstr,'|15!|12 \s',s)
  add2Chat(tempstr)
ENDPROC

PROC showWelcome()
  DEF tempstr[255]:STRING
  -> Welcome info text [sf]
  
  add2Chat('* |10Welcome to Multi Relay Chat MPL v1.2.9a [sf]')
  StringF(tempstr,'* |10Your maximum message length is \d characters',iMaxBuffer)
  add2Chat(tempstr)
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

PROC sendOut(fu:PTR TO CHAR,fs:PTR TO CHAR,fr:PTR TO CHAR,tu:PTR TO CHAR,ts:PTR TO CHAR,tr:PTR TO CHAR,s:PTR TO CHAR)
DEF tx[1000]:STRING
  StringF(tx,'\s~\s~\s~\s~\s~\s~\s~\n',fu,fs,fr,tu,ts,tr,s)
  Send(mrcserver,tx,StrLen(tx),0)
ENDPROC

PROC sendToServer(s:PTR TO CHAR)
  sendOut(userTag,siteTag,myRoom,'SERVER',siteTag,myRoom,s)
ENDPROC

PROC sendToMe(s:PTR TO CHAR)
  add2Chat(s)
  ->ShowChat(0)
ENDPROC

PROC sendToAllNotMe(s:PTR TO CHAR)
  sendOut(userTag,siteTag,myRoom,'NOTME','','',s)
ENDPROC
        
PROC sendToRoomNotMe(s:PTR TO CHAR)
  sendOut(userTag,siteTag,myRoom,'NOTME','',myRoom,s)
ENDPROC

PROC sendToAll(s:PTR TO CHAR)
  sendOut(userTag,siteTag,myRoom,'','','',s)
ENDPROC

PROC sendToRoom(s:PTR TO CHAR)
  sendOut(userTag,siteTag,myRoom,'','',myRoom,s)
ENDPROC

PROC sendToUser(u:PTR TO CHAR, s:PTR TO CHAR)
  sendOut(userTag,siteTag,myRoom,u,'','',s)
ENDPROC

PROC sendToClient(s:PTR TO CHAR)
  sendOut(userTag,siteTag,myRoom,'CLIENT',siteTag,myRoom,s)
ENDPROC

PROC joinRoom(s:PTR TO CHAR,b)
  DEF newRoom[32]:STRING
  DEF oldRoom[32]:STRING
  DEF tmpRoom[32]:STRING
  DEF tempstr[255]:STRING

  IF StrLen(s) > 30 
    showError('Room name is limited to 30 chars max')
  ELSE
    IF StrLen(s) > 0
      StrCopy(oldRoom,myRoom)
      StrCopy(newRoom,s)
      LowerStr(newRoom)
      StrCopy(tmpRoom,s)
      replaceStr(tmpRoom,'#','')
      StringF(tempstr,'NEWROOM:\s:\s',myRoom,tmpRoom)
      sendToServer(tempstr)
      IF b
        StringF(tempstr,'|07- |10You have left room |02\s',oldRoom)
        sendToMe(tempstr)
        StringF(tempstr,'|07- |02\s |10has left the room.',userName)
        sendToRoomNotMe(tempstr)
        StrCopy(myRoom,newRoom)
        StringF(tempstr,'|07- |11You are now in |02\s',newRoom)
        sendToMe(tempstr)
        StringF(tempstr,'|07- |11\s |03has entered the room.',userName)
        sendToRoomNotMe(tempstr)
      ENDIF
      StrCopy(myRoom,tmpRoom)
      ->SetPromptInfo(4,'#'+S)
      ->UpdateScreen
      sendToServer('USERLIST')
    ENDIF
  ENDIF
ENDPROC

PROC enterChat()
  DEF tempstr[255]:STRING
  showWelcome()

  add2Chat('|07- |15You have entered chat')
  add2Chat('')
  StringF(tempstr,'|07- |11\s |03has arrived!',userName)
  sendToAllNotMe(tempstr)
  Delay(20)
  sendToServer('IAMHERE')
  Delay(20)
  sendToServer('BANNERS')
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

PROC stats(s:PTR TO CHAR)
->incoming stats
ENDPROC

PROC message(s:PTR TO CHAR)
  add2Chat(s)
ENDPROC

PROC banner(s:PTR TO CHAR)
  add2Chat(s)
ENDPROC

PROC roomTopic(room:PTR TO CHAR,topic:PTR TO CHAR)
  DEF tempstr[255]:STRING
  StringF(tempstr,'Room: \s  Topic: \s',room,topic)
  add2Chat(tempstr)
  add2Chat('')
ENDPROC

PROC userList(s:PTR TO CHAR)
  add2Chat(s)
ENDPROC

PROC logoff(s:PTR TO CHAR)
  ->add2Chat(s)
ENDPROC

PROC processUserInput(s:PTR TO CHAR)
  DEF tempstr[255]:STRING
  IF StrLen(s)>0
    IF s[0]="/"
      StrCopy(tempstr,s)
      UpperStr(tempstr)
      IF StrCmp(tempstr,'/MOTD')
        sendToServer('MOTD')
      ELSEIF StrCmp(tempstr,'/HELP')
        sendToServer('HELP')
      ELSEIF StrCmp(tempstr,'/BBSES')
        sendToServer('CONNECTED')
      ELSEIF StrCmp(tempstr,'/CHANNEL')
        sendToServer('CHANNEL')
      ELSEIF StrCmp(tempstr,'/CHATTERS')
        sendToServer('CHATTERS')
      ELSEIF StrCmp(tempstr,'/LIST') OR StrCmp(tempstr,'/ROOMS')
        sendToServer('LIST')
      ELSEIF StrCmp(tempstr,'/USERS')
        sendToServer('USERS')
      ELSEIF StrCmp(tempstr,'/WHOON')
        sendToServer('WHOON')
      ENDIF        
    ELSE
      StringF(tempstr,'\s\s\s',namePrompt,'|11',s)
      replaceStr(tempstr,'~',' ')
      sendToRoom(tempstr)
    ENDIF
  ENDIF
ENDPROC

PROC processServerResponse(r:PTR TO CHAR)
  DEF packet:PTR TO LONG
  DEF fromuser[255]:STRING
  DEF fromsite[255]:STRING
  DEF fromroom[255]:STRING
  DEF tosite[255]:STRING
  DEF touser[255]:STRING
  DEF toroom[255]:STRING
  DEF msg[255]:STRING
  DEF tmpstr[255]:STRING
  DEF params:PTR TO LONG
  
  packet:=splitBuffer(r,'~')
  IF ListLen(packet)>6
    StrCopy(fromuser,packet[0])
    StrCopy(fromsite,packet[1])
    StrCopy(fromroom,packet[2])
    StrCopy(touser,packet[3])
    StrCopy(tosite,packet[4])
    StrCopy(toroom,packet[5])
    StrCopy(msg,packet[6])

    IF StrCmp(fromuser,'SERVER')    
      StrCopy(tmpstr,msg)
      params:=splitBuffer(tmpstr,':')
      IF StrCmp(params[0],'BANNER')
        banner(params[1])
      ELSEIF StrCmp(params[0],'ROOMTOPIC')
        roomTopic(params[1],params[2])
      ELSEIF StrCmp(params[0],'USERLIST')
        userList(params[1])
      ELSEIF StrCmp(params[0],'STATS')
        stats(params[1])
      ELSE
        message(msg)
      ENDIF
      Dispose(params)
    ELSEIF StrCmp(touser,'SERVER')
      IF StrCmp(msg,'LOGOFF')
        logoff(fromuser)
      ENDIF
    ELSEIF (StrLen(touser)=0) OR (strCmpi(touser,userName))
      IF (StrLen(toroom)=0) OR (StrCmp(toroom,myRoom))
        message(msg)
      ENDIF
/*            if (msg.to_room == state.room
                && state.nicks.indexOf(msg.from_user) < 0
            ) {
                send_command('USERLIST', 'ALL');
            }*/
    ELSEIF StrCmp(touser,'NOTME')
/*            if (msg.body.search(/left\ the\ (room|server)\.*$/ > -1)) {
                const udix = state.nicks.indexOf(msg.from_user);
                if (uidx > -1) {
                    state.nicks.splice(uidx, 1);
                    emit('nicks', state.nicks);
                }
            } else if (msg.body.search(/just joined room/) > -1) {
                send_command('USERLIST', 'ALL');
            }
            emit('message', msg);*/
      message(msg)
    ENDIF
    
  ELSE
    WriteF('Bad packet: \s',r)
  ENDIF
  Dispose(packet)

ENDPROC

PROC main() HANDLE
  DEF readBuffer=0
  DEF i,b,e,res
  DEF sa=0:PTR TO sockaddr_in
  DEF tempstr[255]:STRING

  DEF addr: PTR TO LONG
  DEF hostEnt: PTR TO hostent
  DEF p
  DEF wptr:PTR TO window
  DEF m:PTR TO intuimessage
  DEF inputStr[255]:STRING
  DEF tdat:PTR TO LONG
  DEF data
  DEF sep[2]:STRING

  StrCopy(userTag,'REbEL')
  StrCopy(userName,'REbEL')
  StrCopy(siteTag,'Unconfigured BBS')
  StringF(namePrompt,'|03<|11\s|03>|16|07 ',userName)

	socketbase:=OpenLibrary('bsdsocket.library',2)
  IF socketbase=NIL
    WriteF('Unable to open bsdsocket.library\n')
    RETURN
  ENDIF
   
  mrcserver:=Socket(AF_INET,SOCK_STREAM,0)

  hostEnt:=GetHostByName('localhost')
  addr:=hostEnt.h_addr_list[]
  addr:=addr[]
  
  NEW sa
  sa.sin_len:=SIZEOF sockaddr_in
  sa.sin_family:=2
  sa.sin_port:=5000
  sa.sin_addr:=addr[]

  res:=Connect(mrcserver,sa,SIZEOF sockaddr_in)
  
  END sa
  
  IF (res<>0) OR (Errno()<>0)
    StringF(tempstr,'Unable to connect to mrc proxy')
    CloseSocket(mrcserver)
    RETURN
  ENDIF
  
  IoctlSocket(mrcserver,FIONBIO,[1])
  
  enterChat()
  joinRoom('lobby',FALSE)
  
  wptr:=OpenW(0,300,640,100,IDCMP_VANILLAKEY,WFLG_SIMPLE_REFRESH OR WFLG_DRAGBAR,'Key input window',
                    NIL,1,NIL)

  
  readBuffer:=New(8193)
  REPEAT
    b:=Recv(mrcserver,readBuffer,8192,0)
    IF b=-1
      e:=Errno()
      IF e<>EAGAIN
        WriteF('socket error \d\n',e)
        Raise(ERR_EXCEPT)
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
            IF StrLen(data)>0 THEN processServerResponse(data)
          ENDIF
          i++
        ENDWHILE
        Dispose(tdat)
      ENDIF
    ENDIF
    Delay(50)
    m:=GetMsg(wptr.userport)
    
    IF m<>0
      IF (m.code=CHAR_BACKSPACE) 
        IF StrLen(inputStr)>0
          SetStr(inputStr,StrLen(inputStr)-1)
          StringF(tempstr,'\c \c',CHAR_BACKSPACE,CHAR_BACKSPACE)
          WriteF(tempstr)
        ENDIF
      ELSEIF (m.code>31) AND (m.code<127)
        StrCopy(tempstr,'#')
        tempstr[0]:=m.code
        StrAdd(inputStr,tempstr)
        WriteF(tempstr)
      ELSEIF m.code=13
        IF StrLen(inputStr)>0
          WriteF('\n')
          processUserInput(inputStr)
          StrCopy(inputStr,'')
        ENDIF
      ENDIF
    ENDIF
    
  UNTIL CtrlC()
 
EXCEPT DO
  IF wptr THEN CloseW(wptr)
  IF readBuffer THEN Dispose(readBuffer)
  IF mrcserver<>-1 THEN CloseSocket(mrcserver)
  IF socketbase<>NIL THEN CloseLibrary(socketbase)
ENDPROC
