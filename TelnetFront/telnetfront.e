/*
** TELNET FRONTEND
** Amiga E version
*/

OPT REG=5

MODULE 'AEDoor'                 /* Include libcalls & constants */
MODULE 'dos/dos'

  DEF diface,strfield:LONG
  DEF aemode

PROC centre(outString,width)
  DEF tempStr[255]:STRING
  
  StrCopy(tempStr,outString,width)
  
  REPEAT
    IF EstrLen(tempStr)<width THEN StringF(tempStr,' \s',tempStr)
    IF EstrLen(tempStr)<width THEN StrAdd(tempStr,' ')
  UNTIL EstrLen(tempStr)=width
  
  StrCopy(outString,tempStr)
ENDPROC

PROC transmit(textLine)
  IF aemode
    WriteStr(diface,textLine,LF)
  ELSE
    WriteF('\s\n',textLine)
  ENDIF
ENDPROC

PROC getAEStringValue(valueKey, valueOutBuffer)
  IF aemode
    GetDT(diface,valueKey,0)        /* no string input here, so use 0 as last parameter */
    StrCopy(valueOutBuffer,strfield)
  ENDIF
ENDPROC

PROC main()
  DEF ipAddr[20]:STRING
  DEF hostName[100]:STRING
  DEF fname[255]:STRING
  DEF fh1,fh2,fh3
  
  DEF node
  
  DEF user[232]:ARRAY OF CHAR
  DEF stat[32]:ARRAY OF CHAR
  DEF action[2]:STRING
  DEF nullStr[1]:STRING
  DEF nameStr[30]:STRING
  DEF locStr[30]:STRING
  DEF actId
  
  DEF i
  
  DEF tempStr[255]:STRING
  
  IF aedoorbase:=OpenLibrary('AEDoor.library',1)
    diface:=CreateComm(arg[])     /* Establish Link   */
    IF diface<>0 THEN aemode:=TRUE
    strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
  ENDIF

  node:=Val(arg)

  getAEStringValue(701,ipAddr)
  IF EstrLen(ipAddr)>0
    StringF(fname,'ENV:NODE\dIP',node)
    fh1:=Open(fname,MODE_NEWFILE)
    Write(fh1,ipAddr,StrLen(ipAddr))
    Close(fh1)
  ENDIF

  getAEStringValue(700,hostName)
  IF EstrLen(hostName)>0
    StringF(fname,'ENV:NODE\dHOST',node)
    fh1:=Open(fname,MODE_NEWFILE)
    Write(fh1,ipAddr,StrLen(ipAddr))
    Close(fh1)
  ENDIF

  transmit('     [34m.------------------------------------------------------------------.')
  transmit('     [34m|[36mNode[34m| [36mHandle/Username [34m| [36mLocation/Group        [34m| [36mUser Ip Address   [34m|')
  transmit('     [34m|----+-----------------+-----------------------+-------------------|')

  FOR i:=0 TO 31

    StrCopy(nameStr,'')
    StrCopy(locStr,'')
    StrCopy(ipAddr,'')
    StrCopy(action,'')
    
    StringF(fname,'BBS:node\d.user',i)
    fh1:=Open(fname,MODE_OLDFILE)
    StringF(fname,'ENV:STATS@\d',i)
    fh2:=Open(fname,MODE_OLDFILE)
    StringF(fname,'env:node\dip',i)
    fh3:=Open(fname,MODE_OLDFILE)
    
    /* read user data if nodex.user is present */
    IF (fh1>=0)
      Read(fh1,user,232)      
      StrCopy(nameStr,user)
      StrCopy(locStr,user+40,21)
      Close(fh1)
    ENDIF
    
    /* Read current action if @stats file is present */
    IF (fh2>=0)
      Read(fh2,stat,38)
      StrCopy(action,stat+36,2)
      Close(fh2)
    ENDIF
    
    /* Read ip address of user if nodexip file is present */
    IF (fh3>=0)
      ReadStr(fh3,tempStr)
      StringF(ipAddr,' \s ',tempStr)
      Close(fh3)
    ELSE
      StrCopy(ipAddr,'  NOT AVAILABLE  ')
    ENDIF
        
    /* Node is awaiting connect */
    actId:=Val(action)
    IF (actId=22)
      StrCopy(nameStr,'Awaiting Call')
      StrCopy(locStr,'')
      StrCopy(ipAddr,'')
    ENDIF
    
    /* Node is inactive */
    IF (actId=24)
      StrCopy(nameStr,'Inactive')
      StrCopy(locStr,'')
      StrCopy(ipAddr,'')
    ENDIF
    
    /* Node is suspended */
    IF (actId=26)
      StrCopy(nameStr,'Suspended')
      StrCopy(locStr,'')
      StrCopy(ipAddr,'')
    ENDIF
    
    /* If no stats@ file then node hasnt been initialised */
    IF(fh2<=0)
      StrCopy(nameStr,'Inactive')
      StrCopy(locStr,'')
      StrCopy(ipAddr,'')
    ENDIF
    
    /* User is in the process of connecting */
    IF (i=node)
      StrCopy(nameStr,'Connecting')
      StrCopy(locStr,'')
    ENDIF

    centre(locStr,21)
    centre(ipAddr,17)

    IF fh2>0
      StringF(tempStr,' [34m    | [32m\z\d[2] [34m| [37m\l\s[14]  [34m| [37m\s[21] [34m|[36m \s[17] [34m|',i,nameStr,locStr,ipAddr)
      transmit(tempStr)
    ENDIF
    
  ENDFOR


  transmit('    [34m `-----·-----------------·-----------------------·------------------''')

  IF (EstrLen(ipAddr)>0)
    StringF(tempStr,' [34m    | [32mLogin Established from Host :  [37m\l\s[26]        [34m|',hostName)
    transmit(tempStr)
  ELSE
    transmit(' [34m    | [32mLogin Established from Host :     [37m N O T  A V A I L A B L E      [34m|')
  ENDIF

  transmit(' [34m    `------------------------------------------------------------------''')
  transmit('[0m')


  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)

ENDPROC