/*
** bbslink door - requires /X 5.4 and amissl.library
** Amiga E version
*/

  MODULE 'AEDoor'                 /* Include libcalls & constants */
  MODULE  'dos/dos'

  MODULE  '*stringlist'

CONST TELNET_CONNECT=706
CONST TELNET_USERNAME_PROMPT=708
CONST TELNET_USERNAME=709
CONST TELNET_PASSWORD_PROMPT=710
CONST TELNET_PASSWORD=711

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

PROC main() HANDLE
  DEF diface=0
  DEF strfield=0
  DEF configNames:PTR TO stringlist
  DEF configValues:PTR TO stringlist
  DEF serverHost[255]:STRING
  DEF telnetPort=23
  DEF username[255]:STRING
  DEF usernamePrompt[255]:STRING
  DEF password[255]:STRING
  DEF passwordPrompt[255]:STRING
  
  StrCopy(serverHost,'')

  IF aedoorbase:=OpenLibrary('AEDoor.library',1)
    diface:=CreateComm(arg[])     /* Establish Link   */
    IF diface<>0
      strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
    ELSE
      Raise('unable to open aedoor.library')
    ENDIF
  ENDIF

  configNames:=NEW configNames.stringlist(2)
  configNames.add('SERVERHOST')
  configNames.add('TELNETPORT')
  configNames.add('USERNAMEPROMPT')
  configNames.add('PASSWORDPROMPT')
  configNames.add('USERNAME')
  configNames.add('PASSWORD')
    
  configValues:=NEW configValues.stringlist(2)
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')
  configValues.add('')

  parseConfigFile('PROGDIR:telnetdoor.cfg',configNames,configValues)
  parseConfigFile('telnetdoor.cfg',configNames,configValues)
  IF StrLen(configValues.item(0))>0 THEN StrCopy(serverHost,configValues.item(0))
  IF StrLen(configValues.item(1))>0 THEN telnetPort:=Val(configValues.item(1))
  IF StrLen(configValues.item(2))>0 THEN StrCopy(usernamePrompt,configValues.item(2))
  IF StrLen(configValues.item(3))>0 THEN StrCopy(passwordPrompt,configValues.item(3))
  IF StrLen(configValues.item(4))>0 THEN StrCopy(username,configValues.item(4))
  IF StrLen(configValues.item(5))>0 THEN StrCopy(password,configValues.item(5))

  IF StrLen(serverHost)=0 THEN Raise('serverhost entry missing from telnetdoor.cfg')

  IF StrCmp(username,'#')
    GetDT(diface,DT_NAME,0)        /* no string input here, so use 0 as last parameter */
    StrCopy(username,strfield)
  ENDIF


  SendStrCmd(diface,TELNET_USERNAME_PROMPT,usernamePrompt)
  SendStrCmd(diface,TELNET_USERNAME,username)
  SendStrCmd(diface,TELNET_PASSWORD_PROMPT,passwordPrompt)
  SendStrCmd(diface,TELNET_PASSWORD,password)

  SendStrDataCmd(diface,TELNET_CONNECT,serverHost,telnetPort)

EXCEPT DO
  IF exception 
    IF diface THEN WriteStr(diface,exception,LF) ELSE WriteF('\s\n',exception)
  ENDIF
  
  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC

