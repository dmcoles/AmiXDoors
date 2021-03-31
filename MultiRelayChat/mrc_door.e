/* MRC Door */

  OPT LARGE

MODULE 'dos/dos','dos/dosasl','dos/datetime','socket','net/netdb','net/in','net/socket','exec/ports','devices/timer','dos/dosextens','exec/io','amigalib/ports','amigalib/io','exec/nodes'
MODULE 'AEDoor'                 /* Include libcalls & constants */
/*
 /who
*/

CONST ERR_EXCEPT=1

CONST EAGAIN=35
CONST ECONNRESET=54
CONST FIONBIO=$8004667e

CONST CHAR_BACKSPACE=8
CONST LEFTARROW=2
CONST RIGHTARROW=3
CONST UPARROW=4
CONST DOWNARROW=5

CONST MAX_BUFFER=140    -> Max input buffer limit [sf]

OBJECT ansi
  ansicode: INT
  buf[80]: ARRAY OF CHAR
ENDOBJECT

OBJECT userRec
  recIdx:LONG
  permIdx:LONG
  enterChatMe[80]:ARRAY OF CHAR
  enterChatRoom[80]:ARRAY OF CHAR
  enterRoomMe[80]:ARRAY OF CHAR
  enterRoomRoom[80]:ARRAY OF CHAR
  leaveChatMe[80]:ARRAY OF CHAR
  leaveChatRoom[80]:ARRAY OF CHAR
  leaveRoomMe[80]:ARRAY OF CHAR
  leaveRoomRoom[80]:ARRAY OF CHAR
  name[80]:ARRAY OF CHAR
  defaultRoom[80]:ARRAY OF CHAR
  temp1[80]:ARRAY OF CHAR
  temp5[80]:ARRAY OF CHAR
  temp6[80]:ARRAY OF CHAR
  temp7[80]:ARRAY OF CHAR
  nameColor[16]:ARRAY OF CHAR
  ltBracket[16]:ARRAY OF CHAR
  rtBracket[16]:ARRAY OF CHAR
  useClock:LONG
  clockFormat:LONG
ENDOBJECT

DEF diface=0,strfield:LONG
DEF node

DEF plyr=NIL:PTR TO userRec

DEF userFile[255]:STRING
DEF userTag[255]:STRING
DEF siteTag[255]:STRING
DEF userAlias[255]:STRING
DEF userIndex=0
DEF myRoom[255]:STRING
DEF myTopic[255]:STRING
DEF myNamePrompt[255]:STRING
DEF mrcVersion[255]:STRING
DEF mrcStats[255]:STRING
DEF lastPrivMsg[255]:STRING
DEF mrcserver=-1
DEF iMaxBuffer=75
DEF chatLines:PTR TO LONG
DEF inputStr[255]:STRING
DEF roomUsers=NIL:PTR TO CHAR
DEF bufferHist=NIL:PTR TO LONG
DEF bannerList=NIL:PTR TO LONG
DEF currCount=0
DEF exitChat=FALSE
DEF chatLog[255]:STRING

->DEF keycount=0

DEF inputColour=15
DEF numLines=29
DEF cursorPos=0
DEF bufferItem=-1
DEF charsEntered=FALSE
DEF latencyVal=0
DEF loop=0

DEF banIdx=-1
DEF bannerOff=0
DEF scrollWait=0
DEF scrollDly=0

DEF scrollSpeed=15

DEF userIdx=1    -> Index of UserList search [sf]
DEF lastUSearch[255]:STRING -> Last user search string [sf]

DEF ansi:ansi

PROC fetchKey()
  DEF res

  SendCmd(diface,GETKEY)
  IF StrCmp(strfield,'1')
    res:=HotKey(diface,'')
    SendDataCmd(diface,705,1) ->console cursor on
    RETURN res
  ENDIF
ENDPROC 0

PROC listAddItem(list:PTR TO LONG, item)
  DEF n
  n:=ListLen(list)
  ListAdd(list,[0])
  list[n]:=item
ENDPROC

PROC listAddNewString(list:PTR TO LONG, v, l=ALL)
  DEF n
  n:=ListLen(list)
  ListAdd(list,[0])
  list[n]:=String(StrLen(v))
  StrCopy(list[n],v,l)
ENDPROC

/*PROC strCmpi(s1:PTR TO CHAR,s2:PTR TO CHAR,len=ALL)
  DEF ts1,ts2,r
  ts1:=String(StrLen(s1))
  ts2:=String(StrLen(s2))
  StrCopy(ts1,s1)
  StrCopy(ts2,s2)
  LowerStr(ts1)
  LowerStr(ts2)
  r:=StrCmp(ts1,ts2,len)
  DisposeLink(ts1)
  DisposeLink(ts2)
ENDPROC r*/

PROC charToLower(c)
  /* convert a given char to lowercase */
  DEF str[1]:STRING
  str[0]:=c
  LowerStr(str)
ENDPROC str[0]

PROC strCmpi(test1: PTR TO CHAR, test2: PTR TO CHAR, len=ALL)
  /* case insensitive string compare */
  DEF i,l1,l2

  IF len=ALL
    l1:=StrLen(test1)
    l2:=StrLen(test2)
    IF l1<>l2 THEN RETURN FALSE
    len:=l1
  ENDIF

  FOR i:=0 TO len-1
    IF charToLower(test1[i])<>charToLower(test2[i]) THEN RETURN FALSE
  ENDFOR
ENDPROC TRUE

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

PROC getDateTime(outDateStr:PTR TO CHAR)
  DEF datestr[10]:STRING
  DEF timestr[10]:STRING
  DEF d : PTR TO datestamp
  DEF dt : datetime

  d:=dt.stamp
  DateStamp(d)

  dt.format:=FORMAT_DOS
  dt.flags:=0
  dt.strday:=0
  dt.strdate:=datestr
  dt.strtime:=timestr

  IF DateToStr(dt)
    StringF(outDateStr,'\s[7]\d\s \s',datestr,IF dt.stamp.days>=8035 THEN 20 ELSE 19,datestr+7,timestr)
  ENDIF 
ENDPROC

PROC getTime(outTimeStr:PTR TO CHAR)
  DEF d : PTR TO datestamp
  DEF dt : datetime
  DEF timestr[10]:STRING
  DEF hours[2]:STRING
  DEF hr

  d:=dt.stamp
  DateStamp(d)

  dt.format:=FORMAT_DOS
  dt.flags:=0
  dt.strday:=0
  dt.strdate:=0
  dt.strtime:=timestr
  
  IF DateToStr(dt)
    IF plyr.clockFormat
      StrCopy(hours,timestr,2)
      hr:=Val(hours)
      IF hr>=12 
        timestr[5]:="P"
      ELSE    
        timestr[5]:="A"
      ENDIF
      IF hr>12 THEN hr:=hr-12
      StringF(outTimeStr,'\r\z\d[2]\s[4]',hr,timestr+2)
    ELSE
      StringF(outTimeStr,'\s[5]',timestr)
    ENDIF
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC findPlyr()
  DEF x,ret = 0
  DEF done=FALSE
  DEF un[255]:STRING
  DEF tmp[255]:STRING
  
  x:=1
  StrCopy(un,userAlias)
  replaceStr(un,' ','_')
  stripMCI(un)
  UpperStr(un)
  WHILE readPlyr(x) AND (done=FALSE)
    StrCopy(tmp,plyr.name)
    stripMCI(tmp)
    UpperStr(tmp)
    IF StrCmp(tmp,un) 
      done:=TRUE
      ret:=x
    ENDIF
    x++
  ENDWHILE
ENDPROC ret

