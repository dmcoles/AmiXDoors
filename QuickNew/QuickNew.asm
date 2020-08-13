	OPT W-
MEMF_CLEAR	EQU	$10000
_LVOOpen	EQU	-$1E
MEMHF_RECYCLE	EQU	$1
_LVORead	EQU	-$2A
_LVOFreeMem	EQU	-$D2
_LVOCloseLibrary	EQU	-$19E
_LVOExamine	EQU	-$66
MEMF_PUBLIC	EQU	$1
_LVOSeek	EQU	-$42
_LVODateStamp	EQU	-$C0
_LVOUnLock	EQU	-$5A
_LVOOutput	EQU	-$3C
_LVOWrite	EQU	-$30
_LVOOpenLibrary	EQU	-$228
_LVOAllocMem	EQU	-$C6
MODE_OLDFILE	EQU	$3ED
_LVOClose	EQU	-$24
_LVOLock	EQU	-$54
_LVODateToStr	EQU	-$2E8
_LVOReadArgs EQU -798
_LVOFreeArgs EQU -858

****************************************************************************
	SECTION	QuickNew000000,CODE
ProgStart
	MOVE.L	A0,cmdparams.L
	MOVE.L	D0,cmdparamslen.L
	MOVEA.L	4.W,A6
	LEA	dosname(PC),A1
	MOVEQ	#0,D0
	JSR	_LVOOpenLibrary(A6)
	MOVE.L	D0,dosbase.L
	BEQ.L	nodos
	MOVEA.L	dosbase(PC),A6
	JSR	_LVOOutput(A6)
	MOVE.L	D0,stdout.L
	BEQ.L	shutdown
	MOVEQ	#0,D0
	;BSR.L	calccrc       ;checksum
	NOP
	NOP
	TST.L	D0
	BNE.L	badcrc
	;BSR.L	decrypttext       ;decrypt
	NOP
	NOP

	MOVE.L #argstemplate,D1
	MOVE.L #argsdata,D2
	CLR.L D3
	MOVEA.L	dosbase(PC),A6
	JSR _LVOReadArgs(a6)
	TST.L D0
	BEQ nocfg

	MOVE.L D0,args
 
	MOVE.L paramfilename,A0
	BEQ nocfg
  
	LEA	lbL000D50(PC),A2
fnloop
	MOVE.B	(A0)+,(A2)+
	CMPI.B	#0,(A0)
	BNE.S	fnloop

	MOVE.L numdaysptr,D0
	BEQ defaultdays

	MOVE.L D0,A0
	MOVE.L (a0),numdays

defaultdays	MOVE.L args,D1
	JSR _LVOFreeArgs(a6)
	CLR.L args


;	MOVE.L	cmdparamslen(PC),D0
;	SUBQ.L	#1,D0
;	BEQ.L	nocfg  
 
  ;extract config file name from parametesr
;	ADDQ.L	#1,D0
;	MOVEA.L	cmdparams(PC),A0
;	LEA	lbL000D50(PC),A2
;lbC00005A	SUBQ.L	#1,D0
;	BEQ.S	lbC000066
;	MOVE.B	(A0)+,(A2)+
;	CMPI.B	#$20,(A0)
;	BNE.S	lbC00005A
  
lbC000066	MOVE.L	#lbL000D50,filename.L
	MOVE.L	#configfileData,filedataPtr.L
	MOVE.L	#configfileLength,filelengthPtr.L
	BSR.L	loadfile
	CMPI.B	#1,result.L
	BEQ.L	missingcfg
	CMPI.B	#2,result.L
	BEQ.L	nomem
	CMPI.B	#3,result.L
	BEQ.L	readerr

	BSR.L	getdatestrings     ;get the system time for today and yesterday
	TST.L	D0
	BEQ.L	badtime     ;error
  
  ;update quick new text with correct time and date
	LEA	lbL000B68(PC),A0  - time part of date string
	LEA	lbB000C07(PC),A1
	MOVEQ	#7,D7
lbC0000C0	MOVE.B	(A0)+,(A1)+
	DBRA	D7,lbC0000C0

	LEA	todaystr(PC),A0
	LEA	lbB000BEB(PC),A1
	MOVEQ	#7,D7
lbC0000D0	MOVE.B	(A0)+,(A1)+
	DBRA	D7,lbC0000D0
    
    
    
	MOVEA.L	configfileData(PC),A0
	MOVEA.L	A0,A1
lbC0000DC	CMPI.B	#10,(A0)+
	BNE.S	lbC0000DC
	MOVE.L	A0,lbL000A0A.L
	MOVE.L	A0,D0
	SUB.L	A1,D0
	SUBQ.L	#1,D0
	MOVE.L	D0,lbL000A0E.L
	MOVEA.L	A0,A1
lbC0000F6	CMPI.B	#10,(A0)+  - find the end of the second config line
	BNE.S	lbC0000F6
	MOVEQ	#0,D0
	MOVE.B	(A0),D0   - get digit
	SUBI.B	#$31,D0   - subtract "0"
	MOVE.B	D0,displaymode.L
	MOVE.L	A0,D0
	SUB.L	A1,D0
	SUBQ.L	#1,D0
	MOVE.L	D0,lbL000A12.L
lbC000116	CMPI.B	#10,(A0)+
	BNE.S	lbC000116
	MOVE.L	A0,nextConfigBlock.L

lbC000122	BSR.L	getConfigBlock - find block in config file (ending with the #)
	TST.B	result.L
	BNE.L	showfooter  - end of file
  
	MOVE.L	currentConfigBlock(PC),currBlockStart.L
	MOVE.L	nextConfigBlock(PC),currBlockEnd.L
	BSR.L	getConfigLine  - read next line (dir file)
	TST.B	result.L
	BNE.L	showfooter

	BSR.L	processBlock
	BRA.S	lbC000122   - repeat



showfooter	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#quicknewtext,D2
	MOVE.L	#nocfgerrtext-quicknewtext,D3
	JSR	_LVOWrite(A6)
	BRA.L	shutdown

badcrc	;BSR.L	decrypttext   - decrypt
  NOP
  NOP
	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#handsofftext,D2
	MOVE.L	#$24,D3
	JSR	_LVOWrite(A6)
	BRA.L	shutdown

nocfg	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#nocfgerrtext,D2
	MOVE.L	#missingcfgerrtxt-nocfgerrtext,D3
	JSR	_LVOWrite(A6)
	BRA.S	shutdown

badtime	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#badtimeerrtxt,D2
	MOVE.L	#$21,D3
	JSR	_LVOWrite(A6)
	BRA.S	shutdown

readerr	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#filereaderrtxt,D2
	MOVE.L	#$2E,D3
	JSR	_LVOWrite(A6)
	BRA.S	shutdown

nomem	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#nomemerrtxt,D2
	MOVE.L	#$1D,D3
	JSR	_LVOWrite(A6)
	BRA.S	shutdown

missingcfg	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#missingcfgerrtxt,D2
	MOVE.L	#$25,D3
	JSR	_LVOWrite(A6)
shutdown	TST.L	configfileData.L
	BEQ.S	lbC000228
	MOVEA.L	4.W,A6
	MOVEA.L	configfileData(PC),A1
	MOVE.L	configfileLength(PC),D0
	JSR	_LVOFreeMem(A6)
lbC000228
	MOVE.L args,D1
	BEQ nofreeargs
	MOVEA.L	dosbase(PC),A6
	JSR _LVOFreeArgs(a6)

nofreeargs
	MOVEA.L	4.W,A6
	MOVEA.L	dosbase(PC),A1
	JSR	_LVOCloseLibrary(A6)
nodos	MOVEQ	#0,D0
	RTS

getConfigLine	MOVE.L	nextConfigBlock(PC),currentConfigBlock.L
	MOVEA.L	currentConfigBlock(PC),A0
	MOVEA.L	configfileData(PC),A1
	ADDA.L	configfileLength(PC),A1
lbC00024C	CMPA.L	A0,A1
	BEQ.S	lbC000266
	CMPI.B	#10,(A0)+
	BNE.S	lbC00024C
	MOVE.L	A0,nextConfigBlock.L
	MOVE.B	#0,result.L
	RTS

lbC000266	MOVE.B	#1,result.L
	RTS

getConfigBlock	MOVE.L	nextConfigBlock(PC),currentConfigBlock.L
	MOVEA.L	currentConfigBlock(PC),A0
	MOVEA.L	configfileData(PC),A1
	ADDA.L	configfileLength(PC),A1
lbC000284	CMPA.L	A0,A1
	BEQ.S	lbC0002A0
	CMPI.B	#$23,(A0)+   ;find the hash
	BNE.S	lbC000284
	ADDQ.L	#1,A0
	MOVE.L	A0,nextConfigBlock.L
	MOVE.B	#0,result.L
	RTS

lbC0002A0	MOVE.B	#1,result.L
	RTS

loadfile	MOVE.B	#1,result.L
	MOVEA.L	dosbase(PC),A6
	MOVE.L	filename(PC),D1
	MOVE.L	#MODE_OLDFILE,D2
	JSR	_LVOOpen(A6)
	MOVE.L	D0,filehandle.L
	BEQ.L	lbC0003A6
	MOVEA.L	dosbase(PC),A6
	MOVE.L	filename(PC),D1
	MOVE.L	#$FFFFFFFE,D2
	JSR	_LVOLock(A6)
	MOVE.L	D0,filelock.L
	BEQ.L	lbC00039A
	MOVEA.L	dosbase(PC),A6
	MOVE.L	filelock(PC),D1
	MOVE.L	#lbL000E5C,D2
	JSR	_LVOExamine(A6)
	TST.L	D0
	BEQ.L	lbC00038E
	LEA	lbL000E5C(PC),A2
	MOVE.L	$7C(A2),D3
	CMPI.L	#$13880,D3
	BLE.S	lbC000332
	MOVEA.L	dosbase(PC),A6
	MOVE.L	filehandle(PC),D1
	MOVE.L	D3,D2
	SUBI.L	#$13880,D2
	MOVE.L	#$FFFFFFFF,D3
	JSR	_LVOSeek(A6)
	MOVE.L	#$13880,D3
lbC000332	MOVEA.L	filelengthPtr(PC),A0
	MOVE.L	D3,(A0)
	MOVE.B	#2,result.L
	MOVEA.L	filelengthPtr(PC),A0
	MOVE.L	(A0),D0
	MOVE.L	#(MEMF_PUBLIC|MEMF_CLEAR),D1
	MOVEA.L	4.W,A6
	JSR	_LVOAllocMem(A6)
	MOVEA.L	filedataPtr(PC),A0
	MOVE.L	D0,(A0)
	BEQ.S	lbC00038E
	MOVE.B	#3,result.L
	MOVEA.L	dosbase(PC),A6
	MOVE.L	filehandle(PC),D1
	MOVEA.L	filedataPtr(PC),A0
	MOVE.L	(A0),D2
	MOVEA.L	filelengthPtr(PC),A0
	MOVE.L	(A0),D3
	JSR	_LVORead(A6)
	CMPI.L	#$FFFFFFFF,D0
	BEQ.L	lbC00038E
	MOVE.B	#0,result.L
lbC00038E	MOVEA.L	dosbase(PC),A6
	MOVE.L	filelock(PC),D1
	JSR	_LVOUnLock(A6)
lbC00039A	MOVEA.L	dosbase(PC),A6
	MOVE.L	filehandle(PC),D1
	JSR	_LVOClose(A6)
lbC0003A6	RTS

getdatestrings	MOVEA.L	dosbase(PC),A6
	MOVE.L	#datestamp,D1
	JSR	_LVODateStamp(A6)
	MOVE.L dateoffset.L,D1
	SUB.L	D1,datestamp.L
	MOVE.L	#todaystr,lbL000B50.L
	MOVEA.L	dosbase(PC),A6
	MOVE.L	#datestamp,D1
	JSR	_LVODateToStr(A6)
	MOVE.L numdays.L,D1
	SUB.L	D1,datestamp.L
	MOVE.L	#yesterdaystr,lbL000B50.L
	MOVEA.L	dosbase(PC),A6
	MOVE.L	#datestamp,D1
	JSR	_LVODateToStr(A6)
	RTS

processBlock	LEA	dirFilename(PC),A1
	MOVE.L	#$40,D7
lbC0003EE	CLR.L	(A1)+
	DBRA	D7,lbC0003EE
  
	MOVEA.L	currentConfigBlock(PC),A0
	LEA	dirFilename(PC),A1
lbC0003FC	CMPI.B	#10,(A0)
	BEQ.S	lbC000406
	MOVE.B	(A0)+,(A1)+
	BRA.S	lbC0003FC

lbC000406	MOVE.L	#dirFilename,filename.L
	MOVE.L	#dirFileData,filedataPtr.L
	MOVE.L	#dirFileLength,filelengthPtr.L
	BSR.L	loadfile
	CMPI.B	#1,result.L
	BEQ.L	lbC0006A4
	CMPI.B	#2,result.L
	BEQ.L	lbC0006A4
	CMPI.B	#3,result.L
	BEQ.L	lbC0006A4
  
	MOVE.W	#0,lbW000B2A.L
	MOVE.W	#0,lbW000B34.L
  
  CLR.L dateoffset

	MOVE.W	#0,todaysfilecount.L
	MOVE.W	#0,todaysfakecount.L
	MOVE.L	#0,todaysmegabytes.L
	MOVE.W	#0,yesterdaysfilecount.L
	MOVE.W	#0,yesterdaysfakecount.L
	MOVE.L	#0,yesterdaysmegabytes.L

calcallstats
  BSR getdatestrings
	BSR.L	calcdaystats
  ADD.L #1,dateoffset
  MOVE.L dateoffset,D0
  CMP.L numdays,D0
  BNE calcallstats
  
  BSR.L updateplaceholders
  
  ;display block
	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	currBlockStart(PC),D2
	MOVE.L	currBlockEnd(PC),D3
	SUB.L	D2,D3
	SUBQ.L	#3,D3
	JSR	_LVOWrite(A6)
	MOVE.L	stdout(PC),D1
	MOVE.L	#lbB000D4A,D2
	MOVE.L	#2,D3
	JSR	_LVOWrite(A6)

	MOVE.W	#0,lbW000F60.L
	LEA	lbL000F8A(PC),A4
  CLR.L dateoffset
showallfiles
  BSR getdatestrings

	MOVEA.L	dirFileData(PC),A0
	MOVEA.L	A0,A2
	ADDA.L	dirFileLength(PC),A2
	LEA	todaystr(PC),A1
	BRA.S	lbC0004BA

lbC0004A8	MOVEA.L	A3,A0
	LEA	todaystr(PC),A1
	CMPA.L	A0,A2
	BLE.L	lbC000620
lbC0004B4	CMPI.B	#10,(A0)+
	BNE.S	lbC0004B4   ;find start of next line
lbC0004BA	MOVEA.L	A0,A3
	ADDA.L	#$17,A0   ;skip filename, file length etc

;compare date string with todays date string (8 characters)
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0004A8
  
	MOVE.W	#1,lbW000B34.L
	SUBA.L	#$1F,A0
	MOVE.L	A0,-(SP)
	TST.W	lbW000B2A.L
	BNE.L	lbC00053A
	CMPI.B	#1,displaymode.L
	BNE.S	lbC00052E
	MOVE.B	#$20,(A4)+
	MOVE.B	#$20,(A4)+
	MOVE.B	#$20,(A4)+
	MOVE.B	#$20,(A4)+
	ADDI.W	#4,lbW000F60.L
lbC00052E	MOVE.B	#$20,(A4)+
	ADDI.W	#1,lbW000F60.L
lbC00053A	MOVEA.L	(SP),A0
	CMPI.B	#$44,13(A0)
	BEQ.S	lbC000556
	MOVEA.L	configfileData(PC),A3
	MOVE.L	lbL000A0E(PC),D7
	SUBQ.L	#1,D7
lbC00054E	MOVE.B	(A3)+,(A4)+
	DBRA	D7,lbC00054E
	BRA.S	lbC000566

lbC000556	MOVEA.L	lbL000A0A(PC),A3
	MOVE.L	lbL000A12(PC),D7
	SUBQ.L	#1,D7
lbC000560	MOVE.B	(A3)+,(A4)+
	DBRA	D7,lbC000560
lbC000566	MOVEA.L	(SP),A0
	MOVEA.L	A0,A3
lbC00056A	MOVE.B	(A0)+,(A4)+
	ADDI.W	#1,lbW000F60.L
	CMPI.B	#$20,(A0)
	BNE.S	lbC00056A
	MOVE.B	#$20,(A4)+
	ADDI.W	#1,lbW000F60.L
	CMPI.B	#1,displaymode.L
	BNE.S	lbC0005A6
	SUBA.L	A3,A0
	MOVEQ	#12,D7
	SUB.L	A0,D7
lbC000596	MOVE.B	#$20,(A4)+
	ADDI.W	#1,lbW000F60.L
	DBRA	D7,lbC000596
lbC0005A6	ADDQ.W	#1,lbW000B2A.L
	MOVE.W	lbW000B2A(PC),D1
	MOVE.W	#5,D0
	CMPI.B	#1,displaymode.L
	BEQ.S	lbC0005C0
	ADDQ.W	#1,D0
lbC0005C0	CMP.W	D0,D1
	BNE.S	lbC000614
	MOVE.B	#10,(A4)+
	ADDI.W	#1,lbW000F60.L
	MOVE.W	#0,lbW000B2A.L
	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#lbL000F8A,D2
	MOVE.L	A4,D3
	SUBI.L	#lbL000F8A,D3
	CMPI.B	#2,displaymode.L
	BNE.S	lbC000604
	MOVEQ	#$51,D0
	SUB.W	lbW000F60(PC),D0
	LSR.L	#1,D0
	SUB.L	D0,D2
	ADD.L	D0,D3
lbC000604	JSR	_LVOWrite(A6)
	LEA	lbL000F8A(PC),A4
	MOVE.W	#0,lbW000F60.L
lbC000614	MOVEA.L	(SP)+,A0
	ADDA.L	#$21,A0
	BRA.L	lbC0004A8

lbC000620
  ADD.L #1,dateoffset
  MOVE.L dateoffset,D0
  CMP.L numdays,D0
  BNE showallfiles
  

	TST.W	lbW000B2A.L
	BEQ.L	lbC00067A
	MOVE.B	#10,(A4)+
	ADDI.W	#1,lbW000F60.L
	MOVE.W	#0,lbW000B2A.L
	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#lbL000F8A,D2
	MOVE.L	A4,D3
	SUBI.L	#lbL000F8A,D3
	CMPI.B	#2,displaymode.L
	BNE.S	lbC00066A
	MOVEQ	#$51,D0
	SUB.W	lbW000F60(PC),D0
	LSR.L	#1,D0
	SUB.L	D0,D2
	ADD.L	D0,D3
lbC00066A	JSR	_LVOWrite(A6)
	LEA	lbL000F8A(PC),A4
	MOVE.W	#0,lbW000F60.L
lbC00067A	TST.W	lbW000B2A.L
	BNE.S	lbC0006A2
	TST.W	lbW000B34.L
	BEQ.S	lbC0006A2
	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#lbB000D4F,D2
	MOVE.L	#1,D3
	JSR	_LVOWrite(A6)
lbC0006A2	BRA.S	lbC0006BC

lbC0006A4	MOVEA.L	dosbase(PC),A6
	MOVE.L	stdout(PC),D1
	MOVE.L	#dirfileerrtxt,D2
	MOVE.L	#$21,D3
	JSR	_LVOWrite(A6)
lbC0006BC	TST.L	dirFileData.L
	BEQ.S	lbC0006DA
	MOVEA.L	4.W,A6
	MOVEA.L	dirFileData(PC),A1
	MOVE.L	dirFileLength(PC),D0
	JSR	_LVOFreeMem(A6)
	CLR.L	dirFileData.L
lbC0006DA	RTS

calcdaystats
	MOVEA.L	dirFileData(PC),A0
	MOVEA.L	A0,A2
	ADDA.L	dirFileLength(PC),A2
lbC000700	LEA	todaystr(PC),A1
	CMPA.L	A0,A2
	BLE.L	calcyesterdaystats
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC000700
	CMPI.B	#"9",-15(A0)  
	BGT.S	lbC000778
	CMPI.B	#"0",-15(A0)
	BLT.S	lbC000778
	MOVEQ	#0,D1
	MOVE.B	-$11(A0),D2
	ANDI.B	#15,D2
	ADD.B	D2,D1
	MULU.W	#10,D1
	MOVE.B	-$10(A0),D2
	ANDI.B	#15,D2
	ADD.B	D2,D1
	MULU.W	#10,D1
	MOVE.B	-15(A0),D2
	ANDI.B	#15,D2
	ADD.B	D2,D1
	ADD.L	D1,todaysmegabytes.L
lbC000778	CMPI.B	#"D",-$12(A0)
	BEQ.S	lbC000788 
	ADDQ.W	#1,todaysfilecount.L
	BRA.S	lbC00078E

lbC000788	ADDQ.W	#1,todaysfakecount.L
lbC00078E	BRA.L	lbC000700

calcyesterdaystats
	MOVEA.L	dirFileData(PC),A0
	MOVEA.L	A0,A2
	ADDA.L	dirFileLength(PC),A2
lbC0007B6	LEA	yesterdaystr(PC),A1
	CMPA.L	A0,A2
	BLE.L	statsdone
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	MOVE.B	(A0)+,D0
	CMP.B	(A1)+,D0
	BNE.S	lbC0007B6
	CMPI.B	#"9",-15(A0)
	BGT.S	lbC00082E
	CMPI.B	#"0",-15(A0)
	BLT.S	lbC00082E
	MOVEQ	#0,D1
	MOVE.B	-$11(A0),D2
	ANDI.B	#15,D2
	ADD.B	D2,D1
	MULU.W	#10,D1
	MOVE.B	-$10(A0),D2
	ANDI.B	#15,D2
	ADD.B	D2,D1
	MULU.W	#10,D1
	MOVE.B	-15(A0),D2
	ANDI.B	#15,D2
	ADD.B	D2,D1
	ADD.L	D1,yesterdaysmegabytes.L
lbC00082E	CMPI.B	#"D",-$12(A0)
	BEQ.S	lbC00083E
	ADDQ.W	#1,yesterdaysfilecount.L
	BRA.S	lbC000844

lbC00083E	ADDQ.W	#1,yesterdaysfakecount.L
lbC000844	BRA.L	lbC0007B6

statsdone  RTS

updateplaceholders	MOVEA.L	currBlockStart(PC),A0
	MOVEA.L	currBlockEnd(PC),A1
lbC000850	CMPA.L	A0,A1
	BEQ.L	lbC00097C
	CMPI.B	#"@",(A0)+
	BNE.S	lbC000850
	CMPI.B	#"D",(A0) 
	BEQ.S	daysplaceholder   ;found @D number of days placeholder
	CMPI.B	#"N",(A0) 
	BEQ.S	lbC000888         ;found @N (number of todays files)
	CMPI.B	#$46,(A0)
	BEQ.S	lbC0008A6         ;found @F (number of todays fakes)
	CMPI.B	#$4D,(A0)
	BEQ.S	lbC0008C4         ;found @M (todays megabytes)
	CMPI.B	#$59,(A0)
	BEQ.L	lbC000900         ;found @Y (number of yesterdays files)
	CMPI.B	#$5A,(A0)
	BEQ.L	lbC000920         ;found @Z (number of yesterdays fakes)
	CMPI.B	#$42,(A0)
	BEQ.L	lbC000940         ;found @B (yesterdays megabytes)
	BRA.L	lbC000850

daysplaceholder
	MOVE.B	#$30,-1(A0)
	MOVE.B	#$30,(A0)
	MOVEQ	#0,D0
	MOVE.L	numdays,D0
	DIVU.W	#10,D0
	ADD.B	D0,-1(A0)
	SWAP	D0
	ADD.B	D0,(A0)
	BRA.S	lbC000850

lbC000888	MOVE.B	#$30,-1(A0)
	MOVE.B	#$30,(A0)
	MOVEQ	#0,D0
	MOVE.W	todaysfilecount(PC),D0
	DIVU.W	#10,D0
	ADD.B	D0,-1(A0)
	SWAP	D0
	ADD.B	D0,(A0)
	BRA.S	lbC000850

lbC0008A6	MOVE.B	#$30,-1(A0)
	MOVE.B	#$30,(A0)
	MOVEQ	#0,D0
	MOVE.W	todaysfakecount(PC),D0
	DIVU.W	#10,D0
	ADD.B	D0,-1(A0)
	SWAP	D0
	ADD.B	D0,(A0)
	BRA.L	lbC000850

lbC0008C4	MOVE.B	#$30,-1(A0)
	MOVE.B	#$30,(A0)
	MOVEQ	#0,D0
	MOVE.L	todaysmegabytes(PC),D0
	DIVU.W	#10,D0
	ANDI.L	#$FFFF,D0
	DIVU.W	#10,D0
	SWAP	D0
	ADD.B	D0,2(A0)
	SWAP	D0
	ANDI.L	#$FFFF,D0
	DIVU.W	#10,D0
	ADD.B	D0,-1(A0)
	SWAP	D0
	ADD.B	D0,(A0)
	BRA.L	lbC000850

lbC000900	MOVE.B	#$30,-1(A0)
	MOVE.B	#$30,(A0)
	MOVEQ	#0,D0
	MOVE.W	yesterdaysfilecount(PC),D0
	DIVU.W	#10,D0
	ADD.B	D0,-1(A0)
	SWAP	D0
	ADD.B	D0,(A0)
	BRA.L	lbC000850

lbC000920	MOVE.B	#$30,-1(A0)
	MOVE.B	#$30,(A0)
	MOVEQ	#0,D0
	MOVE.W	yesterdaysfakecount(PC),D0
	DIVU.W	#10,D0
	ADD.B	D0,-1(A0)
	SWAP	D0
	ADD.B	D0,(A0)
	BRA.L	lbC000850

lbC000940	MOVE.B	#$30,-1(A0)
	MOVE.B	#$30,(A0)
	MOVEQ	#0,D0
	MOVE.L	yesterdaysmegabytes(PC),D0
	DIVU.W	#10,D0
	ANDI.L	#$FFFF,D0
	DIVU.W	#10,D0
	SWAP	D0
	ADD.B	D0,2(A0)
	SWAP	D0
	ANDI.L	#$FFFF,D0
	DIVU.W	#10,D0
	ADD.B	D0,-1(A0)
	SWAP	D0
	ADD.B	D0,(A0)
	BRA.L	lbC000850

lbC00097C	RTS

decrypttext	LEA	handsofftext(PC),A0
	MOVE.L	#lbL000D50,D7
	SUB.L	A0,D7
	SUBQ.L	#1,D7
	MOVE.B	#$FF,D0
	ANDI.B	#$55,D0
lbC000994	EOR.B	D0,(A0)+
	DBRA	D7,lbC000994
	RTS

;calculate checksum over text
calccrc	LEA	handsofftext(PC),A0
	MOVE.L	#lbL000D50,D7
	SUB.L	A0,D7
	SUBQ.L	#1,D7
	MOVEQ	#0,D0
lbC0009AC	ADD.B	(A0)+,D0
	DBRA	D7,lbC0009AC
	TST.L	lbL000B88.L
	BNE.S	lbC0009C2
	MOVE.L	D0,lbL000B88.L        ;save calculated checksum
	BRA.S	lbC0009CC

lbC0009C2	CMP.L	lbL000B88(PC),D0    ;compare checksum
	BEQ.S	lbC0009CC
	MOVEQ	#1,D0       ;bad
	RTS

lbC0009CC	MOVEQ	#0,D0   ;good
	RTS

dosbase	dc.l	0
dosname	dc.b	'dos.library',0
result	dc.b	0
displaymode	dc.b	0
filename	dc.l	0
filedataPtr	dc.l	0
filelengthPtr	dc.l	0
stdout	dc.l	0
configfileLength	dc.l	0
configfileData	dc.l	0
currentConfigBlock	dc.l	0
nextConfigBlock	dc.l	0
cmdparams	dc.l	0
cmdparamslen	dc.l	0
lbL000A0A	dc.l	0
lbL000A0E	dc.l	0
lbL000A12	dc.l	0
dirFilename	dcb.l	$3F,0
	dcb.l	2,0
dirFileData	dc.l	0
dirFileLength	dc.l	0
currBlockStart	dc.l	0
currBlockEnd	dc.l	0
lbW000B2A	dc.w	0
todaysfilecount	dc.w	0
todaysfakecount	dc.w	0
todaysmegabytes	dc.l	0
lbW000B34	dc.w	0
yesterdaysfilecount	dc.w	0
yesterdaysfakecount	dc.w	0
yesterdaysmegabytes	dc.l	0
datestamp	dcb.l	3,0
	dc.l	$2000000
	dc.w	0
lbL000B50	dc.l	todaystr
	dc.l	lbL000B68
todaystr	dcb.l	4,0
lbL000B68	dcb.l	4,0
yesterdaystr	dcb.l	4,0
lbL000B88	dc.l	$A0

argstemplate dc.b "FILE/A,DAYS/N",0

handsofftext	dc.b	10,"Get your hands out of my tools !!!",10
quicknewtext	dc.b	27,"[44;33m  QuickNew V2.2 by Calypso/GOD & REbEL/QTX",27,"[36m Date : "
lbB000BEB	dc.b	"          ",27,"[35m Time : "
lbB000C07	dc.b  "          ",10  ;,27,"[0;44m  UNREGISTERED !               Please register !               UNREGISTERED !  "
          dc.b 27,"[0m",10
nocfgerrtext	dc.b	"ERROR : No Config-File Given !",10,10
missingcfgerrtxt	dc.b	"ERROR : Couldn't Open Config-File !",10,10
nomemerrtxt	dc.b	"ERROR : Not Enough Memory !",10,10
filereaderrtxt	dc.b	"ERROR : Couldn't Read Out Of Config-File !!!",10,10
badtimeerrtxt	dc.b	"ERROR : Couldn't Get The Time !",10,10
dirfileerrtxt	dc.b	"ERROR : Couldn't Open DirFile !",10,10
          dc.b  "Found @ !",10,10
lbB000D4A	dc.b  10,10,"   "
lbB000D4F	dc.b	10
lbL000D50	dcb.l	$3F,0
	dcb.l	2,0
filehandle	dc.l	0
filelock	dc.l	0

    cnop 0,4
lbL000E5C	dcb.l	$3F,0
	dcb.l	2,0
lbW000F60	dc.w	0
	dcb.w	$14,$2020
lbL000F8A	dcb.l	$28,0
	dcb.b	2,1

args	dc.l 0
argsdata
paramfilename	dc.l 0
numdaysptr	dc.l 0

dateoffset	dc.l 0
numdays	dc.l 1
	end
