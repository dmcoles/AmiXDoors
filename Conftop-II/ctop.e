/*
** conftop door for /X5
*/

->special users
->playpens
->shared data
->bring over conftop.data 

OPT LARGE

  MODULE 'AEDoor'                 /* Include libcalls & constants */
  MODULE 'icon'
  MODULE 'workbench/workbench'
  MODULE 'dos/dos'
  MODULE 'dos/datetime'

#ifndef EVO_3_4_0
  FATAL 'This should only be compiled with E-VO Amiga E Compiler'
#endif

ENUM EXCEPT_CONF_CTOP_DB=1,ERR_NOICON=2

CONST MSGBASE_LOC=604
CONST RESULT_NOT_TESTED=2

OBJECT user
  userName[32]:ARRAY OF CHAR
  location[30]:ARRAY OF CHAR
  uploadedBytesBCD[8]:ARRAY OF CHAR
  uploadedFiles: LONG
ENDOBJECT

OBJECT stdlist
  PRIVATE items:PTR TO LONG
  PRIVATE initialMax:LONG
ENDOBJECT

OBJECT mailHeader
  status: CHAR
  msgNumb: LONG
  toName[31]: ARRAY OF CHAR
  fromName[31]: ARRAY OF CHAR
  subject[31]: ARRAY OF CHAR
  msgDate: LONG
  recv: LONG
  pad: CHAR
ENDOBJECT

OBJECT mailStat
  lowestKey : LONG
  highMsgNum : LONG
  lowestNotDel : LONG
  pad[6]:ARRAY OF CHAR
ENDOBJECT

DEF diface,strfield:LONG
DEF confName[255]:STRING
DEF days=-1
DEF rows=10
DEF skipEmpty=FALSE
DEF minLimit=0
DEF showResetDate=FALSE
DEF node=0

DEF cfgFileName[255]:STRING
DEF dataFileName[255]:STRING

DEF userName[255]:STRING
DEF userLocation[255]:STRING
DEF uploadFile[255]:STRING

DEF bbsLoc[255]:STRING
DEF confLocation[255]:STRING
DEF msgBaseLocation[255]:STRING
DEF mailUser[255]:STRING
DEF bullFile[255]:STRING
DEF nextDoor[255]:STRING
DEF fromUser[255]:STRING
DEF subject[255]:STRING

DEF topUpName[255]:STRING
DEF topUpBytes[8]:ARRAY OF CHAR
DEF topUpFiles
DEF periodUpName[255]:STRING
DEF periodUpBytes[8]:ARRAY OF CHAR
DEF periodUpFiles

DEF userList=NIL:PTR TO stdlist
DEF totalFiles
DEF totalBytesBCD[8]:ARRAY OF CHAR
DEF outputStart,outputReset

DEF outputDebug=FALSE

PROC end() OF stdlist				-> destructor
  DisposeLink(self.items)
ENDPROC

PROC stdlist(maxSize=-1) OF stdlist  ->constructor
  IF maxSize=-1 THEN maxSize:=100
  self.initialMax:=maxSize
  self.items:=List(maxSize)
ENDPROC

PROC item(n) OF stdlist
  ->IF (n<0) OR (n>=ListLen(self.items)) THEN WriteF('stdlist index error \d',n)
ENDPROC self.items[n]

PROC clear() OF stdlist
  IF ListMax(self.items)>self.initialMax
    DisposeLink(self.items)
    self.items:=List(self.initialMax)
  ELSE  
    SetList(self.items,0)
  ENDIF
ENDPROC

PROC expand() OF stdlist
  DEF old,len,inc
  old:=self.items
  len:=ListLen(old)
  inc:=Shr(len,2)
  IF inc<5 THEN inc:=5
  len:=len+inc
  self.items:=List(len)
  ListAdd(self.items,old)
  DisposeLink(old)
ENDPROC len

PROC add(v:LONG) OF stdlist
  DEF c
  
  c:=ListLen(self.items)
  IF c=ListMax(self.items) THEN self.expand()
  
  ListAdd(self.items,[0])
  self.items[c]:=v
ENDPROC c

PROC setItem(n,v) OF stdlist  
  WHILE n>=ListLen(self.items) DO self.add(0)
  self.items[n]:=v
ENDPROC

PROC remove(n) OF stdlist
  DEF i,t
  t:=ListLen(self.items)
  FOR i:=n TO t-2
    self.items[i]:=self.items[i+1]
  ENDFOR
  SetList(self.items,t-1)
ENDPROC

PROC setSize(n) OF stdlist
  SetList(self.items,n)
ENDPROC

PROC count() OF stdlist IS ListLen(self.items)

PROC maxSize() OF stdlist IS ListMax(self.items)