PROC readPlyr(i)
  DEF ret = FALSE
  DEF fh
  
  fh:=Open(userFile,MODE_OLDFILE)
  IF fh<>0
    Seek(fh,(i-1)*SIZEOF userRec,OFFSET_BEGINNING)
    IF Read(fh,plyr,SIZEOF userRec) = SIZEOF userRec THEN ret:=TRUE
    Close(fh)
  ENDIF
ENDPROC ret

PROC savePlyr(i)
  DEF fh
  IF FileLength(userFile)=-1
    i:=1
    plyr.recIdx:=1
  ENDIF

  fh:=Open(userFile,MODE_READWRITE)
  IF fh<>0
    Seek(fh,(i-1)*SIZEOF userRec,OFFSET_BEGINNING)
    Write(fh,plyr,SIZEOF userRec)
    Close(fh)
  ENDIF
ENDPROC

PROC newPlyr()
  DEF i=0
  DEF tempstr[255]:STRING
  WHILE readPlyr(i+1) DO i++
  
  END plyr
  plyr:=NEW plyr
  plyr.recIdx:=i+1
  plyr.permIdx:=userIndex
  AstrCopy(plyr.enterChatMe,'|07- |15You have entered chat',80)
  AstrCopy(plyr.enterChatRoom,'|07- |11%1 |03has arrived!',80)
  AstrCopy(plyr.leaveChatMe,'|07- |12You have left chat.',80)
  AstrCopy(plyr.leaveChatRoom,'|07- |12%1 |04has left chat.',80)
  AstrCopy(plyr.enterRoomMe,'|07- |11You are now in |02%3',80)
  AstrCopy(plyr.leaveRoomRoom,'|07- |02%1 |10has left the room.',80)
  AstrCopy(plyr.leaveRoomMe,'|07- |10You have left room |02%4',80)
  AstrCopy(plyr.enterRoomRoom,'|07- |11%1 |03has entered the room.',80)
  AstrCopy(plyr.defaultRoom,'lobby',80)
  AstrCopy(plyr.nameColor,'|11',16)
  AstrCopy(plyr.ltBracket,'|03<',16)
  AstrCopy(plyr.rtBracket,'|03>',16)
  plyr.useClock:=TRUE
  plyr.clockFormat:=FALSE
 
  StrCopy(tempstr,userAlias)
  replaceStr(tempstr,' ','_')
  stripMCI(tempstr)
  AstrCopy(plyr.name,tempstr,80)

  savePlyr(plyr.recIdx) 
ENDPROC

PROC stripAnsi(s: PTR TO CHAR, d: PTR TO CHAR, resetit, strip)
  DEF i,j,k,p,c
  IF resetit
    ansi.ansicode:=0
    RETURN
  ENDIF

  i:=StrLen(s)
  j:=0
  k:=0
  WHILE(j<i)
    c:=s[j]
    IF((c=13) AND (strip<>0))
      j++
      ansi.ansicode:=0
    ELSEIF((ansi.ansicode=0) AND (c<>""))
      d[k]:=c
      j++
      k++
    ELSE
      IF(ansi.ansicode)
        ansi.buf[ansi.ansicode]:=c
        IF((ansi.ansicode=1) AND (c<>"["))
          ansi.ansicode:=ansi.ansicode+1

          p:=0
          ansi.buf[ansi.ansicode]:=0
          WHILE(ansi.buf[p]<>0)
            d[k]:=ansi.buf[p]
            k++
            p++
          ENDWHILE
          ansi.ansicode:=0
        ELSE
          SELECT c
            CASE "m"
              ansi.ansicode:=0
            DEFAULT
              ansi.ansicode:=ansi.ansicode+1
              IF(((c>="A") AND (c<="Z")) OR ((c>="a") AND (c<="z")) OR (ansi.ansicode>30))
                p:=0
                ansi.buf[ansi.ansicode]:=0
                WHILE(ansi.buf[p]<>0)
                  d[k]:=ansi.buf[p]
                  k++
                  p++
                ENDWHILE
                ansi.ansicode:=0
              ENDIF
          ENDSELECT
        ENDIF
      ELSEIF(c="")
        ansi.buf[0]:=""
        ansi.ansicode:=1
      ENDIF
      j++
    ENDIF
  ENDWHILE
  d[k]:=0

  ->ensure estring length is updated
  SetStr(d,StrLen(d))
ENDPROC

PROC stripMCI(t:PTR TO CHAR)
  DEF s[255]:STRING
  DEF skip=0
  DEF i
  
  FOR i:=0 TO StrLen(t)-1
    IF skip=0
      IF t[i]<>"|"
        StrAdd(s,t+i,1)
      ELSE
        skip:=2
      ENDIF
    ELSE
      skip--
    ENDIF
  ENDFOR
  
  StrCopy(t,s)
ENDPROC

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
  WriteStr(diface,'[4;1H[0m`------------------------------------------------------------------------------''',0)
  updateFooter()
ENDPROC

PROC restoreCursor()
  DEF tempstr[255]:STRING
  StrCopy(tempstr,myNamePrompt)
  stripMCI(tempstr)

  StringF(tempstr,'[\d;\dH',ListLen(chatLines)+6,Min(79,cursorPos+1+StrLen(tempstr)))
  WriteStr(diface,tempstr,0)
ENDPROC

PROC updateHeartbeat(anim)
  DEF tempstr[255]:STRING
  IF anim
    StringF(tempstr,'[0m[\d;77H+',ListLen(chatLines)+5)
  ELSE
    StringF(tempstr,'[0m[\d;77H ',ListLen(chatLines)+5)
  ENDIF
  WriteStr(diface,tempstr,0)
ENDPROC

PROC updateHeader()
  DEF tempstr[255]:STRING
  StringF(tempstr,'[2;1H[0m| R[36moom  [33m>[0m>> [K[67C|[68D#\s',myRoom)
  WriteStr(diface,tempstr,0)
  StringF(tempstr,'[3;1H[0m| T[36mopic [33m>[0m>> [K[59C/? H[36me[36mlp [0m|[68D\s',myTopic)
  WriteStr(diface,tempstr,0)
  
ENDPROC

PROC updateFooter()
  DEF tempstr[255]:STRING
  updateMaxBuffersize()
  StringF(tempstr,'[\d;1H[0m--[Latency-\r\z\d[3]ms]-[Chatters-\r\z\d[2]]---------------------[Buffer-\r\z\d[3]/\r\z\d[3]]-[[36mM[34mR[36mC[0m]-[ ]--',ListLen(chatLines)+5,latencyVal,currCount,StrLen(inputStr),iMaxBuffer)
  WriteStr(diface,tempstr,0)
ENDPROC


PROC addToBufferHistory(b:PTR TO CHAR)
  DEF i

  FOR i:=(ListLen(bufferHist)-1) TO 1 STEP -1
    StrCopy(bufferHist[i],bufferHist[i-1])
  ENDFOR
  StrCopy(bufferHist[0],b)
  bufferItem:=-1
ENDPROC

PROC displayCurrentInput()
  DEF tempstr[255]:STRING
  DEF tempInput[80]:STRING
  DEF xpos,ypos,plen
  
  StrCopy(tempstr,myNamePrompt)
  stripMCI(tempstr)
  plen:=StrLen(tempstr)
  
  IF cursorPos>(78-plen)
  	StrCopy(tempInput,inputStr+cursorPos-(78-plen),78-plen)
    xpos:=79
  ELSE
    StrCopy(tempInput,inputStr,78-plen)
    xpos:=cursorPos
  ENDIF
  ypos:=ListLen(chatLines)+6
  StringF(tempstr,'[\d;1H[K[0m\s|\r\z\d[2]\s[\d;\dH',ypos,myNamePrompt,inputColour,tempInput,ListLen(chatLines)+6,Min(79,cursorPos+1+plen))
  pipeToAnsi(tempstr)
  WriteStr(diface,tempstr,0)
