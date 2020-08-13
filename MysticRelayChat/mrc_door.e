MODULE 'dos/dos','dos/dosasl','dos/datetime','socket','net/netdb','net/in','net/socket','AEDoor'

/*
 check protocol for spaces to underscores conversion
 nick autocompletion
 nick mention highlight
 scrolling banners

 cursor left/right
 buffer history
 dl chatlog
 put strings into settings
 persist settings for user
 /set update settings
 changes page
 latency
*/

CONST ERR_EXCEPT=1

CONST EAGAIN=35
CONST ECONNRESET=54
CONST FIONBIO=$8004667e

CONST CHAR_BACKSPACE=8
CONST UPARROW=4
CONST DOWNARROW=5

CONST MAX_BUFFER=140    -> Max input buffer limit [sf]

DEF userTag[255]:STRING
DEF siteTag[255]:STRING
DEF myRoom[255]:STRING
DEF userName[100]:STRING
DEF myNamePrompt[255]:STRING
DEF mrcVersion[255]:STRING
DEF lastPrivMsg[255]:STRING
DEF mrcserver=-1
DEF iMaxBuffer=75
DEF diface,strfield:LONG
DEF chatLines:PTR TO LONG
DEF inputStr[255]:STRING
DEF roomUsers=NIL:PTR TO CHAR

DEF currRoom[255]:STRING
DEF currTopic[255]:STRING
DEF currCount=0
DEF exitChat=FALSE

DEF inputColour=13

PROC strCmpi(s1:PTR TO CHAR,s2:PTR TO CHAR,len=ALL)
  DEF ts1,ts2,r
  ts1:=String(StrLen(s1))
  ts2:=String(StrLen(s2))
  StrCopy(ts1,s1)
  StrCopy(ts2,s2)
  LowerStr(ts1)
  LowerStr(ts2)
  r:=StrCmp(ts1,ts2,len)
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

PROC getTime(outTimeStr:PTR TO CHAR)
  DEF d : PTR TO datestamp
  DEF dt : datetime
  DEF datestr[10]:STRING
  DEF daystr[10]:STRING
  DEF timestr[10]:STRING
  DEF r,dateVal

  d:=dt.stamp
  DateStamp(d)

  dt.format:=FORMAT_DOS
  dt.flags:=0
  dt.strday:=0
  dt.strdate:=0
  dt.strtime:=timestr

  IF DateToStr(dt)
    StringF(outTimeStr,'\s[5]',timestr)
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC updateMaxBuffersize()
  iMaxBuffer:=255-(StrLen(userTag)+StrLen(siteTag)+(StrLen(myRoom)*2)+StrLen(myNamePrompt)+20)
  IF iMaxBuffer>MAX_BUFFER THEN iMaxBuffer:=MAX_BUFFER
  
  IF strCmpi(inputStr,'/RAINBOW ',9)
    iMaxBuffer:=(iMaxBuffer/4) - 4
  ENDIF
ENDPROC

PROC showTitle()
  DEF tempstr[255]:STRING
  StringF(tempstr,'\c',12)
  WriteStr(diface,tempstr,0)
  WriteStr(diface,'[0m.------------------------------- [34mMu[36mlti [0mRela[36my Ch[34mat [0m-----------------------------.',0)
  updateHeader()
  WriteStr(diface,'[3;1H[0m|[70C/? H[36me[36mlp [0m|\b\n',0)
  WriteStr(diface,'[5;1H[0m`------------------------------------------------------------------------------''',0)
  updateFooter()
ENDPROC

PROC updateHeartbeat(anim)
  DEF tempstr[255]:STRING
  IF anim
    StringF(tempstr,'[0m[\d;77H+[\d;\dH',ListLen(chatLines)+6,ListLen(chatLines)+7,Min(79,StrLen(inputStr)+1))
  ELSE
    StringF(tempstr,'[0m[\d;77H [\d;\dH',ListLen(chatLines)+6,ListLen(chatLines)+7,Min(79,StrLen(inputStr)+1))
  ENDIF
  WriteStr(diface,tempstr,0)
ENDPROC

PROC updateHeader()
  DEF tempstr[255]:STRING
  StringF(tempstr,'[2;1H[0m| R[36moom  [33m>[0m>> [K[67C|[68D\s',currRoom)
  WriteStr(diface,tempstr,0)
  StringF(tempstr,'[4;1H[0m| T[36mopic [33m>[0m>> [K[67C|[68D\s',currTopic)
  WriteStr(diface,tempstr,0)
