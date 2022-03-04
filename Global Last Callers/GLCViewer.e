/*
JSON parser
*/
OPT OSVERSION=37,REG=5

  MODULE 'dos/dos','*jsonParser','*stringList'
  MODULE    'socket'
  MODULE    'net/netdb'
  MODULE  'devices/timer'
  MODULE    'net/in'
  MODULE 'AEDoor'                 /* Include libcalls & constants */

CONST BUFSIZE=8192
CONST FIONBIO=$8004667e
CONST ERR_FDSRANGE=$80000001
CONST GET_CMD_TOOLTYPE=707

ENUM ERR_NONE, ERR_KICK

RAISE ERR_KICK IF KickVersion()=FALSE

DEF serverHost[255]:STRING
DEF serverPort=1541
DEF aemode=FALSE
DEF diface:LONG
DEF strfield:LONG
DEF datafield:PTR TO LONG
DEF fds=NIL:PTR TO LONG

PROC urlEncode(str:PTR TO CHAR)
  DEF tempStr:PTR TO CHAR
 
  tempStr:=String(255)
  StrCopy(tempStr,TrimStr(str))

  replacestr(tempStr,'%','%25')
  replacestr(tempStr,' ','%20')
  replacestr(tempStr,'"','%22')
  replacestr(tempStr,'#','%23')
  replacestr(tempStr,'$','%24')
  replacestr(tempStr,'&','%26')
  replacestr(tempStr,'+','%2B')
  replacestr(tempStr,',','%2C')
  replacestr(tempStr,'/','%2F')
  replacestr(tempStr,':','%3A')
  replacestr(tempStr,';','%3B')
  replacestr(tempStr,'<','%3C')
  replacestr(tempStr,'=','%3D')
  replacestr(tempStr,'>','%3E')
  replacestr(tempStr,'?','%3F')
  replacestr(tempStr,'@','%40')

  replacestr(tempStr,'[','%5B')
  replacestr(tempStr,'\\','%5C')
  replacestr(tempStr,']','%5D')
  replacestr(tempStr,'^','%5E')
  replacestr(tempStr,'~','%7E')

  StrCopy(str,tempStr)
  DisposeLink(tempStr)
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


PROC displayData(fh,scrnclear,style,centreName,showlocation)
  DEF tempStr[255]:STRING
  DEF writeStr[300]:STRING
  DEF username[20]:STRING
  DEF location[25]:STRING
  DEF bbsname[25]:STRING
  DEF dateon[10]:STRING
  DEF timeon[10]:STRING
  DEF timeoff[10]:STRING
  DEF actions[10]:STRING
  DEF upload[10]:STRING
  DEF download[10]:STRING
  
  DEF statdate1[10]:STRING
  DEF statcalls1[5]:STRING
  DEF statcps1[10]:STRING
  DEF statup1[10]:STRING
  DEF statdown1[10]:STRING

  DEF statdate2[10]:STRING
  DEF statcalls2[5]:STRING
  DEF statcps2[10]:STRING
  DEF statup2[10]:STRING
  DEF statdown2[10]:STRING

  DEF allcalls[5]:STRING
  DEF recordcalls[5]:STRING
  DEF mostcalls[5]:STRING
  DEF recordsystem[25]:STRING
  DEF mostcalls2[5]:STRING
  DEF recordsystem2[25]:STRING
  DEF mostcalls3[5]:STRING
  DEF recordsystem3[25]:STRING
  
  DEF match
  DEF callsdata=0
  DEF recordstats=0
  DEF upkb,downkb
  DEF i,f

  IF scrnclear
    StringF(tempStr,'\c',12)
  ENDIF
  IF (style=1) OR (style=3)
    StrAdd(tempStr,'[0;40;37m   [35m   ___   ___________________________________   ___   __________________')
    transmit(tempStr) 
    transmit('[37m  [35m   /  /\\ / _   /  ___/__   __/  ___/ _   /  /\\ /  /\\ /  ___/ _  _/  ___/\\')
    transmit('[37m  [35m  /  /_//[5C/\\__  /\\_/  /\\/  /\\_/[5C/  /_//  /_//  ___/[5C)\\__  /\\/')
    transmit('[37m  [35m /_____/__/__/_____/ //__/ /_____/__/__/_____/_____/_____/__/__/_____/ /')
    transmit('[37m  [35m \\_____\\__\\__\\_____\\/ \\__\\/\\_____\\__\\__\\_____\\_____\\_____\\__\\__\\_____\\/[34mSdN')
    transmit('[1;44;33m                   GLOBAL LASTCALLERS! - (C) REBEL/qUARTEX                     [0m')
    IF showlocation
      transmit('[36mUSERNAME [37m[10C[36mLOCATION [37m[13C[36mDATE [30m [36mTIME ON BBS ACTIONS    UPL DWNL')
    ELSE
      transmit('[36mUSERNAME [37m[10C[36mBBS [37m[18C[36mDATE [30m [36mTIME ON BBS ACTIONS    UPL DWNL')
    ENDIF
  ENDIF
  IF (style=2) OR (style=4)
    StrAdd(tempStr,'[0;40;34m [35m  [37m [35m_______  [37m    .........  ........    ......[35m_______[37m[6C.........  ......')
    transmit(tempStr) 
    transmit('[35m   [37m [35m\\_[37m[5C[35m|___[37m   ....::::::::::.....  :::::: [35m\\_[37m[5C[35ml___[37m :::::.:::: ::: ::::')
    transmit('[35m   _/[37m[6C[35m| [37m [35m \\_[37m:::: :::::..... ::::: ::::::[35m_/ [37m[5C[35m __/_[37m::::: .... ::: ::::')
    transmit('[35m   \\____  [37m [35ml [37m  [35m /[37m:::: :::::::::: ::::::::::::[35m\\____ [37m  [35ml[37m   [35m /[37m:::: :::::::: ::::')
    transmit('[35m   [37m ÷2F÷[35m\\______/[37m:::::.:::::::::::::::::::::::[5C[35m\\______/[37m:::::::::::::: ::::')
    transmit('[1;44;33m                   GLOBAL LASTCALLERS! - (C) REBEL/qUARTEX                     [0m')
    IF showlocation
      transmit('[36mUSERNAME [37m[10C[36mLOCATION [37m[13C[36mDATE [30m [36mTIME ON BBS ACTIONS    UPL  DWNL')
    ELSE
      transmit('[36mUSERNAME [37m[10C[36mBBS [37m[18C[36mDATE [30m [36mTIME ON BBS ACTIONS    UPL  DWNL')
    ENDIF
  ENDIF 
  transmit('[34m------------------v---------------------v-----v-----------v----------v----v----')
  WHILE(ReadStr(fh,tempStr)<>-1) OR (StrLen(tempStr)>0)
    IF StrCmp('calls\\',tempStr,6)
      match:=FALSE
      IF StrCmp('calls\\Username=',tempStr,15)
        StrCopy(username,tempStr+15)
        match:=TRUE
      ENDIF
        
      IF StrCmp('calls\\Location=',tempStr,15)
        IF centreName
          StrCopy(location,TrimStr(tempStr+15))
          WHILE StrLen(location)<21
            StrAdd(location,' ')
            StringF(location,' \s',location)
          ENDWHILE
        ELSE
          StrCopy(location,tempStr+15)
        ENDIF
        match:=TRUE
      ENDIF

      IF StrCmp('calls\\Bbsname=',tempStr,14)
        IF centreName
          StrCopy(bbsname,TrimStr(tempStr+14))
          WHILE StrLen(bbsname)<21
            StrAdd(bbsname,' ')
            StringF(bbsname,' \s',bbsname)
          ENDWHILE
        ELSE
          StrCopy(bbsname,tempStr+14)
        ENDIF
      
        match:=TRUE
      ENDIF
        
      IF StrCmp('calls\\Dateon=',tempStr,13)
        StrCopy(dateon,tempStr+13)
        match:=TRUE
      ENDIF

      IF StrCmp('calls\\Timeon=',tempStr,13)
        StrCopy(timeon,tempStr+13)
        match:=TRUE
      ENDIF

      IF StrCmp('calls\\Timeoff=',tempStr,14)
        StrCopy(timeoff,tempStr+14)
        match:=TRUE
      ENDIF

      IF StrCmp('calls\\Actions=',tempStr,14)
        StrCopy(actions,tempStr+14)
        match:=TRUE
      ENDIF

      IF StrCmp('calls\\Upload=',tempStr,13)
        upkb:=Val(tempStr+13)
        IF (upkb<0) OR (upkb>9999)
          upkb:=Shr(upkb,10) AND $003fffff
          IF upkb>999
            i:=Shr(upkb,10)
            f:=Shr(Mul(upkb AND 1023,10),10)
            IF (i>9)
              StringF(upload,'----\dG',i)
            ELSE
              StringF(upload,'----\d.\dG',i,f)
            ENDIF
          ELSE
            StringF(upload,'----\dM',upkb)
          ENDIF
        ELSE
          StringF(upload,'----\s',tempStr+13)
        ENDIF
        match:=TRUE
      ENDIF

      IF StrCmp('calls\\Download=',tempStr,15)
        downkb:=Val(tempStr+15)
        IF (downkb<0) OR (downkb>9999)
          downkb:=Shr(downkb,10) AND $003fffff
          IF downkb>999
            i:=Shr(downkb,10)
            f:=Shr(Mul(downkb AND 1023,10),10)
            IF (i>9)
              StringF(download,'----\dG',i)
            ELSE 
              StringF(download,'----\d.\dG',i,f)
            ENDIF
            
          ELSE
            StringF(download,'----\dM',downkb)
          ENDIF
        ELSE
          StringF(download,'----\s',tempStr+15)
        ENDIF
        match:=TRUE
      ENDIF
      
      IF match THEN callsdata++

      IF callsdata=9
        callsdata:=0
        IF StrLen(upload)>8 THEN StrCopy(upload,'----LOTS')
        IF StrLen(download)>8 THEN StrCopy(download,'----LOTS')
        StringF(writeStr,'[36m\l\s[18][34m:[32m\l\s[21][34m:[37m\l\s[5][34m:[37m\l\s[5]-\l\s[5][34m:[36m\l\s[10][34m:[37m\r\s[4][34m:[37m\r\s[4]',username,IF showlocation THEN location ELSE bbsname,dateon,timeon,timeoff,actions,upload+StrLen(upload)-4,download+StrLen(download)-4)
        
        transmit(writeStr)
      ENDIF
    ENDIF

    IF StrCmp('yesterdayStats\\',tempStr,15)
      match:=FALSE
      IF StrCmp('yesterdayStats\\statdate=',tempStr,24) 
        StrCopy(statdate1,tempStr+24)
      ENDIF
      IF StrCmp('yesterdayStats\\calls=',tempStr,21) 
        StrCopy(statcalls1,tempStr+21)
      ENDIF
      
      IF StrCmp('yesterdayStats\\topcps=',tempStr,22) 
        StrCopy(statcps1,tempStr+22)
      ENDIF
      
      IF StrCmp('yesterdayStats\\uploads=',tempStr,23)
        StrCopy(statup1,tempStr+23)
      ENDIF
      
      IF StrCmp('yesterdayStats\\downloads=',tempStr,25)
        StrCopy(statdown1,tempStr+25)
      ENDIF
    ENDIF
    
    IF StrCmp('previousDayStats\\',tempStr,17)
      IF StrCmp('previousDayStats\\statdate=',tempStr,26)
        StrCopy(statdate2,tempStr+26)
      ENDIF
      IF StrCmp('previousDayStats\\calls=',tempStr,23)
        StrCopy(statcalls2,tempStr+23)
      ENDIF
      
      IF StrCmp('previousDayStats\\topcps=',tempStr,24)
        StrCopy(statcps2,tempStr+24)
      ENDIF
      
      IF StrCmp('previousDayStats\\uploads=',tempStr,25)
        StrCopy(statup2,tempStr+25)
      ENDIF
      
      IF StrCmp('previousDayStats\\downloads=',tempStr,27)
        StrCopy(statdown2,tempStr+27)
      ENDIF
    ENDIF

    IF StrCmp('records\\',tempStr,8)
      IF StrCmp('records\\allcalls=',tempStr,17) 
        StrCopy(allcalls,tempStr+17)
      ENDIF
      
      IF StrCmp('records\\recordcalls=',tempStr,20) 
        StrCopy(recordcalls,tempStr+20)
      ENDIF

      IF StrCmp('records\\calls=',tempStr,14) 
        StrCopy(mostcalls,tempStr+14)
      ENDIF
      
      IF StrCmp('records\\mostcalled=',tempStr,19)
        StrCopy(recordsystem,tempStr+19)
      ENDIF

      IF StrCmp('records\\calls2=',tempStr,15) 
        StrCopy(mostcalls2,tempStr+15)
      ENDIF

      IF StrCmp('records\\secondmostcalled=',tempStr,25)
        StrCopy(recordsystem2,tempStr+25)
      ENDIF

      IF StrCmp('records\\calls3=',tempStr,15) 
        StrCopy(mostcalls3,tempStr+15)
      ENDIF

      IF StrCmp('records\\thirdmostcalled=',tempStr,24)
        StrCopy(recordsystem3,tempStr+24)
      ENDIF

    ENDIF
  ENDWHILE

  IF StrLen(statcalls1)>3 THEN StrCopy(statcalls1,'999')
  IF StrLen(statcps1)>5 THEN StrCopy(statcps1,'99999')
  IF StrLen(statup1)>7 THEN StrCopy(statup1,'9999999')
  IF StrLen(statdown1)>7 THEN StrCopy(statdown1,'9999999')
  
  IF StrLen(statcalls2)>3 THEN StrCopy(statcalls2,'999')
  IF StrLen(statcps2)>5 THEN StrCopy(statcps2,'99999')
  IF StrLen(statup2)>7 THEN StrCopy(statup2,'9999999')
  IF StrLen(statdown2)>7 THEN StrCopy(statdown2,'9999999')

  transmit('[34m------------------^---------------------^-----^-----------^----------^----^----')
  transmit('[35m [1;33m[[0;36mD[1;33m][0;35mOWNLOAD   [1;33m[[0;36md[1;33m][0;35mOWNLOAD FAIL  [1;33m[[0;36mo[1;33m][0;35mPERATOR PAGED!  [1;33m[[0;36mF[1;33m][0;35mILE SCAN   [1;33m[[0;36mA[1;33m][0;35mCCOUNT EDIT!')
  transmit(' [1;33m[[0;36mU[1;33m][0;35mPLOAD [1;33m[[0;36mu[1;33m][0;35mPLOAD FAIL    [1;33m[[0;36mO[1;33m][0;35mPERATOR CHAT !  [1;33m[[0;36mH[1;33m][0;35mACK TRY!   [1;33m[[0;36mL[1;33m][0;35mOST CARRIER!')
  transmit(' [1;33m[[0;36m*[1;33m][0;35mNEW-USER  [1;33m[[0;36mB[1;33m][0;35mULLETINS      [1;33m[[0;36mE[1;33m][0;35mX. RESTR. FILE')
  transmit('[34m-------------------------------------------------------------------------------')

  IF (style=1) OR (style=2)
    StringF(writeStr,'[35mSTATUS [32m\l\s[8][35m: [1;33mCALLS [0;34m[[36m\r\s[3][34m] [1;33mTOP-CPS [0;34m[[36m\r\s[5][34m]  [1;33mUL [0;34m[[36m\r\s[7] [1;33mKB[0;34m]  [1;33mDL [0;34m[[36m\r\s[7] [1;33mKB[0;34m]',statdate1,statcalls1,statcps1,statup1,statdown1)
    transmit(writeStr)
    StringF(writeStr,'[35mSTATUS [32m\l\s[8][35m: [1;33mCALLS [0;34m[[36m\r\s[3][34m] [1;33mTOP-CPS [0;34m[[36m\r\s[5][34m]  [1;33mUL [0;34m[[36m\r\s[7] [1;33mKB[0;34m]  [1;33mDL [0;34m[[36m\r\s[7] [1;33mKB[0;34m]',statdate2,statcalls2,statcps2,statup2,statdown2)
    transmit(writeStr)
    StringF(writeStr,'[35mALLTIME RECORDS: [1;33mCALLS [0;34m[[36m\r\s[3][34m] [35mMOST CALLED SYSTEM  [34m[[36m\r\s[3][34m][35m: [32m\l\s[21]',recordcalls,mostcalls,recordsystem)
    transmit(writeStr)
  ENDIF

  IF (style=3) OR (style=4)
    StringF(writeStr,'[35mSTATUS [32m\l\s[8][35m: [1;33mCALLS [0;34m[[36m\r\s[3][34m]     [35mTOP 3 MOST     [37m1[0;34m[[36m\r\s[7][34m] [37m\l\s[20]',statdate1,statcalls1,mostcalls,recordsystem)
    transmit(writeStr)
    StringF(writeStr,'[35mSTATUS [32m\l\s[8][35m: [1;33mCALLS [0;34m[[36m\r\s[3][34m]                    [37m2[0;34m[[36m\r\s[7][34m] [37m\l\s[20]',statdate2,statcalls2,mostcalls2,recordsystem2)
    transmit(writeStr)
    StringF(writeStr,'[35mALLTIME RECORDS: [1;33mCALLS [0;34m[[36m\r\s[3][34m]   [35mCALLED SYSTEMS   [37m3[0;34m[[36m\r\s[7][34m] [37m\l\s[20]',recordcalls,mostcalls3,recordsystem3)
    transmit(writeStr)
  ENDIF

  transmit('[34m-------------------------------------------------------------------------------[0m')