ENDPROC

PROC showChat()
  DEF i
  DEF tempstr[255]:STRING
  
  FOR i:=0 TO ListLen(chatLines)-1
    StringF(tempstr,'[\d;1H[0m[K\s',i+5,chatLines[i])
    WriteStr(diface,tempstr,0)
  ENDFOR
 
  displayCurrentInput()
ENDPROC

PROC add2Chat(s:PTR TO CHAR)
  DEF timeStr[10]:STRING
  DEF tempstr[255]:STRING
  DEF tempstr2[255]:STRING
  DEF tempCharStr[1]:STRING
  DEF lastColourCode[3]:STRING
  DEF hl[20]:STRING
  DEF i,c,p,spaceI

  StrCopy(hl,'|16|00.|16|07')
  
  StrCopy(tempstr,s)
  StrCopy(tempstr2,userTag)
  UpperStr(tempstr)
  p:=InStr(tempstr,' ') ->skip upto the first space so we don't highlight our own nick at the start of the message
  IF p=-1 THEN p:=0

  UpperStr(tempstr2)
  IF InStr(tempstr+p,tempstr2)>=0
    StrCopy(hl,'|16|10»|16|07')
  ENDIF

  IF plyr.useClock
    getTime(timeStr)
  ENDIF
  StringF(tempstr,'\s\s',timeStr,hl)
  FOR i:=0 TO StrLen(timeStr)-1 DO timeStr[i]:=" "
  i:=0
  c:=0
  
  StrCopy(tempCharStr,'#')
  StrCopy(lastColourCode,'')
  spaceI:=-1
  WHILE i<StrLen(s)
    IF s[i]<>"|"
      IF s[i]=" "
        spaceI:=i
      ENDIF
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
    IF c=(79-StrLen(timeStr))
      IF (spaceI<>-1)
        SetStr(tempstr,StrLen(tempstr)-(i-spaceI))
        i:=spaceI+1
      ENDIF
      addChatLine(tempstr)
      StringF(tempstr,'\s\s\s',timeStr,hl,lastColourCode)
      c:=0
      spaceI:=-1
    ENDIF
  ENDWHILE
  IF c>0 THEN addChatLine(tempstr)
ENDPROC

PROC updateStrings(s:PTR TO CHAR,m:PTR TO CHAR, u:PTR TO CHAR, nr:PTR TO CHAR, or:PTR TO CHAR)
  DEF tempstr[255]:STRING
  replaceStr(s,'%1',m)
  replaceStr(s,'%2',u)
  StringF(tempstr,'#\s',nr)
  replaceStr(s,'%3',tempstr)
  StringF(tempstr,'#\s',or)
  replaceStr(s,'%4',tempstr)
ENDPROC

PROC pipeToAnsi(s:PTR TO CHAR)
  DEF clsStr[2]:STRING
  replaceStr(s,'|00','[30m')
  replaceStr(s,'|01','[34m')
  replaceStr(s,'|02','[32m')
  replaceStr(s,'|03','[36m')
  replaceStr(s,'|04','[31m')
  replaceStr(s,'|05','[35m')

  replaceStr(s,'|06','[33m')
  replaceStr(s,'|07','[0m')
  replaceStr(s,'|08','[0m')
  
  replaceStr(s,'|09','[34m')
  replaceStr(s,'|10','[32m')
  replaceStr(s,'|11','[36m')
  replaceStr(s,'|12','[31m')
  replaceStr(s,'|13','[35m')
  replaceStr(s,'|14','[33m')
  replaceStr(s,'|15','[0m')

  replaceStr(s,'|16','[40m')
  replaceStr(s,'|17','[44m')
  replaceStr(s,'|18','[42m')
  replaceStr(s,'|19','[46m')
  replaceStr(s,'|20','[41m')
  replaceStr(s,'|21','[45m')
  replaceStr(s,'|22','[43m')

  replaceStr(s,'|23','[40m') 
  replaceStr(s,'|24','[40m')
  
  replaceStr(s,'|25','[45m')
  replaceStr(s,'|26','[42m')
  replaceStr(s,'|27','[46m')
  replaceStr(s,'|28','[41m')
  replaceStr(s,'|29','[45m')
  replaceStr(s,'|30','[43m')
  replaceStr(s,'|31','[47m')
  
  StringF(clsStr,'\c',12)
  replaceStr(s,'|CL',clsStr)
ENDPROC

PROC addChatLine(s:PTR TO CHAR)  
  DEF i,fh
  DEF tempstr[255]:STRING
  StrCopy(tempstr,s)

  pipeToAnsi(tempstr)

  FOR i:=1 TO ListLen(chatLines)-1
    StrCopy(chatLines[i-1],chatLines[i])
  ENDFOR
  StrCopy(chatLines[ListLen(chatLines)-1],tempstr)
  
  fh:=Open(chatLog,MODE_READWRITE)
  IF fh<>0
    StrAdd(tempstr,'\n')
    Seek(fh,0,OFFSET_END)
    Write(fh,tempstr,StrLen(tempstr))
    Close(fh)
  ENDIF
  
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
  
  StringF(tempstr,'* |10Welcome to \s',mrcVersion)
  add2Chat(tempstr)
  add2Chat('* |11ESC|10 to clear input buffer, |15UP|10/|15DN|10 arrows for buffer history')
  add2Chat('* |10and to change your chat text color and |11TAB|10 for nick completion')
  add2Chat('* |10The bottom-right heartbeat indicates your status with BBS and server')

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
        StrCopy(tempstr,plyr.leaveRoomMe)
        updateStrings(tempstr,plyr.name,'',newRoom,oldRoom)
        sendToMe(tempstr)
        StrCopy(tempstr,plyr.leaveRoomRoom)
        updateStrings(tempstr,plyr.name,'',newRoom,oldRoom)
        sendToRoomNotMe(tempstr)
        StrCopy(myRoom,newRoom)
        StrCopy(tempstr,plyr.enterRoomMe)
        updateStrings(tempstr,plyr.name,'',newRoom,oldRoom)
        sendToMe(tempstr)
        StrCopy(tempstr,plyr.enterRoomRoom)
        updateStrings(tempstr,plyr.name,'',newRoom,oldRoom)
        sendToRoomNotMe(tempstr)
      ENDIF
      StrCopy(myRoom,newRoom)
      ->SetPromptInfo(4,'#'+S)
      updateHeader()
      sendToServer('USERLIST')
    ENDIF
  ENDIF
ENDPROC



PROC enterChat()
  DEF tempstr[255]:STRING
  showTitle()
  showWelcome()

  StrCopy(tempstr,plyr.enterChatMe)
  updateStrings(tempstr,plyr.name,'',myRoom,myRoom)
  add2Chat(tempstr)
  StrCopy(tempstr,plyr.enterChatRoom)
  updateStrings(tempstr,plyr.name,'',myRoom,myRoom)
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

PROC findSplitBufferPos(buffer,sep,num)
  DEF count=0
  DEF s=-1
  DEF res=0
  
  WHILE((s:=InStr(buffer,sep,s+1))<>-1) AND (count<num)
    count++
    res:=s
  ENDWHILE
  
ENDPROC res