ENDPROC

PROC updateFooter()
  DEF tempstr[255]:STRING
  updateMaxBuffersize()
  StringF(tempstr,'[\d;1H[0m--[Latency-000ms]-[Chatters-\r\z\d[2]]---------------------[Buffer-\r\z\d[3]/\r\z\d[3]]-[[36mM[34mR[36mC[0m]-[ ]--',ListLen(chatLines)+6,currCount,StrLen(inputStr),iMaxBuffer)
  WriteStr(diface,tempstr,0)
ENDPROC

PROC displayCurrentInput()
  DEF tempstr[255]:STRING
  DEF tempInput[80]:STRING
  IF StrLen(inputStr)>78
  	RightStr(tempInput,inputStr,78)
  ELSE
    StrCopy(tempInput,inputStr)
  ENDIF
  StringF(tempstr,'[\d;1H[K[0m|\r\z\d[2]\s',ListLen(chatLines)+7,inputColour,tempInput)
  pipeToAnsi(tempstr)
  WriteStr(diface,tempstr,0)
ENDPROC

PROC showChat()
  DEF i
  DEF tempstr[255]:STRING
  
  FOR i:=0 TO ListLen(chatLines)-1
    StringF(tempstr,'[\d;1H[0m[K\s',i+6,chatLines[i])
    WriteStr(diface,tempstr,0)
  ENDFOR
 
  displayCurrentInput()
ENDPROC

PROC add2Chat(s:PTR TO CHAR)
  DEF timeStr[10]:STRING
  DEF tempstr[255]:STRING
  DEF tempCharStr[1]:STRING
  DEF lastColourCode[3]:STRING
  DEF i,c

  getTime(timeStr)  
  i:=0
  c:=0
  StringF(tempstr,'\s ',timeStr)
  StrCopy(tempCharStr,'#')
  StrCopy(lastColourCode,'')
  WHILE i<StrLen(s)
    IF s[i]<>"|"
      tempCharStr[0]:=s[i]
      StrAdd(tempstr,tempCharStr)
      c++
      i++
    ELSE
      StrCopy(lastColourCode,'###')
      lastColourCode[0]:=s[i]
      lastColourCode[1]:=s[i+1]
      lastColourCode[2]:=s[i+2]
      StrAdd(tempstr,lastColourCode)
      i:=i+3
    ENDIF
    IF c=(78-StrLen(timeStr))
      addChatLine(tempstr)
      StringF(tempstr,'\s \s',timeStr,lastColourCode)
      c:=0
    ENDIF
  ENDWHILE
  IF c>0 THEN addChatLine(tempstr)
ENDPROC

PROC pipeToAnsi(s:PTR TO CHAR)
  DEF clsStr[2]:STRING
  replaceStr(s,'|00','[30m')
  replaceStr(s,'|01','[35m')
  replaceStr(s,'|02','[36m')
  replaceStr(s,'|03','[31m')
  replaceStr(s,'|04','[32m')
  replaceStr(s,'|05','[33m')
  replaceStr(s,'|06','[34m')
  replaceStr(s,'|07','[35m')
  replaceStr(s,'|08','[36m')
  replaceStr(s,'|09','[31m')
  replaceStr(s,'|10','[32m')
  replaceStr(s,'|11','[33m')
  replaceStr(s,'|12','[34m')
  replaceStr(s,'|13','[35m')
  replaceStr(s,'|14','[36m')
  replaceStr(s,'|15','[37m')

  replaceStr(s,'|16','[40m')
  replaceStr(s,'|17','[45m')
  replaceStr(s,'|18','[46m')
  replaceStr(s,'|19','[41m')
  replaceStr(s,'|20','[42m')
  replaceStr(s,'|21','[43m')
  replaceStr(s,'|22','[44m')
  replaceStr(s,'|23','[45m')
  replaceStr(s,'|24','[46m')
  replaceStr(s,'|25','[41m')
  replaceStr(s,'|26','[42m')
  replaceStr(s,'|27','[43m')
  replaceStr(s,'|28','[44m')
  replaceStr(s,'|29','[45m')
  replaceStr(s,'|30','[46m')
  replaceStr(s,'|31','[47m')
  
  StringF(clsStr,'\c',12)
  replaceStr(s,'|CL',clsStr)
ENDPROC

PROC addChatLine(s:PTR TO CHAR)  
  DEF i
  DEF tempstr[255]:STRING
  StrCopy(tempstr,s)

  pipeToAnsi(tempstr)

  FOR i:=1 TO ListLen(chatLines)-1
    StrCopy(chatLines[i-1],chatLines[i])
  ENDFOR
  StrCopy(chatLines[ListLen(chatLines)-1],tempstr)
  
ENDPROC

-> Display error message to chat window [sf]
PROC showError(s:PTR TO CHAR)
  DEF tempstr[255]:STRING
  StringF(tempstr,'|15!|12 \s',s)
  add2Chat(tempstr)
  showChat()
ENDPROC

PROC rainbowStr(source:PTR TO CHAR, dest:PTR TO CHAR)
  DEF i
  DEF tempstr[100]:STRING
  StrCopy(dest,'')
  FOR i:=0 TO StrLen(source)-1
    StringF(tempstr,'|\r\z\d[2]\c',Rnd(14)+1,source[i])
    StrAdd(dest,tempstr)
  ENDFOR

ENDPROC

PROC showWelcome()
  DEF tempstr[255]:STRING
  -> Welcome info text [sf]
  
  StringF(tempstr,'|14* |10Welcome to \s',mrcVersion)
  add2Chat(tempstr)
  add2Chat('|14* |11UP|10/|11DN|10 arrows to change your chat text color and |11TAB|10 for nick completion')
  add2Chat('|14* |11ESC|10 to clear input buffer')
  add2Chat('|14* |10The bottom-right heartbeat indicates your status with BBS and server')

  StringF(tempstr,'|14* |10Your maximum message length is \d characters',iMaxBuffer)
  add2Chat(tempstr)
  showChat()
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
  showChat()
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
  DEF tempstr[255]:STRING

  IF StrLen(s) > 30 
    showError('Room name is limited to 30 chars max')
  ELSE
    IF StrLen(s) > 0
      StrCopy(oldRoom,myRoom)
      StrCopy(newRoom,s)
      LowerStr(newRoom)
      replaceStr(newRoom,'#','')
      StringF(tempstr,'NEWROOM:\s:\s',myRoom,newRoom)
      sendToServer(tempstr)
      IF b
        StringF(tempstr,'|07- |10You have left room |02\s',oldRoom)
        sendToMe(tempstr)
        StringF(tempstr,'|07- |02\s |10has left the room.',userTag)
        sendToRoomNotMe(tempstr)
        StrCopy(myRoom,newRoom)
        StringF(tempstr,'|07- |11You are now in |02\s',newRoom)
        sendToMe(tempstr)
        StringF(tempstr,'|07- |11\s |03has entered the room.',userTag)
        sendToRoomNotMe(tempstr)
      ENDIF
      StrCopy(myRoom,newRoom)
      ->SetPromptInfo(4,'#'+S)
      ->UpdateScreen
      sendToServer('USERLIST')
    ENDIF
  ENDIF
ENDPROC

PROC enterChat()
  DEF tempstr[255]:STRING
  showTitle()
  showWelcome()

  add2Chat('|07- |15You have entered chat')
  add2Chat('')
  StringF(tempstr,'|07- |11\s |03has arrived!',userTag)
  sendToAllNotMe(tempstr)
  Delay(20)
  sendToServer('IAMHERE')
  Delay(20)
  sendToServer('BANNERS')
  showChat()
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

PROC stats(s:PTR TO CHAR)
->incoming stats
ENDPROC

PROC message(s:PTR TO CHAR)
  add2Chat(s)
  showChat()
ENDPROC

PROC banner(s:PTR TO CHAR)
  add2Chat(s)
  showChat()
ENDPROC

PROC roomTopic(room:PTR TO CHAR,topic:PTR TO CHAR)
  StrCopy(currRoom,room)
  StrCopy(currTopic,topic)
  updateHeader()
ENDPROC

PROC userList(s:PTR TO CHAR)
  DEF i
  currCount:=1
  IF (roomUsers<>NIL)
    Dispose(roomUsers)
    roomUsers:=String(StrLen(s)+200)
    StringF(roomUsers,',\s,',s)
    replaceStr(roomUsers,' ','')
  ENDIF
  FOR i:=0 TO StrLen(s)-1
   IF s[i]="," THEN currCount++
  ENDFOR
  updateFooter()
ENDPROC

PROC logoff(s:PTR TO CHAR)
  ->add2Chat(s)
ENDPROC

PROC doCls()
  DEF i
  FOR i:=0 TO ListLen(chatLines)-1
    StrCopy(chatLines[i],'')
  ENDFOR
  showChat()
ENDPROC

PROC doHelp()
  DEF tempstr[255]:STRING
  StringF(tempstr,'\c[0;44m \l\s[67][0m',12,'MULTI RELAY CHAT COMMANDS')
  WriteStr(diface,tempstr,LF)
  WriteStr(diface,'.------------------------------------------------------------------.',LF)
  WriteStr(diface,'| /B <text>                   Broadcast message to all channels    |',LF)
  WriteStr(diface,'| /CLS                        Clears window and scrollback text    |',LF)
  WriteStr(diface,'| /MSG or /M <user> <text>    Sends a private message              |',LF)
  WriteStr(diface,'| /TELL or /T <user> <text>   Sends a private message              |',LF)
  WriteStr(diface,'| /TOPIC <text>               Set the TOPIC of the current channel |',LF)
  WriteStr(diface,'| /WHO                        List all users on current BBS system |',LF)
  WriteStr(diface,'| /ME <text>                  Perform an action                    |',LF)
  WriteStr(diface,'| /JOIN <channel>             Join a new channel [name]            |',LF)
  WriteStr(diface,'| /SCROLL                     Enter scrollback mode                |',LF)
  WriteStr(diface,'| /Q or /QUIT                 Leave/Quit Multi Relay Chat          |',LF)
  WriteStr(diface,'|------------------------------------------------------------------|',LF)
  WriteStr(diface,'| /WHOON      List all users bbs   /ROOMS       List all rooms     |',LF)
  WriteStr(diface,'| /BBSES      List all BBS''s       /USERS       List all users     |',LF)
  WriteStr(diface,'| /CHANNEL    List channel users   /INFO        Show info on BBS   |',LF)
  WriteStr(diface,'| /CHATTERS   List all users room  /DLCHATLOG   Download chat log  |',LF)
  WriteStr(diface,'| /CHANGES    List of changes      /HELP        Show server help   |',LF)
  WriteStr(diface,'| /VERSION    Check client and server versions                     |',LF)
  WriteStr(diface,'| /SET        Set various fields to your account (/SET HELP)       |',LF)
  WriteStr(diface,'`------------------------------------------------------------------''',LF)
  SendStrDataCmd(diface,DT_TIMEOUT,'300',0)
  HotKey(diface,'')
  SendStrDataCmd(diface,DT_TIMEOUT,'1',0)
  showTitle()
  showChat()
ENDPROC

PROC showChanges()
->does nothing yet
ENDPROC

PROC doBroadcast(s:PTR TO CHAR)
  DEF tempStr[255]:STRING
  StringF(tempStr,'|15* |08(|15\s|08/|14Broadcast|08) |07\s',userTag,s)
  sendToAll(tempStr)
ENDPROC

PROC leaveChat()
  DEF tempStr[255]:STRING

  add2Chat('|07- |15You have left chat.')
  StringF(tempStr,'|07- |12\s |04has left chat.',userTag)
  sendToAllNotMe(tempStr)
  showChat()
  Delay(25)
  sendToServer('LOGOFF')
  showChat()
ENDPROC

PROC doMeAction(s:PTR TO CHAR)
  DEF tempStr[255]:STRING
  StringF(tempStr,'|15* |13\s \s',userTag,s)
  sendToRoom(tempStr)
ENDPROC

PROC doPrivateMessage(s:PTR TO CHAR)
  DEF toName[255]:STRING
  DEF tempStr[255]:STRING
  DEF p
  
  s:=TrimStr(s)
  p:=InStr(s,' ')
  StrCopy(toName,s,p)

  StringF(tempStr,'|15* |08(|15\s|08/|14PrivMsg|08) |07\s',userTag,TrimStr(s+p))
  sendToUser(toName,tempStr)
  StringF(tempStr,'|15* |08(|14PrivMsg|08->|15\s|08) |07',userTag,TrimStr(s+p))
  add2Chat(tempStr)
  showChat()
ENDPROC

PROC changeTopic(s:PTR TO CHAR)
  DEF tempStr[255]:STRING
  
  IF StrLen(s)>55
    showError('Topic is limited to 55 chars max')
  ELSE
    StringF(tempStr,'NEWTOPIC:\s:\s',myRoom,s)
    sendToServer(tempStr)
  ENDIF
ENDPROC

PROC checkUserList(userName:PTR TO CHAR)
  DEF tempStr[255]:STRING
  DEF newUsers
  IF StrCmp(userName,'SERVER') OR StrCmp(userName,'CLIENT') THEN RETURN
  StringF(tempStr,',\s,',userName)
  IF InStr(roomUsers,tempStr)=-1
    IF (StrLen(roomUsers)+StrLen(userName)+1)>=StrMax(roomUsers)
      newUsers:=String(StrLen(roomUsers)+200)
      StringF(newUsers,'\s\s,',roomUsers,userName)
      Dispose(roomUsers)
      roomUsers:=newUsers
    ELSE
      StrAdd(roomUsers,userName)
      StrAdd(roomUsers,',')
    ENDIF
    updateFooter()
  ENDIF
ENDPROC

PROC processUserInput(s:PTR TO CHAR)
  DEF tempstr[255]:STRING
  IF StrLen(s)>0
    IF s[0]="/"
      StrCopy(tempstr,s)
      UpperStr(tempstr)
      IF StrCmp(tempstr,'/CHANGES')
        showChanges()
      ELSEIF StrCmp(tempstr,'/CLS')
        doCls()
      ELSEIF StrCmp(tempstr,'/?')
        doHelp()
      ELSEIF StrCmp(tempstr,'/B ',3)
        doBroadcast(s+3)
      ELSEIF StrCmp(tempstr,'/Q') OR StrCmp(tempstr,'/QUIT')
        leaveChat()
        exitChat:=TRUE
      ELSEIF StrCmp(tempstr,'/JOIN ',6)
        joinRoom(s+6,TRUE)
      ELSEIF StrCmp(tempstr,'/ME ',4)
        doMeAction(s+4)
      ELSEIF StrCmp(tempstr,'/TOPIC ',7)
        changeTopic(s+7)
      ELSEIF StrCmp(tempstr,'/MOTD')
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
      ELSEIF StrCmp(tempstr,'/T ',3) OR StrCmp(tempstr,'/M ',3)
        doPrivateMessage(s+3)
      ELSEIF StrCmp(tempstr,'/MSG ',5)
        doPrivateMessage(s+5)
      ELSEIF StrCmp(tempstr,'/TELL ',6)
        doPrivateMessage(s+6)
      ELSEIF StrCmp(tempstr,'/INFO ',6)
        StringF(tempstr,'INFO \s',s+6)
        sendToServer(tempstr)
      ELSEIF StrCmp(tempstr,'/QUOTE ',7)
        sendToServer(s+7)
      ELSEIF StrCmp(tempstr,'/VERSION',8)
        sendToServer('VERSION')
        StringF(tempstr,'|07- |13\s',mrcVersion)
        add2Chat(tempstr)
      ENDIF            
      
/*                '/DLCHATLOG' : DLChatLog
                '/SCROLL'    : DoScrollBack
                '/WHO'       : DoWho*/
      
    ELSE
      StringF(tempstr,'\s|\r\z\d[2]\s',myNamePrompt,inputColour,s)
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
      ELSEIF StrCmp(params[0],'HELLO')
        sendToServer('IAMHERE')
      ELSE
        message(msg)
      ENDIF
      Dispose(params)
    ELSEIF StrCmp(touser,'SERVER')
      IF StrCmp(msg,'LOGOFF')
        logoff(fromuser)
      ENDIF
    ELSEIF (StrLen(touser)=0) OR (strCmpi(touser,userTag))
      IF (StrLen(toroom)=0) OR (StrCmp(toroom,myRoom))
        checkUserList(fromuser)
        message(msg)
      ENDIF
    ELSEIF StrCmp(touser,'NOTME') AND (strCmpi(fromuser,userTag)=FALSE)
      checkUserList(fromuser)
      message(msg)
    ENDIF

    IF (StrCmp(fromuser,'SERVER')=FALSE) AND (StrCmp(fromuser,'CLIENT')=FALSE)
      IF strCmpi(touser,userTag) THEN StrCopy(lastPrivMsg,fromuser)
    ENDIF
  ENDIF
  Dispose(packet)

ENDPROC

PROC main() HANDLE
  DEF readBuffer=0
  DEF i,b,e,res,m
  DEF sa=0:PTR TO sockaddr_in
  DEF tempstr[255]:STRING
  DEF tempstr2[255]:STRING

  DEF addr: PTR TO LONG
  DEF hostEnt: PTR TO hostent
  DEF p
  DEF sep[2]:STRING
  DEF tdat:PTR TO LONG
  DEF data
  DEF anim=0
  
  StrCopy(mrcVersion,'Multi Relay Chat door v1.2.9a [sf]')
  
	socketbase:=OpenLibrary('bsdsocket.library',2)
  IF socketbase=NIL
    WriteStr(diface,'Unable to open bsdsocket.library',LF)
    RETURN
  ENDIF

  IF aedoorbase:=OpenLibrary('AEDoor.library',1)
    diface:=CreateComm(arg[])     /* Establish Link   */
    strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
  ENDIF
  
  GetDT(diface,DT_NAME,0)
  StrCopy(userTag,strfield)
  replaceStr(userTag,'~','')

  GetDT(diface,JH_BBSNAME,0)
  StrCopy(siteTag,strfield)
  replaceStr(siteTag,'~','')

  GetDT(diface,501,0)

  StringF(myNamePrompt,'|03<|11\s|03>|16|07 ',userTag)


  IF strCmpi(userTag,'SERVER') OR strCmpi(userTag,'CLIENT') OR strCmpi(userTag,'NOTME')
    StrCopy(tempstr,'|16|12|CL|CRUnfortunately, your User Alias is a reserved word and therefore cannot be used.')
    pipeToAnsi(tempstr)
    WriteStr(diface,tempstr,LF)
    StrCopy(tempstr,'|12Please ask your SysOp to change your User Alias to use MRC.')
    pipeToAnsi(tempstr)
    WriteStr(diface,tempstr,LF)
    Raise(ERR_EXCEPT)
  ENDIF

  updateMaxBuffersize()

  chatLines:=List(20)
  FOR i:=0 TO ListMax(chatLines)-1
    ListAdd(chatLines,[String(255)])
  ENDFOR
  
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
    WriteStr(diface,tempstr,LF)
    Raise(ERR_EXCEPT)
  ENDIF
  
  IoctlSocket(mrcserver,FIONBIO,[1])
  
  enterChat()
  joinRoom('lobby',FALSE)
  
  SendStrDataCmd(diface,DT_TIMEOUT,'1',0)
  
  readBuffer:=New(8193)
  REPEAT
    anim:=Eor(anim,1)
    updateHeartbeat(anim)
    
    b:=Recv(mrcserver,readBuffer,8192,0)
    IF b=-1
      e:=Errno()
      IF e<>EAGAIN
        StringF(tempstr,'socket error \d',e)
        WriteStr(diface,tempstr,LF)
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

    updateMaxBuffersize()
    
    m:=HotKey(diface,'')
    IF m>0
      IF m=3
        IF exitChat=FALSE
          leaveChat()
          exitChat:=TRUE
        ENDIF
      ELSEIF m=27
        StrCopy(inputStr,'')
        updateFooter()        
        displayCurrentInput()    
      ELSEIF (m=UPARROW) AND (inputColour<15)
        inputColour++
        displayCurrentInput()
      ELSEIF (m=DOWNARROW)  AND (inputColour>9)
        inputColour--
        displayCurrentInput()
      ELSEIF (m=CHAR_BACKSPACE) 
        IF StrLen(inputStr)>0
          SetStr(inputStr,StrLen(inputStr)-1)
          updateFooter()        
          displayCurrentInput()
        ENDIF
      ELSEIF (m>31) AND (m<126) AND (StrLen(inputStr)<iMaxBuffer)
        IF (m<>32) OR (StrLen(inputStr)>0)
          StrCopy(tempstr,'#')
          tempstr[0]:=m
          StrAdd(inputStr,tempstr)
          updateFooter()
          displayCurrentInput()
        ENDIF
      ELSEIF m=13
        IF StrLen(inputStr)>0
          IF strCmpi(inputStr,'/RAINBOW ',9)
            rainbowStr(inputStr+9,tempstr2)
          ELSE
            StrCopy(tempstr2,inputStr)
          ENDIF
          StrCopy(inputStr,'')
          updateFooter()
          displayCurrentInput()
          processUserInput(tempstr2)
        ENDIF
      ENDIF
      
      IF (strCmpi(inputStr,'/R ',3)) AND (StrLen(lastPrivMsg)>0)
        StringF(inputStr,'/T \s ',lastPrivMsg)
        updateFooter()
        displayCurrentInput()
      ENDIF
    ENDIF
  UNTIL exitChat
 
EXCEPT DO
  IF roomUsers<>NIL THEN Dispose(roomUsers)
  IF readBuffer THEN Dispose(readBuffer)
  IF mrcserver<>-1 THEN CloseSocket(mrcserver)
  IF socketbase<>NIL THEN CloseLibrary(socketbase)
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC
