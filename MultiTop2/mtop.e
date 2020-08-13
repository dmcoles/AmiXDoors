/*
/X5 compatible TOP door
*/
OPT OSVERSION=37,REG=5

  MODULE 'dos/dos'
  MODULE 'dos/datetime'
ENUM ERR_USERDATA=1,ERR_USERKEYS=2,ERR_USERMISC=3, ERR_TEMPLATEFILE=4, ERR_OUTPUTFILE=5, ERR_USERDATA_READ=6,ERR_USERKEYS_READ=7,ERR_USERMISC_READ=8, ERR_INVALID_SORT=9, ERR_INVALID_SORT2=10, ERR_INVALID_PARAMS=11, ERR_CONFDB

ENUM SORT_ULBYTES, SORT_ULFILES, SORT_DLBYTES, SORT_DLFILES, SORT_MSGS, SORT_CALLS, SORT_CPSUP, SORT_CPSDOWN

DEF regString[255]:STRING

OBJECT userData
  name[30]:ARRAY OF CHAR
  name31: CHAR  -> last character of name (odd sized arrays are always padded so need this kludge)
  pass0: CHAR   -> first character of pass (odd sized arrays are always padded so need this kludge)
  pass[8]:ARRAY OF CHAR
  location[30]:ARRAY OF CHAR
  phoneNumber[13]:ARRAY OF CHAR
  slotNumber: INT
  secStatus: INT
  secBoard: INT                   /* File or Byte Ratio */
  secLibrary: INT                 /* Ratio              */
  secBulletin: INT                /* Computer Type      */
  messagesPosted: INT
 /* Note ConfYM = the last msg you actually read, ConfRead is the same ?? */
  newSinceDate: LONG
  pwdHash: LONG
  confRead2: LONG   ->not used
  confRead3: LONG   ->not used
  zoomType: INT
  unknown: INT      ->not used
  unknown2: INT     ->not used
  unknown3: INT     ->not used
  xferProtocol: INT
  filler2: INT      ->not used
  lcFiles: INT      ->not used
  badFiles: INT     ->not used
  accountDate: LONG
  screenType: INT
  editorType: INT
  conferenceAccess[10]: ARRAY OF CHAR
  uploads: INT
  downloads: INT
  confRJoin: INT
  timesCalled: INT
  timeLastOn: LONG
  timeUsed: LONG
  timeLimit: LONG
  timeTotal: LONG
  bytesDownload: LONG
  bytesUpload: LONG
  dailyBytesLimit: LONG
  dailyBytesDld: LONG
  expert: CHAR
  chatRemain: LONG
  chatLimit: LONG
  creditDays: LONG -> used to store days credited credit account
  creditAmount: LONG -> used to store amount paid credit account
  creditStartDate: LONG -> start date credit account
  creditTotalToDate: LONG ->  used to store amount paid to date credit account
  creditTotalDate: LONG -> credit total to date date
  creditTracking: CHAR ->  track uploads/downloads flags in credit account
  translatorID: CHAR
  msgBaseRJoin:INT
  confYM9: LONG ->not used
  beginLogCall : LONG ->not used
  protocol: CHAR  ->not really used
  uucpa: CHAR
  lineLength: CHAR
  newUser: CHAR
ENDOBJECT

OBJECT userKeys
  userName[31]: ARRAY OF CHAR
  number: LONG
  newUser: CHAR
  oldUpCPS: INT            /* highest upload cps rate (max 64k) */
  oldDnCPS: INT            /* highest dnload cps rate (max 64k)*/
  userFlags: INT           /*                         */
  baud: INT                /* last online baud rate   */
  upCPS2: LONG             /* new high upload cps with support for >64k */
  dnCPS2: LONG             /* new high download cps with support for >64k */
  timesOnToday: INT        /* number of times user has been online today */
ENDOBJECT

OBJECT userMisc
  internetName[10]:ARRAY OF CHAR
  realName[26]:ARRAY OF CHAR
  downloadBytesBCD[8]:ARRAY OF CHAR
  uploadBytesBCD[8]:ARRAY OF CHAR
  eMail[50]:ARRAY OF CHAR
  lastDlCPS:LONG
  unused[142]:ARRAY OF CHAR
  ->unknown[28]:ARRAY OF CHAR
  ->nodeFlags[32]:ARRAY OF LONG
  ->confFlags2[10]:ARRAY OF LONG
ENDOBJECT

OBJECT confBase
  handle[16]: ARRAY OF CHAR
  downloadBytesBCD[8]:ARRAY OF CHAR
  uploadBytesBCD[8]:ARRAY OF CHAR
  newSinceDate: LONG
  confRead: LONG
  confYM: LONG
  bytesDownload: LONG
  bytesUpload: LONG
  lastEMail: LONG
  dailyBytesDld: LONG
  upload: INT
  downloads: INT
  ratioType: INT
  ratio: INT
  messagesPosted: INT
  access: INT
  active:INT
ENDOBJECT

OBJECT user
  userName[31]:ARRAY OF CHAR
  location[30]:ARRAY OF CHAR
  uploadedBytesBCD[8]:ARRAY OF CHAR
  uploadedFiles: LONG
  downloadedBytesBCD[8]:ARRAY OF CHAR
  downloadedFiles: LONG
  messages: LONG
  calls: LONG
  cpsUp: LONG
  cpsDown: LONG
ENDOBJECT

OBJECT stats
  totalCalls: LONG
  totalBytesUpBCD[8]:ARRAY OF CHAR
  totalFilesUp: LONG
  totalBytesDownBCD[8]:ARRAY OF CHAR
  totalFilesDown: LONG
  totalMessages: LONG
  activeUsers: LONG
ENDOBJECT


OBJECT stdlist
  PRIVATE items:PTR TO LONG
  PRIVATE initialMax:LONG
ENDOBJECT

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

PROC sort(compareProc,sortField,l,r) OF stdlist
DEF i,j,x,t:PTR TO user
  i:=l; j:=r; x:=self.items[Shr(l+r,1)]
  REPEAT
    WHILE compareProc(self.items[i],x,sortField)<0 DO i++
    WHILE compareProc(self.items[j],x,sortField)>0 DO j--
    IF i<=j
      t:=self.items[i]; self.items[i]:=self.items[j]; self.items[j]:=t
      i++; j--
    ENDIF
  UNTIL i>j
  IF l<j THEN self.sort(compareProc,sortField,l,j)
  IF i<r THEN self.sort(compareProc,sortField,i,r)
ENDPROC

PROC getSystemTime()
  DEF currDate: datestamp
  DEF startds:PTR TO datestamp

  startds:=DateStamp(currDate)
  ->2922 days between 1/1/70 and 1/1/78

ENDPROC (Mul(Mul(startds.days+2922,1440),60)+(startds.minute*60)+(startds.tick/50))+21600,Mod(startds.tick,50)

PROC formatLongTime(cDateVal,outDateStr)
  DEF d : PTR TO datestamp
  DEF dt : datetime
  DEF time[10]:STRING
  DEF dateVal

  dateVal:=cDateVal-21600

  d:=dt.stamp
  d.tick:=(dateVal-Mul(Div(dateVal,60),60))
  d.tick:=Mul(d.tick,50)
  dateVal:=Div(dateVal,60)
  d.days:=Div((dateVal),1440)-2922   ->-2922 days between 1/1/70 and 1/1/78
  d.minute:=dateVal-(Mul(d.days+2922,1440))

  dt.format:=FORMAT_USA
  dt.flags:=0
  dt.strday:=0
  dt.strdate:=0
  dt.strtime:=time

  IF DateToStr(dt)
    StringF(outDateStr,'\s',time)
    RETURN TRUE
  ENDIF
ENDPROC FALSE

PROC formatLongDate(cDateVal,outDateStr)
  DEF d : PTR TO datestamp
  DEF dt : datetime
  DEF datestr[10]:STRING
  DEF dateVal

  dateVal:=cDateVal-21600

  d:=dt.stamp
  d.tick:=(dateVal-Mul(Div(dateVal,60),60))
  d.tick:=Mul(d.tick,50)
  dateVal:=Div(dateVal,60)
  d.days:=Div((dateVal),1440)-2922   ->-2922 days between 1/1/70 and 1/1/78
  d.minute:=dateVal-(Mul(d.days+2922,1440))

  dt.format:=FORMAT_USA
  dt.flags:=0
  dt.strday:=0
  dt.strdate:=datestr
  dt.strtime:=0

  IF DateToStr(dt)
    StringF(outDateStr,'\s',datestr)
    RETURN TRUE
  ENDIF
  
ENDPROC FALSE

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

PROC bcdCopy(dest:PTR TO CHAR, src:PTR TO CHAR)
  DEF n
  FOR n:=0 TO 7 DO dest[n]:=src[n]
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

PROC divBCD1024(bcdVal:PTR TO CHAR)
  DEF decVal[16]:ARRAY OF CHAR
  DEF i,i2,n=0,c=0
  
  FOR i:=0 TO 7
    decVal[n]:=Shr(bcdVal[i] AND $f0,4)
    n++
    decVal[n]:=bcdVal[i] AND $f
    n++
  ENDFOR
  
  FOR i2:=0 TO 9
    c:=0
    FOR i:=0 TO 15
      n:=Shr(decVal[i],1)
      IF c THEN n:=n+5
      c:=decVal[i] AND 1
      decVal[i]:=n
    ENDFOR
  ENDFOR

  n:=0
  FOR i:=0 TO 7
    bcdVal[i]:=Shl(decVal[n],4)+decVal[n+1]
    n:=n+2
  ENDFOR
ENDPROC

PROC unsignedLongComp(v1,v2)
    MOVE.L v1,D1
    MOVE.L v2,D2
    MOVE.L #0,D0
    CMP.L D1,D2
    BEQ done
    MOVE.L #1,D0
    CMP.L D1,D2
    BHI done
    MOVE.L #-1,D0
done:
ENDPROC D0

PROC subBCD2(bcdTotal:PTR TO CHAR, bcdValToSub: PTR TO CHAR)
  MOVE.L bcdValToSub,A0
  LEA 8(A0),A0
  MOVE.L bcdTotal,A1
  LEA 8(A1),A1

  SUB.L D0,D0        ->clear X flag

  SBCD -(A0),-(A1)
  SBCD -(A0),-(A1)
  SBCD -(A0),-(A1)
  SBCD -(A0),-(A1)
  SBCD -(A0),-(A1)
  SBCD -(A0),-(A1)
  SBCD -(A0),-(A1)
  SBCD -(A0),-(A1)
ENDPROC

PROC convertFromBCD(inArray:PTR TO CHAR)
  DEF tempBCD[8]:ARRAY
  DEF bcdStr[20]:STRING

  convertToBCD($ffffffff,tempBCD)
  subBCD2(tempBCD,inArray)
  IF ((tempBCD[0] AND $F0)<>0)
    RETURN $ffffffff
  ENDIF
  formatBCD(inArray,bcdStr)
ENDPROC Val(bcdStr)

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

PROC itemCompare(user1:PTR TO user, user2:PTR TO user,sortField)
  SELECT sortField
    CASE SORT_ULBYTES
      RETURN bcdComp(user1.uploadedBytesBCD,user2.uploadedBytesBCD)
    CASE SORT_ULFILES
      RETURN unsignedLongComp(user1.uploadedFiles,user2.uploadedFiles)
    CASE SORT_DLBYTES
      RETURN bcdComp(user1.downloadedBytesBCD,user2.downloadedBytesBCD)
    CASE SORT_DLFILES
      RETURN unsignedLongComp(user1.downloadedFiles,user2.downloadedFiles)
    CASE SORT_MSGS
      RETURN unsignedLongComp(user1.messages,user2.messages)
    CASE SORT_CALLS
      RETURN unsignedLongComp(user1.calls,user2.calls)
    CASE SORT_CPSUP
      RETURN unsignedLongComp(user1.cpsUp,user2.cpsUp)
    CASE SORT_CPSDOWN
      RETURN unsignedLongComp(user1.cpsDown,user2.cpsDown)
  ENDSELECT
ENDPROC 0

PROC processUser(showall,minUserLevel,n,userdata:PTR TO userData,userkeys:PTR TO userKeys,usermisc:PTR TO userMisc,confdb:PTR TO confBase,stats:PTR TO stats)
  DEF u:PTR TO user
  DEF v
  
  u:=NIL 
  IF (userdata.slotNumber=n) OR showall
  
    IF (userdata.secStatus<minUserLevel) THEN RETURN u
  
    u:=NEW u
    AstrCopy(u.userName,userdata.name,31)
    AstrCopy(u.location,userdata.location,30)
    u.calls:=userdata.timesCalled AND $FFFF

    IF confdb=NIL     
      v:=convertFromBCD(usermisc.downloadBytesBCD)
      IF (userdata.bytesDownload=-1) AND (v=-1) THEN bcdCopy(u.downloadedBytesBCD,usermisc.downloadBytesBCD) ELSE convertToBCD(userdata.bytesDownload,u.downloadedBytesBCD)

      v:=convertFromBCD(usermisc.uploadBytesBCD)
      IF (userdata.bytesUpload=-1) AND (v=-1) THEN bcdCopy(u.uploadedBytesBCD,usermisc.uploadBytesBCD) ELSE convertToBCD(userdata.bytesUpload,u.uploadedBytesBCD)
          
      u.uploadedFiles:=userdata.uploads AND $FFFF
      u.downloadedFiles:=userdata.downloads AND $FFFF
      u.messages:=(userdata.messagesPosted AND $FFFF)
    ELSE
      v:=convertFromBCD(confdb.downloadBytesBCD)
      IF (confdb.bytesDownload=-1) AND (v=-1) THEN bcdCopy(u.downloadedBytesBCD,confdb.downloadBytesBCD) ELSE convertToBCD(confdb.bytesDownload,u.downloadedBytesBCD)

      v:=convertFromBCD(confdb.uploadBytesBCD)
      IF (confdb.bytesUpload=-1) AND (v=-1) THEN bcdCopy(u.uploadedBytesBCD,confdb.uploadBytesBCD) ELSE convertToBCD(confdb.bytesUpload,u.uploadedBytesBCD)

      u.uploadedFiles:=confdb.upload AND $FFFF
      u.downloadedFiles:=confdb.downloads AND $FFFF
      u.messages:=(confdb.messagesPosted AND $FFFF)
    ENDIF

    IF ((userkeys.oldUpCPS AND $FFFF)<>65535) OR ((userkeys.upCPS2 AND $FFFF0000)=0)
      u.cpsUp:=userkeys.oldUpCPS AND $FFFF
    ELSE
      u.cpsUp:=userkeys.upCPS2
    ENDIF
    IF ((userkeys.oldDnCPS AND $FFFF)<>65535) OR ((userkeys.dnCPS2 AND $FFFF0000)=0)
      u.cpsDown:=userkeys.oldDnCPS AND $FFFF
    ELSE
      u.cpsDown:=userkeys.dnCPS2
    ENDIF
    
    stats.totalCalls:=stats.totalCalls+u.calls
    stats.totalFilesUp:=stats.totalFilesUp+u.uploadedFiles
    stats.totalFilesDown:=stats.totalFilesDown+u.downloadedFiles
    stats.totalMessages:=stats.totalMessages+u.messages
    addBCD2(stats.totalBytesDownBCD,u.downloadedBytesBCD)
    addBCD2(stats.totalBytesUpBCD,u.uploadedBytesBCD)
    IF userdata.slotNumber=n THEN stats.activeUsers:=stats.activeUsers+1 
  ENDIF
ENDPROC u

PROC formatOutput(width,pos,outputStr)
  IF width=0 THEN RETURN
  
  IF StrLen(outputStr)>width
    SetStr(outputStr,width)
    RETURN
  ENDIF
  
  IF pos="-"
    WHILE StrLen(outputStr)<width DO StrAdd(outputStr,' ')
  ELSE
    WHILE StrLen(outputStr)<width DO StringF(outputStr,' \s',outputStr)
  ENDIF
ENDPROC

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

PROC processCode(separator:PTR TO CHAR,num,pos,width,code,userList:PTR TO stdlist,stats:PTR TO stats,output)
  DEF res=FALSE
  DEF out[255]:STRING
  DEF user=NIL:PTR TO user
  DEF bcdTmp[8]:ARRAY OF CHAR
  DEF bcdTmp2[8]:ARRAY OF CHAR
  DEF bcdTmp3[8]:ARRAY OF CHAR
  DEF r
  DEF addseparators

  IF (num>0) AND (num<=userList.count())
    user:=userList.item(num-1)
  ENDIF

  IF user=NIL
    StrCopy(out,'')
  ENDIF
  
  addseparators:=StrLen(separator)<>0
  IF num>0
    IF StrCmp(code,'UN',2)
      res:=TRUE
      IF user<>NIL THEN StrCopy(out,user.userName,31)
      addseparators:=FALSE
  ELSEIF StrCmp(code,'LT',2)
      res:=TRUE
      IF user<>NIL THEN StrCopy(out,user.location,30)
      addseparators:=FALSE
    ELSEIF StrCmp(code,'UF',2)
      res:=TRUE
      IF user<>NIL THEN StringF(out,'\d',user.uploadedFiles)
    ELSEIF StrCmp(code,'DF',2)
      res:=TRUE
      IF user<>NIL THEN StringF(out,'\d',user.downloadedFiles)
    ELSEIF StrCmp(code,'UC',2)
      res:=TRUE
      IF user<>NIL THEN StringF(out,'\d',user.cpsUp)
    ELSEIF StrCmp(code,'DC',2)
      res:=TRUE
      IF user<>NIL THEN StringF(out,'\d',user.cpsDown)
    ELSEIF StrCmp(code,'MS',2)
      res:=TRUE
      IF user<>NIL THEN StringF(out,'\d',user.messages)
    ELSEIF StrCmp(code,'CS',2)
      res:=TRUE
      IF user<>NIL THEN StringF(out,'\d',user.calls)
    ELSEIF StrCmp(code,'UB',2)
      res:=TRUE
      IF user<>NIL
        formatBCD(user.uploadedBytesBCD,out)
      ENDIF
    ELSEIF StrCmp(code,'DB',2)
      res:=TRUE
      IF user<>NIL
        formatBCD(user.downloadedBytesBCD,out)
      ENDIF
    ELSEIF StrCmp(code,'UK',2)
      res:=TRUE
      IF user<>NIL
        bcdCopy(bcdTmp,user.uploadedBytesBCD)
        divBCD1024(bcdTmp)
        formatBCD(bcdTmp,out)
      ENDIF
    ELSEIF StrCmp(code,'UM',2)
      res:=TRUE
      IF user<>NIL
        bcdCopy(bcdTmp,user.uploadedBytesBCD)
        divBCD1024(bcdTmp)
        divBCD1024(bcdTmp)
        formatBCD(bcdTmp,out)
      ENDIF
    ELSEIF StrCmp(code,'DK',2)
      res:=TRUE
      IF user<>NIL
        bcdCopy(bcdTmp,user.downloadedBytesBCD)
        divBCD1024(bcdTmp)
        formatBCD(bcdTmp,out)
      ENDIF
    ELSEIF StrCmp(code,'DM',2)
      res:=TRUE
      IF user<>NIL
        bcdCopy(bcdTmp,user.downloadedBytesBCD)
        divBCD1024(bcdTmp)
        divBCD1024(bcdTmp)
        formatBCD(bcdTmp,out)
      ENDIF
    ELSEIF StrCmp(code,'ST',2)
      res:=TRUE
      addseparators:=FALSE
      IF user<>NIL

        bcdCopy(bcdTmp,user.downloadedBytesBCD)
        bcdCopy(bcdTmp2,user.uploadedBytesBCD)
        r:=bcdComp(bcdTmp,bcdTmp2)
        IF r=0
          ->exactly the same uploads and downloads gets neutral
          StrCopy(out,'')
        ELSEIF r>0
          ->more uploads than downloads

          ->less than 1mb uploaded gets neutral
          convertToBCD(1048576,bcdTmp3)
          IF bcdComp(bcdTmp2,bcdTmp3)>0
            StrCopy(out,'')
          ELSE
            bcdCopy(bcdTmp3,bcdTmp)
            addBCD2(bcdTmp,bcdTmp3)
            r:=bcdComp(bcdTmp,bcdTmp2)
            IF r<0
              ->less than 2:1 gets neutral
              StrCopy(out,'')
            ELSE
              addBCD2(bcdTmp,bcdTmp3)
              r:=bcdComp(bcdTmp,bcdTmp2)
              IF r<0
                ->less than 3:1 gets one star
                StrCopy(out,'*')
              ELSE
                ->more than 3:1 gets two star
                StrCopy(out,'**')
              ENDIF
            ENDIF            
          ENDIF         
        ELSE
          ->more downloads than uploads
          ->less than 1mb downloaded gets neutral
          convertToBCD(1048576,bcdTmp3)
          IF bcdComp(bcdTmp,bcdTmp3)>0
            StrCopy(out,'')
          ELSE
            bcdCopy(bcdTmp3,bcdTmp2)
            addBCD2(bcdTmp2,bcdTmp3)
            r:=bcdComp(bcdTmp2,bcdTmp)
            IF r<0
              ->less than 1:2 gets neutral
              StrCopy(out,'')
            ELSE
              addBCD2(bcdTmp2,bcdTmp3)
              r:=bcdComp(bcdTmp2,bcdTmp)
              IF r<0
                ->less than 1:3 gets one mark
                StrCopy(out,'!')
              ELSE
                ->more than 1:3 gets two marks
                StrCopy(out,'!!')
              ENDIF
            ENDIF
          ENDIF
        ENDIF

      ENDIF
    ENDIF
  ELSE
    IF StrCmp(code,'TC',2)
      res:=TRUE
      StringF(out,'\d',stats.totalCalls)
    ELSEIF StrCmp(code,'TM',2)
      res:=TRUE
      StringF(out,'\d',stats.totalMessages)
    ELSEIF StrCmp(code,'UF',2)
      res:=TRUE
      StringF(out,'\d',stats.totalFilesUp)
    ELSEIF StrCmp(code,'DF',2)
      res:=TRUE
      StringF(out,'\d',stats.totalFilesDown)
    ELSEIF StrCmp(code,'SC',2)
      res:=TRUE
      StringF(out,'\d',stats.totalCalls)
    ELSEIF StrCmp(code,'TU',2)
      res:=TRUE
      StringF(out,'\d',stats.activeUsers)
    ELSEIF StrCmp(code,'UB',2)
      res:=TRUE
      formatBCD(stats.totalBytesUpBCD,out)
    ELSEIF StrCmp(code,'DB',2)
      res:=TRUE
      formatBCD(stats.totalBytesDownBCD,out)
    ELSEIF StrCmp(code,'UK',2)
      res:=TRUE
      bcdCopy(bcdTmp,stats.totalBytesUpBCD)
      divBCD1024(bcdTmp)     
      formatBCD(bcdTmp,out)
    ELSEIF StrCmp(code,'UM',2)
      res:=TRUE
      bcdCopy(bcdTmp,stats.totalBytesUpBCD)
      divBCD1024(bcdTmp)     
      divBCD1024(bcdTmp)     
      formatBCD(bcdTmp,out)
    ELSEIF StrCmp(code,'DK',2)
      res:=TRUE
      bcdCopy(bcdTmp,stats.totalBytesDownBCD)
      divBCD1024(bcdTmp)     
      formatBCD(bcdTmp,out)
    ELSEIF StrCmp(code,'DM',2)
      res:=TRUE
      bcdCopy(bcdTmp,stats.totalBytesDownBCD)
      divBCD1024(bcdTmp)     
      divBCD1024(bcdTmp)     
      formatBCD(bcdTmp,out)
    ELSEIF StrCmp(code,'LT',2)
      res:=TRUE
      formatLongTime(getSystemTime(),out)
      addseparators:=FALSE
    ELSEIF StrCmp(code,'LD',2)
      res:=TRUE
      formatLongDate(getSystemTime(),out)
      addseparators:=FALSE
    ELSEIF StrCmp(code,'VT',2)
      res:=TRUE
      StrCopy(out,'  MultiTop-II ')
      addseparators:=FALSE
    ELSEIF StrCmp(code,'RG',2)
      res:=TRUE
      StrCopy(out,regString)
      addseparators:=FALSE
    ENDIF
  ENDIF

  IF res
    IF addseparators THEN formatseparators(separator,out)
    formatOutput(width,pos,out)
    StrAdd(output,out)
  ENDIF
  /*

  ST=Status              
  
  LT=Last Updated (Time)
  LD=Last Updated (Date)
  RG=Register Information
  VT
  */
ENDPROC res

PROC getSortField(sortStr:PTR TO CHAR)
  DEF sortField
  IF StrCmp(sortStr,'UPLOADEDBYTES')
    sortField:=SORT_ULBYTES
  ELSEIF StrCmp(sortStr,'UPLOADEDFILES')
    sortField:=SORT_ULFILES
  ELSEIF StrCmp(sortStr,'DOWNLOADEDBYTES')
    sortField:=SORT_DLBYTES
  ELSEIF StrCmp(sortStr,'DOWNLOADEDFILES')
    sortField:=SORT_DLFILES
  ELSEIF StrCmp(sortStr,'CALLS')
    sortField:=SORT_CALLS
  ELSEIF StrCmp(sortStr,'MESSAGES')
    sortField:=SORT_MSGS
  ELSEIF StrCmp(sortStr,'UPLOADCPS')
    sortField:=SORT_CPSUP
  ELSEIF StrCmp(sortStr,'DOWNLOADCPS')
    sortField:=SORT_CPSDOWN
  ELSE
    sortField:=-1
  ENDIF
ENDPROC sortField

PROC findSortField(fh)
  DEF tempStr[255]:STRING
  DEF sortField[255]:STRING
  DEF p
  
  WHILE Fgets(fh,tempStr,255)<>0
    SetStr(tempStr,StrLen(tempStr))
    IF (p:=InStr(tempStr,'@SORT='))>=0
      Seek(fh,0,OFFSET_BEGINNING)
      
      StrCopy(sortField,tempStr+p+6)
      p:=0
      WHILE (sortField[p]>="A") AND (sortField[p]<="Z") DO p++
      SetStr(sortField,p)
      
      UpperStr(sortField)
      RETURN getSortField(sortField)
    ENDIF
  ENDWHILE
  Seek(fh,0,OFFSET_BEGINNING)
ENDPROC -1

PROC createOutput(userList:PTR TO stdlist,stats:PTR TO stats,separator:PTR TO CHAR,templfh,outputfh)
  DEF tempStr[255]:STRING
  DEF outStr[255]:STRING
  DEF t1[5]:STRING,t2[5]:STRING,code[5]:STRING
  DEF v1,v2,n
  DEF match=FALSE
 
  WHILE Fgets(templfh,tempStr,255)<>0
    SetStr(tempStr,StrLen(tempStr))
    IF StrCmp(tempStr,'@',1)=FALSE
      n:=0
      StrCopy(outStr,'')
      WHILE n<(EstrLen(tempStr))
        match:=FALSE
        IF n<=(EstrLen(tempStr)-8)
          IF (tempStr[n]="%") AND 
             (tempStr[n+1]>="0") AND (tempStr[n+1]<="9") AND 
             (tempStr[n+2]>="0") AND (tempStr[n+2]<="9") AND
             ((tempStr[n+3]=".") OR (tempStr[n+3]<="-")) AND
             (tempStr[n+4]>="0") AND (tempStr[n+4]<="9") AND 
             (tempStr[n+5]>="0") AND (tempStr[n+5]<="9") AND
             (tempStr[n+6]>="A") AND (tempStr[n+6]<="Z") AND
             (tempStr[n+7]>="A") AND (tempStr[n+7]<="Z")
            
            StrCopy(t1,tempStr+n+1,2)
            v1:=Val(t1)
            StrCopy(t2,tempStr+n+4,2)
            v2:=Val(t2)
            StrCopy(code,tempStr+n+6,2)
            
            IF processCode(separator,v1,tempStr[n+3],v2,code,userList,stats,outStr)
              n:=n+8
              match:=TRUE
            ENDIF
          ENDIF
        ENDIF
        IF (match=FALSE) AND (n<=(EstrLen(tempStr)-6))
          IF (tempStr[n]="%") AND 
             (tempStr[n+1]>="0") AND (tempStr[n+1]<="9") AND 
             (tempStr[n+2]>="0") AND (tempStr[n+2]<="9") AND
             ((tempStr[n+3]=".") OR (tempStr[n+3]<="-")) AND
             (tempStr[n+4]>="A") AND (tempStr[n+4]<="Z") AND
             (tempStr[n+5]>="A") AND (tempStr[n+5]<="Z")
            
            StrCopy(t2,tempStr+n+1,2)
            v2:=Val(t2)
            StrCopy(code,tempStr+n+4,2)
            
            IF processCode(separator,-1,tempStr[n+3],v2,code,userList,stats,outStr)
              n:=n+6
              match:=TRUE
            ENDIF
          ENDIF
        ENDIF
          
        IF match=FALSE
          StrAdd(outStr,tempStr+n,1)
          n:=n+1
        ENDIF
      ENDWHILE
      Write(outputfh,outStr,StrLen(outStr))
    ENDIF
  ENDWHILE    
ENDPROC

PROC main() HANDLE
  DEF myargs:PTR TO LONG,rdargs,argp:PTR TO LONG
  DEF userdata[255]:STRING
  DEF userkeys[255]:STRING
  DEF usermisc[255]:STRING
  DEF confDbName[255]:STRING
  
  DEF templatefile[255]:STRING
  DEF outputFile[255]:STRING
  DEF sortStr[255]:STRING
  DEF udfh=0,ukfh=0,umfh=0,templfh=0,outputfh=0,confdbfh=0

  DEF ud:userData
  DEF uk:userKeys
  DEF um:userMisc
  DEF confdb:confBase
  DEF stats:stats
  DEF userList=NIL:PTR TO stdlist
  DEF user:PTR TO user
  DEF n,i,sortField=0
  DEF showall=FALSE
  DEF ignoreSysop=FALSE
  DEF minUserLevel=0
  DEF separator[1]:STRING
  
  DEF l1,l2,l3,l4

  StrCopy(userdata,'bbs:user.data')
  StrCopy(userkeys,'bbs:user.keys')
  StrCopy(usermisc,'bbs:user.misc')
  StrCopy(confDbName,'')
  minUserLevel:=0
  StrCopy(templatefile,'doors:multitop/designs/mtopulfiles2.dsg')
  StrCopy(outputFile,'*')
  StrCopy(sortStr,'')
  StrCopy(regString,'< UNREGISTERED VERSION >')
  sortField:=SORT_ULBYTES
  StrCopy(separator,',')

  WriteF('MultiTop-II Written By Darren Coles\n\n')

  myargs:=[0,0,0,0,0,0,0,0,0,0,0,0,0]:LONG
  IF rdargs:=ReadArgs('template/A,outfile/A,sortfield/K,userdata/K,userkeys/K,usermisc/K,confdb/K,regstring/K,showInactive/S,ignoreSysop/S,minUserLevel/N,noseparator/S,dotseparator/S',myargs,NIL)
    IF myargs[0]<>NIL 
      StrCopy(templatefile,myargs[0],255)
    ENDIF
    IF myargs[1]<>NIL 
      StrCopy(outputFile,myargs[1],255)
    ENDIF
    IF myargs[2]<>NIL 
      StrCopy(sortStr,myargs[2],255)
    ENDIF
    IF myargs[3]<>NIL 
      StrCopy(userdata,myargs[3],255)
    ENDIF
    IF myargs[4]<>NIL 
      StrCopy(userkeys,myargs[4],255)
    ENDIF
    IF myargs[5]<>NIL 
      StrCopy(usermisc,myargs[5],255)
    ENDIF
    IF myargs[6]<>NIL 
      StrCopy(confDbName,myargs[6],255)
    ENDIF
    IF myargs[7]<>NIL 
      StrCopy(regString,myargs[7],255)
    ENDIF
    IF myargs[8]<>NIL 
      showall:=TRUE
    ENDIF
    IF myargs[9]<>NIL 
      ignoreSysop:=TRUE
    ENDIF
    IF myargs[10]<>NIL 
      argp:=myargs[10]
      minUserLevel:=argp[]
    ENDIF
    IF myargs[11]<>NIL 
      StrCopy(separator,'')
    ENDIF
    IF myargs[12]<>NIL 
      StrCopy(separator,'.')
    ENDIF
    FreeArgs(rdargs)
  ELSE
    Raise(ERR_INVALID_PARAMS)
  ENDIF

 IF StrLen(sortStr)>0
    UpperStr(sortStr)
    sortField:=getSortField(sortStr)
    IF sortField=-1 THEN Raise(ERR_INVALID_SORT)
  ENDIF
 
  userList:=NEW userList.stdlist(1000)

  udfh:=Open(userdata,MODE_OLDFILE)
  IF udfh<=0 THEN Raise(ERR_USERDATA)
  ukfh:=Open(userkeys,MODE_OLDFILE)
  IF ukfh<=0 THEN Raise(ERR_USERKEYS)
  umfh:=Open(usermisc,MODE_OLDFILE)
  IF umfh<=0 THEN Raise(ERR_USERMISC)
  
  IF StrLen(confDbName)>0
    confdbfh:=Open(confDbName,MODE_OLDFILE)
    IF confdbfh<=0 THEN Raise(ERR_CONFDB)
  ENDIF
  
  templfh:=Open(templatefile,MODE_OLDFILE)
  IF templfh<=0 THEN Raise(ERR_TEMPLATEFILE)
  
  IF StrLen(sortStr)=0
    IF (sortField:=findSortField(templfh))=-1
      Raise(ERR_INVALID_SORT2)
    ENDIF
  ENDIF

  stats.totalCalls:=0
  stats.totalFilesUp:=0
  stats.totalFilesDown:=0
  stats.totalMessages:=0
  stats.activeUsers:=0
  convertToBCD(0,stats.totalBytesUpBCD)
  convertToBCD(0,stats.totalBytesDownBCD)
  
  n:=1
  REPEAT
    l1:=Read(udfh,ud,SIZEOF userData)
    l2:=Read(ukfh,uk,SIZEOF userKeys)   
    l3:=Read(umfh,um,SIZEOF userMisc)
    IF confdbfh>0 THEN l4:=Read(confdbfh,confdb,SIZEOF confBase) ELSE l4:=SIZEOF confBase
    
    IF (l1=SIZEOF userData) AND (l2=SIZEOF userKeys) AND (l3=SIZEOF userMisc)
      
      IF (n<>1) OR (ignoreSysop=FALSE)
        user:=processUser(showall,minUserLevel,n,ud,uk,um,IF (confdbfh>0) AND (l4=SIZEOF confBase) THEN confdb ELSE NIL,stats)
        IF user<>NIL THEN userList.add(user)
      ENDIF
      n++
    ENDIF
  UNTIL (l1=0) AND (l2=0) AND (l3=0)
  outputfh:=Open(outputFile,MODE_NEWFILE)
  IF outputfh<=0 THEN Raise(ERR_OUTPUTFILE)

  userList.sort({itemCompare},sortField,0,userList.count()-1)
  createOutput(userList,stats,separator,templfh,outputfh)
  WriteF('operation completed\n')

EXCEPT DO
  IF udfh>0 THEN Close(udfh)
  IF ukfh>0 THEN Close(ukfh)
  IF umfh>0 THEN Close(umfh)
  IF confdbfh>0 THEN Close(confdbfh)
  IF templfh>0 THEN Close(templfh)
  IF outputfh>0 THEN Close(outputfh)
  IF userList<>NIL
    FOR i:=0 TO userList.count()-1
      user:=userList.item(i)
      END user
    ENDFOR
    END userList
  ENDIF

  SELECT exception
    CASE ERR_USERDATA
      WriteF('Error opening user.data\n')
    CASE ERR_USERKEYS
      WriteF('Error opening user.keys\n')
    CASE ERR_USERMISC
      WriteF('Error opening user.misc\n')
    CASE ERR_CONFDB
      WriteF('Error opening \s\n',confDbName)
    CASE ERR_TEMPLATEFILE
      WriteF('Error opening template file \s\n',templatefile)
    CASE ERR_OUTPUTFILE
      WriteF('Error opening output file \n')
    CASE ERR_USERDATA_READ
      WriteF('Error while reading user.data\n')
    CASE ERR_USERKEYS_READ
      WriteF('Error while reading user.keys\n')
    CASE ERR_USERMISC_READ
      WriteF('Error while reading user.misc\n')
    CASE ERR_INVALID_SORT
      WriteF('Invalid sort field specified\n')
    CASE ERR_INVALID_SORT2
      WriteF('Could not determine sort order from template\n')
    CASE ERR_INVALID_PARAMS
      WriteF('Incorrect parameters\n')
  ENDSELECT
ENDPROC