PROC splitBuffer(buffer,sep)
  DEF count=0
  DEF olds,s=-1,l
  DEF tdat: PTR TO LONG
  
  l:=StrLen(buffer)
  IF l>0
    count:=1
    WHILE(s:=InStr(buffer,sep,s+1))<>-1
      IF (s+1)<>l THEN count++
    ENDWHILE
  ENDIF

  tdat:=List(count)
  
  s:=-1
  olds:=s
  WHILE(s:=InStr(buffer,sep,s+1))<>-1
    listAddNewString(tdat,buffer+olds+1,s-olds-1)
    olds:=s
  ENDWHILE
  IF (olds+1)<>l THEN listAddNewString(tdat,buffer+olds+1)
ENDPROC tdat

PROC releaseStringList(list:PTR TO LONG)
  DEF i
  FOR i:=0 TO ListLen(list)-1
    DisposeLink(list[i])
  ENDFOR
  DisposeLink(list)
ENDPROC

PROC stats(s:PTR TO CHAR)
  DEF tempstr[255]:STRING
  DEF wordList:PTR TO LONG
  
  StrCopy(tempstr,s)
  wordList:=splitBuffer(tempstr,' ')
  StringF(mrcStats,':: Server Stats >> BBSes:\s Rooms:\s Users:\s',wordList[0],wordList[1],wordList[2])
  releaseStringList(wordList)
  loadBanners()
ENDPROC

PROC latency(s:PTR TO CHAR)
  latencyVal:=Val(s)
  IF latencyVal>999 THEN latencyVal:=999
ENDPROC

PROC message(s:PTR TO CHAR)
  add2Chat(s)
  showChat()
ENDPROC


PROC roomTopic(room:PTR TO CHAR,topic:PTR TO CHAR)
  IF StrCmp(room,myRoom)
    StrCopy(myTopic,topic)
    updateHeader()
  ENDIF
ENDPROC

PROC userList(s:PTR TO CHAR)
  DEF i
  currCount:=0
  IF (s>StrMax(roomUsers))
    DisposeLink(roomUsers)
    roomUsers:=String(StrLen(s)+200)
  ENDIF
  StrCopy(roomUsers,s)

  IF StrLen(s)>0 THEN currCount:=1
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
  HotKey(diface,'')
  showTitle()
  showChat()
ENDPROC

PROC showChanges()
  -> Changes info text [sf]
  add2Chat('* |15List of changes from MRC v1.1')
  add2Chat('* |10Completely redesigned Input routine [sf]')
  add2Chat('* |10Ability to receive chat while typing (non-blocking) [sf]')
  add2Chat('* |10Built-in input buffer history [sf]')
  add2Chat('* |10Chat text color changing using PgUp and PgDn [sf]')
  add2Chat('* |10Visual indicator when your nick is mentioned [sf]')
  add2Chat('* |10Input buffer with color coded characters counter [sf]')
  add2Chat('* |10Server latency and synchronization heartbeat indicator [sf]')
  add2Chat('* |10Enlarged view port, more lines are available for the chat [sf]')
  add2Chat('* |10Customizable information scroller [sf]')
  add2Chat('* |10Improvement of performance and responsiveness of the interface [sf]')
  add2Chat('* |10Brand new backend for improved speed and scalability [sf]')
  add2Chat('* |10Nick auto-completion using TAB [sf]')
  add2Chat('* |10Reply to last private message using /r [sf]')
  showChat()
ENDPROC

PROC doBroadcast(s:PTR TO CHAR)
  DEF tempStr[255]:STRING
  StringF(tempStr,'|15* |08(|15\s|08/|14Broadcast|08) |07\s',plyr.name,s)
  sendToAll(tempStr)
ENDPROC

PROC leaveChat()
  DEF tempStr[255]:STRING

  StrCopy(tempStr,plyr.leaveChatMe)
  updateStrings(tempStr,plyr.name,'',myRoom,myRoom)
  add2Chat(tempStr)

  StrCopy(tempStr,plyr.leaveChatRoom)
  updateStrings(tempStr,plyr.name,'',myRoom,myRoom)
  sendToAllNotMe(tempStr)
  showChat()
  Delay(25)
  sendToServer('LOGOFF')
  showChat()
ENDPROC

PROC doMeAction(s:PTR TO CHAR)
  DEF tempStr[255]:STRING
  StringF(tempStr,'|15* |13\s \s',plyr.name,s)
  sendToRoom(tempStr)
ENDPROC

PROC doSetHelp()
  DEF b=FALSE

  b:=plyr.useClock
  plyr.useClock:=FALSE
  add2Chat('|15/SET |08<|03tag|08> <|03text|08>')
  add2Chat('|11Use |15SET |11to set various fields to your account')
  add2Chat('|15HELP            |03This helps message')
  add2Chat('|15LIST            |03List all fields and tabs')
  add2Chat('|15ENTERCHATME     |03Displayed to |11me |03when I enter chat.')
  add2Chat('|15ENTERCHATROOM   |03Displayed to |11room |03when I enter chat.')
  add2Chat('|15ENTERROOMME     |03Displayed to |11me |03when I enter room.' )
  add2Chat('|15ENTERROOMROOM   |03Displayed to |11room |03when I enter room.' )
  add2Chat('|15LEAVECHATME     |03Displayed to |11me |03when I leave chat.' )
  add2Chat('|15LEAVECHATROOM   |03Displayed to |11room |03when I leave chat.' )
  add2Chat('|15LEAVEROOMME     |03Displayed to |11me |03when I leave room.')
  add2Chat('|15LEAVEROOMROOM   |03Displayed to |11room |03when I leave room.')
  add2Chat('|15DEFAULTROOM     |03Join this room when you join chat.')
  add2Chat('|15NICKCOLOR       |03Change my nickname color |11(MCI Pipe codes).' )
  add2Chat('|15LTBRACKET       |03Change my left bracket / color |11(MCI Pipe codes).' )
  add2Chat('|15RTBRACKET       |03Change my right bracket / color |11(MCI Pipe codes).' )
  add2Chat('|15USECLOCK        |03(|15Y|03/|15N|03) Use timestamp in chat')
  add2Chat('|15CLOCKFORMAT     |1112 |03or |1124 |03hour clock format')
  showChat()
  plyr.useClock:=b
ENDPROC

PROC doSetList()
  DEF s[10]:STRING
  DEF r[20]:STRING
  DEF temp[255]:STRING
  DEF b=FALSE

  IF plyr.useClock THEN StrCopy(s,'True') ELSE StrCopy(s,'False')

  IF plyr.clockFormat=FALSE THEN StrCopy(r,'24Hour (HH:MM)') ELSE StrCopy(r,'12Hour (HH:MMa or HHMMp)')

  b:=plyr.useClock
  plyr.useClock:=FALSE
  add2Chat('|11List of current |15/SET |11values from your account')
  StringF(temp,'|15ENTERCHATME   |08:|07 \s',plyr.enterChatMe)
  add2Chat(temp)
  StringF(temp,'|15ENTERCHATROOM |08:|07 \s',plyr.enterChatRoom)
  add2Chat(temp)
  StringF(temp,'|15ENTERROOMME   |08:|07 \s',plyr.enterRoomMe)
  add2Chat(temp)
  StringF(temp,'|15ENTERROOMROOM |08:|07 \s',plyr.enterRoomRoom)
  add2Chat(temp)
  StringF(temp,'|15LEAVECHATME   |08:|07 \s',plyr.leaveChatMe)
  add2Chat(temp)
  StringF(temp,'|15LEAVECHATROOM |08:|07 \s',plyr.leaveChatRoom)
  add2Chat(temp)
  StringF(temp,'|15LEAVEROOMME   |08:|07 \s',plyr.leaveRoomMe)
  add2Chat(temp)
  StringF(temp,'|15LEAVEROOMROOM |08:|07 \s',plyr.leaveRoomRoom)
  add2Chat(temp)
  StringF(temp,'|15DEFAULTROOM   |08:|07 \s',plyr.defaultRoom)
  add2Chat(temp)
  StringF(temp,'|15NICKCOLOR     |08:|07 \s\s',plyr.nameColor,plyr.name)
  add2Chat(temp)
  StringF(temp,'|15LTBRACKET     |08:|07 \s',plyr.ltBracket)
  add2Chat(temp)
  StringF(temp,'|15RTBRACKET     |08:|07 \s',plyr.rtBracket)
  add2Chat(temp)
  StringF(temp,'|15USECLOCK      |08:|07 \s',s)
  add2Chat(temp)
  StringF(temp,'|15CLOCKFORMAT   |08:|07 \s',r)
  add2Chat(temp)
  showChat()
  plyr.useClock:=b
ENDPROC

PROC changeClock(t,l:PTR TO CHAR)
  DEF s[255]:STRING
  StrCopy(s,TrimStr(l))
  UpperStr(s)

  SELECT t
    CASE 1
      IF (InStr(s,'YE') >= 0) OR (InStr(s,'TR') >= 0)
        plyr.useClock:=TRUE
        add2Chat('|11USECLOCK      |08: |15True')
      ELSEIF (InStr(s,'NO') >= 0) OR (InStr(s,'FA') >= 0)
        plyr.useClock:=FALSE
        add2Chat('|11USECLOCK      |08: |15False')
      ELSE
        add2Chat('|11Usage: |15/SET USECLOCK YES||TRUE|08 or |15/SET USECLOCK NO||FALSE')
      ENDIF
      showChat()
    CASE 2
    IF StrCmp('12',s)
      plyr.clockFormat:=TRUE
      add2Chat('|07CLOCKFORMAT   |08: |0712 hour')
    ELSE
      IF StrCmp('24',s)
          plyr.clockFormat:=FALSE
          add2Chat('|07CLOCKFORMAT   |08: |0724 hour')
        ELSE
          add2Chat('|11Usage: |08"|03/SET CLOCKFORMAT 12|08" or "|03/SET CLOCKFORMAT 24|08"')
        ENDIF
    ENDIF
    showChat()
  ENDSELECT
  savePlyr(plyr.recIdx)
ENDPROC

PROC doDebugAction()
  DEF i
  FOR i:=0 TO ListLen(bannerList)-1
    add2Chat(bannerList[i])
  ENDFOR
  showChat()
ENDPROC

PROC mainScrollBack(lines:PTR TO LONG)
  DEF p,p2,key,i,max
  
  max:=ListLen(lines)-(numLines-3)
  p:=max
  REPEAT
    p2:=p
    FOR i:=0 TO numLines-5
      IF p2<0 
        WriteStr(diface,'[K',LF)
      ELSE
        WriteStr(diface,'[0m',0)
        WriteStr(diface,lines[p2],0)
        WriteStr(diface,'[K',LF)
      ENDIF
      p2++
    ENDFOR
    key:=HotKey(diface,'')
    IF (key=18) THEN p:=p-(numLines-5) ->CTRL R
    IF (key=3) THEN p:=p+(numLines-5) ->CTRL C
    IF (key=UPARROW) THEN p:=p-1
    IF (key=DOWNARROW) THEN p:=p+1
    IF p<0 THEN p:=0
    IF p>max THEN p:=max
    WriteStr(diface,'[2;1H',0)
  UNTIL (key=27) OR (key="Q") OR ((key AND $FF)>250)
ENDPROC

PROC doScrollAction()
  DEF tempstr[255]:STRING
  DEF l,m:PTR TO CHAR,fh,loaded,nomem,i,c
  
  DEF lines:PTR TO LONG
  StringF(tempstr,'\c[0m------------------------------- [32mScrollback Buffer[0m ------------------------------',12)
  WriteStr(diface,tempstr,LF)
  StringF(tempstr,'[\d;1H--------------------------------------------------------------------------------',numLines-2)
  WriteStr(diface,tempstr,LF)
  WriteStr(diface,'   Move ([32mUp[0m/[32mDown[0m)     Page Up ([32mCtrl-R[0m)     Page Down ([32mCtrl-C[0m)     [32mESC [0mto QUIT[0m[2;1H',0)
  l:=FileLength(chatLog)
  IF l=0
    WriteStr(diface,'No chatlog available.',LF)
    WriteStr(diface,'Press any key to return to chat.',LF)
    HotKey(diface,'')
  ELSE
    nomem:=FALSE
    m:=New(l)
    IF m<>NIL
      loaded:=FALSE
      fh:=Open(chatLog,MODE_OLDFILE)
      IF fh<>NIL
        IF Read(fh,m,l)=l THEN loaded:=TRUE
        Close(fh)
      ENDIF
      
      IF loaded
        c:=1
        FOR i:=0 TO l-1 DO IF m[i]="\n" THEN c++
        lines:=List(c)
        IF lines=NIL
          nomem:=TRUE
        ELSE
          listAddItem(lines,m)
          
          FOR i:=0 TO l-1
            IF m[i]="\n"
              m[i]:=0
              IF i<l-1 THEN listAddItem(lines,m+i+1)
            ENDIF
          ENDFOR
          mainScrollBack(lines)
        ENDIF
      ELSE
        WriteStr(diface,'Unable to load chatlog.',LF)
        WriteStr(diface,'Press any key to return to chat.',LF)
        Dispose(m)
        HotKey(diface,'')
      ENDIF
    ELSE
      nomem:=TRUE
    ENDIF
    IF nomem
      WriteStr(diface,'Not enough memory to load chatlog.',LF)
      WriteStr(diface,'Press any key to return to chat.',LF)
      HotKey(diface,'')
    ENDIF
  ENDIF
  showTitle()
  showChat()
ENDPROC

PROC doSetAction(s:PTR TO CHAR)
  DEF tag[255]:STRING
  DEF tempstr[255]:STRING
  DEF p=0
  DEF wordList:PTR TO LONG

  StrCopy(tempstr,s)
  wordList:=splitBuffer(tempstr,' ')
  IF ListLen(wordList)>0 THEN StrCopy(tag,wordList[0])
  p:=StrLen(tag)+1
  s:=TrimStr(s+p)
  releaseStringList(wordList)

  UpperStr(tag)
  
  IF StrCmp(tag,'HELP')
    doSetHelp()
  ELSEIF StrCmp(tag,'LIST')
    doSetList()
  ELSEIF StrCmp(tag,'ENTERCHATME')
    AstrCopy(plyr.enterChatMe,s,80)
  ELSEIF StrCmp(tag,'ENTERCHATROOM')
    AstrCopy(plyr.enterChatRoom,s,80)
  ELSEIF StrCmp(tag,'ENTERROOMME')
    AstrCopy(plyr.enterRoomMe,s,80)
  ELSEIF StrCmp(tag,'ENTERROOMROOM')
    AstrCopy(plyr.enterRoomRoom,s,80)
  ELSEIF StrCmp(tag,'LEAVECHATME')
    AstrCopy(plyr.leaveChatMe,s,80)
  ELSEIF StrCmp(tag,'LEAVECHATROOM')
    AstrCopy(plyr.leaveChatRoom,s,80)
  ELSEIF StrCmp(tag,'LEAVEROOMME')
    AstrCopy(plyr.leaveRoomMe,s,80)
  ELSEIF StrCmp(tag,'LEAVEROOMROOM')
    AstrCopy(plyr.leaveRoomRoom,s,80)
  ELSEIF StrCmp(tag,'DEFAULTROOM')
    AstrCopy(plyr.defaultRoom,s,80)
  ELSEIF StrCmp(tag,'NICKCOLOR')
    changeNick("C",s)
  ELSEIF StrCmp(tag,'LTBRACKET')
    changeNick("L",s)
  ELSEIF StrCmp(tag,'RTBRACKET')
    changeNick("R",s)
  ELSEIF StrCmp(tag,'USECLOCK')
    changeClock(1,s)
  ELSEIF StrCmp(tag,'CLOCKFORMAT')
    changeClock(2,s)
  ELSEIF StrCmp(tag,'')
    doSetHelp()
  ENDIF
  savePlyr(plyr.recIdx)

ENDPROC

PROC doPrivateMessage(s:PTR TO CHAR)
  DEF toName[255]:STRING
  DEF tempStr[255]:STRING
  DEF p
  
  s:=TrimStr(s)
  p:=InStr(s,' ')
  StrCopy(toName,s,p)

  StringF(tempStr,'|15* |08(|15\s|08/|14PrivMsg|08) |07\s',plyr.name,TrimStr(s+p))
  sendToUser(toName,tempStr)
  StringF(tempStr,'|15* |08(|14PrivMsg|08->|15\s|08) |07',toName,TrimStr(s+p))
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
  DEF users2
  IF StrCmp(userName,'SERVER') OR StrCmp(userName,'CLIENT') THEN RETURN
  StringF(tempStr,',\s,',userName)
  users2:=String(StrLen(roomUsers)+2)
  StringF(users2,',\s,',roomUsers)
  IF InStr(users2,tempStr)=-1
    IF (StrLen(roomUsers)+StrLen(userName)+1)>=StrMax(roomUsers)
      newUsers:=String(StrLen(roomUsers)+StrLen(userName)+200)
      StringF(newUsers,'\s,\s',roomUsers,userName)
      DisposeLink(roomUsers)
      roomUsers:=newUsers
    ELSE
      StrAdd(roomUsers,',')
      StrAdd(roomUsers,userName)
    ENDIF
    updateFooter()
  ENDIF
  DisposeLink(users2)
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
      ELSEIF StrCmp(tempstr,'/DLCHATLOG',10)
        dlChatLog()
      ELSEIF StrCmp(tempstr,'/B ',3)
        doBroadcast(s+3)
      ELSEIF StrCmp(tempstr,'/Q') OR StrCmp(tempstr,'/QUIT')
        leaveChat()
        exitChat:=TRUE
      ELSEIF StrCmp(tempstr,'/JOIN ',6)
        joinRoom(s+6,TRUE)
      ELSEIF StrCmp(tempstr,'/ME ',4)
        doMeAction(s+4)
      ELSEIF StrCmp(tempstr,'/SET ',5)
        doSetAction(s+5)
      ELSEIF StrCmp(tempstr,'/DEBUG',6)
        doDebugAction()
      ELSEIF StrCmp(tempstr,'/SCROLL',7)
        doScrollAction()
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
      