PROC sort(compareProc,l,r) OF stdlist
DEF i,j,x,t:PTR TO user
  i:=l; j:=r; x:=self.items[Shr(l+r,1)]
  REPEAT
    WHILE compareProc(self.items[i],x)<0 DO i++
    WHILE compareProc(self.items[j],x)>0 DO j--
    IF i<=j
      t:=self.items[i]; self.items[i]:=self.items[j]; self.items[j]:=t
      i++; j--
    ENDIF
  UNTIL i>j
  IF l<j THEN self.sort(compareProc,l,j)
  IF i<r THEN self.sort(compareProc,i,r)
ENDPROC

->returns system date
PROC getSystemDate()
  DEF currDate: datestamp
  DEF startds:PTR TO datestamp

  startds:=DateStamp(currDate)
ENDPROC startds.days,startds.minute

->returns system time converted to c time format
PROC getSystemTime()
  DEF currDate: datestamp
  DEF startds:PTR TO datestamp

  startds:=DateStamp(currDate)
  ->2922 days between 1/1/70 and 1/1/78

ENDPROC (Mul(Mul(startds.days+2922,1440),60)+(startds.minute*60)+(startds.tick/50))+21600,Mod(startds.tick,50)


PROC itemCompare(user1:PTR TO user, user2:PTR TO user)
  RETURN bcdComp(user1.uploadedBytesBCD,user2.uploadedBytesBCD)
ENDPROC 0

PROC addBCD2(bcdTotal:PTR TO CHAR, bcdValToAdd: PTR TO CHAR)
  MOVE.L bcdValToAdd,A0
  LEA 8(A0),A0
  MOVE.L bcdTotal,A1
  LEA 8(A1),A1

  SUB.L D0,D0        ->clear X flag

  ABCD -(A0),-(A1)
  ABCD -(A0),-(A1)
  ABCD -(A0),-(A1)
  ABCD -(A0),-(A1)
  ABCD -(A0),-(A1)
  ABCD -(A0),-(A1)
  ABCD -(A0),-(A1)
  ABCD -(A0),-(A1)
ENDPROC

PROC formatBCD(valArrayBCD:PTR TO CHAR, outStr)
  DEF tempStr[2]:STRING
  DEF i,n,start=FALSE

  StrCopy(outStr,'')
  FOR i:=0 TO 7
    n:=valArrayBCD[i]
    IF (n<>0) OR (start) OR (i=7)
      IF (start) OR (n>=$10)
        StringF(tempStr,'\d\d',Shr(n AND $F0,4),n AND $F)
      ELSE
        StringF(tempStr,'\d',n AND $F)
      ENDIF
      StrAdd(outStr,tempStr)
      start:=TRUE
    ENDIF
  ENDFOR
ENDPROC

PROC bcdCopy(dest:PTR TO CHAR, src:PTR TO CHAR)
  DEF n
  FOR n:=0 TO 7 DO dest[n]:=src[n]
ENDPROC

PROC convertToBCD(invalue,outArray: PTR TO CHAR)
  DEF shift,i

  FOR i:=0 TO 7
    outArray[i]:=0
  ENDFOR

  FOR shift:=0 TO 31
    FOR i:=0 TO 7
      IF (outArray[i] AND $F0)>=$50 THEN outArray[i]:=outArray[i]+$30
      IF (outArray[i] AND $F)>=$5 THEN outArray[i]:=outArray[i]+$3
    ENDFOR
    FOR i:=0 TO 6
      outArray[i]:=Shl(outArray[i],1)
      IF outArray[i+1] AND $80
        outArray[i]:=outArray[i] OR 1
      ENDIF
    ENDFOR
    outArray[7]:=Shl(outArray[7],1)
    IF (invalue AND $80000000)
      outArray[7]:=outArray[7] OR 1
    ENDIF
    invalue:=Shl(invalue,1)
  ENDFOR
ENDPROC

PROC bcdComp(v1:PTR TO CHAR,v2:PTR TO CHAR)
  DEF i
  FOR i:=0 TO 7
    IF v1[i]>v2[i]
      RETURN -1
    ELSEIF v1[i]<v2[i]
      RETURN 1
    ENDIF
  ENDFOR
ENDPROC 0

PROC dow(v)
  v:=Mod(v,7)
  IF v=0 THEN RETURN 7 ELSE RETURN v
ENDPROC

PROC dom(v)
  DEF testDateStr[20]:STRING
  formatDate(v,testDateStr)     
ENDPROC Val(testDateStr+8)

PROC formatseparators(separator:PTR TO CHAR,outputStr:PTR TO CHAR)
  DEF tempStr[255]:STRING
  DEF i,l
  StrCopy(tempStr,'')
  l:=StrLen(outputStr)
  FOR i:=1 TO l
    StrAdd(tempStr,outputStr+l-i,1)
    IF (Mod(i,3)=0) AND (i<>l) THEN StrAdd(tempStr,separator)
  ENDFOR
  StrCopy(outputStr,'')
  l:=StrLen(tempStr)
  FOR i:=1 TO l
    StrAdd(outputStr,tempStr+l-i,1)
  ENDFOR
ENDPROC

PROC formatDate(dateVal,outDateStr)
  DEF d : PTR TO datestamp
  DEF dt : datetime
  DEF datestr[10]:STRING
  DEF daystr[10]:STRING
  DEF timestr[10]:STRING

  d:=dt.stamp
  d.tick:=0
  d.days:=dateVal
  d.minute:=0

  dt.format:=FORMAT_DOS
  dt.flags:=0
  dt.strday:=daystr
  dt.strdate:=datestr
  dt.strtime:=timestr

  IF DateToStr(dt)
    StringF(outDateStr,'\s[3] \s[3] \s[2]',daystr,datestr+3,datestr)
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC formatDateTime(dateVal,timeVal,outDateStr)
  DEF d : PTR TO datestamp
  DEF dt : datetime
  DEF datestr[10]:STRING
  DEF daystr[10]:STRING
  DEF timestr[10]:STRING

  d:=dt.stamp
  d.tick:=0
  d.days:=dateVal
  d.minute:=timeVal

  dt.format:=FORMAT_DOS
  dt.flags:=0
  dt.strday:=daystr
  dt.strdate:=datestr
  dt.strtime:=timestr

  IF DateToStr(dt)
    StringF(outDateStr,'\s[3] \s[3] \s[2] \s',daystr,datestr+3,datestr,timestr)
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC getAEStringValue(valueKey, valueOutBuffer)
  IF (diface<>0) AND (strfield<>0)
    GetDT(diface,valueKey,0)        /* no string input here, so use 0 as last parameter */
    StrCopy(valueOutBuffer,strfield)
  ENDIF
ENDPROC

PROC setAEIntValue(valueKey,newVal)
  IF (diface<>0)
    SendDataCmd(diface,valueKey,newVal)
  ENDIF
ENDPROC

PROC getAEIntValue(valueKey)
  DEF result
  IF (diface<>0) AND (strfield<>0)
    GetDT(diface,valueKey,0)        /* no string input here, so use 0 as last parameter */
    result:=Val(strfield)
  ENDIF
ENDPROC result

/* display text followed by a linefeed */
PROC transmit(textLine)
  IF diface<>0 THEN WriteStr(diface,textLine,LF)
  ->WriteF('\s\n',textLine)
ENDPROC

PROC writeLine(fh,textLine)
  IF fh<>0
    Write(fh,textLine,StrLen(textLine))
    Write(fh,'\n',1)
  ELSE
    transmit(textLine)
  ENDIF
ENDPROC

PROC header(cls=FALSE)
  IF cls
    transmit('[4;33m                                                                             [0m')
  ELSE
    transmit('[4;33m                                                                             [0m')
  ENDIF
  transmit('[4;33;44mConference Top Uploaders (Conftop-II) Coded by REbEL/QTX                     [0m')
  transmit('')
ENDPROC

PROC readToolType(tooltypes,key,outValue,trim=TRUE)
  DEF s
  IF (s:=FindToolType(tooltypes,key)) 
    IF trim THEN s:=TrimStr(s)
    StrCopy(outValue,s,ALL)
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC checkToolTypeExists(tooltypes,key) IS FindToolType(tooltypes,key)

PROC readConfig(configFile:PTR TO CHAR)
  DEF do=NIL:PTR TO diskobject
  DEF tempStr[255]:STRING
  do:=GetDiskObject(configFile)
  IF do<>NIL
    readToolType(do.tooltypes,'DAYS',tempStr)
    UpperStr(tempStr)
    IF StrCmp(tempStr,'WEEKLY')
      days:=-1
    ELSEIF StrCmp(tempStr,'MONTHLY')
      days:=-2
    ELSE
      days:=Val(tempStr)
      IF days<1 THEN days:=-1
    ENDIF
    
    IF readToolType(do.tooltypes,'ROWS',tempStr)
      rows:=Val(tempStr)
      IF rows<1 THEN rows:=10
    ENDIF

    IF readToolType(do.tooltypes,'DEBUG',tempStr)
      outputDebug:=TRUE
    ENDIF

    readToolType(do.tooltypes,'MAILUSER',mailUser)
    readToolType(do.tooltypes,'BULLFILE',bullFile)
    readToolType(do.tooltypes,'NEXTDOOR',nextDoor)
    readToolType(do.tooltypes,'CONFNAME',confName)
    readToolType(do.tooltypes,'FROMUSER',fromUser)
    readToolType(do.tooltypes,'CFGFILE',cfgFileName)
    readToolType(do.tooltypes,'DATAFILE',dataFileName)
    readToolType(do.tooltypes,'SUBJECT',subject,FALSE)
    
    RightStr(tempStr,cfgFileName,5)
    UpperStr(tempStr)
    IF StrCmp(tempStr,'.INFO')
      SetStr(cfgFileName,EstrLen(cfgFileName)-5)
    ENDIF
    
    IF readToolType(do.tooltypes,'MIN_LIMIT',tempStr)
      minLimit:=Val(tempStr)
      IF minLimit<1 THEN minLimit:=0
    ENDIF

    IF checkToolTypeExists(do.tooltypes,'SKIP_EMPTY_LINES') THEN skipEmpty:=TRUE
    IF checkToolTypeExists(do.tooltypes,'SHOW_RESETDATE') THEN showResetDate:=TRUE

    FreeDiskObject(do)
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC checkPriv(filename:PTR TO CHAR)
  DEF tempName[255]:STRING
  DEF tempStr[255]:STRING
  DEF fh
  DEF priv=FALSE

  StringF(tempName,'\sNode\d/Work/\s',bbsLoc,node,filename)
  fh:=Open(tempName,MODE_OLDFILE)
  IF fh<>0
    ReadStr(fh,tempStr)
    IF ((EstrLen(tempStr)>0) AND (tempStr[0]="/")) THEN priv:=TRUE
    Close(fh)
  ENDIF
ENDPROC priv

PROC doDbReset(dbFilename,initialCreate=FALSE)
  DEF startDate=0,resetDate=0,fh
  DEF user:PTR TO user
  DEF oldDbFile[255]:STRING
  DEF topName[28]:ARRAY OF CHAR
  DEF tmp

  IF initialCreate
    StrCopy(oldDbFile,dbFilename)
    SetStr(oldDbFile,PathPart(oldDbFile)-oldDbFile+1)
    StrAdd(oldDbFile,'conftop.data')
    
    fh:=Open(oldDbFile,MODE_OLDFILE)
    IF fh<>0
      Seek(fh,214,OFFSET_BEGINNING)
      Read(fh,topName,40)
      StrCopy(topUpName,topName,40)
      Read(fh,{tmp},4)
      convertToBCD(tmp,topUpBytes)
      Read(fh,{topUpFiles},4)
      Close(fh)
    ENDIF
  ENDIF

  buildOutput()

  IF userList.count()>0
    user:=userList.item(0)
    StrCopy(periodUpName,user.userName)
    periodUpFiles:=user.uploadedFiles
    bcdCopy(periodUpBytes,user.uploadedBytesBCD)
    
    IF bcdComp(topUpBytes,user.uploadedBytesBCD)>0
      StrCopy(topUpName,user.userName)
      topUpFiles:=user.uploadedFiles
      bcdCopy(topUpBytes,user.uploadedBytesBCD)
    ENDIF
  ELSE
    StrCopy(periodUpName,'NONE')
    periodUpFiles:=0
    convertToBCD(0,periodUpBytes)
  ENDIF
  
  sendEall()
  IF (EstrLen(bullFile)>0) AND (EstrLen(uploadFile)=0)
    writeOutput(TRUE,TRUE)
  ENDIF  
  
  fh:=Open(dbFilename,MODE_OLDFILE)
  IF fh<>0
    Read(fh,{resetDate},4)
    Close(fh)
    REPEAT
      IF days=-1
        startDate:=resetDate
        resetDate:=resetDate+7
      ELSEIF days=-2
        startDate:=resetDate
        resetDate++
        WHILE dom(resetDate)<>1 DO resetDate++
      ELSE
        startDate:=resetDate
        resetDate:=resetDate+days
      ENDIF
    UNTIL (resetDate>getSystemDate())
  ELSE
    IF days=-1
      resetDate:=getSystemDate()+1
      WHILE dow(resetDate)<>1 DO resetDate++
      startDate:=resetDate-7
    ELSEIF days=-2
      resetDate:=getSystemDate()+1
      WHILE dom(resetDate)<>1 DO resetDate++
      startDate:=getSystemDate()
      WHILE dom(startDate)<>1 DO startDate--
    ELSE
      resetDate:=getSystemDate()+days
      startDate:=resetDate-days
    ENDIF
  ENDIF
  
  fh:=Open(dbFilename,MODE_NEWFILE)
  IF fh<>0
    Write(fh,{resetDate},4)
    Write(fh,{startDate},4)
    Write(fh,topUpName,32)
    Write(fh,topUpBytes,8)
    Write(fh,{topUpFiles},4)
    Write(fh,periodUpName,32)
    Write(fh,periodUpBytes,8)
    Write(fh,{periodUpFiles},4)
    Close(fh)
  ENDIF
ENDPROC

PROC checkForReset()
  DEF fh
  DEF confCtopDb[255]:STRING
  DEF sysdate=0,sysdate2=0

  StringF(confCtopDb,'\s\s',confLocation,dataFileName)
  writeDebugLog('conftop checking for reset')
  writeDebugLog(confCtopDb)

  fh:=Open(confCtopDb,MODE_OLDFILE)
  IF fh<>0
    sysdate:=getSystemDate()
    Read(fh,{sysdate2},4)
    Close(fh)
    IF sysdate>=sysdate2
      transmit('Resetting Conference Top Uploaders...')
      writeDebugLog('Resetting top uploaders')
      doDbReset(confCtopDb)
    ENDIF   
  ELSE
    transmit('Creating datafile...')
    writeDebugLog('Creating datafile')
    doDbReset(confCtopDb,TRUE)
  ENDIF
ENDPROC

PROC updateStats(filename:PTR TO CHAR, userName, userLocation)
  DEF fh
  DEF fsize
  DEF confCtopDb[255]:STRING
  DEF tempName[255]:STRING
  DEF tempStr[255]:STRING
 
  StringF(tempName,'\sNode\d/Playpen/\s',bbsLoc,node,filename)
  
  fsize:=FileLength(tempName)
  IF fsize<0 THEN RETURN
  
  StringF(tempStr,'Updating stats: \s (\d bytes)',filename,fsize)
  transmit(tempStr)

  StringF(confCtopDb,'\s\s',confLocation,dataFileName)
  
  fh:=Open(confCtopDb,MODE_READWRITE)
  IF fh<>0 
    Seek(fh,0,OFFSET_END)
    Write(fh,userName,32)
    Write(fh,userLocation,30)
    Write(fh,{fsize},4)
    Close(fh)
  ELSE
    Throw(EXCEPT_CONF_CTOP_DB,0)
  ENDIF
ENDPROC

PROC lockMsgBase()
  DEF lock, loop, error
  DEF tempstr[255]:STRING

  loop:=0
  StringF(tempstr,'\sMailLock',msgBaseLocation)
  REPEAT
    lock:=Lock(tempstr,ACCESS_WRITE)
    IF(lock=0)
      error:=IoErr()
      IF(error=205) THEN createFile(tempstr)
      Delay(120)
    ENDIF
  UNTIL((lock<>0) OR (loop++>=30))
ENDPROC lock

PROC createFile(filename)
  DEF fh
  fh:=Open(filename,MODE_NEWFILE)
  Close(fh)
ENDPROC

PROC saveStatOnly(mailStat: PTR TO mailStat)
  DEF error
  DEF string[255]:STRING
  DEF fd

  StringF(string,'\s\s',msgBaseLocation,'MailStats')
  fd:=Open(string,MODE_READWRITE)
  IF(fd=0)
    RETURN FALSE
  ENDIF

  error:=Write(fd,mailStat,SIZEOF mailStat)
  IF(error<>SIZEOF mailStat)
    Close(fd)
    RETURN FALSE
  ENDIF
  Close(fd)
ENDPROC TRUE

PROC saveMessageHeader(mailStat:PTR TO mailStat, mh:PTR TO mailHeader)
  DEF error,size
  DEF gfh
  DEF filename[255]:STRING
  DEF tempstr[255]:STRING

  StringF(filename,'\s\s',msgBaseLocation,'HeaderFile')

  gfh:=Open(filename,MODE_READWRITE)
  IF(gfh=0)
    gfh:=Open(filename,MODE_NEWFILE)
    IF(gfh=0)
      writeDebugLog('unable to open header file')
      RETURN FALSE
    ENDIF
  ENDIF

  Seek(gfh,0,OFFSET_END)

  size:=SIZEOF mailHeader

  mh.pad:=0
  error:=Write(gfh,mh,size)

  StringF(tempstr,'message header status: \c',mh.status)
  writeDebugLog(tempstr)
  StringF(tempstr,'message header msgnum: \d',mh.msgNumb)
  writeDebugLog(tempstr)
  StringF(tempstr,'message header toname: \s',mh.toName)
  writeDebugLog(tempstr)
  StringF(tempstr,'message header fromname: \s',mh.fromName)
  writeDebugLog(tempstr)
  StringF(tempstr,'message header subject: \s',mh.subject)
  writeDebugLog(tempstr)
  StringF(tempstr,'message header msgdate: \d',mh.msgDate)
  writeDebugLog(tempstr)
  StringF(tempstr,'message header recv: \d',mh.recv)
  writeDebugLog(tempstr)
  StringF(tempstr,'message header pad: \d',mh.pad)
  writeDebugLog(tempstr)

  Close(gfh)
  IF(error<>size)
    writeDebugLog('Error writing to header file')
    RETURN FALSE
  ENDIF

  mailStat.highMsgNum:=mailStat.highMsgNum+1
  IF(mailStat.highMsgNum=2) THEN mailStat.lowestNotDel:=1
ENDPROC saveStatOnly(mailStat)

PROC readMailStatFile(mailStat:PTR TO mailStat)
  DEF fd, stat
  DEF string[100]:STRING

  StringF(string,'\sMailStats',msgBaseLocation)

  fd:=Open(string,OLDFILE)
  IF(fd=0)
    fd:=Open(string,MODE_READWRITE)
    IF(fd=0)
      mailStat.lowestKey:=0
      mailStat.lowestNotDel:=0
      mailStat.highMsgNum:=0
      writeDebugLog('Error reading mailstat')

      RETURN FALSE
    ENDIF

    mailStat.lowestNotDel:=0
    mailStat.lowestKey:=1
    mailStat.highMsgNum:=1
    stat:=Write(fd,mailStat,SIZEOF mailStat)
  ELSE
    stat:=Read(fd,mailStat,SIZEOF mailStat)
  ENDIF

  IF (stat<>SIZEOF mailStat)
    writeDebugLog('Error writing to mailstat file')
    Close(fd)
    RETURN FALSE
  ENDIF

  Close(fd)

ENDPROC TRUE

PROC saveNewMSG()
  DEF msgbaselock
  DEF f,stat
  DEF tempStr[255]:STRING
  DEF mh: mailHeader
  DEF mailStat: mailStat

  AstrCopy(mh.toName,mailUser,31)
  AstrCopy(mh.fromName,fromUser,31)
  AstrCopy(mh.subject,subject,31)
  mh.status:="P"
  mh.pad:=0

  mh.recv:=0
  mh.msgDate:=getSystemTime()
   
  IF(msgbaselock:=lockMsgBase())
    
    readMailStatFile(mailStat)
    mh.msgNumb:=mailStat.highMsgNum
    stat:=saveMessageHeader(mailStat,mh)
    IF(stat=TRUE)
      StringF(tempStr,'\s\d',msgBaseLocation,mh.msgNumb)
      IF((f:=Open(tempStr,MODE_NEWFILE)))=0
        transmit('ERROR! Unable to open message output file\b\nMessage has not been saved!')
        writeDebugLog('ERROR! Unable to open message output file')

        RETURN FALSE
      ENDIF
      
      writeFile(f,TRUE)
      Close(f)
    ELSE
      transmit('ERROR! Unable to update message header file\b\nMessage has not been saved!')
      writeDebugLog('ERROR! Unable to update message header file')
    ENDIF
    UnLock(msgbaselock)
  ELSE
    transmit('ERROR! Another task has the MsgBase locked!\b\nMessage has not been saved!')
    writeDebugLog('ERROR! Another task has the MsgBase locked')
  ENDIF
ENDPROC TRUE

PROC sendEall()
  DEF tempStr[255]:STRING
  IF EstrLen(mailUser)>0
    StringF(tempStr,'Sending message to: (\s)',mailUser)
    transmit(tempStr)
    writeDebugLog(tempStr)
    saveNewMSG()
  ENDIF
ENDPROC

PROC buildOutput()
  DEF confCtopDb[255]:STRING
  DEF tempStr[255]:STRING
  DEF userName[255]:STRING
  DEF userLoc[255]:STRING
  DEF tmpBCD[8]:ARRAY OF CHAR
  DEF userUpBytes
  DEF startDate,resetDate
  DEF user:PTR TO user
  DEF tmpUser:PTR TO user
  DEF fh,n,i
  
  userList.clear()

  StringF(confCtopDb,'\s\s',confLocation,dataFileName)
  fh:=Open(confCtopDb,MODE_OLDFILE)
  IF fh<>0
    Read(fh,{resetDate},4)
    Read(fh,{startDate},4)
    Read(fh,tempStr,32)
    StrCopy(topUpName,tempStr)
    Read(fh,topUpBytes,8)
    Read(fh,{topUpFiles},4)

    Read(fh,tempStr,32)
    StrCopy(periodUpName,tempStr)
    Read(fh,periodUpBytes,8)
    Read(fh,{periodUpFiles},4)
    
    totalFiles:=0
    convertToBCD(0,totalBytesBCD)
   
    
    REPEAT
      n:=Read(fh,tempStr,32)
      IF n>0
        StrCopy(userName,tempStr)
        
        Read(fh,tempStr,30)
        StrCopy(userLoc,tempStr)
        Read(fh,{userUpBytes},4)

        user:=NIL
        FOR i:=0 TO userList.count()-1
          tmpUser:=userList.item(i)
          IF StrCmp(tmpUser.userName,userName)
            user:=tmpUser
          ENDIF
        ENDFOR
        
        IF user=NIL
          user:=NEW user
          AstrCopy(user.userName,userName,32)
          convertToBCD(0,user.uploadedBytesBCD)
          user.uploadedFiles:=0
          userList.add(user)
        ENDIF
        AstrCopy(user.location,userLoc,30)
        convertToBCD(userUpBytes,tmpBCD)
        addBCD2(user.uploadedBytesBCD,tmpBCD)
        user.uploadedFiles:=user.uploadedFiles+1
        totalFiles++
        addBCD2(totalBytesBCD,tmpBCD)
      ENDIF
    UNTIL n=0
    
    Close(fh)
  ENDIF

  userList.sort({itemCompare},0,userList.count()-1)
  outputStart:=startDate
  outputReset:=resetDate

ENDPROC

PROC displayFile(fname)
  DEF fh
  DEF string[255]:STRING
  
  fh:=Open(fname,MODE_OLDFILE)
  IF fh<>0
    WHILE((ReadStr(fh,string)<>-1) OR (StrLen(string)>0))
      transmit(string)
    ENDWHILE
    Close(fh)
  ENDIF
ENDPROC

PROC writeHeader()
  DEF file[255]:STRING
  StringF(file,'\sConftop.header',confLocation)
  IF FileLength(file)>0
    displayFile(file)
    RETURN TRUE
  ELSE
    StrCopy(file,'Conftop.header')
    IF FileLength(file)>0
      displayFile(file)
      RETURN TRUE
    ENDIF
  ENDIF
ENDPROC FALSE

PROC writeTailer()
  DEF file[255]:STRING
  StringF(file,'\sConftop.tailer',confLocation)
  IF FileLength(file)>0
    displayFile(file)
  ELSE
    StrCopy(file,'Conftop.tailer')
    IF FileLength(file)>0
      displayFile(file)
    ENDIF
  ENDIF
ENDPROC

PROC writeFile(fh,finalResult)
  DEF currDate,i
  DEF tmpStr[255]:STRING
  DEF dateStr[20]:STRING
  DEF tempBCDStr[255]:STRING
  DEF user:PTR TO user
  DEF written

  currDate:=getSystemDate()

  IF finalResult
    StringF(tmpStr,'[32mConference: [33m\l\s[38]  [32mDay ([33m\d/\d - Final Results[32m)[0m',confName,outputReset-outputStart,outputReset-outputStart,outputReset-getSystemDate()-1)
  ELSEIF showResetDate
    formatDate(outputReset,dateStr)     
    StringF(tmpStr,'[32mConference: [33m\l\s[32]  [32mResetDate ([33m\s 00:00:00[32m)[0m',confName,dateStr)
  ELSE
    StringF(tmpStr,'[32mConference: [33m\l\s[40]  [32mDay ([33m\d/\d - \d days left[32m)[0m',confName,currDate-outputStart+1,outputReset-outputStart,outputReset-getSystemDate()-1)
  ENDIF
  writeLine(fh,tmpStr)
  writeLine(fh,'')
  writeLine(fh,'[35mNo# Username (Handle)       Location (Group)         Files Uploaded Bytes')
  writeLine(fh,'[34m===-=======================-========================-=====-==================')
  
  FOR i:=0 TO rows-1
    written:=FALSE     
    IF (i<userList.count())
      user:=userList.item(i)
      
      convertToBCD(minLimit,tempBCDStr)
      IF bcdComp(tempBCDStr,user.uploadedBytesBCD)>0
        formatBCD(user.uploadedBytesBCD,tempBCDStr)
        formatseparators(',',tempBCDStr)
                
        StringF(tmpStr,'[32m\r\d[2]. [0m\l\s[23] [33m\l\s[24] [32m\r\d[5] [0m\r\s[18]',i+1,user.userName,user.location,user.uploadedFiles,tempBCDStr)
        writeLine(fh,tmpStr)
        written:=TRUE
      ENDIF
    ENDIF
    IF written=FALSE
      IF skipEmpty=FALSE
        IF (userList.count()=0) AND (i=(Shr(rows,1)-1))
          StringF(tmpStr,'[32m\r\d[2].[0m            - NO UPLOADERS ARE AVAILABLE IN THIS CONFERENCE -',i+1)
          
        ELSE
          StringF(tmpStr,'[32m\r\d[2].',i+1)
        ENDIF
        writeLine(fh,tmpStr)
      ENDIF
    ENDIF
  ENDFOR
  
  writeLine(fh,'')
  formatBCD(totalBytesBCD,tempBCDStr)
  formatseparators(',',tempBCDStr)
     
  StringF(tmpStr,'[35mTotal Uploaded Files[36m: [ [0m\r\d[5] [36m]   [35mTotal Uploaded Bytes[36m: [ [0m\r\s[17] [36m][0m',totalFiles,tempBCDStr)
  writeLine(fh,tmpStr)
  IF (finalResult=FALSE)
    writeLine(fh,'[34m===-=======================-========================-=====-==================')
    formatBCD(periodUpBytes,tempBCDStr)
    formatseparators(',',tempBCDStr)
    StringF(tmpStr,'[33mTop Uploader Last Period[32m:[0m \l\s[16] [33mBytes[32m:[0m \r\s[15] [33mFiles[32m: [0m\r\d[4]',periodUpName,tempBCDStr,periodUpFiles)
    writeLine(fh,tmpStr)
    formatBCD(topUpBytes,tempBCDStr)
    formatseparators(',',tempBCDStr)
    StringF(tmpStr,'[33mTop Uploader Record     [32m:[0m \l\s[16] [33mBytes[32m:[0m \r\s[15] [33mFiles[32m: [0m\r\d[4]',topUpName,tempBCDStr,topUpFiles)
    writeLine(fh,tmpStr)
  ENDIF
ENDPROC

PROC writeOutput(bull,finalResult=FALSE)
  DEF fh
  DEF r
  DEF tmpStr[255]:STRING
  
  IF bull AND (EstrLen(bullFile)>0)
    fh:=Open(bullFile,MODE_NEWFILE)
  ELSE
    fh:=0
  ENDIF

  IF (bull=FALSE)
    r:=writeHeader()
    header(r=FALSE)
  ELSE
    StringF(tmpStr,'Writing bulletin to: (\s)',bullFile)
    transmit(tmpStr)
  ENDIF

  writeFile(fh,finalResult)
  IF bull=FALSE THEN writeTailer()
  
  IF fh<>0 THEN Close(fh)
ENDPROC

PROC writeDebugLog(logtxt:PTR TO CHAR)
  DEF debugDateStr[25]:STRING
  DEF dfh
  DEF days,mins
  
  IF outputDebug=FALSE THEN RETURN
  
  days,mins:=getSystemDate()
  formatDateTime(days,mins,debugDateStr)     
  StrAdd(debugDateStr,' ')
  dfh:=Open('PROGDIR:debug.log',MODE_READWRITE)
  IF dfh<>0 
    Seek(dfh,0,OFFSET_END)
    Write(dfh,debugDateStr,StrLen(debugDateStr))
    Write(dfh,logtxt,StrLen(logtxt))
    Write(dfh,'\n',1)
    Close(dfh)
  ENDIF
ENDPROC

PROC main() HANDLE

  DEF tempStr[255]:STRING
  DEF n,priv,i,found
  DEF user:PTR TO user

  diface:=0
  strfield:=0
  
  IF (iconbase:=OpenLibrary('icon.library',33))=NIL THEN Raise(ERR_NOICON)
  
  IF aedoorbase:=OpenLibrary('AEDoor.library',1)
    diface:=CreateComm(arg[])     /* Establish Link   */
    IF diface<>0
      strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
    ENDIF
  ENDIF

  StrCopy(mailUser,'')
  StrCopy(bullFile,'')
  StrCopy(nextDoor,'')
  StrCopy(subject,'Results from Conftop!')
  StrCopy(periodUpName,'NONE')
  StrCopy(topUpName,'NONE')
  StrCopy(cfgFileName,'conftop')
  StrCopy(dataFileName,'ctop.data')

  userList:=NEW userList.stdlist(1000)

  node:=getAEIntValue(BB_NODEID)
  getAEStringValue(BB_LOCAL,bbsLoc)
  getAEStringValue(BB_CONFNAME,confName)
  getAEStringValue(BB_CONFLOCAL,confLocation)
  getAEStringValue(DT_NAME,userName)
  getAEStringValue(DT_LOCATION,userLocation)
  getAEStringValue(MSGBASE_LOC,msgBaseLocation)
  getAEStringValue(JH_SYSOP,fromUser)
  getAEStringValue(BB_MAINLINE,tempStr)
  
  /*node:=0
  StrCopy(bbsLoc,'bbs:')
  StrCopy(confName,'amiga warez')
  StringF(confLocation,'\sconf02/',bbsLoc)
  StringF(msgBaseLocation,'\smsgbase/',confLocation)
  StrCopy(fromUser,'SYSOP')
  StrCopy(userName,'bob')
  StrCopy(userLocation,'yep')
  StrCopy(tempStr,'FILECHECK')*/
  
  n:=InStr(tempStr,' ')
  IF n>=0 THEN StrCopy(uploadFile,TrimStr(tempStr+n+1))

  readConfig('PROGDIR:conftop')
  StringF(tempStr,'\sDoors/\s',bbsLoc,cfgFileName)
  readConfig(tempStr)
  StringF(tempStr,'\s\s',confLocation,cfgFileName)
  found:=readConfig(tempStr)
  
  header()
  
  IF found=TRUE
    checkForReset()
    
    IF (EstrLen(uploadFile)>0)
      priv:=checkPriv(uploadFile)
      IF priv=FALSE
        updateStats(uploadFile,userName,userLocation)
      ELSE
        transmit('Private upload, skipping update.')
        writeDebugLog('Private upload, skipping update.')
      ENDIF
    ELSE
      buildOutput()
      writeOutput(FALSE)
    ENDIF
  ELSE
    transmit('Conference Top Uploaders is not installed in this conference.')
    writeDebugLog('Conference Top Uploaders is not installed in this conference.')
  ENDIF
  
EXCEPT DO
  IF userList<>NIL
    FOR i:=0 TO userList.count()-1
      user:=userList.item(i)
      END user
    ENDFOR
    END userList
  ENDIF
  IF diface<>0
    setAEIntValue(DT_GOODFILE,RESULT_NOT_TESTED)
    DeleteComm(diface)        /* Close Link w /X  */
  ENDIF
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
  IF iconbase<>0 THEN CloseLibrary(iconbase)
ENDPROC

verdata:
  CHAR '$VER: Conftop-II V0.99-130420221312 By REbEL/QTX',0
