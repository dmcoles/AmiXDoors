/*
** gLOBAL tHERMONUCLEAR wALL v1.0ß
** Amiga E version
*/

OPT LARGE


  MODULE 'AEDoor'                 /* Include libcalls & constants */
  MODULE	'socket'
  MODULE	'net/netdb'
  MODULE	'net/in'
  MODULE  'dos/dos'
  MODULE  'devices/timer'

  MODULE  '*stringlist'

CONST BUFSIZE=8192

ENUM DP_USERNAME, DP_SOURCE, DP_BBSSHORTCODE, DP_COMMENT

CONST ERR_FDSRANGE=$80000001

CONST MAXSTYLE = 4
CONST MAXPRESET = 2
CONST SYSOPLEVEL = 255
CONST DEFAULTSTYLE = 4
CONST BUFFERSIZE=512
CONST COLOURPRESETLEN=14

CONST DT_ACCESSLEVEL=105

CONST FIONBIO=$8004667e

OBJECT settingsData
  sysoplevel
  style
  screenheight
  mybbsshortcode
  coloursettings
  gridcolour
  titlecolour
  headingcolour
  authorcolour
  sysoptitlecolour
  sysopmenuitemscolour
  bbsshortcodecolour
  commentdefaultcolour
  showbbskeycolour
  bbskeymaincolour
  textcolour
  textcolourYN
  choosecolourheader
  radiationheadercolour
  node
ENDOBJECT

OBJECT bbsItem
  bbsName
  bbsShortCode
ENDOBJECT

OBJECT wallItem
  id
  username
  source
  comment
  bbsshortcode
ENDOBJECT

DEF serverHost[255]:STRING
DEF serverPort=1541
DEF timeout=10
DEF fds=NIL:PTR TO LONG
DEF timeoutError=FALSE

DEF bbsList: PTR TO bbsItem
DEF wallItems: PTR TO wallItem
DEF diface,strfield:LONG

DEF colourpresets: PTR TO LONG
DEF settings:settingsData
DEF jsonBuffer

DEF aemode

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
  DEF displaylines,accesslevel,pagenum,rep,redo,style,inputBuffer,textdata,bbsname, username, displaytext, colour, comment
  DEF configNames:PTR TO stringlist
  DEF configValues:PTR TO stringlist
 
  StrCopy(serverHost,'scenewall.bbs.io')
  fds:=NEW [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]:LONG

  aemode:=FALSE

  colourpresets:=['42626717772363','32656717772363']

    IF aedoorbase:=OpenLibrary('AEDoor.library',1)
      diface:=CreateComm(arg[])     /* Establish Link   */
      IF diface<>0
        aemode:=TRUE
        strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
      ENDIF
    ENDIF

    configNames:=NEW configNames.stringlist(3)
    configNames.add('SERVERHOST')
    configNames.add('SERVERPORT')
    configNames.add('TIMEOUT')
    
    configValues:=NEW configValues.stringlist(3)
    configValues.add('')
    configValues.add('')
    configValues.add('')

    parseConfigFile('PROGDIR:GWALL.cfg',configNames,configValues)
    parseConfigFile('GWALL.cfg',configNames,configValues)
    IF StrLen(configValues.item(0))>0 THEN StrCopy(serverHost,configValues.item(0))
    IF StrLen(configValues.item(1))>0 THEN serverPort:=Val(configValues.item(1))
    IF StrLen(configValues.item(2))>0 THEN timeout:=Val(configValues.item(2))


    settings.node:=String(10)
    StrCopy(settings.node,'0')
    IF StrCmp(arg,'')=FALSE THEN StrCopy(settings.node,arg)

    settings.sysoplevel:=SYSOPLEVEL
    settings.style:=DEFAULTSTYLE
    settings.coloursettings:=String(COLOURPRESETLEN)
    StrCopy(settings.coloursettings,colourpresets[0]);
    settings.mybbsshortcode:='???'
    settings.screenheight:=getAEIntValue(DT_LINELENGTH)

    readSettings()
    applyColours()

    displaylines:=calculateDisplayLines()

    bbsList:=List(displaylines)
    wallItems:=List(displaylines)
    
    IF (StrCmp(settings.mybbsshortcode,'???'))
      accesslevel:=getAEIntValue(DT_ACCESSLEVEL)
      IF (accesslevel >= settings.sysoplevel)
        transmit('')
        transmit('[0mThe wall has not yet been configured, performing initial setup')
        sysopShortCodeUpdate()
      ELSE
        transmit('')
        transmit('[0mThe wall has not been configured, please advice your sysop to configure this wall')
        transmit('')
        IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
        IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
        CleanUp()
      ENDIF
    ENDIF
    
    pagenum:=1
    rep:=1
    redo:=1
    
    inputBuffer:=String(255)
    WHILE rep<>0 

      style:=settings.style
      IF redo=1
        jsonBuffer:=String(30000)
        getwalljson(pagenum,displaylines, jsonBuffer)
        decodejson(jsonBuffer)
        DisposeLink(jsonBuffer)
        sendCLS()

        SELECT style
          CASE 1
            header1(FALSE)
          CASE 2
            header2(FALSE)
          CASE 3
            header3(FALSE)
          CASE 4
            header4(FALSE)
          DEFAULT
            header2(FALSE)
        ENDSELECT

        displaywalldata(displaylines,FALSE)

        SELECT style
          CASE 1
            footer1(FALSE)
          CASE 2
            footer2(FALSE)
          CASE 3
            footer3(FALSE)
          CASE 4
            footer4(FALSE)
          DEFAULT
            footer2(FALSE)
        ENDSELECT
        redo:=0
      ENDIF
      
      transmit('')
      textdata:=String(255)

      IF timeoutError
        transmit('[0mThe server is not currently responding. Please try again later')
        END fds[32]
        IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
        IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
        RETURN
      ENDIF

      StringF(textdata,'\s\s\s\s\s\s\s\s\s\s',settings.textcolour,'pUSH[1CtHE[1CbUTTON[1C?![1C[',settings.textcolourYN,'y',settings.textcolour,'/',settings.textcolourYN,'N',settings.textcolour,'][0m ')
      sendStr(textdata)
      getChar(inputBuffer, TRUE)
      
      transmit('[0m')

      IF StrCmp(inputBuffer,'S')
        accesslevel:=getAEIntValue(DT_ACCESSLEVEL)
        IF accesslevel >= settings.sysoplevel
          sysopMode()
          transmit('')
          transmit('[0mGoodbye...')
          transmit('')
          IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
          IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
          CleanUp()
        ENDIF
      ENDIF

      IF StrCmp(inputBuffer,'K')
        showBBSKey()
      ELSEIF StrCmp(inputBuffer,'B')
        pagenum:=pagenum+1
        redo:=1
      ELSEIF StrCmp(inputBuffer,'F')
        IF (pagenum>1) THEN pagenum:=pagenum-1
        redo:=1
      ELSE
        rep:=0  
      ENDIF
    ENDWHILE
        
    IF (StrCmp(inputBuffer,'Y'))=FALSE
      transmit('')
      transmit('[0mok be like that...')
      transmit('')
      IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
      IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
      CleanUp()
    ENDIF

    comment:=String(255)
    query('Enter your comment: ',56,inputBuffer)
    trimStr(inputBuffer,comment)
    IF EstrLen(comment)=0
      transmit('')
      transmit('[0myou forgot to enter something...')
      transmit('')
      IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
      IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
      CleanUp()
    ENDIF

    transmit('')
    displaytext:=String(255)
    StringF(displaytext,'\s\s\s\s\s\s\s\s\s\s',settings.textcolour,'sTAY aNONYMOUS? [',settings.textcolourYN,'y',settings.textcolour,'/',settings.textcolourYN,'N',settings.textcolour,'][0m ')
    sendStr(displaytext)

    getChar(inputBuffer,TRUE)

    bbsname:=String(255)
    username:=String(255)
    getAEStringValue(JH_BBSNAME,bbsname)

    IF StrCmp(inputBuffer,'Y')
      StrCopy(username,'somebody')
    ELSE
      getAEStringValue(DT_NAME,username)
    ENDIF

    colour:=String(1)

    WHILE EstrLen(colour)=0
      transmit('')
      StringF(displaytext,'\s\s\s\s\s\s',settings.gridcolour,'.-[» ',settings.choosecolourheader,'cHOOSE yOUR cOLOUR',settings.gridcolour,' «]----- -- ------ --------------------- -  - ---------.')
      transmit(displaytext)
      StringF(displaytext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.gridcolour,'¦     [37m[W]HITE ',settings.gridcolour,'- [31m[R]ED ',settings.gridcolour,'- [33m[Y]ELLOW ',settings.gridcolour,'- [34m[D]ARKBLUE ',settings.gridcolour,'- [35m[P]INK ',settings.gridcolour,'- [36m[C]YAN ',settings.gridcolour,'- [32m[G]REEN',settings.gridcolour,'     ¦' )
      transmit(displaytext)
      StringF(displaytext,'\s\s',settings.gridcolour,'`----------- -- ----- - --    - -- --  ---- - -----        - -- -------- -- --''[0m')
      transmit(displaytext)
      EXIT getChar(inputBuffer,TRUE)=FALSE
      IF ((StrCmp(inputBuffer,'W')) OR (StrCmp(inputBuffer,'7'))) THEN StrCopy(colour,'7')
      IF ((StrCmp(inputBuffer,'R')) OR (StrCmp(inputBuffer,'1'))) THEN StrCopy(colour,'1')
      IF ((StrCmp(inputBuffer,'Y')) OR (StrCmp(inputBuffer,'3'))) THEN StrCopy(colour,'3')
      IF ((StrCmp(inputBuffer,'D')) OR (StrCmp(inputBuffer,'4'))) THEN StrCopy(colour,'4')
      IF ((StrCmp(inputBuffer,'P')) OR (StrCmp(inputBuffer,'5'))) THEN StrCopy(colour,'5')
      IF ((StrCmp(inputBuffer,'C')) OR (StrCmp(inputBuffer,'6'))) THEN StrCopy(colour,'6')
      IF ((StrCmp(inputBuffer,'G')) OR (StrCmp(inputBuffer,'2'))) THEN StrCopy(colour,'2')
    ENDWHILE

    IF EstrLen(colour)>0
      encodeAnsiColour(colour,displaytext)
      StrAdd(displaytext,comment)
      postcomment(username,bbsname,displaytext)

      transmit('')
      transmit('[0myour comment has been posted')
      transmit('')
    ENDIF

    END fds[32]
    IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
    IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC

PROC sysopMode()
  DEF pagenum,displaylines, key,seperator1,seperator2,seperator3,sendtext,style

  pagenum:=1
  displaylines:=calculateDisplayLines()-4
  style:=settings.style

  key:=String(255)
  WHILE StrCmp(key,'4')=FALSE
    sendCLS()
    SELECT style
      CASE 1
        header1(FALSE)
      CASE 2
        header2(FALSE)
      CASE 3
        header3(FALSE)
      CASE 4
        header4(FALSE)
      DEFAULT
        header2(FALSE)
    ENDSELECT

    jsonBuffer:=String(30000)
    getwalljson(pagenum,displaylines, jsonBuffer)
    decodejson(jsonBuffer)
    DisposeLink(jsonBuffer)
    displaywalldata(displaylines,TRUE)

    SELECT style
    CASE 3
      seperator1:='|'
      seperator2:='¦'
      seperator3:='¦' 
    CASE 4
      seperator1:='|'
      seperator2:='¦'
      seperator3:='|'
    DEFAULT
      seperator1:='¦'
      seperator2:='¦'
      seperator3:='¦'
    ENDSELECT

    sendtext:=String(255)
    StringF(sendtext,'\s\s\s',seperator1,'------- -  -  - --- - --- ----------------------- ---------- ----------------',seperator3)
    transmit(sendtext)
    StringF(sendtext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'1) Edit a comment',settings.gridcolour,'[59C',seperator3)
    transmit(sendtext)
    StringF(sendtext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'2) Remove a comment',settings.gridcolour,'[57C',seperator3)
    transmit(sendtext)
    StringF(sendtext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'3) Update settings',settings.gridcolour,'[58C',seperator3)
    transmit(sendtext)
    StringF(sendtext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'4) Exit',settings.gridcolour,'[69C',seperator3)
    transmit(sendtext)
    DisposeLink(sendtext)

    SELECT style
      CASE 1
        footer1(FALSE)
      CASE 2
        footer2(FALSE)
      CASE 3
        footer3(FALSE)
      CASE 4
        footer4(FALSE)
      DEFAULT
        footer2(FALSE)
    ENDSELECT

    EXIT getChar(key, FALSE)=FALSE
    IF StrCmp(key,'1') THEN sysopEdit()
    IF StrCmp(key,'2') THEN sysopRemove()
    IF StrCmp(key,'3') THEN sysopSettingsUpdate()
    IF StrCmp(key,'B') THEN pagenum:=pagenum+1
    IF (StrCmp(key,'F')) AND (pagenum>1) THEN pagenum:=pagenum - 1
  ENDWHILE
  DisposeLink(key)
ENDPROC

PROC sysopEdit()
  DEF inputBuffer,lineid,datapoint,itemval,newusername,newcomment,newshortcode,newsource,colourtxt,tempbuffer,newvalue
  inputBuffer:=String(5)
  lineid:=String(5)
  itemval:=String(255)
  
  transmit('')
  query('Enter the id of the line you wish to edit: ',5,inputBuffer)
  trimStr(inputBuffer,lineid)

  IF EstrLen(lineid)=0 THEN RETURN
  
  transmit('')
  transmit('1) Edit username')
  transmit('2) Edit source')
  transmit('3) Edit bbs code')
  transmit('4) Edit comment')
  transmit('5) Cancel edit')
  transmit('')

  sendStr('Choose 1-5: ')

  StrCopy(inputBuffer,'')
  WHILE (StrCmp(inputBuffer,'1')=FALSE) AND (StrCmp(inputBuffer,'2')=FALSE) AND (StrCmp(inputBuffer,'3')=FALSE) AND (StrCmp(inputBuffer,'4')=FALSE) AND (StrCmp(inputBuffer,'5')=FALSE)
    EXIT getChar(inputBuffer,FALSE)=FALSE
    IF StrCmp(inputBuffer,'1') THEN datapoint:=DP_USERNAME
    IF StrCmp(inputBuffer,'2') THEN datapoint:=DP_SOURCE
    IF StrCmp(inputBuffer,'3') THEN datapoint:=DP_BBSSHORTCODE
    IF StrCmp(inputBuffer,'4') THEN datapoint:=DP_COMMENT
  ENDWHILE
  transmit(inputBuffer)

  IF StrCmp(inputBuffer,'5')=FALSE
    IF extractwalldataitem(lineid,datapoint, itemval)

      tempbuffer:=String(255)
      colourtxt:=String(10)
      IF datapoint=DP_COMMENT
        StrCopy(tempbuffer,itemval,3)
        IF (StrCmp(tempbuffer,'[3')) AND (itemval[4]="m") THEN StrCopy(colourtxt,itemval,5)
      ENDIF

      transmit('')
      sendStr('OldValue: ')
      transmit(itemval)
      transmit('')
      StringF(tempbuffer,'\s\s','[0mEnter new value: ',colourtxt)
      newvalue:=String(255)
      newvalue:=String(255)
      query(tempbuffer,255,newvalue)

      IF (EstrLen(newvalue)<>0)
        newusername:=String(255)
        newsource:=String(255)
        newcomment:=String(255)
        newshortcode:=String(255)

        IF datapoint=DP_USERNAME THEN StrCopy(newusername,newvalue)
        IF datapoint=DP_SOURCE THEN StrCopy(newsource,newvalue)
        IF datapoint=DP_COMMENT THEN StrCopy(newcomment,newvalue)
        IF datapoint=DP_BBSSHORTCODE THEN StrCopy(newshortcode,newvalue)

        IF datapoint=DP_COMMENT
          StringF(tempbuffer,'\s\s',colourtxt,newcomment)
        ELSE
          StrCopy(tempbuffer,newcomment)
        ENDIF

        putcomment(lineid,newusername,newsource,tempbuffer, newshortcode)

        DisposeLink(newusername)
        DisposeLink(newshortcode)
        DisposeLink(newsource)
        DisposeLink(newcomment)
      ENDIF

      DisposeLink(colourtxt)
      DisposeLink(newvalue)
      DisposeLink(tempbuffer)
    ENDIF
  ENDIF

  DisposeLink(inputBuffer)
  DisposeLink(lineid)
  DisposeLink(itemval)
ENDPROC

PROC sysopRemove()
  DEF lineid
  DEF inputBuffer

  lineid:=String(5)
  inputBuffer:=String(5)
  transmit('')
  query('Enter the id of the line you wish to remove: ',5,inputBuffer)
  trimStr(inputBuffer,lineid)
  IF EstrLen(lineid)<>0 THEN deletecomment(lineid)
  DisposeLink(lineid)
  DisposeLink(inputBuffer)
ENDPROC

PROC sysopSettingsUpdate()
  DEF pagenum,displaylines,inputBuffer,displaytext,style,seperator1,seperator2,seperator3

  pagenum:=1
  displaylines:=calculateDisplayLines()-4
  inputBuffer:=String(255)
  displaytext:=String(255)
  style:=settings.style
  WHILE StrCmp(inputBuffer,'4')=FALSE
    sendCLS()

    SELECT style
      CASE 1
        header1(FALSE)
      CASE 2
        header2(FALSE)
      CASE 3
        header3(FALSE)
      CASE 4
        header4(FALSE)
      DEFAULT
        header2(FALSE)
    ENDSELECT

    jsonBuffer:=String(30000)
    getwalljson(pagenum,displaylines, jsonBuffer)
    decodejson(jsonBuffer)
    DisposeLink(jsonBuffer)
    displaywalldata(displaylines,TRUE)

    SELECT style
    CASE 3
      seperator1:='|'
      seperator2:='¦'
      seperator3:='¦'
    CASE 4
      seperator1:='|'
      seperator2:='¦'
      seperator3:='|'
    DEFAULT
      seperator1:='¦'
      seperator2:='¦'
      seperator3:='¦'
    ENDSELECT

    StringF(displaytext,'\s\s\s',seperator1,'------- -  -  - --- - --- ----------------------- ---------- ----------------',seperator3)
    transmit(displaytext)
    StringF(displaytext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'1) Edit BBS Short code',settings.gridcolour,'[54C',seperator3)
    transmit(displaytext)
    StringF(displaytext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'2) Edit Wall Style',settings.gridcolour,'[58C',seperator3)
    transmit(displaytext)
    StringF(displaytext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'3) Edit Colour Preset',settings.gridcolour,'[55C',seperator3)
    transmit(displaytext)
    StringF(displaytext,'\s\s\s\s\s\s\s',seperator1,' ',settings.sysopmenuitemscolour,'4) Back to Sysop Page',settings.gridcolour,'[55C',seperator3)
    transmit(displaytext)
    
    SELECT style
      CASE 1
        footer1(FALSE)
      CASE 2
        footer2(FALSE)
      CASE 3
        footer3(FALSE)
      CASE 4
        footer4(FALSE)
      DEFAULT
        footer2(FALSE)
    ENDSELECT

    EXIT getChar(inputBuffer,FALSE)=FALSE
    IF StrCmp(inputBuffer,'1') THEN sysopshortcodeUpdate()
    IF StrCmp(inputBuffer,'2') THEN sysopStyleUpdate()
    IF StrCmp(inputBuffer,'3') THEN sysopColourUpdate()
  ENDWHILE
  DisposeLink(inputBuffer)
  DisposeLink(displaytext)
ENDPROC

PROC sysopStyleUpdate()
  DEF newvalue,newstyle,displaytext
  newvalue:=String(255)
  displaytext:=String(255)
  newstyle:=0
  transmit('')
  WHILE ((newstyle < 1) OR (newstyle>MAXSTYLE))
    sendStr('OldValue: ')
    StringF(displaytext,'\d',settings.style)
    transmit(displaytext)
    transmit('')
    StringF(displaytext,'\s\d\s','Select new style (1-',MAXSTYLE,'): ')
    query(displaytext,1,newvalue)
    newstyle:=Val(newvalue)
  ENDWHILE

  settings.style:=newstyle
  saveSettings()
  DisposeLink(newvalue)
  DisposeLink(displaytext)
ENDPROC

PROC sysopshortcodeUpdate()
  DEF newvalue
  newvalue:=String(255)
  transmit('')

  WHILE ((EstrLen(newvalue)=0) OR (EstrLen(newvalue)>3))
    IF StrCmp(settings.mybbsshortcode,'???')=FALSE
      sendStr('OldValue: ')
      transmit(settings.mybbsshortcode)
      transmit('')
      query('Enter new value: ',3,newvalue)
    ELSE
      query('Enter the 3 digit code to use for your bbs: ',3,newvalue)
    ENDIF
  ENDWHILE

  StrCopy(settings.mybbsshortcode,newvalue)
  saveSettings()
  DisposeLink(newvalue)
ENDPROC

PROC sysopColourUpdate()
  DEF newvalue, newcolour, displaytext
  newvalue:=String(255)
  displaytext:=String(255)
  newcolour:=0
  transmit('')

  WHILE ((newcolour < 1) OR (newcolour>MAXPRESET))
    StringF(displaytext,'\s\d\s','Select new colour preset (1-',MAXPRESET,'): ')
    query(displaytext,1,newvalue)
    newcolour:=Val(newvalue)
  ENDWHILE

  StrCopy(settings.coloursettings,colourpresets[newcolour-1])
  applyColours()
  saveSettings()
ENDPROC

PROC showBBSKey()
  DEF sendtext,i, item: PTR TO bbsItem
  sendtext:=String(255)
  StringF(sendtext,'\s\s',settings.gridcolour,'.------- -  -  - --- - --- ----------------------- ---------- ----------------.')
  transmit(sendtext)
  FOR i:=0 TO ListLen(bbsList)-1
    item:=ListItem(bbsList,i)
    StringF(sendtext,'\s\s\s\s\s\s[0m',settings.gridcolour,'¦ [76C¦[74D',settings.bbskeymaincolour,item.bbsShortCode,': ',item.bbsName)
    transmit(sendtext)
  ENDFOR
  StringF(sendtext,'\s\s',settings.gridcolour,'`----- ----- - --------- ------------------------------- -- ---------------- -''')
  transmit(sendtext)
  DisposeLink(sendtext)
ENDPROC

PROC header1(sysopmode)
  DEF sysopstr,sendtext
  sysopstr:=String(255)
  sendtext:=String(255)
  IF sysopmode
    StringF(sysopstr,'\s\s\s\s\s','[',settings.sysoptitlecolour,'sYSOP mODE',settings.gridcolour,']')
  ELSE
    sysopstr:='------------'
  ENDIF

  StringF(sendtext,'\s\s\s\s\s\s\s\s', settings.gridcolour,'.-[» ',settings.titlecolour,'gLOBAL tHERMONUCLEAR wALL V1ß',settings.gridcolour,' «]--------------------',sysopstr,'---------.');
  transmit(sendtext);
  transmit('!----- ----- - --------- ------------------------------- -- --------------÷- -|')
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s','¦',settings.headingcolour,'cOMMENt[60ChANDLE',settings.gridcolour,'¡',settings.headingcolour,'bBS',settings.gridcolour,'¦')
  transmit(sendtext);
  transmit('¦------- -  -  - --- - --- ----------------------- ---------- ------------!---¦')
  DisposeLink(sysopstr)
  DisposeLink(sendtext)
ENDPROC

PROC header2(sysopmode)
  DEF sendtext
  sendtext:=String(255)

  StringF(sendtext,'\s\s\s','[9C',settings.radiationheadercolour,'__')
  transmit(sendtext)

  StringF(sendtext,'\s\s\s\s\s\s',settings.gridcolour,'.-[1C-[1C---',settings.radiationheadercolour,'_\\/_',settings.gridcolour,'--÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'G',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷',settings.titlecolour,'O',settings.gridcolour,'÷',settings.titlecolour,'B',settings.gridcolour,'÷',settings.titlecolour,'A',settings.gridcolour,'÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'L',settings.gridcolour,'÷--÷',settings.titlecolour,'T',settings.gridcolour,'÷',settings.titlecolour,'H',settings.gridcolour,'÷',settings.titlecolour,'E',settings.gridcolour,'÷',settings.titlecolour,'R',settings.gridcolour,'÷',settings.titlecolour,'M',settings.gridcolour,'÷',settings.titlecolour,'O',settings.gridcolour,'÷',settings.titlecolour,'N',settings.gridcolour,'÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'U',settings.gridcolour,'÷',settings.titlecolour,'C',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷',settings.titlecolour,'E',settings.gridcolour,'÷',settings.titlecolour,'A',settings.gridcolour,'÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'R',settings.gridcolour,'÷--÷',settings.titlecolour,'W',settings.gridcolour,'÷',settings.titlecolour,'A',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷-- --- ----.')
  transmit(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.gridcolour,'!',settings.headingcolour,'cOMMENt',settings.radiationheadercolour,'\\/\\/[56C',settings.headingcolour,'hANDLE',settings.gridcolour,'¡',settings.headingcolour,'bBS',settings.gridcolour,'!')
  transmit(sendtext)
  StringF(sendtext,'\s\s',settings.gridcolour,'¦-------[1C-[2C-[2C-[1C---[1C-[1C---[1C---------------------[1C------------[1C------------÷---¦')
  transmit(sendtext)
  DisposeLink(sendtext)
ENDPROC

PROC header3(sysopmode)
  DEF sysopstr,sendtext
  sysopstr:=String(255)
  sendtext:=String(255)
  IF sysopmode
    StringF(sysopstr,'\s\s\s\s\s','[',settings.sysoptitlecolour,'sYSOP mODE',settings.gridcolour,']')
  ELSE
    sysopstr:='____________'
  ENDIF

  StringF(sendtext,'\s\s',settings.gridcolour,'   __________')
  transmit(sendtext);
  StringF(sendtext,'\s\s\s',' __\\        /_________________________________________',sysopstr,'____________')
  transmit(sendtext);
  transmit('|   \\      /                                                                  |')

  StringF(sendtext,'\s\s\s\s\s','|    \\    /    ',settings.titlecolour,'gLOBAL tHERMONUCLEAR wALL',settings.gridcolour,'                                      |')
  transmit(sendtext);
  transmit('|_____\\  /____________________________________________________________________|')
  transmit('       \\/')
  transmit(' _____________________________________________________________________________')
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s','|',settings.headingcolour,'cOMMENt[60ChANDLE',settings.gridcolour,'|',settings.headingcolour,'bBS',settings.gridcolour,'|')
  transmit(sendtext);
  transmit('|------- -  -  - --- - --- ----------------------- ---------- ------------^---|')
  DisposeLink(sysopstr)
  DisposeLink(sendtext)
ENDPROC

PROC header4(sysopmode)
  DEF sendtext
  sendtext:=String(255)

  StringF(sendtext,'\s\s\s','[9C',settings.radiationheadercolour,'__')
  transmit(sendtext)

  StringF(sendtext,'\s\s\s\s\s\s',settings.gridcolour,'.-[1C-[1C---',settings.radiationheadercolour,'_\\/_',settings.gridcolour,'--÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'G',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷',settings.titlecolour,'O',settings.gridcolour,'÷',settings.titlecolour,'B',settings.gridcolour,'÷',settings.titlecolour,'A',settings.gridcolour,'÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'L',settings.gridcolour,'÷--÷',settings.titlecolour,'T',settings.gridcolour,'÷',settings.titlecolour,'H',settings.gridcolour,'÷',settings.titlecolour,'E',settings.gridcolour,'÷',settings.titlecolour,'R',settings.gridcolour,'÷',settings.titlecolour,'M',settings.gridcolour,'÷',settings.titlecolour,'O',settings.gridcolour,'÷',settings.titlecolour,'N',settings.gridcolour,'÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'U',settings.gridcolour,'÷',settings.titlecolour,'C',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷',settings.titlecolour,'E',settings.gridcolour,'÷',settings.titlecolour,'A',settings.gridcolour,'÷')
  sendStr(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.titlecolour,'R',settings.gridcolour,'÷--÷',settings.titlecolour,'W',settings.gridcolour,'÷',settings.titlecolour,'A',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷',settings.titlecolour,'L',settings.gridcolour,'÷--÷',settings.titlecolour,'V',settings.gridcolour,'÷',settings.titlecolour,'1',settings.gridcolour,'÷',settings.titlecolour,'ß',settings.gridcolour,'÷--.')
  transmit(sendtext)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s\s\s',settings.gridcolour,'!',settings.headingcolour,'cOMMENt',settings.radiationheadercolour,'\\/\\/[56C',settings.headingcolour,'hANDLE',settings.gridcolour,'¡',settings.headingcolour,'bBS',settings.gridcolour,'!')
  transmit(sendtext)
  StringF(sendtext,'\s\s',settings.gridcolour,'¦-------[1C-[2C-[2C-[1C---[1C-[1C---[1C---------------------[1C------------[1C------------÷---¦')
  transmit(sendtext) 
  DisposeLink(sendtext)
ENDPROC

PROC footer1(sysopmode)
  DEF sendtext
  sendtext:=String(255)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s','`-----[',settings.authorcolour,'REbEL/QTX',settings.gridcolour,']----- - --    - -- --  -- - --         - -- [',settings.authorcolour,'oRdYNe/NVX',settings.gridcolour,']-----''[0m')
  transmit(sendtext)
  DisposeLink(sendtext)
ENDPROC

PROC footer2(sysopmode)
  DEF bbskeystr,sendtext
  bbskeystr:=String(255)
  sendtext:=String(255)

  IF sysopmode
    bbskeystr:='-----------------'
  ELSE
    StringF(bbskeystr,'\s\s\s\s\s','[',settings.showbbskeycolour,'K[1CsHOWS[1CbBS[1CkEY',settings.gridcolour,']')
  ENDIF

  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s',settings.gridcolour,'`----[',settings.authorcolour,'REbEL/QTX',settings.gridcolour,']-----[2C-[1C---[2C---',bbskeystr,'----[1C-[2C----[1C---[',settings.authorcolour,'oRdYNe',settings.gridcolour,']-[1C--''[0m')
  transmit(sendtext)
  DisposeLink(bbskeystr)
  DisposeLink(sendtext)
ENDPROC

PROC footer3(sysopmode)
  DEF sendtext
  sendtext:=String(255)
  StringF(sendtext,'\s\s\s\s\s\s\s\s\s','`-----[',settings.authorcolour,'REbEL/QTX',settings.gridcolour,']----- - --    - -- --  -- - --         - -- [',settings.authorcolour,'oRdYNe/NVX',settings.gridcolour,']-----''[0m')
  transmit(sendtext)
  DisposeLink(sendtext)
ENDPROC

PROC footer4(sysopmode)
  DEF bbskeystr,sendtext
  bbskeystr:=String(255)
  sendtext:=String(255)

  IF sysopmode
    bbskeystr:='-----------------'
  ELSE
    StringF(bbskeystr,'\s\s\s\s\s','[',settings.showbbskeycolour,'K[1CsHOWS[1CbBS[1CkEY',settings.gridcolour,']')
  ENDIF

  StringF(sendtext,'\s\s\s\s\s\s\s\s\s\s\s\s',settings.gridcolour,'`----[',settings.authorcolour,'REbEL/QTX',settings.gridcolour,']-----[2C-[1C---[2C---',bbskeystr,'----[1C-[2C----[1C---[',settings.authorcolour,'oRdYNe',settings.gridcolour,']-[1C--''[0m')
  transmit(sendtext)
  DisposeLink(bbskeystr)
  DisposeLink(sendtext)
ENDPROC

PROC displaywalldata(displaylines,displayids)
  DEF style, seperator1, seperator2, seperator3, item: PTR TO wallItem, lines: PTR TO LONG
  DEF comment,comment2,i: LONG,maxcommentlen :LONG, visibleLen: LONG, bbscode,displaystring

  style:=settings.style
  lines:=List(ListLen(wallItems))

  SELECT style
  CASE 3
    seperator1:='|'
    seperator2:='¦'
    seperator3:='¦'
  CASE 4
    seperator1:='|'
    seperator2:='¦'
    seperator3:='|'
  DEFAULT
    seperator1:='¦'
    seperator2:='¦'
    seperator3:='¦'
  ENDSELECT

  comment:=String(255)
  comment2:=String(255)
  bbscode:=String(3)
  FOR i:=0 TO ListLen(wallItems)-1
    item:=ListItem(wallItems,i)

    IF displayids = TRUE
      StringF(comment,'\d\s\s',item.id,': ',item.comment)
    ELSE
      StrCopy(comment,item.comment)
    ENDIF

    maxcommentlen:=72-EstrLen(item.username)
    StrCopy(comment2,comment,maxcommentlen)

    visibleLen:=strLenWithoutAnsiColour(comment2)
    IF maxcommentlen>visibleLen
      maxcommentlen:=maxcommentlen-visibleLen
      StringF(comment,'\s\d\s','[',maxcommentlen,'C')
      StrAdd(comment2,comment)
    ENDIF
    
    StrCopy(bbscode,item.bbsshortcode)
    IF EstrLen(bbscode)=0 THEN StrCopy(bbscode,'???')

    displaystring:=String(255)
    StringF(displaystring,'\s\s\s\s\s\s[0m\s\s\s\s[0m\s\s',settings.gridcolour,seperator1,settings.commentdefaultcolour,comment2,'-',item.username,settings.gridcolour,seperator2,settings.bbsshortcodecolour,bbscode,settings.gridcolour,seperator3)
    ListAdd(lines,[displaystring])
  ENDFOR

  displaystring:=String(255)
  FOR i:=(ListLen(lines)-displaylines) TO (ListLen(lines)-1)
    IF i<0
      StringF(displaystring,'\s\s\s\s\s\s',settings.gridcolour,seperator1,'[73C',seperator2,'[3C',seperator3)
    ELSE
      StrCopy(displaystring,ListItem(lines,i))
      DisposeLink(ListItem(lines,i))
    ENDIF
    transmit(displaystring)
  ENDFOR
  DisposeLink(displaystring)

  DisposeLink(comment)
  DisposeLink(comment2)
  DisposeLink(bbscode)
  DisposeLink(lines)
ENDPROC

PROC extractwalldataitem(lineid,datapoint, itemval)
    DEF idval,getItem: PTR TO wallItem,i
    idval:=Val(lineid)
    FOR i:=0 TO ListLen(wallItems)-1
      getItem:=ListItem(wallItems,i)
      IF getItem.id=idval
        SELECT datapoint
          CASE DP_USERNAME
            StrCopy(itemval,getItem.username)    
          CASE DP_SOURCE
            StrCopy(itemval,getItem.source)
          CASE DP_BBSSHORTCODE
            StrCopy(itemval,getItem.bbsshortcode)
          CASE DP_COMMENT
            StrCopy(itemval,getItem.comment) 
        ENDSELECT
        RETURN TRUE
      ENDIF
    ENDFOR
ENDPROC FALSE

PROC decodejson(jsondata)
  DEF item1: PTR TO wallItem
  DEF item2: PTR TO bbsItem
  DEF i : LONG
  DEF idfield,idvalue, position,newposition, tokenBuffer

  FOR i:=0 TO ListLen(wallItems)-1
    item1:=ListItem(wallItems,i)
    DisposeLink(item1.username)
    DisposeLink(item1.source)
    DisposeLink(item1.comment)
    DisposeLink(item1.bbsshortcode)
    END item1
  ENDFOR

  FOR i:=0 TO ListLen(bbsList)-1
    item2:=ListItem(bbsList,i)
    DisposeLink(item2.bbsName)
    DisposeLink(item2.bbsShortCode)
    END item2
  ENDFOR
  SetList(wallItems,0)
  SetList(bbsList,0)

/*
  test data

  StrCopy(jsondata,'[{"id":46,"userName":"Phantasm","source":"7HE EdGE","comment":"\\u001b&#91;32mI brought my bbs back from the dead&#44; and now i''m running","bbsshortcode":"EDG","createdDate":"2018-03-26T12:55:40.6566084+00:00"},')
  StrAdd(jsondata,'{"id":47,"userName":"Phantasm","source":"7HE EdGE","comment":"\\u001b&#91;32mtwo of them!!!","bbsshortcode":"EDG","createdDate":"2018-03-26T12:55:55.3597945+00:00"},')
  StrAdd(jsondata,'{"id":48,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;31mPush the button!","bbsshortcode":"MBS","createdDate":"2018-03-28T10:28:28.1687482+01:00"},')
  StrAdd(jsondata,'{"id":49,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;33mdon''t push the button!","bbsshortcode":"MBS","createdDate":"2018-03-28T11:18:05.9084478+01:00"},')
  StrAdd(jsondata,'{"id":50,"userName":"Necromaster","source":"7HE EdGE","comment":"\\u001b&#91;31mNecronomicon (CNet) necrobbs.strangled.net&#58;40","bbsshortcode":"EDG","createdDate":"2018-03-28T18:44:37.4107443+01:00"},')
  StrAdd(jsondata,'{"id":51,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;35mcement city is back.... i stole it from mdr","bbsshortcode":"MBS","createdDate":"2018-03-29T16:46:28.0666864+01:00"},')
  StrAdd(jsondata,'{"id":52,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;35mcement-city.bbs.io&#58;4000","bbsshortcode":"MBS","createdDate":"2018-03-29T16:47:05.5731977+01:00"},')
  StrAdd(jsondata,'{"id":52,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;35mcement-city.bbs.io&#58;4000","bbsshortcode":"MBS","createdDate":"2018-03-29T16:47:05.5731977+01:00"},')
  StrAdd(jsondata,'{"id":53,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;35msoon all the bbs will be mine...","bbsshortcode":"MBS","createdDate":"2018-03-29T16:47:32.1995394+01:00"},')
  StrAdd(jsondata,'{"id":54,"userName":"Anachronist","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;32mNew Amiga Door game at absinthe.darktech.org!","bbsshortcode":"MBS","createdDate":"2018-03-31T03:27:23.4324699+01:00"},')
  StrAdd(jsondata,'{"id":55,"userName":"somebody","source":"Phantasm","comment":"\\u001b&#91;37mwhy are you on this lame board - get off!","bbsshortcode":"???","createdDate":"2018-04-03T14:33:47.9982612+01:00"},')
  StrAdd(jsondata,'{"id":56,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;32mI farted and I can''t get up!","bbsshortcode":"MBS","createdDate":"2018-04-04T11:37:11.4941019+01:00"},')
  StrAdd(jsondata,'{"id":57,"userName":"Black Beard","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;31mKilling everyone off in Space Empire!","bbsshortcode":"MBS","createdDate":"2018-04-05T02:31:40.3668522+01:00"},')
  StrAdd(jsondata,'{"id":59,"userName":"Anachronist","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;36mWhat? This board is the jam!","bbsshortcode":"MBS","createdDate":"2018-04-07T04:27:17.1775461+01:00"},')
  StrAdd(jsondata,'{"id":60,"userName":"Kackboo","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;31m(_8(|)","bbsshortcode":"MBS","createdDate":"2018-04-08T02:56:40.6200683+01:00"},')
  StrAdd(jsondata,'{"id":61,"userName":"Black Beard","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;31mAll will fall before the Beard in Space Empire!","bbsshortcode":"MBS","createdDate":"2018-04-11T11:54:30.5565349+01:00"},')
  StrAdd(jsondata,'{"id":62,"userName":"somebody","source":"Phantasm","comment":"\\u001b&#91;33mtheedgebbs.dyndns.org&#58;1541","bbsshortcode":"PHA","createdDate":"2018-04-12T16:09:01.424157+01:00"},')
  StrAdd(jsondata,'{"id":63,"userName":"somebody","source":"\\u001b&#91;4;37;44mmASTURBAT10N sTAT10N\\u001b&#91;0m","comment":"\\u001b&#91;34mThe lameness from the edge crashed the wall.","bbsshortcode":"MBS","createdDate":"2018-04-13T00:45:53.233211+01:00"}]')
*/

  idfield:=String(255)
  idvalue:=String(255)

  position:=0
  WHILE ((jsondata[position]<>13) OR (jsondata[position+1]<>10) OR (jsondata[position+2]<>13) OR (jsondata[position+3]<>10)) AND (position<EstrLen(jsondata)-4)
    position++
  ENDWHILE
  position++
  position++
  position++
  position++
  IF position>=EstrLen(jsondata) THEN RETURN

  tokenBuffer:=String(255)

  newposition:=getToken(tokenBuffer,jsondata,position)
  IF (StrCmp(tokenBuffer,'[')=FALSE)
    /* the json should be an array so should be encased in [] */
    RETURN
  ENDIF

  position:=newposition
  newposition:=getToken(tokenBuffer,jsondata,position)

  WHILE (EstrLen(tokenBuffer)>0 AND StrCmp(tokenBuffer,']')=FALSE)
    IF (StrCmp(tokenBuffer,'{')=FALSE)
      /* the json should be an object so should be encased in {} for each row */
      RETURN
    ENDIF

    position:=newposition
    newposition:=getToken(tokenBuffer,jsondata,position)

    item1:=NEW item1
    item1.id:=1
    item1.username:=String(255)
    item1.source:=String(255)
    item1.comment:=String(255)
    item1.bbsshortcode:=String(3)

    WHILE ((EstrLen(tokenBuffer)>0) AND (StrCmp(tokenBuffer,'}')=FALSE) AND (ListLen(wallItems)<100))
      IF (EstrLen(tokenBuffer)=0) THEN RETURN /* no more data to parse */
      IF ((tokenBuffer[0]<>34) OR (tokenBuffer[EstrLen(tokenBuffer)-1]<>34)) THEN RETURN /* should be a quoted string for the field name*/
      replacestr(tokenBuffer,'"','')
      StrCopy(idfield,tokenBuffer)

      position:=newposition
      newposition:=getToken(tokenBuffer,jsondata,position)
      IF (EstrLen(tokenBuffer)=0) THEN RETURN /* no more data to parse */
      IF StrCmp(tokenBuffer,':')=FALSE THEN RETURN /* should be a colon following the field name*/

      position:=newposition
      newposition:=getToken(tokenBuffer,jsondata,position)
      IF (EstrLen(tokenBuffer)=0) THEN RETURN /* no more data to parse */

      IF tokenBuffer[0]=34 AND tokenBuffer[EstrLen(tokenBuffer)-1]=34
        /* if we found a quoted string then remove the quotes */
        replacestr(tokenBuffer,'"','')
      ENDIF
      StrCopy(idvalue,tokenBuffer)

      uncleanstr(idvalue)

      IF StrCmp(idfield,'id') 
        item1.id:=Val(idvalue)
      ELSEIF StrCmp(idfield,'userName')
        StrCopy(item1.username,idvalue)
      ELSEIF StrCmp(idfield,'source')
        StrCopy(item1.source,idvalue)
      ELSEIF StrCmp(idfield,'comment')
        StrCopy(item1.comment,idvalue)
      ELSEIF StrCmp(idfield,'bbsshortcode')
        StrCopy(item1.bbsshortcode,idvalue)
      ENDIF

      position:=newposition
      newposition:=getToken(tokenBuffer,jsondata,position)
      IF (EstrLen(tokenBuffer)=0) THEN RETURN /* no more data to parse */

      IF (StrCmp(tokenBuffer,','))
        position:=newposition
        newposition:=getToken(tokenBuffer,jsondata,position)
        IF (EstrLen(tokenBuffer)=0) THEN RETURN /* no more data to parse */
      ENDIF

    ENDWHILE
    ListAdd(wallItems,[item1])
    addBBS(item1.source, item1.bbsshortcode)

    position:=newposition
    newposition:=getToken(tokenBuffer,jsondata,position)
    IF (EstrLen(tokenBuffer)=0) THEN RETURN /* no more data to parse */
    IF StrCmp(tokenBuffer,',')
      position:=newposition
      newposition:=getToken(tokenBuffer,jsondata,position)
    ELSEIF StrCmp(tokenBuffer,']')=FALSE
      RETURN /* should either be a comma between items or a ] to finish anything else is invalid*/
    ENDIF
  ENDWHILE


/*
  [
    {
      "id":33,
      "userName":"somebody",
      "source":"Phantasm",
      "comment":"\u001b&#91;35mblack beard loves pd",
      "bbsshortcode":"PHA",
      "createdDate":"2018-03-13T06:28:26.7927199+00:00"
    },
    {
      "id":37,
      "userName":"Black Beard",
      "source":"\u001b&#91;4;37;44msTAT10N\u001b&#91;0m",
      "comment":"\u001b&#91;35mMStation is now live on the wall!",
      "bbsshortcode":"MBS",
      "createdDate":"2018-03-15T00:08:51.8340861+00:00"
    }
  ]
*/

ENDPROC

PROC addBBS(bbsname, bbscode)
  DEF found,i,search1,search2, founditem: PTR TO bbsItem
  DEF bbs: PTR TO bbsItem
  found:=FALSE
  FOR i:=0 TO ListLen(bbsList)-1
    founditem:=ListItem(bbsList,i)
    search1:=founditem.bbsName
    search2:=founditem.bbsShortCode
    IF ((StrCmp(bbsname,founditem.bbsName)) AND (StrCmp(bbscode,founditem.bbsShortCode))) THEN found:=TRUE
  ENDFOR
  
  IF (found=FALSE)
    bbs:=NEW bbs
    bbs.bbsName:=String(EstrLen(bbsname))
    bbs.bbsShortCode:=String(EstrLen(bbscode))
    StrCopy(bbs.bbsName,bbsname)
    StrCopy(bbs.bbsShortCode,bbscode)
    ListAdd(bbsList,[bbs])
   ENDIF

ENDPROC

PROC getToken(tokenBuffer,sourcedata,position)
  DEF tokenchar,lastwasslash,count
  StrCopy(tokenBuffer,'')

  tokenchar:=" "

  WHILE ((tokenchar=" ") OR (tokenchar="\n") OR (tokenchar="\t"))
    IF position>=EstrLen(sourcedata) THEN RETURN /* no more data */
    tokenchar:=sourcedata[position++]
  ENDWHILE

  IF tokenchar="["
      StrCopy(tokenBuffer,'[')
  ELSEIF tokenchar="]"
      StrCopy(tokenBuffer,']')
  ELSEIF tokenchar="{"
      StrCopy(tokenBuffer,'{')
  ELSEIF tokenchar="}"
      StrCopy(tokenBuffer,'}')
  ELSEIF tokenchar=","
      StrCopy(tokenBuffer,',')
  ELSEIF tokenchar=":"
      StrCopy(tokenBuffer,':')
  ELSEIF tokenchar=34
      StrCopy(tokenBuffer,'"')
      tokenchar:=0
      lastwasslash:=FALSE
      WHILE ((tokenchar<>34) OR (lastwasslash<>FALSE))
        lastwasslash:=tokenchar="\\"
        IF position>=EstrLen(sourcedata) THEN RETURN /* no more data */
        tokenchar:=sourcedata[position++]
        StrAdd(tokenBuffer,'#')
        tokenBuffer[EstrLen(tokenBuffer)-1]:=tokenchar
      ENDWHILE
  ELSEIF (((tokenchar>="0") AND (tokenchar<="9")) OR (tokenchar="-") OR (tokenchar="+") OR (tokenchar="."))
      count:=0
      WHILE (((tokenchar>="0") AND (tokenchar<="9")) OR (tokenchar=".") OR (count=0))
        IF position>=EstrLen(sourcedata) THEN RETURN /* no more data */
        StrAdd(tokenBuffer,'#')
        tokenBuffer[EstrLen(tokenBuffer)-1]:=tokenchar
        tokenchar:=sourcedata[position++]
        count++
      ENDWHILE
      position--
  ENDIF

/*  token types
    {
    }
    ,
    :
    "
    0-9*/
ENDPROC position

PROC httpRequest(requestdata:PTR TO CHAR, outTextBuffer)
  DEF i,s,n
  DEF sa=0:PTR TO sockaddr_in
  DEF addr: PTR TO LONG
  DEF hostEnt: PTR TO hostent
  DEF buf
  DEF tv:timeval

	buf:=String(BUFSIZE+4)
  NEW sa

	socketbase:=OpenLibrary('bsdsocket.library',2)
	IF (socketbase)
    SetErrnoPtr({errno},4)

    hostEnt:=GetHostByName(serverHost)
    addr:=hostEnt.h_addr_list[]
    addr:=addr[]

    sa.sin_len:=SIZEOF sockaddr_in
    sa.sin_family:=2
    sa.sin_port:=serverPort
    sa.sin_addr:=addr[]

    s:=Socket(2,1,0)
    IF (s>=0)
    
        IoctlSocket(s,FIONBIO,[1])
        setSingleFDS(s)
        timeoutError:=FALSE

        Connect(s,sa,SIZEOF sockaddr_in)
        
        tv.secs:=timeout
        tv.micro:=0
        
        n:=WaitSelect(s+1,NIL,fds,NIL,tv,NIL)
       
        IoctlSocket(s,FIONBIO,[0])

        IF (n<=0)
            timeoutError:=TRUE
            CloseSocket(s)
            RETURN
        ENDIF

        Send(s,requestdata,StrLen(requestdata),0)

        i:=0
        REPEAT
            i:=Recv(s,buf,BUFSIZE-1,0)
            IF (i>0) AND (outTextBuffer<>NIL)
              StrAdd(outTextBuffer,buf,i)
            ENDIF
        UNTIL i<=0
        CloseSocket(s)
    ENDIF
    CloseLibrary(socketbase)
	ENDIF
  DisposeLink(buf)
  END sa
ENDPROC

/* gets the json and puts it in OutTextBuffer */
PROC getwalljson(pagenum,maxitems, outTextBuffer)
  DEF getcmd[255]:STRING

  StringF(getcmd,'GET /GlobalWall/api/WallItems?itemCount=\d&pagenum=\d HTTP/1.0\b\nHost:\s\b\n\b\n',maxitems,pagenum,serverHost)
  httpRequest(getcmd,outTextBuffer)
ENDPROC 

PROC postcomment(username, bbsname, comment)
  DEF senddata
  DEF linedata

  senddata:=String(1100)

  cleanstr(username)
  cleanstr(bbsname)
  cleanstr(comment)

  linedata:=String(1000)
  StringF(linedata,'\s\s\s\s\s\s\s\s\s\b\n','{"userName": "',username,'","source": "',bbsname,'","comment": "',comment,'","bbsshortcode": "',settings.mybbsshortcode,'"}')

  StringF(senddata,'POST /GlobalWall/api/WallItems HTTP/1.0\b\nHost:\s\b\nContent-Type: application/json\b\nContent-Length: \d\b\n\b\n',serverHost,EstrLen(linedata))

  StrAdd(senddata,linedata)

  DisposeLink(linedata)

  httpRequest(senddata,NIL)
  DisposeLink(senddata)
ENDPROC

PROC putcomment(lineid, username, bbsname, comment, bbsshortcode)
  DEF senddata
  DEF linedata

  senddata:=String(1100)

  cleanstr(username)
  cleanstr(bbsname)
  cleanstr(comment)
  cleanstr(bbsshortcode)

  stringNullOrQuote(username)
  stringNullOrQuote(bbsname)
  stringNullOrQuote(comment)
  stringNullOrQuote(bbsshortcode)

  linedata:=String(1000)
  StringF(linedata,'\s\s\s\s\s\s\s\s\s\b\n','{"userName": ',username,',"source": ',bbsname,',"comment": ',comment,',"bbsshortcode": ',bbsshortcode,'}')

  StringF(senddata,'PUT /GlobalWall/api/WallItems/\s HTTP/1.0\b\nHost:\s\b\nContent-Type: application/json\b\nContent-Length: \d\b\n\b\n',lineid,serverHost,EstrLen(linedata))

  StrAdd(senddata,linedata)
  DisposeLink(linedata)

  httpRequest(senddata,NIL)
  DisposeLink(senddata)
ENDPROC

PROC deletecomment(lineid)
  DEF senddata
  senddata:=String(255)

  StringF(senddata,'DELETE /GlobalWall/api/WallItems/\s HTTP/1.0\b\nHost:\s\b\n\b\n',lineid,serverHost)
  httpRequest(senddata,NIL)

  DisposeLink(senddata)
ENDPROC

PROC cleanstr(sourcestring)
  replacestr(sourcestring,'[','&#91;')
  replacestr(sourcestring,']','&#93;')
  replacestr(sourcestring,'{','&#123;')
  replacestr(sourcestring,'}','&#125;')
  replacestr(sourcestring,',','&#44;')
  replacestr(sourcestring,':','&#58;')
  replacestr(sourcestring,'"','&#34;')
  replacestr(sourcestring,'\\','&#92;')
ENDPROC

PROC uncleanstr(sourcestring)
  replacestr(sourcestring,'&#91;','[')
  replacestr(sourcestring,'&#93;',']')
  replacestr(sourcestring,'&#123;','{')
  replacestr(sourcestring,'&#125;','}') 
  replacestr(sourcestring,'&#44;',',')
  replacestr(sourcestring,'&#58;',':')
  replacestr(sourcestring,'&#34;','"')
  replacestr(sourcestring,'&#92;','\\')
  replacestr(sourcestring,'\\u001b','')
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

PROC stringNullOrQuote(inputStr)
  DEF newstring
  newstring:=String(255)
  IF (EstrLen(inputStr)=0)
    StrCopy(newstring,'null')
  ELSE
    StrAdd(newstring,'''');
    StrAdd(newstring,inputStr);
    StrAdd(newstring,'''');
  ENDIF
  StrCopy(inputStr,newstring)
  DisposeLink(newstring)
ENDPROC

PROC sysopShortCodeUpdate()
  DEF newvalue
  transmit('')
  newvalue:=String(255)
  WHILE((EstrLen(newvalue)=0) OR (EstrLen(newvalue)>3))
    IF (StrCmp(settings.mybbsshortcode,'???'))
      query('Enter the 3 digit code to use for your bbs:',3,newvalue)
    ELSE
      sendStr('OldValue: ')
      transmit(settings.mybbsshortcode)
      transmit('')
      query('Enter new value:',3,newvalue)
    ENDIF
  ENDWHILE

  StrCopy(settings.mybbsshortcode,newvalue)
  saveSettings()
  DisposeLink(newvalue)
ENDPROC

PROC calculateDisplayLines()
  DEF displaylines
  DEF style
  style:=settings.style
  
  SELECT style
  CASE 1
      displaylines:=settings.screenheight - 9
  CASE 2
      displaylines:=settings.screenheight - 9
  CASE 3
      displaylines:=settings.screenheight - 14
  CASE 4
      displaylines:=settings.screenheight - 11
  DEFAULT
      displaylines:=settings.screenheight - 9
  ENDSELECT   
ENDPROC displaylines

PROC applyColours()
  DEF colourCode
  colourCode:=String(1)

  MidStr(colourCode,settings.coloursettings,0,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='4'
  settings.gridcolour:=String(5)
  encodeAnsiColour(colourCode,settings.gridcolour)

  MidStr(colourCode,settings.coloursettings,1,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='2'
  settings.titlecolour:=String(5)
  encodeAnsiColour(colourCode,settings.titlecolour)

  MidStr(colourCode,settings.coloursettings,2,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='6'
  settings.headingcolour:=String(5)
  encodeAnsiColour(colourCode,settings.headingcolour)

  MidStr(colourCode,settings.coloursettings,3,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='2'
  settings.authorcolour:=String(5)
  encodeAnsiColour(colourCode,settings.authorcolour)

  MidStr(colourCode,settings.coloursettings,4,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='6'
  settings.sysoptitlecolour:=String(5)
  encodeAnsiColour(colourCode,settings.sysoptitlecolour)

  MidStr(colourCode,settings.coloursettings,5,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='7'
  settings.sysopmenuitemscolour:=String(5)
  encodeAnsiColour(colourCode,settings.sysopmenuitemscolour)

  MidStr(colourCode,settings.coloursettings,6,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='1'
  settings.bbsshortcodecolour:=String(5)
  encodeAnsiColour(colourCode,settings.bbsshortcodecolour)

  MidStr(colourCode,settings.coloursettings,7,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='7'
  settings.commentdefaultcolour:=String(5)
  encodeAnsiColour(colourCode,settings.commentdefaultcolour)

  MidStr(colourCode,settings.coloursettings,8,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='7'
  settings.showbbskeycolour:=String(5)
  encodeAnsiColour(colourCode,settings.showbbskeycolour)

  MidStr(colourCode,settings.coloursettings,9,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='7'
  settings.bbskeymaincolour:=String(5)
  encodeAnsiColour(colourCode,settings.bbskeymaincolour)

  MidStr(colourCode,settings.coloursettings,10,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='2'
  settings.textcolour:=String(5)
  encodeAnsiColour(colourCode,settings.textcolour)

  MidStr(colourCode,settings.coloursettings,11,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='3'
  settings.textcolourYN:=String(5)
  encodeAnsiColour(colourCode,settings.textcolourYN)

  MidStr(colourCode,settings.coloursettings,12,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='6'
  settings.choosecolourheader:=String(5)
  encodeAnsiColour(colourCode,settings.choosecolourheader)

  MidStr(colourCode,settings.coloursettings,13,1)
  IF (EstrLen(colourCode) = 0) THEN colourCode[0]:='3'
  settings.radiationheadercolour:=String(5)
  encodeAnsiColour(colourCode,settings.radiationheadercolour)
  DisposeLink(colourCode)
ENDPROC

PROC encodeAnsiColour(colourValue, outColourAnsi)
  DEF colourNum
  
  colourNum:=Val(colourValue)
  colourNum:=colourNum+30
  StringF(outColourAnsi,'\s\d\s','[',colourNum,'m')
ENDPROC

PROC readSettings()
  DEF fh,textdata  
  textdata:=String(255)
  IF (fh:=Open('ENV:GWall.cfg',OLDFILE))<>NIL
    IF ReadStr(fh,textdata)<>-1 THEN settings.style:=Val(textdata)
    IF ReadStr(fh,textdata)<>-1 THEN StrCopy(settings.mybbsshortcode,textdata,3)
    IF ReadStr(fh,textdata)<>-1 THEN StrCopy(settings.coloursettings,textdata,14)
    Close(fh)
  ELSE
      saveSettings()
  ENDIF
  DisposeLink(textdata)
ENDPROC

PROC saveSettings()
  saveToFile('ENV:GWall.cfg')
  saveToFile('ENVARC:GWall.cfg')
ENDPROC

PROC saveToFile(filename)
  DEF fh,textdata
  textdata:=String(255)
    IF (fh:=Open(filename,NEWFILE))=NIL THEN Raise('OPEN')
    StringF(textdata,'\d\n',settings.style)
    Write(fh,textdata,EstrLen(textdata))
    StringF(textdata,'\s\n',settings.mybbsshortcode)
    Write(fh,textdata,EstrLen(textdata))
    StringF(textdata,'\s\n',settings.coloursettings)
    Write(fh,textdata,EstrLen(textdata))
    Close(fh)
  DisposeLink(textdata)
ENDPROC

PROC sendCLS()
  DEF temp
  temp:=String(1)
  temp[0]:=12
  sendStr(temp)
  DisposeLink(temp)
ENDPROC

/* trims (front and back) spaces from intput into output */
PROC trimStr(inputString,outputString)
  StrCopy(outputString,TrimStr(inputString))
  WHILE outputString[EstrLen(outputString)-1]=" " AND EstrLen(outputString)>0
      SetStr(outputString,EstrLen(outputString)-1)
  ENDWHILE
ENDPROC

PROC strLenWithoutAnsiColour(text)
  DEF len: LONG,i
  i:=0
  len:=0
  WHILE i<EstrLen(text)
    IF text[i]=27
      WHILE i<EstrLen(text) AND text[i]<>109
        i++
      ENDWHILE
      i++
    ELSE
      len++
      i++
    ENDIF  
  ENDWHILE
ENDPROC len

/* display text followed by a linefeed */
PROC transmit(textLine)
  IF aemode
    WriteStr(diface,textLine,LF)
  ELSE
    WriteF('\s\n',textLine)
  ENDIF
ENDPROC

/* display text with no linefeed */
PROC sendStr(textLine)
  IF aemode
    WriteStr(diface,textLine,0)
  ELSE
    WriteF('\s',textLine)
  ENDIF
ENDPROC


/* display a prompt and get a string from the input bufer and place it at inBuffer) */
PROC query(promptText, maxlen, inBuffer)
  DEF res

  IF aemode
    res:=Prompt(diface,maxlen,promptText)
		StrCopy(inBuffer,res,ALL)
  ELSE
    WriteF('\s ',promptText)
    ReadStr(stdin,inBuffer)
  ENDIF
ENDPROC

/* get a string from the input buffer and place it at inBuffer) */
PROC getChar(inBuffer, echoChar)
  DEF key
  IF aemode
    key:=HotKey(diface,'')
    IF key=-1
      StrCopy(inBuffer,'')
      RETURN FALSE
    ENDIF
    StrCopy(inBuffer,'#')
    inBuffer[0]:=key
    IF echoChar THEN transmit(inBuffer)
  ELSE
    ReadStr(stdin,inBuffer)
  ENDIF
  UpperStr(inBuffer)
ENDPROC TRUE

PROC getAEStringValue(valueKey, valueOutBuffer)
  IF aemode
    GetDT(diface,valueKey,0)        /* no string input here, so use 0 as last parameter */
    StrCopy(valueOutBuffer,strfield)
  ELSE
    SELECT valueKey
    CASE DT_NAME
      StrCopy(valueOutBuffer,'REbEL')
    CASE JH_BBSNAME
      StrCopy(valueOutBuffer,'Phantasm')
    DEFAULT
      StrCopy(valueOutBuffer,'')
    ENDSELECT
  ENDIF
ENDPROC

PROC getAEIntValue(valueKey)
  DEF result
  IF aemode
    GetDT(diface,valueKey,0)        /* no string input here, so use 0 as last parameter */
    result:=Val(strfield)
  ELSE
    SELECT valueKey
    CASE DT_LINELENGTH
     result:=29
    CASE DT_ACCESSLEVEL
     result:=255
    DEFAULT
     result:=0
    ENDSELECT
  ENDIF
ENDPROC result

errno: 
	LONG 0,0