/*        '/SCROLL'    : DoScrollBack
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
  DEF ok2Send=TRUE
  
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
        ok2Send:=FALSE
        addBanner(params[1])
      ELSEIF StrCmp(params[0],'ROOMTOPIC')
        ok2Send:=FALSE
        roomTopic(params[1],params[2])
      ELSEIF StrCmp(params[0],'USERLIST')
        ok2Send:=FALSE
        userList(params[1])
      ELSEIF StrCmp(params[0],'LATENCY')
        ok2Send:=FALSE
        latency(params[1])
      ELSEIF StrCmp(params[0],'STATS')
        ok2Send:=FALSE
        stats(params[1])
      ELSEIF StrCmp(params[0],'HELLO')
        ok2Send:=FALSE
        sendToServer('IAMHERE')
      ENDIF
      releaseStringList(params)
    ELSEIF StrCmp(touser,'SERVER')
      IF StrCmp(msg,'LOGOFF')
        logoff(fromuser)
        ok2Send:=FALSE
      ENDIF
    ENDIF
    
    IF (StrLen(toroom)<>0) AND (strCmpi(toroom,myRoom)=FALSE) THEN ok2Send:=FALSE
       
    IF StrLen(touser)>0
      IF (StrCmp(touser,'NOTME')=FALSE) AND (strCmpi(touser,userTag)=FALSE) THEN ok2Send:=FALSE
    ENDIF

    IF strCmpi(fromuser,userTag) AND strCmpi(touser,'NOTME') THEN ok2Send:=FALSE

    IF (StrCmp(fromuser,'SERVER')=FALSE) AND (StrCmp(fromuser,'CLIENT')=FALSE)
      IF strCmpi(touser,userTag) THEN StrCopy(lastPrivMsg,fromuser)
    ENDIF

    IF ok2Send 
      message(msg)
      checkUserList(fromuser)
    ENDIF
  ENDIF
  releaseStringList(packet)

ENDPROC

PROC changeNick(lrnc,n:PTR TO CHAR)
  DEF tmp[255]:STRING
  
  SELECT lrnc
    CASE "N"
      StrCopy(tmp,n)
      stripMCI(tmp)
      AstrCopy(plyr.name,tmp,80)

    -> Limit left bracket to 1 visible character [sf]
    CASE "L"
      StrCopy(tmp,n)
      stripMCI(tmp)
      IF StrLen(tmp)>1
        showError('Left bracket max length is 1 char')
      ELSE
        AstrCopy(plyr.ltBracket,n)
      ENDIF

    -> Limit right bracket to 8 visible character [sf]
    -> Record length stays at 16 for compatibility
    CASE "R"
      StrCopy(tmp,n)
      stripMCI(tmp)
      IF (StrLen(tmp)>8) OR (StrLen(n)>16)
        showError('Right brackets max length is 8 chars (16 including Pipe codes)')
      ELSE
        AstrCopy(plyr.rtBracket,n)
      ENDIF
    -> Make sure Nick color is a color PIPE code [sf]
    CASE "C"
      StrCopy(tmp,n)
      stripMCI(tmp)
      IF (StrLen(tmp)>0) OR (StrLen(n)<>3)
        showError('Only color pipe codes allowed for nick color')
      ELSE
        AstrCopy(plyr.nameColor,n)
      ENDIF
  ENDSELECT

  savePlyr(plyr.recIdx)
  StrCopy(tmp,plyr.name)
  stripMCI(tmp)
  StringF(myNamePrompt,'\s\s\s\s|16|07 ',plyr.ltBracket,plyr.nameColor,tmp,plyr.rtBracket)
ENDPROC

PROC addBanner(b:PTR TO CHAR)
  DEF exist=FALSE
  DEF i,n
  
  n:=ListLen(bannerList)
  
  FOR i:=0 TO n-1
    IF StrCmp(bannerList[i],b) THEN exist:=TRUE
  ENDFOR
  
  IF exist=FALSE
    FOR i:=0 TO n-1
      IF StrLen(bannerList[i])=0 
        StrCopy(bannerList[i],b)
        RETURN
      ENDIF
    ENDFOR
  ENDIF
ENDPROC

PROC loadBanners()
  StringF(bannerList[0],'\s\s',mrcVersion,mrcStats)
  StrCopy(bannerList[1],'Find more about the connected BBSes using the /INFO command')
  StrCopy(bannerList[2],'Give a try to the new nick auto-completion feature using the TAB key')
  StrCopy(bannerList[3],'Reply to your last received private message using the /R shortcut')
ENDPROC

-> Select next banner from the defined list [sf]
PROC nextBanner()
  REPEAT
    banIdx++
    IF banIdx>=ListLen(bannerList) THEN banIdx:=0
  UNTIL StrLen(bannerList[banIdx])>0
  scrollWait:=0
  bannerOff:=0
ENDPROC

PROC scrollBanner()
  DEF bs[255]:STRING
  DEF ban[80]:STRING

  StringF(bs,'                                    \s',bannerList[banIdx])
  stripMCI(bs)
  
  ->StringF(ban,'[2;43H[0m\s[1][36m\l\s[34][0m\s[1]',bs+bannerOff,bs+bannerOff+1,bs+bannerOff+35)
  StringF(ban,'[2;43H[36m\l\s[36]',bs+bannerOff)
  WriteStr(diface,ban,0)
  
  IF scrollWait<scrollDly
    scrollWait++
  ELSE    
    bannerOff++
  ENDIF
  
  IF bannerOff=StrLen(bs)
    nextBanner()
  ENDIF

ENDPROC

PROC init()
  DEF y
  DEF tempstr[255]:STRING
  
   IF strCmpi(userTag,'SERVER') OR strCmpi(userTag,'CLIENT') OR strCmpi(userTag,'NOTME')
    StrCopy(tempstr,'|16|12|CL|CRUnfortunately, your User Alias is a reserved word and therefore cannot be used.')
    pipeToAnsi(tempstr)
    WriteStr(diface,tempstr,LF)
    StrCopy(tempstr,'|12Please ask your SysOp to change your User Alias to use MRC.')
    pipeToAnsi(tempstr)
    WriteStr(diface,tempstr,LF)
    Raise(ERR_EXCEPT)
  ENDIF

  roomUsers:=String(1000)
  
  y:=findPlyr()
  IF y = 0 THEN newPlyr() ELSE readPlyr(y)
  
  changeNick("N",userTag)
  
ENDPROC

PROC getPrevBufferItem()
  DEF count=0,found=FALSE
  WHILE (found=FALSE) AND (count<ListLen(bufferHist))
    bufferItem++
    IF bufferItem=ListLen(bufferHist) THEN bufferItem:=0
    count++
    IF StrLen(bufferHist[bufferItem])>0 THEN found:=TRUE
  ENDWHILE
  IF found
    StrCopy(inputStr,bufferHist[bufferItem])
    cursorPos:=StrLen(inputStr)
    charsEntered:=FALSE
  ENDIF
ENDPROC

PROC getNextBufferItem()
  DEF count=0,found=FALSE
  WHILE (found=FALSE) AND (count<ListLen(bufferHist))
    bufferItem--
    IF bufferItem<0 THEN bufferItem:=ListLen(bufferHist)-1
    count++
    IF StrLen(bufferHist[bufferItem])>0 THEN found:=TRUE
  ENDWHILE
  IF found
    StrCopy(inputStr,bufferHist[bufferItem])
    cursorPos:=StrLen(inputStr)
    charsEntered:=FALSE
  ENDIF
ENDPROC

PROC dlChatLog()
  DEF tempChat[255]:STRING
  DEF ds[40]:STRING
  DEF st[255]:STRING
  DEF tempstr[255]:STRING
  DEF tempstr2[255]:STRING
  DEF fh,fh2
  DEF key

  getDateTime(ds)
  replaceStr(ds,'-','')
  replaceStr(ds,':','')
  replaceStr(ds,' ','_')
  StrCopy(st,siteTag)
  replaceStr(st,' ','_')
  StringF(tempChat,'PROGDIR:mrc_chat_\d_\s_\s.log',node,st,ds)
  StringF(tempstr,'\c[0;36m Strip colour codes? ',12)
  WriteStr(diface,tempstr,0)

  REPEAT
    key:=HotKey(diface,'')
  UNTIL (key=-1) OR (key="y") OR (key="Y") OR (key="N") OR (key="n")

  IF key<>-1
    
    IF (key="Y") OR (key="y")
      fh:=Open(chatLog,MODE_OLDFILE)
      fh2:=Open(tempChat,MODE_NEWFILE)
      IF (fh<>0) AND (fh2<>0)
        WHILE(ReadStr(fh,tempstr)<>-1) OR (StrLen(tempstr)>0)
          stripAnsi(tempstr,tempstr2,0,0)
          Fputs(fh2,tempstr2)
        ENDWHILE
      ENDIF
      IF fh<>0 THEN Close(fh)
      IF fh2<>0 THEN Close(fh2)
      
    ELSE
      StringF(tempstr,'COPY \s \s',chatLog,tempChat)
      Execute(tempstr,0,0)
    ENDIF

    IF FileLength(tempChat)>=0
      ->download file tempchat
      SendStrCmd(ZMODEMSEND,0,tempChat)
    ENDIF
  ENDIF

  DeleteFile(tempChat)
  showTitle()
  showChat() 
ENDPROC

PROC main() HANDLE
  DEF readBuffer=0
  DEF i,b,e,res,m
  DEF sa=0:PTR TO sockaddr_in
  DEF tempstr[255]:STRING
  DEF tempstr2[255]:STRING

  DEF addr: PTR TO LONG
  DEF hostEnt: PTR TO hostent
  DEF sep[2]:STRING
  DEF tdat:PTR TO LONG
  DEF data
  DEF anim=0

  DEF wc,lw[255]:STRING,wl
  DEF wordList:PTR TO LONG
  DEF tail[10]:STRING
  DEF pf[255]:STRING
  DEF uMatch=FALSE
  DEF sLoop=0
  DEF uHandle[255]:STRING
  DEF curoff=FALSE

  ansi.ansicode:=0

  StrCopy(mrcVersion,'Multi Relay Chat door v1.2.9a [sf]')
  
  StrCopy(mrcStats,'')
  
  StrCopy(userFile,'PROGDIR:mrcusers.dat')

	socketbase:=OpenLibrary('bsdsocket.library',2)
  IF socketbase=NIL
    WriteStr(diface,'Unable to open bsdsocket.library',LF)
    RETURN
  ENDIF

  node:=Val(arg)
  IF aedoorbase:=OpenLibrary('AEDoor.library',1)
    diface:=CreateComm(arg[])     /* Establish Link   */
    IF diface<>0
      strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
    ENDIF
  ELSE
    Raise(ERR_EXCEPT)
  ENDIF
 
  StringF(chatLog,'PROGDIR:mrcchat\d.log',node)
  DeleteFile(chatLog)

  GetDT(diface,DT_NAME,0)        /* no string input here, so use 0 as last parameter */
  stripAnsi(strfield,userAlias,0,0)

  StrCopy(userTag,userAlias)
  replaceStr(userTag,'~','')
  replaceStr(userTag,' ','_')
  stripMCI(userTag)

  GetDT(diface,DT_SLOTNUMBER,0)        /* no string input here, so use 0 as last parameter */
  userIndex:=Val(strfield)

  GetDT(diface,DT_LINELENGTH,0)        /* no string input here, so use 0 as last parameter */
  numLines:=Val(strfield)

  GetDT(diface,JH_BBSNAME,0)        /* no string input here, so use 0 as last parameter */

  stripAnsi(strfield,siteTag,0,0)
  replaceStr(siteTag,'~','')
  replaceStr(siteTag,' ','_')
  stripMCI(siteTag)

  SendDataCmd(diface,501,0)

  plyr:=NEW plyr

  updateMaxBuffersize()

  chatLines:=List(numLines-5)
  FOR i:=0 TO ListMax(chatLines)-1
    listAddItem(chatLines,String(255))
  ENDFOR
  
  bufferHist:=List(10)
  FOR i:=0 TO ListMax(bufferHist)-1
    listAddItem(bufferHist,String(255))
  ENDFOR
  
  bannerList:=List(20)
  FOR i:=0 TO ListMax(bannerList)-1
    listAddItem(bannerList,String(255))
  ENDFOR
  loadBanners()
  nextBanner()
  
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
  
  init()
  

  enterChat()
  joinRoom(plyr.defaultRoom,FALSE)

  
  
  readBuffer:=New(8193)
  loop:=0

  SendDataCmd(diface,705,1)  
  REPEAT
    loop++

    Delay(1)
    IF Mod(loop,scrollSpeed)=0
      SendDataCmd(diface,705,0)   ->console cursor off
      curoff:=TRUE
      scrollBanner()
    ENDIF

    IF Mod(loop,26)=0
      IF curoff=FALSE 
        SendDataCmd(diface,705,0) ->console cursor off
        curoff:=TRUE
      ENDIF
      
      anim:=Eor(anim,1)
      updateHeartbeat(anim)
    ENDIF

    IF curoff
      restoreCursor()
      SendDataCmd(diface,705,1) ->console cursor on
      curoff:=FALSE
    ENDIF
    
    IF Mod(loop,1999)=0
      sendToServer('USERLIST')
    ENDIF
    
    IF Mod(loop,997)=0
      sendToClient('LATENCY')
    ENDIF
    
    IF Mod(loop,11987)=0
      sendToServer('IAMHERE')
    ENDIF

    IF loop>47948
      sendToServer('BANNERS')
      loop:=1
    ENDIF

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
        releaseStringList(tdat)
      ENDIF
    ENDIF

    updateMaxBuffersize()
    
    m:=fetchKey()
    IF m>0
      -> Nick auto-completion [sf]
      IF m=9
        StrCopy(tempstr2,inputStr)
        wordList:=splitBuffer(tempstr2,' ')
        
        wc:=ListLen(wordList)       -> Count of words in buffer
        IF wc>0 THEN StrCopy(lw,wordList[wc-1]) ELSE StrCopy(lw,'') -> Last word in buffer
        wl:=StrLen(lw)  -> Length of the last word in buffer
        releaseStringList(wordList)

        -> Define display if at the beginning or mid-sentence
        IF wc < 2 THEN StrCopy(tail,': ') ELSE StrCopy(tail,' ')

        IF StrLen(lastUSearch)=0 THEN StrCopy(lastUSearch,lw)
        IF (wl > 0) AND (StrLen(roomUsers) > 0)
          IF wc>1
            StrCopy(pf,inputStr,findSplitBufferPos(inputStr,' ',wc-1)+1)
          ELSE
            StrCopy(pf,'')
          ENDIF
          uMatch:=FALSE
          sLoop:=0

          WHILE (uMatch=FALSE)
            IF userIdx > currCount THEN userIdx:=1
            StrCopy(tempstr,roomUsers)
            wordList:=splitBuffer(tempstr,',')
            IF ListLen(wordList)>=userIdx THEN StrCopy(uHandle,wordList[userIdx-1])
            releaseStringList(wordList)
            IF (StrLen(uHandle) > 0) AND (strCmpi(lastUSearch,uHandle, StrLen(lastUSearch)))
              uMatch:=TRUE
              StringF(inputStr,'\s\s\s',pf,uHandle,tail)
              cursorPos:=StrLen(inputStr)
              displayCurrentInput()   
            ENDIF
            userIdx:=userIdx+1
            sLoop:=sLoop+1
            IF sLoop > currCount THEN uMatch:=TRUE
          ENDWHILE
        ENDIF
      ELSE
        StrCopy(lastUSearch,'')
        userIdx:=1
      ENDIF      

      IF (m=17)
        IF exitChat=FALSE
          leaveChat()
          exitChat:=TRUE
        ENDIF
      ELSEIF m=27
        StrCopy(inputStr,'')
        cursorPos:=0
        updateFooter()        
        displayCurrentInput()    
      ELSEIF (m=LEFTARROW) AND (cursorPos>0)
        cursorPos--
        displayCurrentInput()
      ELSEIF (m=RIGHTARROW) AND (cursorPos<StrLen(inputStr))
        cursorPos++
        displayCurrentInput()
      ELSEIF (m=UPARROW) AND (charsEntered) AND (inputColour<15)
        inputColour++
        displayCurrentInput()
      ELSEIF (m=DOWNARROW) AND (charsEntered) AND (inputColour>9)
        inputColour--
        displayCurrentInput()
      ELSEIF (m=UPARROW) AND (charsEntered=FALSE)
        getPrevBufferItem()
        displayCurrentInput()
      ELSEIF (m=DOWNARROW) AND (charsEntered=FALSE)
        getNextBufferItem()
        displayCurrentInput()
      ELSEIF (m=CHAR_BACKSPACE) 
        IF cursorPos>0
          StrCopy(tempstr,'')
          IF cursorPos>1 THEN StrAdd(tempstr,inputStr,cursorPos-1)
          StrAdd(tempstr,inputStr+cursorPos)
          StrCopy(inputStr,tempstr)
          cursorPos--
          updateFooter()        
          displayCurrentInput()
          charsEntered:=StrLen(inputStr)>0
        ENDIF
      ELSEIF (m>31) AND (m<126) AND (StrLen(inputStr)<iMaxBuffer)
        IF (m<>32) OR (StrLen(inputStr)>0)
          StrCopy(tempstr,'')
          IF cursorPos>0 THEN StrAdd(tempstr,inputStr,cursorPos)
          StrCopy(tempstr2,'#')
          tempstr2[0]:=m
          StrAdd(tempstr,tempstr2)
          StrAdd(tempstr,inputStr+cursorPos)
          StrCopy(inputStr,tempstr)
          cursorPos++
          updateFooter()
          displayCurrentInput()
          charsEntered:=TRUE
        ENDIF
      ELSEIF m=13
        IF StrLen(inputStr)>0
          IF strCmpi(inputStr,'/RAINBOW ',9)
            rainbowStr(inputStr+9,tempstr2)
          ELSE
            StrCopy(tempstr2,inputStr)
          ENDIF
          addToBufferHistory(inputStr)
          StrCopy(inputStr,'')
          cursorPos:=0
          updateFooter()
          displayCurrentInput()
          processUserInput(tempstr2)
          charsEntered:=FALSE
        ENDIF
      ENDIF
      
      IF (strCmpi(inputStr,'/R ',3)) AND (StrLen(lastPrivMsg)>0)
        StringF(inputStr,'/T \s ',lastPrivMsg)
        cursorPos:=StrLen(inputStr)
        updateFooter()
        displayCurrentInput()
      ENDIF
    ENDIF
    
    IF ((m AND $FF)>250) THEN exitChat:=TRUE
  UNTIL exitChat
 
EXCEPT DO
  IF bufferHist<>NIL
    FOR i:=0 TO ListLen(bufferHist)-1
      DisposeLink(bufferHist[i])
    ENDFOR
    DisposeLink(bufferHist)
  ENDIF
  IF bannerList<>NIL
    FOR i:=0 TO ListLen(bannerList)-1
      DisposeLink(bannerList[i])
    ENDFOR
    DisposeLink(bannerList)
  ENDIF
  IF chatLines<>NIL
    FOR i:=0 TO ListLen(chatLines)-1
      DisposeLink(chatLines[i])
    ENDFOR
    DisposeLink(chatLines)
  ENDIF
  IF FileLength(chatLog)>=0 THEN DeleteFile(chatLog)
  IF roomUsers<>NIL THEN DisposeLink(roomUsers)
  IF readBuffer THEN Dispose(readBuffer)
  IF mrcserver<>-1 THEN CloseSocket(mrcserver)
  IF socketbase<>NIL THEN CloseLibrary(socketbase)
  IF plyr<>NIL THEN END plyr
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC

