/*
** UserData Cleaner V2.1
*/
$VER="UserData Cleaner V2.1"
options results
numeric digits 11
signal on error;signal on syntax;signal on ioerr
parse arg Arg.1 Arg.2 Arg.3 Arg.4 Arg.5 Arg.6 Arg.7 Arg.8 Arg.9 Arg.10
FALSE=0
TRUE =1
CLS =d2c(12)
NUL ='0'X
BEEP=d2c(7)
CR =d2c(10)
BLD ='[1m'
AOF ='[0m'
RED ='[31m'; GRN ='[32m'; YEL='[33m'; BLU='[34m'; MAG='[35m'; CYN='[36m'
DST='BBS:BACKUP'
DbSize=1000
Device='RAM:'
i=1
do forever
select
when upper(Arg.i)='HELP' then signal Usage
when upper(Arg.i)='H' then signal Usage
when upper(Arg.i)='DEVICE' then
do
i=i+1
if (Arg.i='' | right(Arg.i,1)~=':') then signal Usage
Device=Arg.i
end
when upper(Arg.i)='DBSIZE' then
do
i=i+1
if (Arg.i='' | datatype(Arg.i,Numeric)=FALSE) then signal Usage
DbSize=Arg.i
end
otherwise NOP
end
i=i+1
if Arg.i='' then break
end
parse version VideoFreq
if pos('NTSC',VideoFreq)>0 then Freq=200
else Freq=256
if ~open(Uconsole,"con:0/114/640/"||Freq-114||"/ Status    UserNr   UserName ") then signal UExit
if ~open(console,"con:1/0/640/114/ "$VER"   -   Done by EMPiRE [MYSTiC]",'W') then signal UExit
address command "makedir "Device"UdC.TEMP"
FirstUse=TRUE
ReStart:
call writeln(console,CLS||AOF)
call writeln(console," Copying User.Data, User.Keys & User.Misc to "Device"UdC.TEMP")
address command "copy BBS:User.Data "Device"UdC.TEMP/User.Data.UdC"
address command "copy BBS:User.Keys "Device"UdC.TEMP/User.Keys.UdC"
address command "copy BBS:User.Misc "Device"UdC.TEMP/User.Misc.UdC"
if exists("BBS:ConfConfig.info") then
do
call open(CnfCfgFile,"BBS:ConfConfig.info",'R')
FileLength=seek(CnfCfgFile,0,'E')
call seek(CnfCfgFile,0,'B')
CnfCfgRAW=upper(readch(CnfCfgFile,FileLength))
call close(CnfCfgFile)
PosCnfNr=pos('NCONFS=',CnfCfgRAW)
if PosCnfNr=0 then call DoError(2)
MaxConf=substr(CnfCfgRAW,PosCnfNr+7,pos(NUL,CnfCfgRAW,PosCnfNr)-PosCnfNr-7)
do j=1 to MaxConf
PosCnfNr=pos('LOCATION.'j'=',CnfCfgRAW)
if PosCnfNr=0 then CnfLoc.j='- EMPTY -'
else
do
PosCnfLoc=pos('=',CnfCfgRAW,PosCnfNr)+1
CnfLoc.j=substr(CnfCfgRAW,PosCnfLoc,pos(NUL,CnfCfgRAW,PosCnfLoc)-PosCnfLoc)
end
end
end
else call DoError(3)

call writeln(console,CR" Copying Conf.DB Files to "Device"UdC.TEMP")
do j=1 to MaxConf
if exists(CnfLoc.j"Conf.DB") then address command "copy "CnfLoc.j"Conf.DB "Device"UdC.TEMP/Conf.DB.OLD."j
else call DoError(4)
end
if FirstUse=TRUE then call CheckFiles
FirstUse=FALSE
if UD_Len/232>=DbSize then call DoError(1)
Start:
call writeln(console,CLS)
call writeln(console,BLD" ["AOF"1"BLD"]"AOF"  Delete InActive/Terminated Accounts")
call writeln(console,BLD" ["AOF"2"BLD"]"AOF"  Delete InActive/Terminated Accounts & Accounts at Selected Level")
call writeln(console,BLD" ["AOF"3"BLD"]"AOF"  CleanUp User.Data.MONTH [MonthTop] File")
call writeln(console,BLD" ["AOF"4"BLD"]"AOF"  BackUp Current User.Data, User.Keys, User.Misc & Conf.DB Files")
call writeln(console,BLD" ["AOF"Q"BLD"]"AOF"  Quit")
call writeln(console,"")
GetKey:
call writech(console,BLD" Select ["AOF"1/2/3/4/R/Q"BLD"]: "copies(' ',60)"[60D"AOF)
Key=upper(readln(console))
if Key='1' then
do
call ProcessUsers(-1)
signal Start
end
if Key='2' then
do
call writech(console,BLD"[1A Select Level ["AOF"0-255"BLD"]:                     [20D"AOF)
Char=readln(console)
if(Char<0 | Char>255) then Signal Start
call ProcessUsers(Char)
signal Start
end
if Key='3' then
do
call ProcessMTU(-1)
signal Start
end
if Key='4' then
do
call DoBackUp
signal Start
end
if Key='R' then signal ReStart
if Key='Q' then signal UExit
call writeln(console,"[2A")
signal GetKey
ProcessUsers:
parse arg DelLevel
call writeln(Uconsole,CLS)
call open(Data,Device"UdC.TEMP/User.Data.UdC",'r')
call open(Keys,Device"UdC.TEMP/User.Keys.UdC",'r')
call open(Misc,Device"UdC.TEMP/User.Misc.UdC",'r')
call open(TempA,Device"UdC.TEMP/User.Data.TEMP",'w')
call open(TempB,Device"UdC.TEMP/User.Keys.TEMP",'w')
call open(TempC,Device"UdC.TEMP/User.Misc.TEMP",'w')
do j=1 to MaxConf
call open(ConfDB.OLD.j,Device"UdC.TEMP/Conf.DB.OLD."j,'r')
call open(ConfDB.j,Device"UdC.TEMP/Conf.DB."j,'w')
end
i =1
kill=0
UD=readch(Data,232)
UK=readch(Keys,56)
UM=readch(Misc,248)
do j=1 to MaxConf
DB.j=readch(ConfDB.OLD.j,74)
end
call writeln(console,CR" Scanning User.Data")
do while (EOF(Data)=FALSE & EOF(Keys)=FALSE & EOF(Misc)=FALSE)
UserName =left(UD,pos(nul,UD)-1)
UserStat =c2d(substr(UD,85,2))
UserLevel=c2d(substr(UD,87,2))
if (UserLevel~=DelLevel & UserStat~=0 & length(UD)=232 & length(UK)=56 & length(UM)=248) then
do
call writeln(Uconsole,BLD" ACTIVE :  "AOF||left("["UserStat"]",5)"    "left(UserName,36,' ')"[A")
UserNr=d2c(i)
if i<256 then UserNr='00'X||UserNr
UD=overlay(UserNr,UD,85,2)
UK=overlay(UserNr,UK,35,2)
call writech(TempA,UD)
call writech(TempB,UK)
call writech(TempC,UM)
do j=1 to MaxConf
call writech(ConfDB.j,DB.j)
end
i=i+1
end
else
do
kill=kill+1
call writeln(Uconsole,BLD" REMOVED:  "AOF||left("["UserStat"]",5)"    "left(UserName,36)" ("i")"BEEP)
end
UD=readch(Data,232)
UK=readch(Keys,56)
UM=readch(Misc,248)
do j=1 to MaxConf
DB.j=readch(ConfDB.OLD.j,74)
end
end
if EOF(Data)=FALSE then
do while EOF(Data)=FALSE
UserNameLen=pos(NUL,UD)-1
UserName =left(UD,UserNameLen)
UserStat =c2d(substr(UD,85,2))
UserLevel=c2d(substr(UD,87,2))
UK=UserName||copies(NUL,56-UserNameLen)
if length(UD)~=232 then
do
kill=kill+1
call writeln(Uconsole,BLD" REMOVED:  "AOF||left("["UserStat"]",5)"    "left(UserName,36)" ("i")"BEEP)
end
else
do
call writeln(Uconsole,BLD" SALVING:  "AOF||left("["UserStat"]",5)"    "left(UserName,36,' ')"[A")
UserNr=d2c(i)
if i<256 then UserNr='00'X||UserNr
UD=overlay(UserNr,UD,85,2)
UK=overlay(UserNr,UK,35,2)
call writech(TempA,UD)
call writech(TempB,UK)
call writech(TempC,UM)
do j=1 to MaxConf
call writech(ConfDB.j,DB.j)
end
i=i+1
end
UD=readch(Data,232)
do j=1 to MaxConf
DB.j=readch(ConfDB.OLD.j,74)
end
end
i=i-1
call writech(Uconsole,copies(' ',40)"[40D")
do j=1 to MaxConf
call writeln(console,"[1A Appending Conf.DB Conference #"j)
call seek(ConfDB.OLD.j,-74,'E')
DB=readch(ConfDB.OLD.j,74)
do k=i+1 to DbSize
call writech(ConfDB.j,DB)
end
end
do j=1 to MaxConf
call close(ConfDB.j)
call close(ConfDB.OLD.j)
end
call close(TempA)
call close(TempB)
call close(TempC)
call close(Data)
call close(Keys)
call close(Misc)
address command "delete "Device"UdC.TEMP/User.Data.UdC FORCE QUIET"
address command "delete "Device"UdC.TEMP/User.Keys.UdC FORCE QUIET"
address command "delete "Device"UdC.TEMP/User.Misc.UdC FORCE QUIET"
address command "rename "Device"UdC.TEMP/User.Data.TEMP "Device"UdC.TEMP/User.Data.UdC"
address command "rename "Device"UdC.TEMP/User.Keys.TEMP "Device"UdC.TEMP/User.Keys.UdC"
address command "rename "Device"UdC.TEMP/User.Misc.TEMP "Device"UdC.TEMP/User.Misc.UdC"
do j=1 to MaxConf
address command "delete "Device"UdC.TEMP/Conf.DB.OLD."j" FORCE QUIET"
address command "rename "Device"UdC.TEMP/Conf.DB."j" "Device"UdC.TEMP/Conf.DB.OLD."j
end
if kill>0 then
do
call writeln(console,"")
call writech(console,"[2A Save & Replace the Existing User.Data [y/N]: ")
GetChar=upper(readln(console))
if GetChar='Y' then
do
address command "copy "Device"UdC.TEMP/User.Data.UdC BBS:User.Data"
address command "copy "Device"UdC.TEMP/User.Keys.UdC BBS:User.Keys"
address command "copy "Device"UdC.TEMP/User.Misc.UdC BBS:User.Misc"
do j=1 to MaxConf
address command "copy "Device"UdC.TEMP/Conf.DB.OLD."j" "CnfLoc.j"Conf.DB"
end
call writeln(console,"[1A User.Data, User.Keys, User.Misc & Conf.DB Files Replaced!                    ")
call writech(console,CR||BLD" - Press Return To Continue - "AOF)
call readln(console)
call writeln(console,CLS||CR" Removed Accounts: "kill)
call writeln(console," Active Accounts : "value(i))
call writeln(console," Cleared Bytes   : "kill*232+kill*56)
select
when exists('BBS:Utils/EMP/MonthTopUp.tup') then
do
call open(TupFile,'BBS:Utils/EMP/MonthTopUp.tup','r')
UDMnth=upper(left(strip(readln(TupFile)),3))
call close(TupFile)
call writech(console,CR" Do You want To Clean User.Data."UDMnth" [MonthTopUp] [y/N]: ")
Key=upper(readln(console))
if Key='Y' then call ProcessMTU(UDMnth)
end
when exists('BBS:Utils/EMP/MonthTop.tup') then
do
call open(TupFile,'BBS:Utils/EMP/MonthTop.tup','r')
UDMnth=upper(left(strip(readln(TupFile)),3))
call close(TupFile)
call writech(console,CR" Do You want To Clean User.Data."UDMnth" [MonthTop] [y/N]: ")
Key=upper(readln(console))
if Key='Y' then call ProcessMTU(UDMnth)
end
otherwise
do
call writech(console,CR||BLD" - Press Return To Continue - "AOF)
call readln(console)
end
end
end
else call writeln(console,CLS||CR" Active Accounts : "value(i))
end
return
ProcessMTU:
parse arg UDMnth
call writeln(Uconsole,CLS)
if UDMnth=-1 then
do
call writeln(console,"")
call writeln(console,"")
call writech(console,BLD"[3A Select Month "AOF"[3 Chars]: User.Data.")
UDMnth=upper(readln(console))
if UDMnth='' then signal Start
end
if ~exists("BBS:User.Data."UDMnth) then
do
call writeln(console,CR||AOF"  BBS:User.Data."UDMnth" Can't be Found!"AOF)
call writech(console,CR||BLD" - Press Return To Continue - "AOF)
call readln(console)
signal Start
end
call writech(console,AOF||CR" BackUp User.Data."UDMnth" [y/N]: ")
GetChar=upper(readln(console))
if GetChar='Y' then address command "copy BBS:User.Data."UDMnth" BBS:BACKUP"
call writeln(console,BLD"[1A Cleaning: "AOF" User.Data."UDMnth"                ")
call open(Data,Device"UdC.TEMP/User.Data.UdC",'R')
call open(DataMth,'BBS:User.Data.'UDMnth,'R')
call open(TmpFile,Device"UdC.TEMP/User.Data.TEMP",'W')
i =1
UD =readch(Data,232)
UdMth =readch(DataMth,232)
QuitFlag=FALSE
Changed =FALSE
do while (EOF(Data)=FALSE & EOF(DataMth)=FALSE & QuitFlag=FALSE)
UserDel=FALSE
UserName =left(UD,pos(nul,UD)-1)
UserStat =c2d(substr(UD,85,2))
UserNameMth=left(UDMth,pos(nul,UDMth)-1)
UserStatMth=c2d(substr(UDMth,85,2))
UserLevel =c2d(substr(UD,87,2))
if length(UD)=232 then
do
if UserName=UserNameMth then
do
UserNr=d2c(i)
if i<256 then UserNr='00'X||UserNr
UDMth=overlay(UserNr,UDMth,85,2)
call writech(TmpFile,UDMth)
i=i+1
end
else
do
call writeln(Uconsole,CLS)
call writeln(Uconsole,"")
call writeln(Uconsole,AOF" User.Data  "left('['UserStat']',5)" : "UserName)
call writeln(Uconsole,"")
call writeln(Uconsole,AOF" User.Data."UDMnth"    : "UserNameMth)
call writech(console,AOF"[1A Is This The Same Account [y/N/q]:           [10D")
Key=strip(upper(readln(console)))
select
when Key='Q' then
do
QuitFlag=TRUE
Changed=FALSE
end
when Key='Y' then
do
UserNr=d2c(i)
if i<256 then UserNr='00'X||UserNr
UDMth=overlay(left(UD,30),UDMth,1,30)
UDMth=overlay(UserNr,UDMth,85,2)
call writech(TmpFile,UDMth)
i=i+1
Changed=TRUE
end
otherwise
do
UserDel=TRUE
Changed=TRUE
end
end
end
end
if UserDel=FALSE then UD=readch(Data,232)
UdMth=readch(DataMth,232)
end
i=i-1
call close(DataMth)
call close(TmpFile)
call close(Data)
If Changed=TRUE then
do
call writeln(Uconsole,CLS)
call writech(console,"[1A Save User.Data."UDMnth" [y/N]:                     [20D")
GetChar=upper(readln(console))
if GetChar='Y' then
do
address command "copy "Device"UdC.TEMP/User.Data.TEMP BBS:User.Data."UDMnth
call writeln(console,"[1A User.Data."UDMnth" Replaced!          ")
end
end
address command "delete "Device"UdC.TEMP/User.Data.TEMP FORCE QUIET"
call writech(console,CR||BLD" - Press Return To Continue - "AOF)
call readln(console)
call writeln(Uconsole,CLS)
return
DoBackUp:
if exists(DST)=FALSE then call DoError(0)
date=compress(date(U)"_"time(),'/:')
address command "makedir "DST"/"date
address command "copy BBS:User.Data "DST"/"date
address command "copy BBS:User.Keys "DST"/"date
address command "copy BBS:User.Misc "DST"/"date
do j=1 to MaxConf
if exists(CnfLoc.j"Conf.DB") then address command "copy "CnfLoc.j"Conf.DB "DST"/"date"/Conf.DB."j
else call DoError(4)
end
call writeln(console,CR" Backup Copied to: "DST)
call writech(console,CR||BLD" - Press Return To Continue - "AOF)
call readln(console)
return
CheckFiles:
call writech(console,CR" Checking User.Data, User.Keys & User.Misc")
call Delay(1)
call open(Data,Device"UdC.TEMP/User.Data.UdC",'R')
call open(Keys,Device"UdC.TEMP/User.Keys.UdC",'R')
call open(Misc,Device"UdC.TEMP/User.Misc.UdC",'R')
UD_Len=seek(Data,0,'E')
UK_Len=seek(Keys,0,'E')
UM_Len=seek(Misc,0,'E')
call close(Data)
call close(Keys)
call close(Misc)
select
when (UD_Len//232~=0 & UK_Len//56~=0 & UM_Len//248~=0) then
do
call writeln(console,BEEP||CLS||CR||BLD" MAJOR ERROR: "AOF"There is Something WRONG with your User.Data, User.Keys & User.Misc!!!")
call writeln(console,CR"  User.Data FileSize is "UD_Len" Bytes And Should be at Least "||((UD_Len/232)%1+1)*232||" Bytes!!")
call writeln(console,"  User.Keys FileSize is "UK_Len" Bytes And Should be at Least "||((UK_Len/56)%1+1)*56||" Bytes!!")
call writeln(console,"  User.Misc FileSize is "UM_Len" Bytes And Should be at Least "||((UM_Len/248)%1+1)*248||" Bytes!!")
signal UdSalvage
end
when UD_Len//232~=0 then
do
call writeln(console,BEEP||CLS||CR||BLD" MAJOR ERROR: "AOF"There is Something WRONG with your User.Data !!!")
call writeln(console,CR"  User.Data FileSize is "UD_Len" Bytes And Should be at Least "||((UD_Len/232)%1+1)*232||" Bytes!!")
signal UdSalvage
end
when UK_Len//56~=0 then
do
call writeln(console,BEEP||CLS||CR||BLD" MAJOR ERROR: "AOF"There is Something WRONG with your User.Keys !!!")
call writeln(console,CR"  User.Keys FileSize is "UK_Len" Bytes And Should be at Least "||((UK_Len/56)%1+1)*56||" Bytes!!")
signal UdSalvage
end
when UM_Len//248~=0 then
do
call writeln(console,BEEP||CLS||CR||BLD" MAJOR ERROR: "AOF"There is Something WRONG with your User.Misc !!!")
call writeln(console,CR"  User.Misc FileSize is "UM_Len" Bytes And Should be at Least "||((UM_Len/248)%1+1)*248||" Bytes!!")
signal UdSalvage
end
otherwise NOP
end
call writeln(console,".... Files Seem to be OK!")
return
UdSalvage:
call writech(console,CR"  Do You Want to Salvage As Much As Possible [y/N] ")
Key=upper(readln(console))
if Key='Y' then call ProcessUsers(-1)
signal UExit
Delay:
parse arg Seconds
call time('R')
do while time('E')<Seconds
end
return 0
Usage:
say CR" "YEL||$VER" by EMPiRE/MYSTiC and REbEL/QTX"
say CR||GRN" SYNTAX :  "AOF"UdClean [DEVICE] [DBSIZE]"
say CR||GRN" OPTIONS:  "AOF"DEVICE - For Storage of TempFiles  [Default RAM:]"
say "           "AOF"DBSIZE - Size of the Conf.DB Files [Default 1000]"
say CR||GRN" EXAMPLE : "AOF"UdClean DEVICE DH0: DBSIZE 500"CR
Exit
DoError:
parse arg Err
select
when Err=0 then call writeln(console,BEEP||CLS||CR||BLD" ERROR:  "AOF"Directory: "DST" Doesn't Exist!!!")
when Err=1 then
do
call writeln(console,BEEP||CLS||CR||BLD" ERROR: "AOF"DBSIZE Must be Greater than the Number of Users in the User.Data!!!")
call writeln(console,CR||AOF"        At present there are "UD_Len/232" Users in the User.Data")
end
when Err=2 then call writeln(console,BEEP||CLS||CR||BLD" ERROR: "AOF"NCONFS must Exist in BBS:ConfConfig.info IconInfo!!!")
when Err=3 then call writeln(console,BEEP||CLS||CR||BLD" ERROR: "AOF"UdClean V2.1 is for /X 4.x and above ONLY !!!")
when Err=4 then call writeln(console,BEEP||CLS||CR||BLD" ERROR: "AOF||CnfLoc.i"Conf.DB doesn't Exist!!")
otherwise NOP
end
call writech(console,CR||BLD" - Press Return To Exit - "AOF)
call readln(console)
signal UExit
ERROR:
SYNTAX:
IOERR:
call writeln(console,BEEP)
call writeln(console,"Error in Line.. #"sigl" Exiting..")
call writeln(console,errortext(sigl))
call writech(console,CR||BLD" - Press Return To Exit - "AOF)
call readln(console)
UExit:
address command "delete "Device"UdC.TEMP/#? FORCE QUIET"
address command "delete "Device"UdC.TEMP FORCE QUIET"
Exit