ENDPROC

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

PROC extractdata(outfh,path:PTR TO CHAR, js:PTR TO CHAR, t, count, doit)
    DEF i, j,s,n,s2,s3,l1,l2,tot
  DEF tempstr[255]:STRING
  DEF path2[255]:ARRAY OF CHAR

  DEF tok:PTR TO jsmntok_t,tok2:PTR TO jsmntok_t
    IF (count = 0)
        RETURN 0,NIL,0
    ENDIF
  tok:=t
    IF (tok.type = JSMN_PRIMITIVE)
    IF js[tok.start]="n"
      ->null
      RETURN 1,js+tok.start,0
    ELSE
      RETURN 1,js+tok.start,tok.end - tok.start
    ENDIF
    ELSEIF (tok.type = JSMN_STRING)
        RETURN 1,js+tok.start,tok.end - tok.start
    ELSEIF (tok.type = JSMN_OBJECT)
        j:=0
    tot:=0
        FOR i:=0 TO tok.size-1
            n,s2,l1:=extractdata(outfh,path,js, t+((1+j)*SIZEOF jsmntok_t), count-j,FALSE)
      j:=j+n
      tot:=tot+l1

            n,s2,l2:=extractdata(outfh,path,js, t+((1+j)*SIZEOF jsmntok_t), count-j,FALSE)
      tok2:=t+((1+j)*SIZEOF jsmntok_t)
      IF (tok2.type=JSMN_PRIMITIVE) OR (tok2.type=JSMN_STRING)
        tot:=tot+l2+1+StrLen(path)+1
      ELSE
        DisposeLink(s2)
      ENDIF
      j:=j+n
      tot++
        ENDFOR
    s:=String(tot)
        j:=0
        FOR i:=0 TO tok.size-1
            n,s2,l1:=extractdata(outfh,path,js, t+((1+j)*SIZEOF jsmntok_t), count-j,doit)
      j:=j+n

      AstrCopy(path2,path)
      StrCopy(tempstr,s2,l1)
      AddPart(path2,tempstr,255)

      tok2:=t+((1+j)*SIZEOF jsmntok_t)
      IF ((tok2.type=JSMN_OBJECT) OR (tok2.type=JSMN_ARRAY)) AND doit
        ->WriteF('test=\s\n',tempstr)
      ENDIF

            n,s3,l2:=extractdata(outfh,path2,js, t+((1+j)*SIZEOF jsmntok_t), count-j,doit)
      IF (tok2.type=JSMN_PRIMITIVE) OR (tok2.type=JSMN_STRING)
        IF l2>0
          IF l1>0
            StrAdd(s,path)
            StrAdd(s,'\\')
            StrAdd(s,s2,l1)
            StrAdd(s,'=')  
          ENDIF
          StrCopy(tempstr,s3,l2)
          replacestr(tempstr,'\\\\','\\')
          replacestr(tempstr,'\\"','"')
          StrAdd(s,tempstr)
          StrAdd(s,'\n')
        ELSE
          IF l1>0
            StrAdd(s,path)
            StrAdd(s,'\\')
            StrAdd(s,s2,l1)
            StrAdd(s,'=')  
            StrAdd(s,'\n')
          ENDIF
        ENDIF
      ELSE
        IF l2<>0
          IF doit
            Write(outfh,s3,StrLen(s3))
          ENDIF
          DisposeLink(s3)
        ELSE
          IF doit
            ->WriteF('test2=\s\n',tempstr)
          ENDIF
        ENDIF
      ENDIF
      j:=j+n
        ENDFOR

        RETURN j+1,s,EstrLen(s)
    ELSEIF (tok.type = JSMN_ARRAY)
        j:=0
    tot:=0
        FOR i:=0 TO tok.size-1
            n,s2,l1:=extractdata(outfh,path,js, t+((1+j)*SIZEOF jsmntok_t), count-j,FALSE)
      j:=j+n
      tot:=tot+l1+1
        ENDFOR
    s:=String(tot)
        j:=0
        FOR i:=0 TO tok.size-1
      n,s2,l1:=extractdata(outfh,path,js, t+((1+j)*SIZEOF jsmntok_t), count-j,TRUE)
      j:=j+n
      StrAdd(s,s2,l1)
      StrAdd(s,'\n')
    ENDFOR
        RETURN j+1,s,EstrLen(s)
    ENDIF
ENDPROC 0

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
  DEF rescode=0
  DEF result[20]:STRING
  DEF n
  DEF tv:timeval

    buf:=String(BUFSIZE+4)
  NEW sa

    socketbase:=OpenLibrary('bsdsocket.library',2)
    IF (socketbase)

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
        IF fh=0 
          CloseSocket(s)
          CloseLibrary(socketbase)
          DisposeLink(buf)
          END sa
          RETURN FALSE
        ENDIF
      ENDIF
              
      REPEAT
        i:=Recv(s,buf,BUFSIZE-1,0)
        IF first 
          StrCopy(result,buf,20)
          first:=FALSE
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

/* gets the json and puts it in OutTextBuffer */
PROC getjson(timeout,page,count,bbsname,timeZone:PTR TO CHAR,tempFile:PTR TO CHAR)
  DEF getcmd[255]:STRING
  DEF bbsProp[255]:STRING
  DEF start
  start:=((page-1)*count)+1
  StrCopy(bbsProp,'')
  IF StrLen(bbsname)>0
    StrCopy(bbsProp,bbsname)
    urlEncode(bbsProp)
    StringF(bbsProp,'&bbsname=\s',bbsProp)
  ENDIF
  IF StrLen(timeZone)>0
    replacestr(timeZone,' ','+')
    StringF(getcmd,'GET /GlobalLastCallers/api/GlobalLastCallers?tzname=\s&start=\d&count=\d\s HTTP/1.0\b\nHost:\s\b\n\b\n',timeZone,start,count,bbsProp,serverHost)
  ELSE
    StringF(getcmd,'GET /GlobalLastCallers/api/GlobalLastCallers?start=\d&count=\d\s HTTP/1.0\b\nHost:\s\b\n\b\n',start,count,bbsProp,serverHost)
  ENDIF
  
  ->StringF(getcmd,'GET /api/GlobalLastCallers?start=\d&count=\d HTTP/1.0\b\nHost:\s\b\n\b\n',start,count,serverHost)
  httpRequest(timeout,getcmd,tempFile)
ENDPROC 

PROC transmit(textLine:PTR TO CHAR)
  IF aemode
    WriteStr(diface,textLine,LF)
  ELSE
    WriteF('\s\n',textLine)
  ENDIF
ENDPROC

PROC getAEIntValue(valueKey)
  DEF result
  IF aemode
    GetDT(diface,valueKey,0)        /* no string input here, so use 0 as last parameter */
    result:=Val(strfield)
  ELSE
    result:=-1
  ENDIF
ENDPROC result

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

ENDPROC (Mul(Mul(startds.days+2922,1440),60)+(startds.minute*60)+(startds.tick/50))+21600

PROC main() HANDLE
    DEF r,l
  DEF rn:PTR TO CHAR
  DEF p:jsmn_parser
  DEF tok:PTR TO jsmntok_t
  DEF tokcount
  DEF fh2=0
  DEF outpath[255]:ARRAY OF CHAR
  DEF tempFile[20]:STRING
  DEF tempStr[255]:STRING
  DEF tempStr2[255]:STRING
  DEF doorPort[20]:STRING
  DEF timeZone[255]:STRING
  DEF configNames:PTR TO stringlist
  DEF configValues:PTR TO stringlist
  DEF styles:PTR TO stringlist
  DEF jsonBuffer,bufsize,position
  DEF jsonStart
  DEF page,count,scrnclear
  DEF p1,p2
  DEF style=1
  DEF timeout=10
  DEF centreName=FALSE
  DEF bbsname[255]:STRING
  DEF node=-1
  DEF myargs:PTR TO LONG,rdargs

  KickVersion(37)  -> E-Note: requires V37

  fds:=NEW [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]:LONG

  StrCopy(serverHost,'scenewall.bbs.io')
  AstrCopy(outpath,'',ALL)
  StrCopy(tempFile,'T:jsondata')

  ->initialise random seed from scanline position and node start time
  rn:=$dff006
  r:=Eor(Shl(rn[0],8)+rn[0],getSystemTime()) AND $FFFF
  Rnd((Shl(r,16)+r) OR $80000000)

  scrnclear:=FALSE
  page:=1
  count:=10

  myargs:=[0,0]:LONG
  IF rdargs:=ReadArgs('BBSNAME/K,NODE/N',myargs,NIL)
    IF myargs[0]<>NIL
      StrCopy(bbsname,myargs[0])
    ENDIF
    IF myargs[1]<>NIL
      node:=Long(myargs[1])
    ENDIF
    FreeArgs(rdargs)
  ELSE
    RETURN
  ENDIF

  aemode:=FALSE
  IF node==[0 TO 31]
    StringF(doorPort,'AEDoorPort\d',node)
    IF FindPort(doorPort)
      IF aedoorbase:=OpenLibrary('AEDoor.library',1)
        diface:=CreateComm(arg[])     /* Establish Link   */
        strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
        datafield:=GetData(diface)

        IF diface<>0 THEN aemode:=TRUE
      ENDIF
    ENDIF
  ENDIF

  configNames:=NEW configNames.stringlist(10)
  configNames.add('SERVERHOST')
  configNames.add('SERVERPORT')
  configNames.add('TEMPFILE')
  configNames.add('LINES')
  configNames.add('SCREENCLEAR')
  configNames.add('STYLE')
  configNames.add('TIMEOUT')
  configNames.add('CENTRENAME')
  configNames.add('TIMEZONE')
  
  configValues:=NEW configValues.stringlist(10)
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')

  parseConfigFile('PROGDIR:GLCViewer.cfg',configNames,configValues)
  parseConfigFile('GLCViewer.cfg',configNames,configValues)
  IF StrLen(configValues.item(0))>0 THEN StrCopy(serverHost,configValues.item(0))
  IF StrLen(configValues.item(1))>0 THEN serverPort:=Val(configValues.item(1))
  IF StrLen(configValues.item(2))>0 THEN StrCopy(tempFile,configValues.item(2))
  IF StrLen(configValues.item(3))>0
    UpperStr(configValues.item(3))
    IF StrCmp(configValues.item(3),'AUTO') AND aemode
      count:=getAEIntValue(DT_LINELENGTH)-18
      IF count<0 THEN count:=5
    ELSE
      r,l:=Val(configValues.item(3))
      IF l>0 THEN count:=r
    ENDIF
  ENDIF
  UpperStr(configValues.item(4))
  IF StrCmp(configValues.item(4),'YES') THEN scrnclear:=TRUE
  IF StrLen(configValues.item(5))>0
    IF InStr(configValues.item(5),',')>=0
      styles:=NEW styles.stringlist(10)
      p1:=0
      StrCopy(tempStr,configValues.item(5))
      WHILE((p2:=InStr(tempStr+p1,','))>=0)
        StrCopy(tempStr2,tempStr+p1,p2)
        styles.add(tempStr2)
        p1:=p1+p2+1
      ENDWHILE
      IF StrLen(tempStr+p1)>0 THEN styles.add(tempStr+p1)
      style:=styles.count()
      style:=Val(styles.item(Rnd(styles.count())))
      Dispose(styles)
    ELSE
      style:=Val(configValues.item(5))
    ENDIF
  ENDIF
  IF StrLen(configValues.item(6))>0 THEN timeout:=Val(configValues.item(6))
  IF StrCmp(configValues.item(7),'1') THEN centreName:=TRUE
  IF StrLen(configValues.item(8))>0 THEN StrCopy(timeZone,configValues.item(8))
  
  IF (style<1) OR (style>4) THEN style:=1
  
  IF aemode
    datafield[]:=0
    GetDT(diface,GET_CMD_TOOLTYPE,'LOCALONLY')
    IF (datafield[])
      GetDT(diface,JH_BBSNAME,0)
      StrCopy(bbsname,strfield)
    ENDIF
  ENDIF
  
  getjson(timeout,page,count,bbsname,timeZone,tempFile)
  bufsize:=FileLength(tempFile)
  IF bufsize<1 THEN Raise(10)
  jsonBuffer:=New(bufsize)
  IF (jsonBuffer = NIL) THEN Raise(6)

  fh2:=Open(tempFile,MODE_OLDFILE)
  IF fh2<>0
    Read(fh2,jsonBuffer,bufsize)
    Close(fh2)
    fh2:=0
  ENDIF

    /* Prepare parser */
    jsmn_init(p)
  
  fh2:=Open(tempFile,MODE_NEWFILE)
  IF fh2=0 THEN Raise(7)
    
  position:=0
  WHILE ((jsonBuffer[position]<>13) OR (jsonBuffer[position+1]<>10) OR (jsonBuffer[position+2]<>13) OR (jsonBuffer[position+3]<>10)) AND (position<bufsize-4)
    position++
  ENDWHILE
  position++
  position++
  position++
  position++
  IF position>=bufsize THEN Raise(8)

  jsonStart:=jsonBuffer+position
  tokcount:=jsmn_parse(p, jsonStart, bufsize-position, 0, 0)

    tok:=New(SIZEOF jsmntok_t * tokcount)
    IF (tok = NIL) THEN Raise(9)   
  
    jsmn_init(p)
  r:=jsmn_parse(p, jsonStart, bufsize-position, tok, tokcount)
  IF (r>=0)
  ->tok, p.toknext
    extractdata(fh2,outpath,jsonStart, tok, p.toknext,TRUE)
    IF fh2<>0 THEN Close(fh2)

    fh2:=Open(tempFile,MODE_OLDFILE)
    IF fh2<>0 THEN displayData(fh2,scrnclear,style,centreName,StrLen(bbsname)>0)
  ELSE
    SELECT r
      CASE JSMN_ERROR_NOMEM
        transmit('Error Parsing json file - not enough memory to proceed\n\n')
      CASE JSMN_ERROR_INVAL
        transmit('Error Parsing json file - invalid data found\n\n')
      CASE JSMN_ERROR_PART
        transmit('Error Parsing json file - incomplete data found\n\n')
    ENDSELECT
  ENDIF
EXCEPT DO
  IF jsonBuffer<>NIL THEN Dispose(jsonBuffer)
  IF fh2<>0 THEN Close(fh2)
  IF fds<>NIL THEN END fds[32]

  DeleteFile(tempFile)
  SELECT exception
    CASE ERR_KICK; transmit('Error: Requires V37\n\n')
    CASE 6; transmit('Could not allocate enough memory to hold json data\n\n')
    CASE 7; transmit('Could not open temporary working file\n\n')
    CASE 8; transmit('Could not find json data in http response\n\n')
    CASE 9; transmit('Could not allocate enough memory to parse json file\n\n')
    CASE 10; transmit('Could not get json data from server\n\n')
  ENDSELECT
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC

