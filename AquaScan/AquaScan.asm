 ; IRA V2.11 (Jan  8 2025) (c)1993-1995 Tim Ruehsen
; (c)2009-2024 Frank Wille, (c)2014-2019 Nicolas Bastien
;
; ==================================================================
; AquaScan v1.1 by Aquarius/OTL & REbEL/QTX
;
; An Ami-Express BBS "door" (external add-on program). It scans the
; caller's message conferences for new messages/files ("conference
; scan") and reports the results back to the terminal.
;
; This file is a disassembly (via IRA) of the original 68k binary.
; It has been annotated here for readability:
;   - Data labels that hold literal strings were renamed from the
;     generic LAB_xxxx form to a descriptive STR_xxxx form derived
;     from their text content (e.g. LAB_5E -> STR_OUT_OF_MEMORY).
;   - Every call through a library base (JSR _LVOxxx(A6)) has an
;     inline comment naming the AmigaOS function and its parameters.
;   - Banner comments mark the start of each subroutine (SUB_xxxx)
;     and note how many places call it.
;   - Code branch-target labels (LAB_xxxx used only as jump targets
;     inside a routine, not as data) were left unchanged, since their
;     original names already work fine as local labels and the
;     control flow they represent was not reverse engineered here.
;
; None of these changes alter any opcode, operand, or data byte, so
; the program reassembles to an identical binary.
; ==================================================================

ABSEXECBASE	EQU	$4


; Custom equates (from config file)
_LVOAllocDosObject	EQU	-228
_LVOAllocMem	EQU	-198
_LVOClose	EQU	-36
_LVOCloseLibrary	EQU	-414
_LVOCreateMsgPort	EQU	-666
_LVOCurrentDir	EQU	-126
_LVODateStamp	EQU	-192
_LVODateToStr	EQU	-744
_LVODelay	EQU	-198
_LVODeleteFile	EQU	-72
_LVODeleteMsgPort	EQU	-672
_LVOExamine	EQU	-102
_LVOFindPort	EQU	-390
_LVOFindToolType	EQU	-96
_LVOForbid	EQU	-132
_LVOFreeArgs	EQU	-858
_LVOFreeDiskObject	EQU	-90
_LVOFreeDosObject	EQU	-234
_LVOFreeMem	EQU	-210
_LVOGetDiskObject	EQU	-78
_LVOGetMsg	EQU	-372
_LVOIoErr	EQU	-132
_LVOLock	EQU	-84
_LVOOpen	EQU	-30
_LVOOpenFromLock	EQU	-378
_LVOOpenLibrary	EQU	-552
_LVOPermit	EQU	-138
_LVOPrintFault	EQU	-474
_LVOPutMsg	EQU	-366
_LVORead	EQU	-42
_LVOReadArgs	EQU	-798
_LVOReplyMsg	EQU	-378
_LVOSeek	EQU	-66
_LVOStrToDate	EQU	-750
_LVOSystemTagList	EQU	-606
_LVOUnLock	EQU	-90
_LVOWait	EQU	-318
_LVOWaitPort	EQU	-384
dosbase	EQU	$15E	; DOOR_ struct field: dos.library base (saved from A3)
iconbase	EQU	$162	; DOOR_ struct field: icon.library base (from OpenLibrary)

; ------------------------------------------------------------------
; Fields of the door's 0x166-byte context/state block (see main(), where
; it is allocated with AllocMem and kept in the local variable at $11C(A7)).
; Offsets/sizes were recovered by tracing accesses made directly off a
; freshly-loaded copy of that pointer within main(); fields whose purpose
; could not be pinned down are named generically (Word_/Long_/Ptr_ + offset)
; rather than guessed. dosbase ($15E) and iconbase ($162) below complete
; the block (offset $162 + 4 bytes = $166, matching the allocation size).
; ------------------------------------------------------------------
DOOR_pEnvironment	EQU	$0	; L         saved copy of the pointer main() was entered with (A5)
DOOR_Msg  EQU $C
DOOR_PortNameBuf	EQU	$18	; buf(0x66) in-place sprintf("AEDoorPort%d", node) buffer
DOOR_pToolTypeArray	EQU	$2C	; L         pointer passed as the ToolTypeArray arg to FindToolType
DOOR_Flag_007E	EQU	$7E	; W         word flag; init 1, cleared later at one point
DOOR_Word_0080	EQU	$80	; W         word; cleared at init, purpose not established
DOOR_Word_0082	EQU	$82	; W         word; cleared at init, later set to 1 (on/off flag)
DOOR_Flag_0084	EQU	$84	; B         byte flag; set TRUE ($FF) at init
DOOR_Word_0086	EQU	$86	; W         word; cleared at init, purpose not established
DOOR_Ptr_008C	EQU	$8C	; L         pointer; cleared at init, purpose not established
DOOR_pConfListA	EQU	$94	; L         pointer; cleared at init; later read and dereferenced (+8) as a linked conference-record list
DOOR_pConfListB	EQU	$98	; L         pointer; cleared at init; when non-null, treated as a conference-record pointer (+0x36 field read)
DOOR_pConfListC	EQU	$9C	; L         pointer; cleared at init; later assigned and dereferenced (+0x36)
DOOR_pConfListD	EQU	$A0	; L         pointer; cleared at init; later assigned from a subroutine result and dereferenced
DOOR_pUserOrConfig	EQU	$A4	; L         pointer; set from SUB_4420's return value
DOOR_DateStampA	EQU	$A8	; buf(0x10) embedded date/time buffer, paired with DOOR_DateStampB via SUB_7852/SUB_75A8
DOOR_PackedConfBits	EQU	$B0	; L         packed longword; a nibble (bits 8-11) is extracted and used as the Date/Div config-file number suffix
DOOR_AccessFlags	EQU	$B1	; B         byte flags; bit 3 tested to gate the "requires higher access" message
DOOR_DateStampB	EQU	$B8	; buf(0x10) second embedded date/time buffer, see DOOR_DateStampA
DOOR_DivFlag	EQU	$C8	; B         TRUE/FALSE result of a keyword search for "div"
DOOR_DateFlag	EQU	$C9	; B         TRUE/FALSE result of a keyword search for "date"
DOOR_Ptr_00CE	EQU	$CE	; L         pointer; cleared at init, purpose not established
DOOR_Word_00F6	EQU	$F6	; W         word; cleared at init, purpose not established
DOOR_Ptr_00F8	EQU	$F8	; L         pointer; cleared at init, later assigned from a call result
DOOR_Long_00FC	EQU	$FC	; L         longword; assigned right after DOOR_Ptr_00F8 (likely a paired size/count)
DOOR_ConfigBlockA	EQU	$100	; buf(0x50) embedded record filled via a helper (sendDoorGetValueMsg/SUB_7F84); its first longword doubles as a count that defaults to $18 (24) when zero
DOOR_Counter_0104	EQU	$104	; L         counter; cleared at init, incremented by 2 and reassigned during the conference-scan loop
DOOR_Word_0108	EQU	$108	; W         word; cleared at init, purpose not established
DOOR_Word_010A	EQU	$10A	; W         word; cleared at init, tested later
DOOR_Word_010E	EQU	$10E	; W         word; init 1, later reassigned to a boolean compare result
DOOR_Word_0110	EQU	$110	; W         word; init 1, purpose not established
DOOR_Flag_0112	EQU	$112	; W         word flag; cleared then set to 1
DOOR_Flag_0116	EQU	$116	; W         word flag; set to 1 (init and later), also reassigned from a compare result
DOOR_pToolTypeResultA	EQU	$120	; L         pointer; result of a FindToolType lookup in the conference-scan loop
DOOR_pToolTypeResultB	EQU	$124	; L         pointer; result of another FindToolType lookup in the conference-scan loop
DOOR_ConfigBlockB	EQU	$150	; buf(0xE)  second embedded record, filled the same way as DOOR_ConfigBlockA
DOOR_Long_0156	EQU	$156	; L         longword; cleared at init, purpose not established
DOOR_pDosObject	EQU	$15A	; L         pointer; result of AllocDosObject (e.g. a FileInfoBlock)
DOOR_flagged EQU $166




	SECTION S_0,CODE

; ------------------------------------------------------------------
; Startup stub: fetches the WBStartup/argument pointer that Ami-Express
; passed in, then jumps into main(). Standard AmigaDOS C-style startup.
; ------------------------------------------------------------------
SECSTRT_0:
	BSR.W	SUB_7E28
	MOVEA.L	D0,A0
	BSR.W	main
	MOVEQ	#0,D0
	RTS
; ------------------------------------------------------------------
; String and constant data table (referenced from the code below).
; Printable-text labels have been renamed STR_xxxx; see file header.
; ------------------------------------------------------------------
LAB_E:
	DS.B	1
STR_PPC:
	DC.B	"PPC_",0
STR_PPC_2:
	DC.B	"PPC_",0,0
DosLibName:
	DC.B	"dos.library",0
ArgsTemplate:
	DC.B	"NODE/N/A",0,0
DoorPortName:
	DC.B	"AEDoorPort%d",0
	DS.B	1
IconLibName:
	DC.B	"icon.library",0
	DS.B	1
OutOfMemoryText:
	DC.B	"Out of memory!",$D
	DC.B	$0a
	DS.W	1
LAB_5E:
	DC.W	$3800
STR_ERROR_LOADING_CONFIG_ICON_TE:
	DC.B	"Error loading config icon/text!",$D
	DC.W	$0a00
STR_DIV:
	DC.B	"div",0
STR_DATE:
	DC.B	"date",0,0
STR_CLS:
	DC.W	$0c00
STR_DOORS_AQUASCAN_AQUASCAN_DATE:
	DC.B	"Doors:AquaScan/AquaScan.Date.%d",0
STR_DOORS_AQUASCAN_AQUASCAN_DIV:
	DC.B	"Doors:AquaScan/AquaScan.Div.%d",0,0
STR_HOLD_LEVEL:
	DC.B	"HOLD_LEVEL",0
	DS.B	1
STR_SCANNING_THE_HOLD_DIR_REQUIR:
	DC.B	"Scanning the HOLD dir requires higher access!",$D
	DC.W	$0a00
STR_WHITE_IS_ZERO:
	DC.B	"WHITE_IS_ZERO",0
LAB_118:
	DC.L	$4e4f0000
STR_LONG_NUKE:
	DC.B	"LONG_NUKE",0
LAB_126:
	DC.L	$59455300
STR_CONFCONFIG:
	DC.B	"%sConfConfig",0,0
STR_NCONFS:
	DC.B	"NCONFS",0
	DS.B	1
STR_0MCONFCONFIG_INFO_ERROR:
	DC.B	$1b
	DC.B	"[0mCONFCONFIG.info error!",$D
	DC.B	$0a
	DS.W	1
STR_ACCESS_AREA:
	DC.B	"%sACCESS/AREA.",0
	DS.B	1
STR_COULDN_T_LOAD_AREA_ICON:
	DC.B	"Couldn't load area icon!!",$D
	DC.W	$0a00
STR_CALLERSLOG:
	DC.B	"CALLERSLOG",0
	DS.B	1
STR_CONFERENCE_SCAN_WITH_AQUASCA:
	DC.B	$09
	DC.B	"Conference Scan with AquaScan by Aquarius"
	DC.W	$0a00
STR_NOSCAN_FROMCONF:
	DC.B	"NOSCAN_FROMCONF",0
STR_LOCATION:
	DC.B	"LOCATION.%d",0
STR_NAME:
	DC.B	"NAME.%d",0
STR_NOSCAN_CONF:
	DC.B	"NOSCAN_CONF.%d",0,0
STR_CONF:
	DC.B	"CONF.%d",0
STR_36MCONFERENCE_34M_36M_34M_0M:
	DC.B	$1b
	DC.B	"[36mConference: "
	DC.B	$1b
	DC.B	"[34m[ "
	DC.B	$1b
	DC.B	"[36m%s "
	DC.B	$1b
	DC.B	"[34m]"
	DC.B	$1b
	DC.B	"[0m",$D
	DC.B	$0a
	DS.W	1
STR_TXT:
	DC.B	"TXT",0
STR_0M:
	DC.B	$1b
	DC.B	"[0m",0
	DS.B	1
STR_SP:
	DC.B	"~SP|",0
	DS.B	1
LAB_23C:
	DC.L	$08200800
STR_0M_34M_36MAQUASCAN_V1_1_BY_A:
	DC.W	$0d0a
	DC.B	$1b
	DC.B	"[0m"
	DC.B	$1b
	DC.B	"[34m--[ "
	DC.B	$1b
	DC.B	"[36mAquaScan v1.1 by Aquarius/OTL & REbEL/QTX "
	DC.B	$1b
	DC.B	"[34m]-",0
STR_36M_FOR_OPTIONS_34M_0M:
	DC.W	$5b20
	DC.B	$1b
	DC.B	"[36m'%s ?' for options "
	DC.B	$1b
	DC.B	"[34m]--"
	DC.B	$1b
	DC.B	"[0m",$D
	DC.B	$0a
	DS.W	1
STR_36MCOPYRIGHT_1994_AQUARIUS_3:
	DC.B	"--------[ "
	DC.B	$1b
	DC.B	"[36mCopyright "
	DC.B	$a9
	DC.B	" 1994 Aquarius "
	DC.B	$1b
	DC.B	"[34m]--"
	DC.B	$1b
	DC.B	"[0m",$D
	DC.W	$0a00
STR_0_34M_36M_END_OF_FILE_LIST_3:
	DC.B	$1b
	DC.B	"[0;34m["
	DC.B	$1b
	DC.B	"[36m End of File List "
	DC.B	$1b
	DC.B	"[34m]"
	DC.B	$1b
	DC.B	"[0m",0
STR_0M_BREAK:
	DC.B	$1b
	DC.B	"[0m**Break",0
LAB_316:
	DC.L	$256c7500
STR_0M_FILE:
	DC.B	$1b
	DC.B	"[0m%s[%s File #%s %s]%s",0
	DS.B	1
LAB_334:
	DS.W	1
STR_0M_2:
	DC.B	$1b
	DC.B	"[0m%s%s",0
STR_NULL:
	DS.B	1
STR_0M_C:
	DC.B	$1b
	DC.B	"[0m%s%s%s%s%s%c%s%s%s%s%s%s",0
	DS.B	1
HIGHLIGHT:
  DC.B  $1b,"[1m",0,0
STR_0_36MMORE_32M_33MY_32M_33MN:
	DC.B	$1b
	DC.B	"[0;36mMore? "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mY"
	DC.B	$1b
	DC.B	"[32m/"
	DC.B	$1b
	DC.B	"[33mn"
	DC.B	$1b
	DC.B	"[32m/"
	DC.B	$1b
	DC.B	"[33mns"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m, "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mC"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36mlear, ",0
	DS.B	1
STR_32M_33MF_32M_33MR_32M_36M_FL:
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mF"
	DC.B	$1b
	DC.B	"[32m/"
	DC.B	$1b
	DC.B	"[33mR"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m Flag, ",0
	DS.B	1
STR_32M_33MF_32M_36MLAG:
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mF"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36mlag, ",0
	DS.B	1
STR_32M_33MS_32M_36MKIP_CONF:
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mS"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36mkip Conf, ",0
STR_32M_33M_32M_36M_HELP_32M_33M:
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33m?"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m Help, "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mQ"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36muit:"
	DC.B	$1b
	DC.B	"[0m ",0
	DS.B	1
LAB_464:
	DC.B	$D,"                                                            "
	DC.B	"         ",$D,0
LAB_4AC:
	DC.B	$D,"                                                            "
	DC.B	"                   ",$D,0
LAB_4FE:
	DC.W	$0d0c
	DC.B	0
	DS.B	1
STR_N:
	DC.B	"n",0
STR_QUIT:
	DC.B	"Quit",0,0
STR_36MFILE_NAME_S_TO_FLAG_0M:
	DC.B	$1b
	DC.B	"[36mFile name(s) to flag:"
	DC.B	$1b
	DC.B	"[0m ",0
LAB_52A:
	DC.L	$08200808,$20080820,$08082008,$08200808
	DC.L	$20080820,$08082008,$08200808,$20080000
STR_36MFILE_NUMBER_S_TO_FLAG_0M:
	DC.B	$1b
	DC.B	"[36mFile number(s) to flag:"
	DC.B	$1b
	DC.B	"[0m ",0
STR_36MTHESE_ARE_THE_COMMANDS_TH:
	DC.W	$0c0d
	DC.B	$0a
	DC.B	"     "
	DC.B	$1b
	DC.B	"[36mThese are the commands that can be used at the pause prom"
	DC.B	"pt:",$D
	DC.W	$0a00
STR_32M_33MENTER_32M_33MY_32M_33:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mEnter"
	DC.B	$1b
	DC.B	"[32m),("
	DC.B	$1b
	DC.B	"[33mY"
	DC.B	$1b
	DC.B	"[32m),("
	DC.B	$1b
	DC.B	"[33mSpace"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .. "
	DC.B	$1b
	DC.B	"[36mContinue file scanning",0
	DS.B	1
STR_32M_33MC_32M_34M_36MCLEAR_SC:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mC"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mClear screen and continue scanning",0
	DS.B	1
STR_32M_33MDOWNARROW_32M_33M3_32:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mDownArrow"
	DC.B	$1b
	DC.B	"[32m),("
	DC.B	$1b
	DC.B	"[33m3"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m ...... "
	DC.B	$1b
	DC.B	"[36mGo one page down",0
	DS.B	1
STR_32M_33MUPARROW_32M_33M9_32M:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mUpArrow"
	DC.B	$1b
	DC.B	"[32m),("
	DC.B	$1b
	DC.B	"[33m9"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m ........ "
	DC.B	$1b
	DC.B	"[36mGo one page up (back)",0
STR_32M_33M7_32M_34M_36MGO_TO_ST:
	DC.B	"      ",$1B
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33m7"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mGo to start of listing",0
	DS.B	1
STR_32M_33M5_32M_34M_36MREDRAW_P:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33m5"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mRedraw page",0
STR_32M_33MNS_32M_34M_36MTURN_ON:
	DC.B	"      ",$1B
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mNS"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m ................. "
	DC.B	$1b
	DC.B	"[36mTurn on non-stop scrolling",0
	DS.B	1
STR_32M_33M_32M_34M_36MVIEW_THIS:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33m?"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mView this help page",0
STR_32M_33MF_32M_34M_36MFLAG_FIL:
	DC.B	"      ",$1B
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mF"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mFlag files by name",0
	DS.B	1
STR_32M_33MR_32M_33M_32M_34M_36M:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mR"
	DC.B	$1b
	DC.B	"[32m),("
	DC.B	$1b
	DC.B	"[33m#"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .............. "
	DC.B	$1b
	DC.B	"[36mFlag files by number",0
	DS.B	1
STR_32M_33MK_32M_34M_36MSKIP_DIR:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mK"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mSkip dir",0
	DS.B	1
STR_32M_33MS_32M_34M_36MSKIP_CON:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mS"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mSkip conf",0
STR_32M_33ML_32M_34M_36MRELOAD_D:
	DC.B	"      ",$1B
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mL"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mReload dir",0
	DS.B	1
STR_32M_33MN_32M_33MQ_32M_34M_36:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mN"
	DC.B	$1b
	DC.B	"[32m),("
	DC.B	$1b
	DC.B	"[33mQ"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .............. "
	DC.B	$1b
	DC.B	"[36mQuit",0
	DS.B	1
STR_32M_33MCTRL_C_32M_34M_36MQUI:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mCtrl-C"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m ............. "
	DC.B	$1b
	DC.B	"[36mQuit (Can be used at any time)",0
	DS.B	1
STR_32M_33MD_32M_34M_36MQUIT_AND:
	DC.B	"      "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mD"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36mQuit and download",0
STR_PPC_3:
	DC.B	"PPC_",0,0
STR_DSC_HU:
	DC.B	"DSC.%hu",0
STR_32M_33M_C_32M_34M_36M_0M:
	DC.B	"    %s ",$1B
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33m%c"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[34m .................. "
	DC.B	$1b
	DC.B	"[36m%s"
	DC.B	$1b
	DC.B	"[0m",0
	DS.B	1
STR_0M_3:
	DC.B	$1b
	DC.B	"[0m*",0
LAB_AE2:
	DC.W	$2000
STR_36M_CAN_ONLY_BE_USED_IN_YOUR:
	DC.W	$0d0a
	DC.B	" *"
	DC.B	$1b
	DC.B	"[36m) Can only be used in your current conference.",0
STR_DOWNLOAD:
	DC.B	"Download",0,0
LAB_B26:
	DC.W	$4400
STR_PPC_CMD_HU:
	DC.B	"PPC_CMD.%hu",0
STR_PPC_NUM_HU:
	DC.B	"PPC_NUM.%hu",0
STR_36M_0M_36M_FILE_NUMBER_S_0M:
	DC.B	$1b
	DC.B	"[36m["
	DC.B	$1b
	DC.B	"[0m%s"
	DC.B	$1b
	DC.B	"[36m] File number(s): "
	DC.B	$1b
	DC.B	"[0m",0
STR_36MTHAT_COMMAND_CAN_ONLY_BE:
	DC.B	$1b
	DC.B	"[36mTHAT COMMAND CAN ONLY BE USED IN YOUR CURRENT CONFERENCE!"
	DC.B	0
	DS.B	1
STR_36MNON_STOP_SCROLLING_ARE_YO:
	DC.B	$1b
	DC.B	"[36mNon-stop scrolling! Are you sure "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mY"
	DC.B	$1b
	DC.B	"[32m/"
	DC.B	$1b
	DC.B	"[33mn"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m? ",0
STR_ARGUMENT_ERROR_TYPE_FOR_HELP:
	DC.B	"Argument error! Type '%s ?' for help.",$D,$A,0
STR_DOORUSE:
	DC.B	"DOORUSE.%s",0
	DS.B	1
STR_FILESCAN:
	DC.B	"FILESCAN",0
	DS.B	1
STR_NEWSCAN:
	DC.B	"NEWSCAN",0
STR_REVSCAN:
	DC.B	"REVSCAN",0
STR_CONFSCAN:
	DC.B	"CONFSCAN",0,0
STR_CONFIG_ERROR_TOOLTYPE_INVALI:
	DC.B	"Config error: Tooltype %s invalid!",$D
	DC.B	$0a
	DS.W	1
STR_CONFIG_ERROR_TOOLTYPE_MISSIN:
	DC.B	"Config error: Tooltype %s missing!",$D
	DC.B	$0a
	DS.W	1
LAB_C98:
	DC.W	$7200
LAB_C9A:
	DC.W	$7300
LAB_C9C:
	DC.W	$7400
LAB_C9E:
	DC.W	$7900
LAB_CA0:
	DC.W	$7500
LAB_CA2:
	DC.W	$6800
LAB_CA4:
	DC.W	$6100
LAB_CA6:
	DC.W	$7700
LAB_CA8:
	DC.W	$6500
LAB_CAA:
	DC.W	$3f00
LAB_CAC:
	DC.L	$6e730000
LAB_CB0:
	DC.W	$7100
LAB_CB2:
	DC.B	"%s-%s",0
STR_DOORS_AQUASCAN_AQUASCAN_HELP:
	DC.B	"Doors:AquaScan/AquaScan.Help.%s",0
STR_DOORS_AQUASCAN:
	DC.B	"Doors:AquaScan/",0
STR_DOORS_AQUASCAN_AQUASCANCONFI:
	DC.B	"Doors:AquaScan/AquaScanConfig",0
STR_AQUASCANCONFIG:
	DC.B	"AquaScanConfig %d %d",0,0
STR_CONFIGURATION_PROGRAM_IS_UNA:
	DC.B	"Configuration program is unavailable!",$D
	DC.W	$0a00
STR_NDIRS:
	DC.B	"NDIRS",0
STR_36MDATE_32M_33MMM_DD_YY_32M:
	DC.B	$1b
	DC.B	"[36mDate: "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mMM-DD-YY"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m, "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33m-X"
	DC.B	$1b
	DC.B	"[32m) "
	DC.B	$1b
	DC.B	"[36mDays, "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mR"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36meverse, "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mEnter"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m=%s ?"
	DC.B	$1b
	DC.B	"[0m ",0
	DS.B	1
STR_ERROR_IN_DATE:
	DC.B	$D
	DC.B	$0a
	DC.B	"Error in date!",$D
	DC.B	$0a
	DS.W	1
STR_FILEHELP:
	DC.B	"FileHelp",0
	DS.B	1
STR_36MDIRECTORIES_32M_33M1_32M:
	DC.B	$1b
	DC.B	"[36mDirectories: "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33m1-%d"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m, "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mA"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36mll, "
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mU"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36mpload, %s"
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mEnter"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36m=None ?"
	DC.B	$1b
	DC.B	"[0m ",0
	DS.B	1
STR_32M_33MH_32M_36MOLD:
	DC.B	$1b
	DC.B	"[32m("
	DC.B	$1b
	DC.B	"[33mH"
	DC.B	$1b
	DC.B	"[32m)"
	DC.B	$1b
	DC.B	"[36mold, ",0
	DS.B	1
STR_ERROR_IN_INPUT:
	DC.W	$0d0a
	DC.B	"Error in input!",$D
	DC.W	$0a00
STR_DIRECTORY_SCAN_WITH_AQUASCAN:
	DC.B	$09
	DC.B	"Directory Scan with AquaScan by Aquarius"
	DC.B	$0a
	DS.W	1
STR_HOLD_HELD:
	DC.B	"/Hold/Held",0
	DS.B	1
STR_DIR:
	DC.B	"/Dir%d",0
	DS.B	1
STR_THE_HIGHEST_DIRECTORY_NUMBER:
	DC.B	"The highest directory number is %d!",0
STR_NO_FILES_AVAILABLE_IN_THIS_C:
	DC.B	"No files available in this conference!",0,0
STR_COULDN_T_LOAD_CONFERENCE_ICO:
	DC.B	"Couldn't load conference icon!",0
	DS.B	1
STR_OUT_OF_MEMORY:
	DC.B	" Out of memory!",0
STR_OK:
	DC.B	" Ok!",$D,$A,0,0
STR_NOTHING_FOUND:
	DC.B	" Nothing found!",0
STR_ERROR_READING_DIR_FILE:
	DC.B	" Error reading dir file!",0,0
STR_ERROR_OPENING_DIR_FILE:
	DC.B	" Error opening dir file!",0
	DS.B	1
STR_REVERSE_SCANNING:
	DC.B	"Reverse-scanning ",0
STR_SCANNING:
	DC.B	"Scanning ",0
STR_HOLD_DIR:
	DC.B	"HOLD dir",0,0
STR_DIR_2:
	DC.B	"dir %d",0
	DS.B	1
STR_FROM_TOP:
	DC.B	" from top",0
STR_FOR:
	DC.B	" for ",0
STR_FOR_THE_LAST_FILE:
	DC.B	" for the last file",0,0
STR_FOR_THE_LAST_FILES:
	DC.B	" for the last %d files",0
	DS.B	1
LAB_102E:
	DC.B	"...",0
LAB_1032:
	DC.B	"@@-@@-@@",0,0
STR_37M:
	DC.B	$1b
	DC.B	"[37m",0
STR_31M:
	DC.B	$1b
	DC.B	"[31m",0
ansiGreen:
	DC.B	$1b
	DC.B	"[32m",0
STR_33M:
	DC.B	$1b
	DC.B	"[33m",0
STR_34M:
	DC.B	$1b
	DC.B	"[34m",0
STR_35M:
	DC.B	$1b
	DC.B	"[35m",0
ansiCyan:
	DC.B	$1b
	DC.B	"[36m",0
STR_KEY_HU:
	DC.B	"KEY.%hu",0
STR_CMD_HU:
	DC.B	"CMD.%hu",0
STR_ERROR_IN_TOOLTYPE:
	DC.B	"Error in tooltype %s!",$D,$A,0
STR_ERROR_IN_TOOLTYPE_KEY_IS_ALR:
	DC.B	"Error in tooltype %s! Key is already taken.",$D
	DC.W	$0a00
STR_ACS_HU:
	DC.B	"ACS.%hu",0
STR_CNF_HU:
	DC.B	"CNF.%hu",0
STR_NUM_HU:
	DC.B	"NUM.%hu",0
STR_MISSING_TOOLTYPE_IN_CONFIG:
	DC.B	"Missing tooltype in config: %s",$D,$A,0,0
STR_DOORS_AQUASCAN_AQUASCAN:
	DC.B	"Doors:AquaScan/AquaScan",0
STR_DOORS_AQUASCAN_AQUASCAN_CONF:
	DC.B	"Doors:AquaScan/AquaScan.config",0,0
STR_DOORS_AQUASCAN_AQUASCAN_2:
	DC.B	"Doors:AquaScan/AquaScan.%s.%d",0
STR_DOORS_AQUASCAN_AQUASCAN_USER:
	DC.B	"Doors:AquaScan/AquaScan.UserData",0,0
STR_FILE_NAME:
	DC.B	"FILE_NAME",0
STR_FILE_TEST:
	DC.B	"FILE_TEST",0
STR_FILE_SIZE:
	DC.B	"FILE_SIZE",0
STR_FILE_DATE:
	DC.B	"FILE_DATE",0
STR_FILE_DESC:
	DC.B	"FILE_DESC",0
STR_SEPARATOR:
	DC.B	"SEPARATOR",0
STR_NUKE_SIZE:
	DC.B	"NUKE_SIZE",0
STR_FILE_NUMBER:
	DC.B	"FILE_NUMBER",0
STR_DATE_LINE:
	DC.B	"DATE_LINE",0
STR_FILE_NUMBERS:
	DC.B	"FILE_NUMBERS",0,0
STR_COLOUR:
	DC.B	"COLOUR.%s",0
STR_WHITE:
	DC.B	"WHITE",0
LAB_11E8:
	DC.L	$52454400
STR_GREEN:
	DC.B	"GREEN",0
STR_YELLOW:
	DC.B	"YELLOW",0,0
STR_BLUE:
	DC.B	"BLUE",0
	DS.B	1
STR_VIOLET:
	DC.B	"VIOLET",0
	DS.B	1
STR_CYAN:
	DC.B	"CYAN",0
	DS.B	1
STR_RANDOM:
	DC.B	"RANDOM",0
	DS.B	1
STR_AQUASCAN_CONFDATA:
	DC.B	"AquaScan.ConfData",0
; ------------------------------------------------------------------
; Subroutine SUB_1228  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_1228:
	SUBQ.W	#4,A7
	MOVEM.L	A2-A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.W	#$0004,A0
	MOVEA.L	(A0),A3
	MOVEA.L	$114(A3),A2
	TST.L	$AC(A2)
	BNE.S	LAB_126C
	LEA	$5C(A2),A0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOWaitPort(A6)	; WaitPort(port) - wait until a message port has a message
	LEA	$5C(A2),A0
	JSR	_LVOGetMsg(A6)	; GetMsg(port) - get next message from a message port
	MOVE.L	D0,$10(A7)
	JSR	_LVOForbid(A6)	; Forbid() - disable task switching
	MOVEA.L	$10(A7),A1
	JSR	_LVOReplyMsg(A6)	; ReplyMsg(msg) - reply to a received message
	MOVEA.L	A5,A0
	MOVEQ	#$A,D0
	BSR.W	SUB_7E30
LAB_126C:
	MOVEM.L	(A7)+,A2-A3/A5-A6
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Program entry point (called from the startup stub above)
; ------------------------------------------------------------------
main:
	SUBA.W	#$0100,A7
	MOVEM.L	D2-D3/D6-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	BSR.S	SUB_1228
	LEA	DosLibName(PC),A1
	MOVEQ	#$24,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOOpenLibrary(A6)	; OpenLibrary(name,version) - open a shared library
	MOVEA.L	D0,A3
	MOVE.L	A3,D0
	BNE.S	LAB_129E
	MOVEA.L	A5,A0
	MOVEQ	#$A,D0
	BSR.W	SUB_7E30
LAB_129E:
	LEA	ArgsTemplate(PC),A0
	MOVE.L	A0,D1
	LEA	$30(A7),A0
	MOVE.L	A0,D2
	MOVEQ	#0,D3
	MOVEA.L	A3,A6
	JSR	_LVOReadArgs(A6)	; ReadArgs(template,array,rdargs) - parse CLI arguments
	MOVE.L	D0,$34(A7)
	TST.L	D0
	BNE.S	LAB_12CE
	JSR	_LVOIoErr(A6)	; IoErr() - return the DOS error code of the last failed call
	MOVE.L	D0,D1
	MOVEQ	#0,D2
	JSR	_LVOPrintFault(A6)	; PrintFault(code,header) - print a DOS error message
	MOVEA.L	A5,A0
	MOVEQ	#5,D0
	BSR.W	SUB_7E30
LAB_12CE:
	MOVEA.L	$30(A7),A0
	MOVE.L	(A0),D7
	MOVE.L	$34(A7),D1
	JSR	_LVOFreeArgs(A6)	; FreeArgs(rdargs) - free ReadArgs() result
	TST.L	D7
	BMI.S	LAB_12E6
	MOVEQ	#$1F,D0
	CMP.L	D0,D7
	BLE.S	LAB_12EE
LAB_12E6:
	MOVEA.L	A5,A0
	MOVEQ	#5,D0
	BSR.W	SUB_7E30
LAB_12EE:
	; Allocate the door's context/state block - see the DOOR_ field table
	; near the top of this file. The pointer lives in this stack slot
	; ($11C(A7)) for the rest of main(); most fields are set up just below.
	MOVE.L	#$00000168,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVE.L	D0,$11C(A7)	; DOOR context pointer, kept in this stack slot throughout main()
	TST.L	D0
	BNE.S	LAB_130E
	MOVEA.L	A5,A0
	MOVEQ	#$A,D0
	BSR.W	SUB_7E30
LAB_130E:
	MOVEA.L	$11C(A7),A0
	MOVE.L	A5,(A0)     ;DOOR_pEnvironment(A0)
	MOVEQ	#1,D0
	MOVE.W	D0,DOOR_Flag_007E(A0)
	CLR.W	DOOR_Word_0080(A0)
	CLR.W	DOOR_Word_0082(A0)
	ST	DOOR_Flag_0084(A0)
	CLR.W	DOOR_Word_0086(A0)
	CLR.L	DOOR_Ptr_008C(A0)
	CLR.L	DOOR_pConfListA(A0)
	CLR.L	DOOR_pConfListB(A0)
	CLR.L	DOOR_pConfListC(A0)
	CLR.L	DOOR_pConfListD(A0)
	CLR.L	DOOR_Ptr_00CE(A0)
	CLR.L	DOOR_Ptr_00F8(A0)
	CLR.W	DOOR_Word_00F6(A0)
	CLR.L	DOOR_Counter_0104(A0)
	CLR.W	DOOR_Word_0108(A0)
	CLR.W	DOOR_Word_010A(A0)
	MOVE.W	D0,DOOR_Word_010E(A0)
	MOVE.W	D0,DOOR_Word_0110(A0)
	CLR.L	DOOR_Long_0156(A0)
	CLR.L	DOOR_pDosObject(A0)
	MOVE.L	A3,dosbase(A0)
  CLR.W DOOR_flagged(A0)

	CLR.L	iconbase(A0)
	LEA	DOOR_PortNameBuf(A0),A1
	MOVE.L	D7,-(A7)
	PEA	DoorPortName(PC)
	MOVE.L	A1,-(A7)
	BSR.W	sprintf
	MOVEA.L	$128(A7),A0
	BSR.W	initAEDoor
	LEA	$C(A7),A7
	TST.L	D0
	BEQ.S	LAB_1398
	MOVEA.L	$11C(A7),A0
	MOVEQ	#$14,D0
	BSR.W	cleanupAEDoor
LAB_1398:
	MOVEA.L	$11C(A7),A0
	MOVEQ	#$68,D0
	BSR.W	sendDoorGetValueMsg      ;DT_SLOTNUMBER
	MOVEA.L	$11C(A7),A0
	ADDA.W	#DOOR_ConfigBlockB,A0	; A0 = &DOOR_ConfigBlockB
	MOVE.L	A0,$24(A7)
	MOVEA.L	D0,A0
	MOVEA.L	$24(A7),A1
	BSR.W	SUB_7F84
	LEA	IconLibName(PC),A1
	MOVEQ	#0,D0
	JSR	_LVOOpenLibrary(A6)	; OpenLibrary(name,version) - open a shared library
	MOVEA.L	D0,A2
	MOVEA.L	A2,A0
	MOVEA.L	$11C(A7),A1
	MOVE.L	A0,iconbase(A1)
	BNE.S	LAB_13D6
	MOVEA.L	A1,A0
	BSR.W	SUB_1D74
LAB_13D6:
	CLR.L	-(A7)
	MOVEQ	#2,D1
	MOVEA.L	A3,A6
	MOVE.L	A7,D2
	JSR	_LVOAllocDosObject(A6)	; AllocDosObject(type,tags) - allocate a DOS structure (e.g. FileInfoBlock)
	LEA	4(A7),A7
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_pDosObject(A0)
	BNE.S	LAB_140C
	MOVEQ	#1,D0
	BSR.W	SUB_22A0
	LEA	OutOfMemoryText(PC),A0
	MOVEA.L	$11C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_140C:
	LEA	LAB_5E(PC),A0
	MOVEA.L	$11C(A7),A1
	MOVEQ	#$5C,D0
	NOT.B	D0
	BSR.W	sendDoorSetValueMsg        ;ENVSTAT
	MOVEA.L	$11C(A7),A0
	MOVEQ	#1,D0
	BSR.W	setNonStop
	MOVEA.L	$11C(A7),A0
	BSR.W	toggleRawArrow
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_223E
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_4420
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_pUserOrConfig(A0)
	BSR.W	SUB_20C6
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_6ED2
	TST.W	D0
	BNE.S	LAB_1476
	MOVEA.L	$11C(A7),A0
	MOVEQ	#1,D0
	BSR.W	SUB_22A0
	LEA	STR_ERROR_LOADING_CONFIG_ICON_TE(PC),A0
	MOVEA.L	$11C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_1476:
	LEA	$108(A7),A0
	MOVEA.L	$11C(A7),A1
	BSR.W	SUB_4526
	MOVE.L	$110(A7),D0
	TST.L	D0
	BEQ.S	LAB_1494
	SUBQ.L	#5,D0
	BEQ.S	LAB_149C
	SUBQ.L	#1,D0
	BEQ.S	LAB_14AC
	BRA.S	LAB_14C6
LAB_1494:
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_149C:
	MOVE.L	$108(A7),D0
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_4C02
	BRA.W	LAB_1A8C
LAB_14AC:
	MOVE.L	D7,D0
	MOVE.L	$108(A7),D1
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_4C56
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
	BRA.W	LAB_1A8C
LAB_14C6:
	MOVEA.L	$11C(A7),A0
	MOVEQ	#$7A,D0
	BSR.W	sendDoorGetValueMsg      ;DT_LINELENGTH
	MOVEA.L	$11C(A7),A0
	ADDA.W	#DOOR_ConfigBlockA,A0	; A0 = &DOOR_ConfigBlockA
	MOVE.L	A0,$24(A7)
	MOVEA.L	D0,A0
	MOVEA.L	$24(A7),A1
	BSR.W	SUB_7F84
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_ConfigBlockA(A0),D0
	TST.L	D0
	BGT.S	LAB_14F8
	MOVEQ	#$18,D0
	MOVE.L	D0,DOOR_ConfigBlockA(A0)
LAB_14F8:
	LEA	STR_DIV(PC),A0
	MOVEA.L	A3,A1
	MOVEQ	#8,D0
	BSR.W	SUB_73FE
	MOVEA.L	$11C(A7),A0
	MOVE.B	D0,DOOR_DivFlag(A0)
	LEA	STR_DATE(PC),A0
	MOVEA.L	A3,A1
	MOVEQ	#8,D0
	BSR.W	SUB_73FE
	MOVEA.L	$11C(A7),A0
	MOVE.B	D0,DOOR_DateFlag(A0)
	LEA	DOOR_DateStampB(A0),A1
	MOVEA.L	A1,A0
	MOVEA.L	$11C(A7),A1
	BSR.W	SUB_7852
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_7456
	MOVEA.L	$11C(A7),A0
	MOVEA.L	A0,A1
	ADDA.W	#DOOR_DateStampA,A1	; A1 = &DOOR_DateStampA
	LEA	DOOR_DateStampB(A0),A6
	MOVE.L	A0,-(A7)
	MOVEA.L	A1,A0
	MOVEA.L	A6,A1
	BSR.W	SUB_75A8
	ADDQ.W	#4,A7
	MOVEA.L	$11C(A7),A0
	BTST	#3,DOOR_AccessFlags(A0)
	BEQ.S	LAB_1568
	MOVEA.L	A0,A1
	LEA	STR_CLS(PC),A0
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_1568:
	MOVEA.L	$11C(A7),A0
	MOVEQ	#1,D0
	BSR.W	SUB_22A0
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_619A
	TST.W	D0
	BNE.S	LAB_1586
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_1586:
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_PackedConfBits(A0),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	BEQ.S	LAB_15BC
	MOVE.L	D0,-(A7)
	PEA	STR_DOORS_AQUASCAN_AQUASCAN_DATE(PC)
	PEA	$40(A7)
	BSR.W	sprintf
	LEA	$44(A7),A0
	MOVEA.L	$128(A7),A1
	BSR.W	SUB_57E8
	LEA	$C(A7),A7
LAB_15BC:
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_PackedConfBits(A0),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	BEQ.S	LAB_1616
	MOVEQ	#1,D1
	CMP.L	D1,D0
	BLE.S	LAB_15FA
	SUBQ.L	#1,D0
	MOVE.L	D0,-(A7)
	PEA	STR_DOORS_AQUASCAN_AQUASCAN_DIV(PC)
	PEA	$40(A7)
	BSR.W	sprintf
	LEA	$44(A7),A0
	MOVEA.L	$128(A7),A1
	BSR.W	SUB_5918
	LEA	$C(A7),A7
	BRA.S	LAB_1616
LAB_15FA:
	MOVE.L	D1,D0
	MOVEQ	#1,D1
	SWAP	D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_Ptr_00F8(A0)
	MOVEQ	#1,D0
	MOVE.L	D0,DOOR_Long_00FC(A0)
LAB_1616:
	MOVEQ	#-1,D0
	CMP.L	$10C(A7),D0
	BEQ.S	LAB_1626
	TST.W	$11A(A7)
	BEQ.W	LAB_16BC
LAB_1626:
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_pConfListB(A0),D0
	BEQ.S	LAB_1638
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_1646
LAB_1638:
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListA(A1),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_1646:
	LEA	STR_HOLD_LEVEL(PC),A1
	MOVEA.L	A2,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$100(A7)
	TST.L	D0
	BEQ.S	LAB_1666
	MOVEA.L	D0,A0
	LEA	$2C(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BNE.S	LAB_166E
LAB_1666:
	MOVE.L	#$000000c8,$2C(A7)
LAB_166E:
	MOVEA.L	$11C(A7),A0
	MOVEQ	#$69,D0
	BSR.W	sendDoorGetValueMsg      ;DT_SECSTATUS
	MOVEA.L	D0,A0
	LEA	$28(A7),A1
	BSR.W	SUB_7F84
	MOVE.L	$2C(A7),D0
	CMP.L	$28(A7),D0
	BLE.S	LAB_16B2
	TST.W	$11A(A7)
	BNE.S	LAB_16A8
	LEA	STR_SCANNING_THE_HOLD_DIR_REQUIR(PC),A0
	MOVEA.L	$11C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_16A8:
	MOVEA.L	$11C(A7),A0
	CLR.W	DOOR_Flag_0112(A0)
	BRA.S	LAB_16BC
LAB_16B2:
	MOVEA.L	$11C(A7),A0
	MOVE.W	#$0001,DOOR_Flag_0112(A0)
LAB_16BC:
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_43A8
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_pConfListB(A0),D0
	BEQ.S	LAB_16D6
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_16E4
LAB_16D6:
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListA(A1),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_16E4:
	LEA	STR_WHITE_IS_ZERO(PC),A1
	MOVEA.L	A2,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$100(A7)
	TST.L	D0
	BEQ.S	LAB_170C
	MOVEA.L	D0,A0
	LEA	LAB_118(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_170C
	MOVEA.L	$11C(A7),A0
	CLR.W	DOOR_Flag_007E(A0)
LAB_170C:
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_pConfListB(A0),D0
	BEQ.S	LAB_171E
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_172C
LAB_171E:
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListA(A1),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_172C:
	LEA	STR_LONG_NUKE(PC),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$100(A7)
	TST.L	D0
	BEQ.S	LAB_1754
	MOVEA.L	D0,A0
	LEA	LAB_126(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_1754
	MOVEA.L	$11C(A7),A0
	MOVE.W	#$0001,DOOR_Word_0082(A0)
LAB_1754:
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_5A58
	MOVEA.L	$11C(A7),A0
	TST.W	DOOR_Word_010A(A0)
	BEQ.W	LAB_1A6C
	MOVEQ	#$40,D0
	ADD.L	D0,D0
	BSR.W	sendDoorGetValueMsg        ;BB_LOCAL
	MOVE.L	D0,-(A7)
	PEA	STR_CONFCONFIG(PC)
	PEA	$40(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	LEA	$38(A7),A0
	JSR	_LVOGetDiskObject(A6)	; GetDiskObject(name) - load a .info icon (and its tooltypes)
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_pConfListC(A0)
	BEQ.S	LAB_17B8
	MOVEA.L	D0,A0
	MOVEA.L	$36(A0),A0
	LEA	STR_NCONFS(PC),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$100(A7)
	TST.L	D0
	BEQ.S	LAB_17B8
	MOVEA.L	D0,A0
	LEA	$104(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BNE.S	LAB_17CE
LAB_17B8:
	LEA	STR_0MCONFCONFIG_INFO_ERROR(PC),A0
	MOVEA.L	$11C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_17CE:
	MOVEA.L	$11C(A7),A0
	MOVEQ	#$40,D0
	ADD.L	D0,D0
	BSR.W	sendDoorGetValueMsg        ;BB_LOCAL
	MOVE.L	D0,-(A7)
	PEA	STR_ACCESS_AREA(PC)
	PEA	$40(A7)
	BSR.W	sprintf
	MOVEA.L	$128(A7),A0
	MOVEQ	#$49,D0
	ADD.L	D0,D0
	BSR.W	sendDoorGetValueMsg        ;DT_CONFACCESS
	MOVEA.L	D0,A1
	LEA	$44(A7),A0
	BSR.W	LAB_812C
	LEA	$C(A7),A7
	LEA	$38(A7),A0
	JSR	_LVOGetDiskObject(A6)	; GetDiskObject(name) - load a .info icon (and its tooltypes)
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_pConfListD(A0)
	BNE.S	LAB_1828
	MOVEA.L	A0,A1
	LEA	STR_COULDN_T_LOAD_AREA_ICON(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_1828:
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_pConfListB(A0),D0
	BEQ.S	LAB_183A
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_1848
LAB_183A:
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListA(A1),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_1848:
	LEA	STR_CALLERSLOG(PC),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$100(A7)
	TST.L	D0
	BEQ.S	LAB_1880
	MOVEA.L	D0,A0
	LEA	LAB_126(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_1880
	PEA	STR_CONFERENCE_SCAN_WITH_AQUASCA(PC)
	MOVEA.L	$120(A7),A0
	MOVE.L	$2C(A0),-(A7)
	BSR.W	sprintf
	MOVEA.L	$124(A7),A0
	BSR.W	writeToCallersLog
	ADDQ.W	#8,A7
LAB_1880:
	MOVEA.L	$11C(A7),A0
	MOVE.L	#$000001fe,D0
	BSR.W	sendDoorGetValueMsg        ;BB_CONFNUM
	MOVEA.L	D0,A0
	LEA	$2C(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_18A2
	ADDQ.L	#1,$2C(A7)
	BRA.S	LAB_18A8
LAB_18A2:
	MOVEQ	#-1,D0
	MOVE.L	D0,$2C(A7)
LAB_18A8:
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_pConfListB(A0),D0
	BEQ.S	LAB_18BA
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_18C8
LAB_18BA:
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListA(A1),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_18C8:
	LEA	STR_NOSCAN_FROMCONF(PC),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$100(A7)
	BEQ.S	LAB_18F4
	MOVEA.L	D0,A0
	LEA	$28(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_18F4
	MOVE.L	$28(A7),D0
	CMP.L	$104(A7),D0
	BGT.S	LAB_18F4
	SUBQ.L	#1,D0
	MOVE.L	D0,$104(A7)
LAB_18F4:
	MOVEQ	#1,D6
LAB_18F6:
	CMP.L	$104(A7),D6
	BGT.W	LAB_1A8C
	MOVE.L	D6,-(A7)
	PEA	STR_LOCATION(PC)
	MOVEA.L	$124(A7),A0
	MOVE.L	$2C(A0),-(A7)
	BSR.W	sprintf
	MOVE.L	D6,(A7)
	PEA	STR_NAME(PC)
	PEA	$48(A7)
	BSR.W	sprintf
	LEA	$14(A7),A7
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListC(A1),A0
	MOVEA.L	$36(A0),A0
	MOVEA.L	DOOR_pToolTypeArray(A1),A1
	MOVEA.L	A2,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_pToolTypeResultB(A0)
	BEQ.S	LAB_195C
	MOVEA.L	DOOR_pConfListC(A0),A1
	MOVEA.L	$36(A1),A0
	LEA	$38(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_pToolTypeResultA(A0)
	BNE.S	LAB_1970
LAB_195C:
	MOVEA.L	A0,A1
	LEA	STR_0MCONFCONFIG_INFO_ERROR(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
LAB_1970:
	MOVE.L	D6,-(A7)
	PEA	STR_NOSCAN_CONF(PC)
	MOVEA.L	$124(A7),A0
	MOVE.L	$2C(A0),-(A7)
	BSR.W	sprintf
	MOVE.L	D6,(A7)
	PEA	STR_CONF(PC)
	PEA	$48(A7)
	BSR.W	sprintf
	LEA	$14(A7),A7
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListD(A1),A0
	MOVEA.L	$36(A0),A0
	LEA	$38(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	TST.L	D0
	BEQ.W	LAB_1A66
	MOVEA.L	$11C(A7),A0
	MOVE.L	DOOR_pConfListB(A0),D0
	BEQ.S	LAB_19C0
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_19CE
LAB_19C0:
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pConfListA(A1),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_19CE:
	MOVEA.L	$11C(A7),A1
	MOVEA.L	DOOR_pToolTypeArray(A1),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	TST.L	D0
	BNE.W	LAB_1A66
	MOVE.L	$11C(A7),-(A7)
	MOVEA.L	$120(A7),A0
	MOVEA.L	$120(A0),A0
	MOVEA.L	$120(A7),A1
	MOVEA.L	$124(A1),A1
	BSR.W	SUB_7C1E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_1A66
	MOVE.L	$104(A7),D1
	CMP.L	D6,D1
	SEQ	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVEA.L	$11C(A7),A0
	MOVE.W	D0,DOOR_Word_010E(A0)
	CMP.L	$2C(A7),D6
	SEQ	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVE.W	D0,DOOR_Flag_0116(A0)
	MOVE.L	DOOR_pToolTypeResultA(A0),-(A7)
	PEA	STR_36MCONFERENCE_34M_36M_34M_0M(PC)
	MOVE.L	DOOR_pToolTypeArray(A0),-(A7)
	BSR.W	sprintf
	MOVEA.L	$128(A7),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	MOVEA.L	$128(A7),A0
	ADDQ.L	#2,$104(A0)
	MOVE.L	A0,(A7)
	MOVEA.L	$124(A0),A0
	LEA	$114(A7),A1
	BSR.W	SUB_4CFC
	LEA	$C(A7),A7
	SUBQ.L	#1,D0
	BEQ.S	LAB_1A8C
	MOVEQ	#1,D0
	MOVEA.L	$11C(A7),A0
	MOVE.L	D0,DOOR_Counter_0104(A0)
LAB_1A66:
	ADDQ.L	#1,D6
	BRA.W	LAB_18F6
LAB_1A6C:
	MOVEA.L	$11C(A7),A0
	MOVE.W	#$0001,DOOR_Flag_0116(A0)
	MOVEQ	#$7F,D0
	BSR.W	sendDoorGetValueMsg        ;BB_CONFLOCAL
	MOVE.L	$11C(A7),-(A7)
	MOVEA.L	D0,A0
	LEA	$10C(A7),A1
	BSR.W	SUB_4CFC
	ADDQ.W	#4,A7
LAB_1A8C:
	MOVEA.L	$11C(A7),A0
	BSR.W	SUB_1D74
	MOVEM.L	(A7)+,D2-D3/D6-D7/A2-A3/A5-A6
	ADDA.W	#$0100,A7
	RTS
; ------------------------------------------------------------------
; Subroutine sendXimMsg  -  referenced from 24 call site(s)
; ------------------------------------------------------------------
sendXimMsg:
	MOVEM.L	D4-D7/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEQ	#0,D7
	MOVEQ	#0,D6
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	$E0(A0),D5
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOForbid(A6)	; Forbid() - disable task switching
	LEA	DOOR_PortNameBuf(A5),A0
	MOVEA.L	A0,A1
	JSR	_LVOFindPort(A6)	; FindPort(name) - find a public message port by name
	MOVE.L	D0,4(A5)
	BEQ.S	LAB_1B16
	MOVEA.L	D0,A0
	MOVEA.L	DOOR_Msg(A5),A1
	JSR	_LVOPutMsg(A6)	; PutMsg(port,msg) - send a message to a message port
	JSR	_LVOPermit(A6)	; Permit() - re-enable task switching (after Forbid)
	MOVE.L	$14(A5),D0
	OR.L	$10(A5),D0
	JSR	_LVOWait(A6)	; Wait(sigmask) - wait for one or more Exec signals
	MOVE.L	D0,D4
	MOVE.L	D4,D0
	AND.L	$10(A5),D0
	BEQ.S	LAB_1B0A
	MOVEA.L	8(A5),A0
	JSR	_LVOGetMsg(A6)	; GetMsg(port) - get next message from a message port
	TST.L	D0
	BEQ.S	LAB_1B0A
	MOVEA.L	DOOR_Msg(A5),A0
	MOVEQ	#-1,D0
	CMP.L	$DC(A0),D0
	BNE.S	LAB_1B06
	MOVEQ	#1,D6
LAB_1B06:
	MOVE.L	$DC(A0),D7
LAB_1B0A:
	MOVE.L	D4,D0
	AND.L	$14(A5),D0
	BEQ.S	LAB_1B1C
	MOVEQ	#1,D6
	BRA.S	LAB_1B1C
LAB_1B16:
	JSR	_LVOPermit(A6)	; Permit() - re-enable task switching (after Forbid)
	MOVEQ	#1,D6
LAB_1B1C:
	TST.L	D6
	BEQ.S	LAB_1B2C
	MOVE.L	D5,D0
	SUBQ.L	#2,D0
	BEQ.S	LAB_1B2C
	MOVEA.L	A5,A0
	BSR.W	SUB_1D74
LAB_1B2C:
	MOVE.L	D7,D0
	MOVEM.L	(A7)+,D4-D7/A5-A6
	RTS
; ------------------------------------------------------------------
; Subroutine initAEDoor  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
initAEDoor:
	MOVEM.L	D7/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEQ	#0,D7
	CLR.L	DOOR_Msg(A5)
	CLR.L	4(A5)
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOCreateMsgPort(A6)	; CreateMsgPort() - create an Exec message port
	MOVE.L	D0,8(A5)
	BEQ.W	LAB_1BE0
	MOVEQ	#0,D1
	MOVEA.L	D0,A0
	MOVE.B	$F(A0),D1
	MOVEQ	#0,D0
	BSET	D1,D0
	MOVE.L	D0,$10(A5)
	MOVE.L	#$00001000,$14(A5)
	MOVE.L	#$00000104,D0
	MOVE.L	#$00010001,D1
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVE.L	D0,DOOR_Msg(A5)
	BEQ.S	LAB_1BDC
	MOVEA.L	D0,A0
	LEA	$14(A0),A1
	MOVE.L	A1,$2C(A5)
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.B	#$05,8(A0)
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.W	#$0104,$12(A0)
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	8(A5),$E(A0)
	MOVEA.L	DOOR_Msg(A5),A0
	MOVEQ	#1,D0
	MOVE.L	D0,$E0(A0)      ;set /X door msg code  (JH_REGISTER)
	JSR	_LVOForbid(A6)	; Forbid() - disable task switching
	LEA	DOOR_PortNameBuf(A5),A0
	MOVEA.L	A0,A1
	JSR	_LVOFindPort(A6)	; FindPort(name) - find a public message port by name
	MOVE.L	D0,4(A5)
	JSR	_LVOPermit(A6)	; Permit() - re-enable task switching (after Forbid)
	TST.L	4(A5)
	BNE.S	LAB_1BD4
	MOVEQ	#3,D7
	BRA.S	LAB_1BE2
LAB_1BD4:
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg      ;send JH_REGISTER
	BRA.S	LAB_1BE2
LAB_1BDC:
	MOVEQ	#2,D7
	BRA.S	LAB_1BE2
LAB_1BE0:
	MOVEQ	#1,D7
LAB_1BE2:
	MOVE.L	D7,D0
	MOVEM.L	(A7)+,D7/A5-A6
	RTS
; ------------------------------------------------------------------
; Subroutine cleanupAEDoor  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
cleanupAEDoor:
	MOVEM.L	D7/A3/A5-A6,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVEA.L	(A5),A3
	MOVE.L	DOOR_Msg(A5),D0
	BEQ.S	LAB_1C20
	TST.L	4(A5)
	BEQ.S	LAB_1C0E
	MOVEQ	#2,D1
	MOVEA.L	D0,A0
	MOVE.L	D1,$E0(A0)     
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg       ;send JH shutdown
LAB_1C0E:
	MOVEA.L	DOOR_Msg(A5),A1
	MOVE.L	#$00000104,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1C20:
	MOVE.L	8(A5),D0
	BEQ.S	LAB_1C30
	MOVEA.L	D0,A0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVODeleteMsgPort(A6)	; DeleteMsgPort(port) - free an Exec message port
LAB_1C30:
	MOVEA.L	A5,A1
	MOVE.L	#$00000168,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
	MOVE.L	D7,D0
	MOVEA.L	A3,A0
	BSR.W	SUB_7E30
	MOVEM.L	(A7)+,D7/A3/A5-A6
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_1C4E  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_1C4E:
	MOVEM.L	D2/A2-A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A5),A3
	MOVEA.L	iconbase(A5),A2
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	BSR.W	setNonStop
	MOVE.L	$156(A5),D0
	BEQ.S	LAB_1C84
	MOVE.W	$154(A5),D1
	SWAP	D1
	CLR.W	D1
	SWAP	D1
	MOVE.L	D1,D2
	ASL.L	#2,D2
	MOVEA.L	D0,A1
	MOVE.L	D2,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1C84:
	MOVE.L	$F8(A5),D0
	BEQ.S	LAB_1C98
	MOVEA.L	D0,A1
	MOVE.L	$FC(A5),D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1C98:
	MOVE.L	$CE(A5),D0
	BEQ.S	LAB_1CAC
	MOVEA.L	D0,A1
	MOVE.L	$F2(A5),D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1CAC:
	MOVE.L	$8C(A5),D0
	BEQ.S	LAB_1CC4
	MOVE.L	$90(A5),D1
	ADDQ.L	#1,D1
	MOVEA.L	D0,A1
	MOVE.L	D1,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1CC4:
	MOVE.L	A2,D0
	BEQ.W	LAB_1D4C
	MOVE.L	$A0(A5),D0
	BEQ.S	LAB_1CD8
	MOVEA.L	D0,A0
	MOVEA.L	A2,A6
	JSR	_LVOFreeDiskObject(A6)	; FreeDiskObject(diskobj) - free an icon loaded by GetDiskObject
LAB_1CD8:
	MOVE.L	$9C(A5),D0
	BEQ.S	LAB_1CE6
	MOVEA.L	D0,A0
	MOVEA.L	A2,A6
	JSR	_LVOFreeDiskObject(A6)	; FreeDiskObject(diskobj) - free an icon loaded by GetDiskObject
LAB_1CE6:
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_1CF6
	MOVEA.L	D0,A0
	MOVEA.L	A2,A6
	JSR	_LVOFreeDiskObject(A6)	; FreeDiskObject(diskobj) - free an icon loaded by GetDiskObject
	BRA.S	LAB_1D42
LAB_1CF6:
	MOVE.L	$94(A5),D0
	BEQ.S	LAB_1D42
	MOVEA.L	D0,A0
	TST.L	8(A0)
	BEQ.S	LAB_1D1E
	MOVEA.L	D0,A0
	MOVE.L	$C(A0),D1
	ADDQ.L	#1,D1
	MOVE.L	D1,D2
	ASL.L	#2,D2
	MOVE.L	D2,D0
	MOVEA.L	8(A0),A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1D1E:
	MOVEA.L	$94(A5),A0
	TST.L	(A0)
	BEQ.S	LAB_1D34
	MOVEA.L	(A0),A1
	MOVE.L	4(A0),D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1D34:
	MOVEA.L	$94(A5),A1
	MOVEQ	#$10,D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
LAB_1D42:
	MOVEA.L	A2,A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOCloseLibrary(A6)	; CloseLibrary(lib) - close a shared library
LAB_1D4C:
	TST.L	dosbase(A5)
	BEQ.S	LAB_1D6E
	MOVE.L	$15A(A5),D0
	BEQ.S	LAB_1D62
	MOVE.L	D0,D2
	MOVEQ	#2,D1
	MOVEA.L	A3,A6
	JSR	_LVOFreeDosObject(A6)	; FreeDosObject(type,ptr) - free a DOS structure
LAB_1D62:
	MOVEA.L	dosbase(A5),A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOCloseLibrary(A6)	; CloseLibrary(lib) - close a shared library
LAB_1D6E:
	MOVEM.L	(A7)+,D2/A2-A3/A5-A6
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_1D74  -  referenced from 20 call site(s)
; ------------------------------------------------------------------
SUB_1D74:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	BSR.W	SUB_1C4E
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	BSR.W	cleanupAEDoor
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine lineInput  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
lineInput:
	MOVEM.L	D7/A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	$C(A3),A0
	CLR.L	$E0(A0)
	MOVEA.L	$C(A3),A0
	MOVE.L	D7,$DC(A0)
	MOVEA.L	A5,A0
	MOVEA.L	$2C(A3),A1
LAB_1DAA:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1DAA
	MOVEA.L	A3,A0
	BSR.W	sendXimMsg      ;send JH_LI
	MOVE.L	$2C(A3),D0
	MOVEM.L	(A7)+,D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine lineOutput  -  referenced from 22 call site(s)
; ------------------------------------------------------------------
lineOutput:
	MOVEM.L	D7/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVEA.L	DOOR_Msg(A5),A0
	MOVEQ	#4,D0
	MOVE.L	D0,$E0(A0)
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	D7,$DC(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg          ;JH_SM
	MOVEM.L	(A7)+,D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine lineOutput2  -  referenced from 97 call site(s)
; ------------------------------------------------------------------
lineOutput2:
	MOVEM.L	D7/A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	$C(A3),A0
	MOVEQ	#4,D0
	MOVE.L	D0,$E0(A0)
	MOVEA.L	$C(A3),A0
	MOVE.L	D7,$DC(A0)
	MOVEA.L	A5,A0
	MOVEA.L	$2C(A3),A1
LAB_1E06:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1E06
	MOVEA.L	A3,A0
	BSR.W	sendXimMsg                    ;JH_SM
	MOVEM.L	(A7)+,D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine sendDoorGetValueMsg  -  referenced from 19 call site(s)
; ------------------------------------------------------------------
sendDoorGetValueMsg:
	MOVEM.L	D7/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	D7,$E0(A0)          ;user defined message code
	MOVEA.L	DOOR_Msg(A5),A0
	MOVEQ	#1,D0
	MOVE.L	D0,$DC(A0)        ;data=1 (get value)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg
	MOVE.L	$2C(A5),D0
	MOVEM.L	(A7)+,D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine sendDoorSetValueMsg  -  referenced from 6 call site(s)
; ------------------------------------------------------------------
sendDoorSetValueMsg:
	MOVEM.L	D7/A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	$C(A3),A0
	MOVE.L	D7,$E0(A0)         ;user defined message code
	MOVEA.L	$C(A3),A0
	CLR.L	$DC(A0)       ;data = 0 (set value)
	MOVEA.L	A5,A0
	MOVEA.L	$2C(A3),A1
LAB_1E60:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1E60
	MOVEA.L	A3,A0
	BSR.W	sendXimMsg
	MOVEM.L	(A7)+,D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine displayFile  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
displayFile:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	DOOR_Msg(A5),A0
	MOVEQ	#8,D0
	MOVE.L	D0,$E0(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg        ;JH_SF
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_1E88  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_1E88:
	SUBA.W	#$0038,A7
	MOVEM.L	D2/D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A3),A2
	MOVEA.L	A3,A0
	MOVE.L	#$0000020f,D0
	BSR.W	sendDoorGetValueMsg        ;DT_LANGUAGE
	MOVEA.L	D0,A0
	LEA	$1A(A7),A1
LAB_1EAA:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1EAA
	MOVEA.L	A5,A0
	MOVEA.L	$2C(A3),A1
LAB_1EB4:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1EB4
	MOVEA.L	$2C(A3),A0
	MOVE.L	A0,D0
LAB_1EBE:
	TST.B	(A0)+
	BNE.S	LAB_1EBE
	SUBQ.L	#1,A0
	SUBA.L	D0,A0
	MOVE.L	A0,D0
	MOVEA.L	$2C(A3),A1
	ADDA.L	D0,A1
	MOVE.B	#$2e,(A1)+
	MOVE.L	A1,$4C(A7)
	LEA	$1A(A7),A0
LAB_1EDA:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1EDA
	MOVE.L	$2C(A3),D1
	MOVEQ	#-2,D2
	MOVEA.L	A2,A6
	JSR	_LVOLock(A6)	; Lock(name,mode) - lock a file or directory
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.S	LAB_1EFE
	MOVE.L	D7,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	MOVEA.L	A3,A0
	BSR.W	displayFile
	BRA.S	LAB_1F34
LAB_1EFE:
	LEA	$1A(A7),A0
	LEA	STR_TXT(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.S	LAB_1F34
	LEA	STR_TXT(PC),A0
	MOVEA.L	$4C(A7),A1
LAB_1F16:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1F16
	MOVE.L	$2C(A3),D1
	JSR	_LVOLock(A6)	; Lock(name,mode) - lock a file or directory
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.S	LAB_1F34
	MOVE.L	D7,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	MOVEA.L	A3,A0
	BSR.W	displayFile
LAB_1F34:
	MOVEM.L	(A7)+,D2/D7/A2-A3/A5-A6
	ADDA.W	#$0038,A7
	RTS
; ------------------------------------------------------------------
; Subroutine hotKey  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
hotKey:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	DOOR_Msg(A5),A0
	MOVEQ	#6,D0
	MOVE.L	D0,$E0(A0)
	MOVEA.L	$2C(A5),A0
	CLR.B	(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg          ;JH_HK
	MOVEA.L	$2C(A5),A0
	MOVE.B	(A0),D0
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine setNonStop  -  referenced from 5 call site(s)
; ------------------------------------------------------------------
setNonStop:
	MOVEM.L	D7/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	#$0000020d,$E0(A0)
	MOVEA.L	DOOR_Msg(A5),A0
	TST.W	D7
	SNE	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVE.L	D0,$DC(A0)
	MOVEA.L	$2C(A5),A0
	CLR.B	(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg        ;BB_NONSTOPTEXT
	MOVEM.L	(A7)+,D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine doPause  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
doPause:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	LEA	STR_0M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	#$000001fb,$E0(A0)
	LEA	STR_SP(PC),A0
	MOVEA.L	$2C(A5),A1
LAB_1FBE:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_1FBE
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg          ;JH_MCI
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine writeToCallersLog  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
writeToCallersLog:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	#$00000096,$E0(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg          ;BB_CALLERSLOG
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine toggleRawArrow  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
toggleRawArrow:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	#$000001f5,$E0(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg          ;RAWARROW
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_2000  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
SUB_2000:
	SUBA.W	#$00c8,A7
	MOVEM.L	D5-D7/A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEQ	#1,D5
	LEA	LAB_E(PC),A0
	LEA	$14(A7),A1
	MOVE.B	(A0)+,(A1)+
	MOVE.W	#$00c6,D0
	MOVEQ	#0,D1
	LEA	$15(A7),A0
LAB_2024:
	MOVE.B	D1,(A0)+
	DBF	D0,LAB_2024
LAB_202A:
	MOVEA.L	A3,A0
	BSR.W	hotKey
	MOVE.L	D0,D6
	MOVE.B	D6,D0
	EXT.W	D0
	EXT.L	D0
	SUBQ.L	#8,D0
	BEQ.S	LAB_2050
	SUBQ.L	#5,D0
	BEQ.S	LAB_20A4
	MOVEQ	#$B,D1
	SUB.L	D1,D0
	BEQ.S	LAB_2066
	SUBQ.L	#3,D0
	BEQ.S	LAB_20A4
	MOVEQ	#$64,D1
	SUB.L	D1,D0
	BNE.S	LAB_207C
LAB_2050:
	MOVEQ	#1,D0
	CMP.L	D0,D5
	BLE.S	LAB_20A4
	LEA	LAB_23C(PC),A0
	MOVEA.L	A3,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	SUBQ.L	#1,D5
	BRA.S	LAB_20A4
LAB_2066:
	MOVEQ	#1,D0
	CMP.L	D0,D5
	BLE.S	LAB_20A4
	LEA	LAB_23C(PC),A0
	MOVEA.L	A3,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	SUBQ.L	#1,D5
	BRA.S	LAB_2066
LAB_207C:
	MOVE.L	D7,D0
	ADDQ.L	#1,D0
	CMP.L	D0,D5
	BGE.S	LAB_20A4
	MOVEA.L	$2C(A3),A0
	MOVE.B	D6,(A0)
	MOVEA.L	$2C(A3),A0
	ADDQ.L	#1,A0
	CLR.B	(A0)
	MOVEA.L	A3,A0
	MOVEQ	#0,D0
	BSR.W	lineOutput
	LEA	$13(A7),A0
	ADDA.L	D5,A0
	ADDQ.L	#1,D5
	MOVE.B	D6,(A0)
LAB_20A4:
	MOVEQ	#$D,D0
	CMP.B	D0,D6
	BNE.S	LAB_202A
	SUBQ.L	#1,D5
	CLR.B	$14(A7,D5.L)
	LEA	$14(A7),A0
	MOVEA.L	A5,A1
LAB_20B6:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_20B6
	MOVE.L	A5,D0
	MOVEM.L	(A7)+,D5-D7/A3/A5
	ADDA.W	#$00c8,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_20C6  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_20C6:
	SUBQ.W	#4,A7
	MOVEM.L	D7/A3/A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	MOVEQ	#$4C,D0
	ADD.L	D0,D0
	BSR.W	sendDoorGetValueMsg      ;EXPRESS_VERSION
	MOVEA.L	D0,A3
	MOVEA.L	A3,A0
LAB_20DC:
	TST.B	(A0)+
	BNE.S	LAB_20DC
	SUBQ.L	#1,A0
	SUBA.L	A3,A0
	MOVE.L	A0,D0
	MOVEQ	#3,D1
	CMP.L	D1,D0
	BLS.S	LAB_2140
	MOVE.B	(A3),D0
	EXT.W	D0
	EXT.L	D0
	BSR.W	SUB_5BFE
	MOVEQ	#$56,D1
	CMP.B	D1,D0
	BNE.S	LAB_2140
	ADDQ.L	#1,A3
	MOVEA.L	A3,A0
	LEA	$C(A7),A1
	BSR.W	SUB_7F84
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.S	LAB_2140
	ADDA.L	D7,A3
	MOVEQ	#$2E,D0
	CMP.B	(A3),D0
	BNE.S	LAB_2140
	MOVE.L	$C(A7),D0
	MOVE.W	D0,$30(A5)
	ADDQ.L	#1,A3
	MOVEA.L	A3,A0
	LEA	$C(A7),A1
	BSR.W	SUB_7F84
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.S	LAB_2140
	ADDA.L	D7,A3
	TST.B	(A3)
	BNE.S	LAB_2140
	MOVE.L	$C(A7),D0
	MOVE.W	D0,$32(A5)
	BRA.S	LAB_2148
LAB_2140:
	CLR.W	$30(A5)
	CLR.W	$32(A5)
LAB_2148:
	MOVEM.L	(A7)+,D7/A3/A5
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_2150  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_2150:
	SUBA.W	#$00a0,A7
	MOVEM.L	D7/A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A3,A0
	MOVEQ	#0,D0
	BSR.W	setNonStop
	MOVEA.L	A3,A0
	BSR.W	toggleRawArrow
	TST.W	$10A(A3)
	BEQ.S	LAB_21C2
	MOVEA.L	A3,A0
	MOVEQ	#$7E,D0
	BSR.W	sendDoorGetValueMsg        ;BB_CONFNAME
	MOVEA.L	D0,A0
	LEA	$70(A7),A1
LAB_217E:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_217E
	MOVEA.L	$120(A3),A0
	MOVEA.L	A3,A1
	MOVEQ	#$7E,D0
	BSR.W	sendDoorSetValueMsg        ;BB_CONFNAME
	MOVEA.L	A3,A0
	MOVEQ	#$7F,D0
	BSR.W	sendDoorGetValueMsg        ;BB_CONFLOCAL
	MOVEA.L	D0,A0
	LEA	$C(A7),A1
LAB_219C:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_219C
	MOVEA.L	$124(A3),A0
	LEA	$C(A7),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.S	LAB_21C0
	MOVEA.L	$124(A3),A0
	MOVEA.L	A3,A1
	MOVEQ	#$7F,D0
	BSR.W	sendDoorSetValueMsg      ;BB_CONFLOCAL
	MOVEQ	#1,D7
	BRA.S	LAB_21C2
LAB_21C0:
	MOVEQ	#0,D7
LAB_21C2:
	MOVEA.L	A5,A0
	MOVEA.L	$2C(A3),A1
LAB_21C8:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_21C8
	MOVEA.L	$C(A3),A0
	MOVE.L	#$000001fc,$E0(A0)
	MOVEA.L	A3,A0
	BSR.W	sendXimMsg        ;PRV_COMMAND
	TST.W	$10A(A3)
	BEQ.S	LAB_2200
	LEA	$70(A7),A0
	MOVEA.L	A3,A1
	MOVEQ	#$7E,D0
	BSR.W	sendDoorSetValueMsg      ;BB_CONFNAME
	TST.W	D7
	BEQ.S	LAB_2200
	LEA	$C(A7),A0
	MOVEA.L	A3,A1
	MOVEQ	#$7F,D0
	BSR.W	sendDoorSetValueMsg      ;BB_CONFLOCAL
LAB_2200:
	MOVEA.L	$C(A3),A0
	MOVE.L	#$00000088,$E0(A0)
	MOVEA.L	$2C(A3),A0
	CLR.B	(A0)
	MOVEA.L	A3,A0
	BSR.W	sendXimMsg        ;RETURNCOMMAND
	LEA	LAB_5E(PC),A0
	MOVEA.L	A3,A1
	MOVEQ	#$5C,D0
	NOT.B	D0
	BSR.W	sendDoorSetValueMsg      ;ENVSTAT
	MOVEA.L	A3,A0
	BSR.W	toggleRawArrow
	MOVEA.L	A3,A0
	MOVEQ	#1,D0
	BSR.W	setNonStop
	MOVEM.L	(A7)+,D7/A3/A5
	ADDA.W	#$00a0,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_223E  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_223E:
	MOVEM.L	D7/A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	MOVEQ	#$7C,D0
	NOT.B	D0
	BSR.W	sendDoorGetValueMsg        ;BB_MAINLINE
	MOVEQ	#0,D7
LAB_2250:
	MOVEA.L	$2C(A5),A0
	MOVEA.L	A0,A1
	ADDA.L	D7,A1
	MOVE.B	(A1),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BEQ.S	LAB_2296
	TST.B	D0
	BEQ.S	LAB_2296
	MOVEA.L	A0,A1
	ADDA.L	D7,A1
	MOVE.B	(A1),D0
	MOVEQ	#$41,D1
	CMP.B	D1,D0
	BLT.S	LAB_2286
	MOVEQ	#$5A,D1
	CMP.B	D1,D0
	BGT.S	LAB_2286
	MOVEA.L	A0,A1
	ADDA.L	D7,A1
	MOVE.B	(A1),D0
	EXT.W	D0
	EXT.L	D0
	MOVEQ	#$20,D1
	ADD.L	D1,D0
	BRA.S	LAB_228E
LAB_2286:
	ADDA.L	D7,A0
	MOVE.B	(A0),D0
	EXT.W	D0
	EXT.L	D0
LAB_228E:
	MOVE.B	D0,$34(A5,D7.L)
	ADDQ.L	#1,D7
	BRA.S	LAB_2250
LAB_2296:
	CLR.B	$34(A5,D7.L)
	MOVEM.L	(A7)+,D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_22A0  -  referenced from 8 call site(s)
; ------------------------------------------------------------------
SUB_22A0:
	MOVEM.L	D6-D7/A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	LEA	$34(A5),A0
	MOVEA.L	A0,A1
LAB_22AE:
	TST.B	(A1)+
	BNE.S	LAB_22AE
	SUBQ.L	#1,A1
	SUBA.L	A0,A1
	MOVE.L	A1,D0
	MOVEQ	#9,D1
	SUB.L	D0,D1
	MOVE.L	D1,D6
	TST.L	D6
	BPL.S	LAB_22C4
	MOVEQ	#0,D6
LAB_22C4:
	LEA	STR_0M_34M_36MAQUASCAN_V1_1_BY_A(PC),A0
	MOVEA.L	$2C(A5),A1
LAB_22CC:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_22CC
	TST.W	D7
	BEQ.S	LAB_2310
	MOVEA.L	$2C(A5),A0
	MOVE.L	A0,D0
LAB_22DA:
	TST.B	(A0)+
	BNE.S	LAB_22DA
	SUBQ.L	#1,A0
	SUBA.L	D0,A0
	MOVE.L	A0,D0
	MOVEA.L	$2C(A5),A1
	ADDA.L	D0,A1
	MOVEA.L	A1,A3
LAB_22EC:
	TST.L	D6
	BEQ.S	LAB_22FA
	MOVE.B	#$2d,(A3)
	SUBQ.L	#1,D6
	ADDQ.L	#1,A3
	BRA.S	LAB_22EC
LAB_22FA:
	LEA	$34(A5),A0
	MOVE.L	A0,-(A7)
	PEA	STR_36M_FOR_OPTIONS_34M_0M(PC)
	MOVE.L	A3,-(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	BRA.S	LAB_231C
LAB_2310:
	MOVEA.L	$2C(A5),A0
	LEA	STR_36MCOPYRIGHT_1994_AQUARIUS_3(PC),A1
	BSR.W	LAB_812C
LAB_231C:
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	MOVEQ	#3,D0
	MOVE.L	D0,$104(A5)
	MOVEM.L	(A7)+,D6-D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_2330  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_2330:
	SUBA.W	#$0030,A7
	MOVEM.L	D5-D7/A2-A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	A1,$18(A7)
	MOVEQ	#0,D6
	MOVE.B	#$02,$36(A7)
	CLR.B	$37(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$40(A7)
	MOVE.L	A0,$38(A7)
	LEA	$1F(A7),A0
	MOVE.L	A0,$3C(A7)
	MOVEA.L	A5,A0
	ADDA.L	D7,A0
	MOVEA.L	A0,A3
	SUBQ.L	#1,A3
LAB_2366:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BEQ.S	LAB_2370
	SUBQ.L	#1,A3
	BRA.S	LAB_2366
LAB_2370:
	CLR.W	$28(A7)
	MOVEA.L	A3,A2
	LEA	1(A3),A0
	MOVEA.L	$4C(A7),A1
	MOVE.L	A0,$11A(A1)
LAB_2382:
	CMPA.L	A5,A3
	BCS.W	LAB_2452
	CMPA.L	A3,A5
	BEQ.S	LAB_2396
	MOVEQ	#$A,D0
	CMP.B	-1(A3),D0
	BNE.W	LAB_244C
LAB_2396:
	MOVE.L	A2,D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	$4C(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$2E(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.W	LAB_2448
	MOVEQ	#0,D5
	MOVEA.L	$4C(A7),A0
	TST.W	$14C(A0)
	BEQ.S	LAB_23C6
	MOVE.L	A3,$134(A0)
	CLR.W	$14C(A0)
LAB_23C6:
	MOVEA.L	$4C(A7),A1
	MOVEA.L	$11A(A1),A0
	MOVE.B	(A0),$11E(A1)
	MOVEA.L	$11A(A1),A0
	CLR.B	(A0)
	MOVE.L	$11A(A1),D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	A1,-(A7)
	MOVEA.L	D1,A0
	MOVEA.L	$1C(A7),A1
	BSR.W	SUB_2592
	MOVE.L	D0,D6
	ADDQ.W	#4,A7
	MOVEA.L	$4C(A7),A1
	MOVEA.L	$11A(A1),A0
	MOVE.B	$11E(A1),(A0)
	MOVE.L	D6,D0
	SUBQ.L	#4,D0
	BNE.S	LAB_2422
	MOVEA.L	$134(A1),A3
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$2E(A7),A1
	BSR.W	SUB_4164
	MOVEA.L	$50(A7),A0
	MOVE.L	D0,$11A(A0)
	ADDQ.W	#4,A7
	MOVEQ	#1,D5
	BRA.S	LAB_23C6
LAB_2422:
	TST.L	D6
	BEQ.S	LAB_242C
	MOVE.L	D6,D0
	BRA.W	LAB_2588
LAB_242C:
	TST.W	D5
	BEQ.S	LAB_2440
	MOVE.L	A1,-(A7)
	MOVEA.L	A3,A0
	LEA	$2E(A7),A1
	BSR.W	SUB_41A4
	MOVEA.L	D0,A3
	ADDQ.W	#4,A7
LAB_2440:
	MOVEA.L	$4C(A7),A0
	MOVE.L	A3,$11A(A0)
LAB_2448:
	MOVEA.L	A3,A2
	SUBQ.L	#1,A2
LAB_244C:
	SUBQ.L	#1,A3
	BRA.W	LAB_2382
LAB_2452:
	MOVEA.L	$4C(A7),A1
	MOVEA.L	$11A(A1),A0
	ADDQ.L	#1,A0
	MOVE.L	A1,-(A7)
	LEA	$2E(A7),A1
	BSR.W	SUB_4164
	ADDQ.W	#4,A7
	MOVE.L	D0,$44(A7)
LAB_246C:
	LEA	STR_0_34M_36M_END_OF_FILE_LIST_3(PC),A0
	MOVEA.L	$4C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$4C(A7),A0
	TST.L	$104(A0)
	BEQ.W	LAB_257E
	TST.W	$108(A0)
	BNE.W	LAB_257E
	BSR.W	SUB_329E
	SUBQ.L	#2,D0
	BLT.W	LAB_257E
	CMPI.L	#$00000008,D0
	BGE.W	LAB_257E
	ADD.W	D0,D0
	MOVE.W	LAB_24AC(PC,D0.W),D0
	JMP	LAB_24AC+2(PC,D0.W)
LAB_24AC:
	DC.W	(LAB_24BC)-(LAB_24AC+2)	;24ac: 000e
	DC.W	(LAB_257E)-(LAB_24AC+2)	;24ae: 00d0
	DC.W	(LAB_257E)-(LAB_24AC+2)	;24b0: 00d0
	DC.W	(LAB_257E)-(LAB_24AC+2)	;24b2: 00d0
	DC.W	(LAB_24C2)-(LAB_24AC+2)	;24b4: 0014
	DC.W	(LAB_24C8)-(LAB_24AC+2)	;24b6: 001a
	DC.W	(LAB_24D4)-(LAB_24AC+2)	;24b8: 0026
	DC.W	(LAB_24CE)-(LAB_24AC+2)	;24ba: 0020

LAB_24BC:
	MOVEQ	#1,D6
	BRA.W	LAB_257E
LAB_24C2:
	MOVEQ	#3,D6
	BRA.W	LAB_257E
LAB_24C8:
	MOVEQ	#2,D6
	BRA.W	LAB_257E
LAB_24CE:
	MOVEQ	#5,D6
	BRA.W	LAB_257E
LAB_24D4:
	MOVEA.L	$4C(A7),A0
	MOVE.L	$140(A0),$144(A0)
	MOVE.W	$148(A0),$14A(A0)
	MOVE.L	$138(A0),$130(A0)
	MOVEA.L	$18(A7),A1
	MOVE.L	$13C(A0),(A1)
LAB_24F2:
	MOVEA.L	$4C(A7),A0
	MOVEA.L	$134(A0),A3
	LEA	1(A3),A1
	MOVE.L	A0,-(A7)
	MOVEA.L	A1,A0
	LEA	$2E(A7),A1
	BSR.W	SUB_4164
	MOVEA.L	$50(A7),A0
	MOVE.L	D0,$11A(A0)
	MOVEA.L	D0,A0
	MOVEA.L	$50(A7),A1
	MOVE.B	(A0),$11E(A1)
	MOVEA.L	$11A(A1),A0
	CLR.B	(A0)
	MOVE.L	$11A(A1),D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	A1,(A7)
	MOVEA.L	D1,A0
	MOVEA.L	$1C(A7),A1
	BSR.W	SUB_2592
	MOVE.L	D0,D6
	ADDQ.W	#4,A7
	MOVEA.L	$4C(A7),A1
	MOVEA.L	$11A(A1),A0
	MOVE.B	$11E(A1),(A0)
	MOVE.L	D6,D0
	SUBQ.L	#5,D0
	BEQ.S	LAB_24F2
	TST.L	D6
	BEQ.S	LAB_2554
	MOVE.L	D6,D0
	BRA.S	LAB_2588
LAB_2554:
	MOVEA.L	$4C(A7),A1
	MOVEA.L	$11A(A1),A0
	CMPA.L	$44(A7),A0
	BEQ.W	LAB_246C
	MOVE.L	A1,-(A7)
	MOVEA.L	A3,A0
	LEA	$2E(A7),A1
	BSR.W	SUB_41A4
	ADDQ.W	#4,A7
	MOVEA.L	D0,A0
	MOVEA.L	D0,A3
	SUBQ.L	#1,A3
	MOVE.W	#$0001,$28(A7)
LAB_257E:
	TST.W	$28(A7)
	BNE.W	LAB_2370
	MOVE.L	D6,D0
LAB_2588:
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5
	ADDA.W	#$0030,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_2592  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
SUB_2592:
	SUBA.W	#$0080,A7
	MOVEM.L	D2/D5-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEM.L	D0/A1,$3C(A7)
	MOVEA.L	$A4(A7),A0
	MOVE.L	dosbase(A0),$9C(A7)
	MOVE.W	#$0001,$98(A7)
	CLR.L	$60(A7)
	MOVE.B	#$02,$7A(A7)
	CLR.B	$7B(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$84(A7)
	MOVE.L	A0,$7C(A7)
	LEA	$65(A7),A0
	MOVE.L	A0,$80(A7)
LAB_25D2:
	CLR.W	$5E(A7)
	MOVEA.L	$A4(A7),A0
	CLR.L	$12C(A0)
	MOVEA.L	A5,A2
	MOVEA.L	A2,A3
LAB_25E2:
	MOVE.B	(A3),D0
	BEQ.W	LAB_316A
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BNE.W	LAB_3164
	MOVE.W	#$0001,$8C(A7)
	MOVE.L	A3,D0
	MOVE.L	A2,D1
	SUB.L	D1,D0
	MOVE.L	$A4(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$72(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.W	LAB_2D3A
	MOVEA.L	$A4(A7),A0
	MOVE.L	A2,$12C(A0)
	ADDQ.L	#1,$130(A0)
	MOVE.L	$6E(A7),D0
	MOVEA.L	$40(A7),A0
	MOVE.L	(A0),D1
	CMP.L	D0,D1
	BEQ.W	LAB_290A
	MOVEA.L	$A4(A7),A0
	MOVE.L	$144(A0),D1
	CMP.L	$CA(A0),D1
	BGE.W	LAB_290A
	TST.L	$CE(A0)
	BEQ.W	LAB_290A
	MOVEA.L	$40(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$A4(A7),A0
	TST.W	$14E(A0)
	BEQ.S	LAB_2664
	CLR.L	$140(A0)
	MOVEQ	#-1,D0
	MOVE.L	D0,$13C(A0)
	CLR.W	$14E(A0)
LAB_2664:
	MOVE.W	#$0001,$F6(A0)
	MOVE.L	$144(A0),$5A(A7)
LAB_2670:
	MOVE.L	$5A(A7),D0
	MOVEA.L	$A4(A7),A0
	CMP.L	$CA(A0),D0
	BGE.W	LAB_2882
	TST.W	$98(A7)
	BEQ.W	LAB_2882
	BTST	#3,$B2(A0)
	BEQ.S	LAB_2696
	TST.W	$108(A0)
	BEQ.S	LAB_26C8
LAB_2696:
	MOVEA.L	$C(A0),A1
	MOVEQ	#$11,D0
	MOVE.L	D0,$E0(A1)
	BSR.W	sendXimMsg        ;JH_FetchKey
	MOVEA.L	$A4(A7),A1
	MOVEA.L	$C(A1),A0
	MOVEQ	#3,D0
	CMP.L	$E0(A0),D0
	BNE.S	LAB_26C8
	CLR.W	$F6(A1)
	LEA	STR_0M_BREAK(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEQ	#1,D0
	BRA.W	LAB_321A
LAB_26C8:
	MOVEA.L	$A4(A7),A0
	TST.W	$108(A0)
	BEQ.S	LAB_26FC
	MOVE.L	$B0(A0),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	TST.L	D0
	BEQ.S	LAB_26FC
	MOVE.L	$B0(A0),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	MOVE.L	D0,D1
	MOVEA.L	$9C(A7),A6
	JSR	_LVODelay(A6)	; Delay(ticks) - pause the task for N ticks (1/50s)
LAB_26FC:
	LEA	STR_0M(PC),A0
	MOVEA.L	$A4(A7),A6
	MOVEA.L	$2C(A6),A1
LAB_2708:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_2708
	MOVE.L	$5A(A7),D0
	MOVE.L	D0,D1
	ASL.L	#2,D1
	MOVEA.L	$2C(A6),A0
	ADDQ.L	#4,A0
	PEA	$65(A7)
	MOVEA.L	A0,A1
	MOVE.L	D1,D0
	ADDI.L	#$000000d2,D0
	MOVEA.L	0(A6,D0.L),A0
	BSR.W	SUB_58D4
	MOVEA.L	A6,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	ADDQ.W	#4,A7
	ADDQ.L	#1,$104(A6)
	MOVE.L	$104(A6),D0
	CMP.L	$100(A6),D0
	BLT.W	LAB_287A
	TST.W	$108(A6)
	BNE.W	LAB_287A
	MOVEA.L	A6,A0
	BSR.W	SUB_329E
	SUBQ.L	#1,D0
	BLT.W	LAB_287A
	CMPI.L	#$00000009,D0
	BGE.W	LAB_287A
	ADD.W	D0,D0
	MOVE.W	LAB_2772(PC,D0.W),D0
	JMP	LAB_2772+2(PC,D0.W)
LAB_2772:
	DC.W	(LAB_2848)-(LAB_2772+2)	;2772: 00d4
	DC.W	(LAB_2784)-(LAB_2772+2)	;2774: 0010
	DC.W	(LAB_287A)-(LAB_2772+2)	;2776: 0106
	DC.W	(LAB_27BC)-(LAB_2772+2)	;2778: 0048
	DC.W	(LAB_2806)-(LAB_2772+2)	;277a: 0092
	DC.W	(LAB_2792)-(LAB_2772+2)	;277c: 001e
	DC.W	(LAB_27A0)-(LAB_2772+2)	;277e: 002c
	DC.W	(LAB_2870)-(LAB_2772+2)	;2780: 00fc
	DC.W	(LAB_27AE)-(LAB_2772+2)	;2782: 003a
LAB_2784:
	CLR.W	$98(A7)
	MOVEQ	#1,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_287A
LAB_2792:
	CLR.W	$98(A7)
	MOVEQ	#3,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_287A
LAB_27A0:
	CLR.W	$98(A7)
	MOVEQ	#2,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_287A
LAB_27AE:
	CLR.W	$98(A7)
	MOVEQ	#5,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_287A
LAB_27BC:
	MOVEA.L	$A4(A7),A0
	MOVE.L	$CA(A0),D0
	CMP.L	$100(A0),D0
	BGE.S	LAB_27E2
	SUBQ.L	#1,D0
	MOVE.L	$5A(A7),D1
	CMP.L	D0,D1
	BGE.S	LAB_27E2
	MOVE.L	D1,D0
	ADDQ.L	#1,D0
	MOVE.L	D0,$104(A0)
	CLR.L	$140(A0)
	BRA.S	LAB_27EC
LAB_27E2:
	MOVE.L	$5A(A7),D0
	ADDQ.L	#1,D0
	MOVE.L	D0,$140(A0)
LAB_27EC:
	MOVE.L	A2,$134(A0)
	MOVEQ	#-1,D0
	MOVE.L	D0,$13C(A0)
	MOVE.L	$130(A0),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,$138(A0)
	CLR.W	$148(A0)
	BRA.S	LAB_287A
LAB_2806:
	MOVEA.L	$A4(A7),A0
	MOVE.L	$CA(A0),D0
	CMP.L	$100(A0),D0
	BGE.S	LAB_2824
	SUBQ.L	#1,D0
	MOVE.L	$5A(A7),D1
	CMP.L	D0,D1
	BGE.S	LAB_2824
	MOVEQ	#-1,D0
	MOVE.L	D0,$5A(A7)
LAB_2824:
	MOVE.L	A2,$134(A0)
	MOVEQ	#-1,D0
	MOVE.L	D0,$13C(A0)
	MOVE.L	$130(A0),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,$138(A0)
	MOVE.L	$5A(A7),D0
	ADDQ.L	#1,D0
	MOVE.L	D0,$140(A0)
	CLR.W	$148(A0)
	BRA.S	LAB_287A
LAB_2848:
	MOVEA.L	$A4(A7),A0
	MOVE.L	A2,$134(A0)
	MOVEQ	#-1,D0
	MOVE.L	D0,$13C(A0)
	MOVE.L	$130(A0),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,$138(A0)
	MOVE.L	$5A(A7),D0
	ADDQ.L	#1,D0
	MOVE.L	D0,$140(A0)
	CLR.W	$148(A0)
	BRA.S	LAB_287A
LAB_2870:
	MOVE.W	#$0001,$5E(A7)
	CLR.W	$98(A7)
LAB_287A:
	ADDQ.L	#1,$5A(A7)
	BRA.W	LAB_2670
LAB_2882:
	MOVEA.L	$A4(A7),A0
	CLR.W	$F6(A0)
	TST.W	$5E(A7)
	BEQ.S	LAB_28F2
	BSR.W	SUB_4312
	MOVEA.L	$A4(A7),A0
	BSR.W	SUB_4216
	MOVEA.L	$A4(A7),A0
	CLR.L	$12C(A0)
	MOVE.L	$140(A0),D0
	MOVE.L	D0,$144(A0)
	MOVE.W	$148(A0),D1
	MOVE.W	D1,$14A(A0)
	MOVE.L	$13C(A0),D0
	MOVEA.L	$40(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$A4(A7),A0
	TST.W	$118(A0)
	BEQ.S	LAB_28D6
	MOVE.L	$138(A0),D1
	MOVE.L	D1,$130(A0)
	MOVEQ	#4,D0
	BRA.W	LAB_321A
LAB_28D6:
	MOVEA.L	$134(A0),A2
	MOVEA.L	A2,A3
	SUBQ.L	#1,A3
	MOVE.L	$138(A0),$130(A0)
	CLR.W	$5E(A7)
	MOVEQ	#1,D0
	MOVE.W	D0,$98(A7)
	BRA.W	LAB_3164
LAB_28F2:
	TST.L	$144(A0)
	BEQ.S	LAB_28FC
	CLR.L	$144(A0)
LAB_28FC:
	TST.W	$98(A7)
	BNE.S	LAB_2928
	MOVE.L	$60(A7),D0
	BRA.W	LAB_321A
LAB_290A:
	MOVEA.L	$A4(A7),A0
	TST.W	$14E(A0)
	BEQ.S	LAB_2928
	CLR.L	$140(A0)
	MOVEA.L	$40(A7),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	(A0),$13C(A1)
	CLR.W	$14E(A1)
LAB_2928:
	MOVEA.L	$A4(A7),A0
	TST.L	$F8(A0)
	BEQ.W	LAB_2C24
	TST.W	$14A(A0)
	BEQ.S	LAB_2942
	CLR.W	$14A(A0)
	BRA.W	LAB_2C24
LAB_2942:
	BSR.W	SUB_4312
LAB_2946:
	MOVEA.L	$A4(A7),A0
	BTST	#3,$B2(A0)
	BEQ.S	LAB_2958
	TST.W	$108(A0)
	BEQ.S	LAB_2986
LAB_2958:
	MOVEA.L	$C(A0),A1
	MOVEQ	#$11,D0
	MOVE.L	D0,$E0(A1)
	BSR.W	sendXimMsg        ;JH_FetchKey
	MOVEA.L	$A4(A7),A1
	MOVEA.L	$C(A1),A0
	MOVEQ	#3,D0
	CMP.L	$E0(A0),D0
	BNE.S	LAB_2986
	LEA	STR_0M_BREAK(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEQ	#1,D0
	BRA.W	LAB_321A
LAB_2986:
	MOVEA.L	$A4(A7),A0
	TST.W	$108(A0)
	BEQ.S	LAB_29BA
	MOVE.L	$B0(A0),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	TST.L	D0
	BEQ.S	LAB_29BA
	MOVE.L	$B0(A0),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	MOVE.L	D0,D1
	MOVEA.L	$9C(A7),A6
	JSR	_LVODelay(A6)	; Delay(ticks) - pause the task for N ticks (1/50s)
LAB_29BA:
	MOVEA.L	$A4(A7),A0
	BTST	#7,$B1(A0)
	BEQ.W	LAB_2A50
	MOVE.L	$130(A0),-(A7)
	PEA	LAB_316(PC)
	PEA	$5A(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	LEA	$52(A7),A0
	MOVEA.L	A0,A1
LAB_29E2:
	TST.B	(A1)+
	BNE.S	LAB_29E2
	SUBQ.L	#1,A1
	SUBA.L	A0,A1
	MOVE.L	A1,D0
	MOVEQ	#$A,D1
	ADD.L	D1,D0
	MOVEA.L	$A4(A7),A0
	MOVEA.L	A0,A1
	ADDA.W	#$006c,A1
	LEA	$78(A0),A6
	MOVE.L	A1,$20(A7)
	LEA	$6C(A0),A1
	MOVE.L	A1,$28(A7)
	MOVEA.L	$A4(A7),A1
	MOVEA.L	$F8(A1),A0
	MOVE.L	A0,D1
LAB_2A14:
	TST.B	(A0)+
	BNE.S	LAB_2A14
	SUBQ.L	#1,A0
	SUBA.L	D1,A0
	MOVE.L	D0,$88(A7)
	CMPA.L	D0,A0
	BLS.S	LAB_2A2A
	MOVEA.L	D1,A0
	ADDA.L	D0,A0
	BRA.S	LAB_2A2E
LAB_2A2A:
	LEA	LAB_334(PC),A0
LAB_2A2E:
	MOVE.L	A0,-(A7)
	MOVE.L	$2C(A7),-(A7)
	PEA	$5A(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	PEA	STR_0M_FILE(PC)
	MOVE.L	$2C(A1),-(A7)
	BSR.W	sprintf
	LEA	$1C(A7),A7
	BRA.S	LAB_2A6A
LAB_2A50:
	LEA	$6C(A0),A1
	MOVE.L	$F8(A0),-(A7)
	MOVE.L	A1,-(A7)
	PEA	STR_0M_2(PC)
	MOVE.L	$2C(A0),-(A7)
	BSR.W	sprintf
	LEA	$10(A7),A7
LAB_2A6A:
	MOVEA.L	$A4(A7),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	CLR.W	$90(A7)
	MOVEA.L	$A4(A7),A0
	ADDQ.L	#1,$104(A0)
	MOVE.L	$104(A0),D0
	CMP.L	$100(A0),D0
	BLT.W	LAB_2BAC
	TST.W	$108(A0)
	BNE.W	LAB_2BAC
	BSR.W	SUB_329E
	SUBQ.L	#1,D0
	BLT.W	LAB_2BAC
	CMPI.L	#$00000009,D0
	BGE.W	LAB_2BAC
	ADD.W	D0,D0
	MOVE.W	LAB_2AB2(PC,D0.W),D0
	JMP	LAB_2AB2+2(PC,D0.W)
LAB_2AB2:
	DC.W	(LAB_2B7C)-(LAB_2AB2+2)	;2ab2: 00c8
	DC.W	(LAB_2AC4)-(LAB_2AB2+2)	;2ab4: 0010
	DC.W	(LAB_2BAC)-(LAB_2AB2+2)	;2ab6: 00f8
	DC.W	(LAB_2AFC)-(LAB_2AB2+2)	;2ab8: 0048
	DC.W	(LAB_2B3C)-(LAB_2AB2+2)	;2aba: 0088
	DC.W	(LAB_2AD2)-(LAB_2AB2+2)	;2abc: 001e
	DC.W	(LAB_2AE0)-(LAB_2AB2+2)	;2abe: 002c
	DC.W	(LAB_2BA6)-(LAB_2AB2+2)	;2ac0: 00f2
	DC.W	(LAB_2AEE)-(LAB_2AB2+2)	;2ac2: 003a
LAB_2AC4:
	CLR.W	$98(A7)
	MOVEQ	#1,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_2BAC
LAB_2AD2:
	CLR.W	$98(A7)
	MOVEQ	#3,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_2BAC
LAB_2AE0:
	CLR.W	$98(A7)
	MOVEQ	#2,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_2BAC
LAB_2AEE:
	CLR.W	$98(A7)
	MOVEQ	#5,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_2BAC
LAB_2AFC:
	MOVEA.L	$A4(A7),A0
	CMPI.L	#$00000001,$100(A0)
	BLE.S	LAB_2B16
	MOVEQ	#1,D0
	MOVE.L	D0,$104(A0)
	CLR.W	$148(A0)
	BRA.S	LAB_2B1C
LAB_2B16:
	MOVE.W	#$0001,$148(A0)
LAB_2B1C:
	MOVE.L	A2,$134(A0)
	MOVEA.L	$40(A7),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	(A0),$13C(A1)
	MOVE.L	$130(A1),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,$138(A1)
	CLR.L	$140(A1)
	BRA.S	LAB_2BAC
LAB_2B3C:
	MOVEA.L	$A4(A7),A0
	CMPI.L	#$00000001,$100(A0)
	BLE.S	LAB_2B56
	MOVEQ	#1,D0
	CLR.W	$148(A0)
	MOVE.W	D0,$90(A7)
	BRA.S	LAB_2B5C
LAB_2B56:
	MOVE.W	#$0001,$148(A0)
LAB_2B5C:
	MOVE.L	A2,$134(A0)
	MOVEA.L	$40(A7),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	(A0),$13C(A1)
	MOVE.L	$130(A1),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,$138(A1)
	CLR.L	$140(A1)
	BRA.S	LAB_2BAC
LAB_2B7C:
	MOVEA.L	$A4(A7),A0
	MOVE.L	A2,$134(A0)
	MOVEA.L	$40(A7),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	(A0),$13C(A1)
	MOVE.L	$130(A1),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,$138(A1)
	CLR.L	$140(A1)
	MOVE.W	#$0001,$148(A1)
	BRA.S	LAB_2BAC
LAB_2BA6:
	MOVE.W	#$0001,$5E(A7)
LAB_2BAC:
	TST.W	$90(A7)
	BNE.W	LAB_2946
	TST.W	$5E(A7)
	BEQ.S	LAB_2C16
	MOVEA.L	$A4(A7),A0
	BSR.W	SUB_4312
	MOVEA.L	$A4(A7),A0
	BSR.W	SUB_4216
	MOVEA.L	$A4(A7),A0
	CLR.L	$12C(A0)
	MOVE.L	$140(A0),$144(A0)
	MOVE.W	$148(A0),$14A(A0)
	MOVEA.L	$40(A7),A1
	MOVE.L	$13C(A0),(A1)
	TST.W	$118(A0)
	BEQ.S	LAB_2BFA
	MOVE.L	$138(A0),D0
	MOVE.L	D0,$130(A0)
	MOVEQ	#4,D0
	BRA.W	LAB_321A
LAB_2BFA:
	MOVEA.L	$134(A0),A2
	MOVEA.L	A2,A3
	SUBQ.L	#1,A3
	MOVE.L	$138(A0),$130(A0)
	CLR.W	$5E(A7)
	MOVEQ	#1,D0
	MOVE.W	D0,$98(A7)
	BRA.W	LAB_3164
LAB_2C16:
	TST.W	$98(A7)
	BNE.S	LAB_2C24
	MOVE.L	$60(A7),D0
	BRA.W	LAB_321A
LAB_2C24:
	MOVEA.L	$A4(A7),A0
	BSR.W	SUB_4216
	MOVEA.L	$A4(A7),A0
	BTST	#3,$B2(A0)
	BEQ.S	LAB_2C3E
	TST.W	$108(A0)
	BEQ.S	LAB_2C6C
LAB_2C3E:
	MOVEA.L	$C(A0),A1
	MOVEQ	#$11,D0
	MOVE.L	D0,$E0(A1)
	BSR.W	sendXimMsg          ;JH_FetchKey
	MOVEA.L	$A4(A7),A1
	MOVEA.L	$C(A1),A0

	MOVEQ	#3,D0           ;CTRL-C
	CMP.L	$E0(A0),D0
	BNE.S	LAB_2C6C
  
	LEA	STR_0M_BREAK(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2            ;print break
	MOVEQ	#1,D0
	BRA.W	LAB_321A
  
LAB_2C6C:
	MOVEA.L	$A4(A7),A0
	MOVE.L	$104(A0),D7
	MOVE.B	$D(A2),D5
	CLR.B	$D(A2)              ;put a null after the filename
	MOVEA.L	A2,A1

  MOVEM.L D0-D6/A0-A6,-(A7)

	MOVEA.L	DOOR_Msg(A0),A2
  MOVE.L	#712,$E0(A2)
	CLR.L	$DC(A2)

 	LEA	$14(A2),A3
.0
	MOVE.B	(A1)+,D0
  CMP.B #32,D0
  BEQ.S .0
  MOVE.B D0,(A3)+
	BNE.S	.0
  
  MOVE.L A0,-(A7)
	BSR.W	sendXimMsg        ;IS_FLAGGED
  MOVE.L (A7)+,A0

	MOVEA.L	DOOR_Msg(A0),A2
	MOVE.L	$DC(A2),D0
  MOVE.W D0,DOOR_flagged(A0)
  
  MOVEM.L (A7)+,D0-D6/A0-A6

	LEA	$44(A7),A6
LAB_2C82:
	MOVE.B	(A1)+,(A6)+       ;copy filename
	BNE.S	LAB_2C82

	MOVE.B	D5,$D(A2)         ;restore old value
	
  MOVE.B	$17(A2),D6
	CLR.B	$17(A2)             ;clear first byte of date string (after filesize)
	
  LEA	$E(A2),A1
	MOVEA.L	A1,A0
	BSR.W	checkDirListFileSize
	CLR.B	(A3)
	MOVEA.L	$A4(A7),A0
	MOVEA.L	A0,A1
	ADDA.W	#$004e,A1
	MOVE.W	D0,$94(A7)
	BEQ.S	LAB_2CBA
	TST.W	$82(A0)
	BEQ.S	LAB_2CBA
	LEA	$72(A0),A6
	BRA.S	LAB_2CBE
LAB_2CBA:
	LEA	$54(A0),A6
LAB_2CBE:
	MOVE.B	D5,D1
	EXT.W	D1
	EXT.L	D1
	MOVEM.L	A6,$24(A7)
	TST.W	D0
	BEQ.S	LAB_2CD4
	LEA	$72(A0),A6
	BRA.S	LAB_2CD8
LAB_2CD4:
	LEA	$5A(A0),A6
LAB_2CD8:
	LEA	$E(A2),A0
	MOVE.L	A0,$30(A7)
	MOVEA.L	$A4(A7),A0
	ADDA.W	#$0060,A0
	MOVE.L	A0,$34(A7)
	MOVEA.L	$A4(A7),A0
	ADDA.W	#$0066,A0
	MOVE.L	A0,$38(A7)

	LEA	$1F(A2),A0
	MOVE.L	A0,-(A7)          ;start of file id
	MOVE.L	$3C(A7),-(A7)     ;ESC[34m
	PEA	$6D(A7)               ;date string
	MOVE.L	$40(A7),-(A7)     ;ESC[33m
	MOVE.L	$40(A7),-(A7)     ;filesize
	MOVE.L	A6,-(A7)          ;ESC[32m
	MOVE.L	D1,-(A7)          ;$4e
	MOVE.L	$40(A7),-(A7)     ;ESC[34m
  PEA	STR_0M(PC)
	PEA	$68(A7)               ;filename
  
  MOVEA.L	$CC(A7),A0
  TST.W DOOR_flagged(A0)
  BEQ.S .1
  PEA	HIGHLIGHT(PC)
  BRA.S .2
.1
  PEA	STR_NULL(PC)
.2
  MOVE.L	A1,-(A7)          ;ESC[36m
  PEA	STR_0M_C(PC)          ;ESC[0m%s%s%s%c%s%s%s%s%s%s
	MOVEA.L	$D8(A7),A0
	MOVE.L	$2C(A0),-(A7)     ;output var
	BSR.W	sprintf
	LEA	$38(A7),A7
	MOVE.B	#$0a,(A3)

	MOVE.B	D6,$17(A2)        ;restore old value for first character of date
	BRA.S	LAB_2DB0
LAB_2D3A:
	MOVEA.L	$A4(A7),A0
	TST.W	$10C(A0)
	BEQ.S	LAB_2D4A
	CLR.W	$8C(A7)
	BRA.S	LAB_2DB0
LAB_2D4A:
	BTST	#3,$B2(A0)
	BEQ.S	LAB_2D58
	TST.W	$108(A0)
	BEQ.S	LAB_2D8A
LAB_2D58:
	MOVEA.L	A0,A1
	MOVEA.L	$C(A1),A0
	MOVEQ	#$11,D0
	MOVE.L	D0,$E0(A0)
	MOVEA.L	A1,A0
	BSR.W	sendXimMsg        ;JH_FetchKey
	MOVEA.L	$A4(A7),A1
	MOVEA.L	$C(A1),A0
	MOVEQ	#3,D0
	CMP.L	$E0(A0),D0
	BNE.S	LAB_2D8A
	LEA	STR_0M_BREAK(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEQ	#1,D0
	BRA.W	LAB_321A
LAB_2D8A:
	CLR.B	(A3)
	MOVEA.L	$A4(A7),A0
	ADDA.W	#$0066,A0
	MOVE.L	A2,-(A7)
	MOVE.L	A0,-(A7)
	PEA	STR_0M_2(PC)
	MOVEA.L	$B0(A7),A1
	MOVE.L	$2C(A1),-(A7)
	BSR.W	sprintf
	LEA	$10(A7),A7
	MOVE.B	#$0a,(A3)
LAB_2DB0:
	TST.W	$8C(A7)
	BEQ.W	LAB_3160
	MOVEA.L	$A4(A7),A0
	TST.W	$108(A0)
	BEQ.S	LAB_2DEC
	MOVE.L	$B0(A0),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	TST.L	D0
	BEQ.S	LAB_2DEC
	MOVE.L	$B0(A0),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	MOVE.L	D0,D1
	MOVEA.L	$9C(A7),A6
	JSR	_LVODelay(A6)	; Delay(ticks) - pause the task for N ticks (1/50s)
LAB_2DEC:
	MOVEA.L	$A4(A7),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	MOVEA.L	$A4(A7),A0
	ADDQ.L	#1,$104(A0)
	MOVE.L	$104(A0),D0
	CMP.L	$100(A0),D0
	BLT.W	LAB_3152
	TST.W	$108(A0)
	BNE.W	LAB_3152
	BSR.W	SUB_329E
	SUBQ.L	#1,D0
	BLT.W	LAB_3152
	CMPI.L	#$00000009,D0
	BGE.W	LAB_3152
	ADD.W	D0,D0
	MOVE.W	LAB_2E30(PC,D0.W),D0
	JMP	LAB_2E30+2(PC,D0.W)
LAB_2E30:
	DC.W	(LAB_3072)-(LAB_2E30+2)	;2e30: 0240
	DC.W	(LAB_2E42)-(LAB_2E30+2)	;2e32: 0010
	DC.W	(LAB_3152)-(LAB_2E30+2)	;2e34: 0320
	DC.W	(LAB_2E7A)-(LAB_2E30+2)	;2e36: 0048
	DC.W	(LAB_2F86)-(LAB_2E30+2)	;2e38: 0154
	DC.W	(LAB_2E50)-(LAB_2E30+2)	;2e3a: 001e
	DC.W	(LAB_2E5E)-(LAB_2E30+2)	;2e3c: 002c
	DC.W	(LAB_310A)-(LAB_2E30+2)	;2e3e: 02d8
	DC.W	(LAB_2E6C)-(LAB_2E30+2)	;2e40: 003a
LAB_2E42:
	CLR.W	$98(A7)
	MOVEQ	#1,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_3152
LAB_2E50:
	CLR.W	$98(A7)
	MOVEQ	#3,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_3152
LAB_2E5E:
	CLR.W	$98(A7)
	MOVEQ	#2,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_3152
LAB_2E6C:
	CLR.W	$98(A7)
	MOVEQ	#5,D0
	MOVE.L	D0,$60(A7)
	BRA.W	LAB_3152
LAB_2E7A:
	MOVEA.L	$40(A7),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	(A0),$13C(A1)
	CLR.L	$140(A1)
	MOVE.L	$130(A1),$138(A1)
	CLR.W	$148(A1)
	TST.W	$10C(A1)
	BEQ.S	LAB_2ECA
	MOVEQ	#1,D0
	MOVE.W	D0,$14E(A1)
	TST.W	$118(A1)
	BEQ.S	LAB_2EAE
	MOVE.W	D0,$14C(A1)
	BRA.W	LAB_3152
LAB_2EAE:
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_4164
	MOVEA.L	$A8(A7),A0
	MOVE.L	D0,$134(A0)
	ADDQ.W	#4,A7
	BRA.W	LAB_3152
LAB_2ECA:
	LEA	1(A3),A0
	MOVE.L	A0,$134(A1)
	TST.L	$12C(A1)
	BEQ.S	LAB_2F46
	TST.L	$F8(A1)
	SNE	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	CMP.L	D0,D7
	BLE.S	LAB_2F46
	TST.B	1(A3)
	BEQ.S	LAB_2F46
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_2F10
	MOVEQ	#1,D0
	MOVEA.L	$A4(A7),A0
	MOVE.W	D0,$14E(A0)
	BRA.W	LAB_3152
LAB_2F10:
	MOVEA.L	$A4(A7),A0
	MOVE.L	$100(A0),D0
	SUB.L	D7,D0
	MOVE.L	$F8(A0),D1
	SNE	D2
	NEG.B	D2
	EXT.W	D2
	EXT.L	D2
	ADD.L	D2,D0
	MOVE.L	D0,$104(A0)
	TST.L	$F8(A0)
	SNE	D7
	NEG.B	D7
	EXT.W	D7
	EXT.L	D7
	MOVE.L	$12C(A0),$134(A0)
	SUBQ.L	#1,$138(A0)
	BRA.W	LAB_3152
LAB_2F46:
	TST.W	$118(A1)
	BEQ.S	LAB_2F62
	TST.B	1(A3)
	BNE.W	LAB_3152
	MOVEQ	#1,D0
	MOVE.W	D0,$14C(A1)
	MOVE.W	D0,$14E(A1)
	BRA.W	LAB_3152
LAB_2F62:
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.W	LAB_3152
	MOVEA.L	$A4(A7),A0
	MOVE.W	#$0001,$14E(A0)
	BRA.W	LAB_3152
LAB_2F86:
	MOVEA.L	$40(A7),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	(A0),$13C(A1)
	CLR.L	$140(A1)
	CLR.W	$148(A1)
	TST.W	$10C(A1)
	BEQ.S	LAB_2FD0
	MOVEQ	#1,D0
	MOVE.W	D0,$14E(A1)
	TST.W	$118(A1)
	BEQ.S	LAB_2FB4
	MOVE.W	D0,$14C(A1)
	BRA.W	LAB_3064
LAB_2FB4:
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_4164
	MOVEA.L	$A8(A7),A0
	MOVE.L	D0,$134(A0)
	ADDQ.W	#4,A7
	BRA.W	LAB_3064
LAB_2FD0:
	TST.L	$12C(A1)
	BEQ.S	LAB_3022
	TST.L	$F8(A1)
	SNE	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	CMP.L	D0,D7
	BLE.S	LAB_3022
	TST.B	1(A3)
	BEQ.S	LAB_3022
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_300C
	MOVEQ	#1,D0
	MOVEA.L	$A4(A7),A0
	MOVE.W	D0,$14E(A0)
	BRA.S	LAB_3058
LAB_300C:
	MOVEA.L	$A4(A7),A0
	MOVEA.L	$12C(A0),A3
	SUBQ.L	#1,A3
	MOVEQ	#1,D0
	MOVE.W	D0,$86(A0)
	SUBQ.L	#1,$130(A0)
	BRA.S	LAB_3058
LAB_3022:
	TST.W	$118(A1)
	BEQ.S	LAB_303A
	TST.B	1(A3)
	BNE.S	LAB_3058
	MOVEQ	#1,D0
	MOVE.W	D0,$14C(A1)
	MOVE.W	D0,$14E(A1)
	BRA.S	LAB_3058
LAB_303A:
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_3058
	MOVEA.L	$A4(A7),A0
	MOVE.W	#$0001,$14E(A0)
LAB_3058:
	LEA	1(A3),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	A0,$134(A1)
LAB_3064:
	MOVEA.L	$A4(A7),A0
	MOVE.L	$130(A0),$138(A0)
	BRA.W	LAB_3152
LAB_3072:
	MOVEA.L	$40(A7),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	(A0),$13C(A1)
	CLR.L	$140(A1)
	MOVE.L	$130(A1),$138(A1)
	CLR.W	$148(A1)
	TST.W	$10C(A1)
	BEQ.S	LAB_30BE
	MOVEQ	#1,D0
	MOVE.W	D0,$14E(A1)
	TST.W	$118(A1)
	BEQ.S	LAB_30A4
	MOVE.W	D0,$14C(A1)
	BRA.S	LAB_30FC
LAB_30A4:
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_4164
	MOVEA.L	$A8(A7),A0
	MOVE.L	D0,$134(A0)
	ADDQ.W	#4,A7
	BRA.S	LAB_30FC
LAB_30BE:
	LEA	1(A3),A0
	MOVE.L	A0,$134(A1)
	TST.W	$118(A1)
	BEQ.S	LAB_30DE
	TST.B	1(A3)
	BNE.S	LAB_30FC
	MOVEQ	#1,D0
	MOVE.W	D0,$14C(A1)
	MOVE.W	D0,$14E(A1)
	BRA.S	LAB_30FC
LAB_30DE:
	LEA	1(A3),A0
	MOVE.L	A1,-(A7)
	LEA	$72(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_30FC
	MOVEA.L	$A4(A7),A0
	MOVE.W	#$0001,$14E(A0)
LAB_30FC:
	LEA	1(A3),A0
	MOVEA.L	$A4(A7),A1
	MOVE.L	A0,$134(A1)
	BRA.S	LAB_3152
LAB_310A:
	MOVEA.L	$A4(A7),A0
	BSR.W	SUB_4312
	MOVEA.L	$A4(A7),A0
	BSR.W	SUB_4216
	MOVEA.L	$A4(A7),A0
	CLR.L	$12C(A0)
	MOVE.L	$140(A0),$144(A0)
	MOVE.W	$148(A0),$14A(A0)
	MOVE.L	$138(A0),$130(A0)
	MOVEA.L	$40(A7),A1
	MOVE.L	$13C(A0),(A1)
	TST.W	$118(A0)
	BEQ.S	LAB_3148
	MOVEQ	#4,D0
	BRA.W	LAB_321A
LAB_3148:
	MOVEA.L	$134(A0),A2
	MOVEA.L	A2,A3
	SUBQ.L	#1,A3
	BRA.S	LAB_3164
LAB_3152:
	TST.W	$98(A7)
	BNE.S	LAB_3160
	MOVE.L	$60(A7),D0
	BRA.W	LAB_321A
LAB_3160:
	LEA	1(A3),A2
LAB_3164:
	ADDQ.L	#1,A3
	BRA.W	LAB_25E2
LAB_316A:
	MOVEA.L	$A4(A7),A0
	TST.W	$118(A0)
	BEQ.S	LAB_317C
	MOVE.L	$60(A7),D0
	BRA.W	LAB_321A
LAB_317C:
	CLR.W	$5E(A7)
	MOVEA.L	A0,A1
	LEA	STR_0_34M_36M_END_OF_FILE_LIST_3(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$A4(A7),A0
	TST.L	$104(A0)
	BEQ.S	LAB_320E
	TST.W	$108(A0)
	BNE.S	LAB_320E
	BSR.W	SUB_329E
	SUBQ.L	#2,D0
	BLT.S	LAB_320E
	CMPI.L	#$00000008,D0
	BGE.S	LAB_320E
	ADD.W	D0,D0
	MOVE.W	LAB_31B6(PC,D0.W),D0
	JMP	LAB_31B6+2(PC,D0.W)
LAB_31B6:
	DC.W	(LAB_31C6)-(LAB_31B6+2)	;31b6: 000e
	DC.W	(LAB_320E)-(LAB_31B6+2)	;31b8: 0056
	DC.W	(LAB_320E)-(LAB_31B6+2)	;31ba: 0056
	DC.W	(LAB_320E)-(LAB_31B6+2)	;31bc: 0056
	DC.W	(LAB_31CE)-(LAB_31B6+2)	;31be: 0016
	DC.W	(LAB_31D6)-(LAB_31B6+2)	;31c0: 001e
	DC.W	(LAB_31E6)-(LAB_31B6+2)	;31c2: 002e
	DC.W	(LAB_31DE)-(LAB_31B6+2)	;31c4: 0026
LAB_31C6:
	MOVEQ	#1,D0
	MOVE.L	D0,$60(A7)
	BRA.S	LAB_320E
LAB_31CE:
	MOVEQ	#3,D0
	MOVE.L	D0,$60(A7)
	BRA.S	LAB_320E
LAB_31D6:
	MOVEQ	#2,D0
	MOVE.L	D0,$60(A7)
	BRA.S	LAB_320E
LAB_31DE:
	MOVEQ	#5,D0
	MOVE.L	D0,$60(A7)
	BRA.S	LAB_320E
LAB_31E6:
	MOVEA.L	$A4(A7),A0
	MOVE.L	$140(A0),$144(A0)
	MOVE.W	$148(A0),$14A(A0)
	MOVE.L	$138(A0),$130(A0)
	MOVEA.L	$40(A7),A1
	MOVE.L	$13C(A0),(A1)
	MOVEA.L	$134(A0),A5
	MOVE.W	#$0001,$5E(A7)
LAB_320E:
	TST.W	$5E(A7)
	BNE.W	LAB_25D2
	MOVE.L	$60(A7),D0
LAB_321A:
	MOVEM.L	(A7)+,D2/D5-D7/A2-A3/A5-A6
	ADDA.W	#$0080,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_3224  -  referenced from 8 call site(s)
; ------------------------------------------------------------------
SUB_3224:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	LEA	STR_0_36MMORE_32M_33MY_32M_33MN(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	TST.W	$114(A5)
	BNE.S	LAB_3254
	BTST	#7,$B1(A5)
	BEQ.S	LAB_3248
	LEA	STR_32M_33MF_32M_33MR_32M_36M_FL(PC),A0
	BRA.S	LAB_324C
LAB_3248:
	LEA	STR_32M_33MF_32M_36MLAG(PC),A0
LAB_324C:
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_3254:
	TST.W	$10A(A5)
	BEQ.S	LAB_3266
	LEA	STR_32M_33MS_32M_36MKIP_CONF(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_3266:
	LEA	STR_32M_33M_32M_36M_HELP_32M_33M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_3276  -  referenced from 10 call site(s)
; ------------------------------------------------------------------
SUB_3276:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	LEA	LAB_464(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_328A  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
SUB_328A:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	LEA	LAB_4AC(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_329E  -  referenced from 5 call site(s)
; ------------------------------------------------------------------

;read keypress and execute relevant action
SUB_329E:
	SUBA.W	#$0134,A7
	MOVEM.L	D5-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A5),A3
	MOVEA.L	iconbase(A5),A2
	MOVEQ	#0,D7
	MOVEQ	#0,D6
	CLR.L	$104(A5)
	MOVEA.L	A5,A0
	BSR.W	SUB_3224
LAB_32BE:
	MOVEA.L	A5,A0
	BSR.W	hotKey
	MOVE.B	D0,$84(A7)
	EXT.W	D0
	EXT.L	D0
	BSR.W	SUB_5BFE
	MOVE.B	D0,$84(A7)
	EXT.W	D0
	EXT.L	D0
	SUBQ.L	#3,D0
	BLT.W	LAB_3B3A
	CMPI.L	#$00000057,D0
	BGE.W	LAB_3B3A
	ADD.W	D0,D0
	MOVE.W	LAB_32F2(PC,D0.W),D0
	JMP	LAB_32F2+2(PC,D0.W)
LAB_32F2:
	DC.W	(LAB_34E4)-(LAB_32F2+2)	;32f2: 01f0
	DC.W	(LAB_3870)-(LAB_32F2+2)	;32f4: 057c
	DC.W	(LAB_385E)-(LAB_32F2+2)	;32f6: 056a
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;32f8: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;32fa: 0846
	DC.W	(LAB_351C)-(LAB_32F2+2)	;32fc: 0228
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;32fe: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3300: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3302: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3304: 0846
	DC.W	(LAB_33A0)-(LAB_32F2+2)	;3306: 00ac
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3308: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;330a: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;330c: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;330e: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3310: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3312: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3314: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3316: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3318: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;331a: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;331c: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;331e: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3320: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3322: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3324: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3326: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3328: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;332a: 0846
	DC.W	(LAB_33A0)-(LAB_32F2+2)	;332c: 00ac
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;332e: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3330: 0846
	DC.W	(LAB_366A)-(LAB_32F2+2)	;3332: 0376
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3334: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3336: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3338: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;333a: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;333c: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;333e: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3340: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3342: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3344: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3346: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3348: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;334a: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;334c: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;334e: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3350: 0846
	DC.W	(LAB_385E)-(LAB_32F2+2)	;3352: 056a
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3354: 0846
	DC.W	(LAB_370C)-(LAB_32F2+2)	;3356: 0418
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3358: 0846
	DC.W	(LAB_371E)-(LAB_32F2+2)	;335a: 042a
	DC.W	(LAB_37CA)-(LAB_32F2+2)	;335c: 04d6
	DC.W	(LAB_3870)-(LAB_32F2+2)	;335e: 057c
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3360: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3362: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3364: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3366: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3368: 0846
	DC.W	(LAB_3908)-(LAB_32F2+2)	;336a: 0614
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;336c: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;336e: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3370: 0846
	DC.W	(LAB_34A2)-(LAB_32F2+2)	;3372: 01ae
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3374: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3376: 0846
	DC.W	(LAB_35CA)-(LAB_32F2+2)	;3378: 02d6
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;337a: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;337c: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;337e: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3380: 0846
	DC.W	(LAB_3468)-(LAB_32F2+2)	;3382: 0174
	DC.W	(LAB_348C)-(LAB_32F2+2)	;3384: 0198
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3386: 0846
	DC.W	(LAB_3400)-(LAB_32F2+2)	;3388: 010c
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;338a: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;338c: 0846
	DC.W	(LAB_34C2)-(LAB_32F2+2)	;338e: 01ce
	DC.W	(LAB_366A)-(LAB_32F2+2)	;3390: 0376
	DC.W	(LAB_3418)-(LAB_32F2+2)	;3392: 0124
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3394: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3396: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;3398: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;339a: 0846
	DC.W	(LAB_3B3A)-(LAB_32F2+2)	;339c: 0846
	DC.W	(LAB_33A0)-(LAB_32F2+2)	;339e: 00ac
LAB_33A0:
	MOVEQ	#$D,D0
	CMP.B	$84(A7),D0
	BNE.S	LAB_33BE
	TST.W	D6
	BEQ.S	LAB_33BE
	MOVEQ	#2,D7
	LEA	LAB_334(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.W	LAB_3DB6
LAB_33BE:
	BTST	#6,$B1(A5)
	BEQ.S	LAB_33E6
	LEA	LAB_4FE(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	BTST	#5,$B1(A5)
	BEQ.S	LAB_33E0
	MOVEQ	#5,D7
	BRA.W	LAB_3DB6
LAB_33E0:
	MOVEQ	#1,D7
	BRA.W	LAB_3DB6
LAB_33E6:
	BTST	#5,$B1(A5)
	SNE	D0
	MOVEQ	#1,D7
	SUB.B	D0,D7
	SUB.B	D0,D7
	SUB.B	D0,D7
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	BRA.W	LAB_3DB6
LAB_3400:
	TST.W	D6
	BNE.W	LAB_3DB6
	MOVEQ	#1,D6
	LEA	STR_N(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	BRA.W	LAB_3DB6
LAB_3418:
	TST.W	D6
	BEQ.S	LAB_343C
	MOVEA.L	A5,A0
	BSR.W	SUB_3DDA
	TST.W	D0
	BEQ.S	LAB_3430
	MOVEQ	#3,D7
	MOVE.W	#$0001,$108(A5)
	BRA.S	LAB_3436
LAB_3430:
	MOVEA.L	A5,A0
	BSR.W	SUB_3224
LAB_3436:
	MOVEQ	#0,D6
	BRA.W	LAB_3DB6
LAB_343C:
	TST.W	$10A(A5)
	BEQ.W	LAB_3DB6
	MOVEQ	#6,D7
	BTST	#4,$B2(A5)
	BEQ.S	LAB_345E
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	BRA.W	LAB_3DB6
LAB_345E:
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	BRA.W	LAB_3DB6
LAB_3468:
	MOVEQ	#7,D7
	BTST	#4,$B2(A5)
	BEQ.S	LAB_3482
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	BRA.W	LAB_3DB6
LAB_3482:
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	BRA.W	LAB_3DB6
LAB_348C:
	MOVEQ	#9,D7
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	ADDQ.L	#1,$104(A5)
	BRA.W	LAB_3DB6
LAB_34A2:
	LEA	LAB_4FE(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	BTST	#4,$B1(A5)
	BEQ.S	LAB_34BC
	MOVEQ	#5,D7
	BRA.W	LAB_3DB6
LAB_34BC:
	MOVEQ	#1,D7
	BRA.W	LAB_3DB6
LAB_34C2:
	TST.W	D6
	BEQ.S	LAB_34D2
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_34D2:
	MOVEQ	#2,D7
	LEA	STR_QUIT(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.W	LAB_3DB6
LAB_34E4:
	BTST	#3,$B2(A5)
	BNE.W	LAB_3DB6
	TST.W	D6
	BEQ.S	LAB_34FE
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_34FE:
	MOVEQ	#2,D7
	LEA	LAB_334(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_0M_BREAK(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.W	LAB_3DB6
LAB_351C:
	TST.W	D6
	BEQ.S	LAB_3532
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#0,D6
	BRA.W	LAB_3DB6
LAB_3532:
	TST.W	$118(A5)
	BEQ.S	LAB_3576
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVE.L	$100(A5),D0
	MOVEA.L	$128(A5),A1
	BSR.W	SUB_6A5A
	LEA	$14(A7),A7
	EXT.L	D0
	BRA.S	LAB_35B2
LAB_3576:
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVE.L	$100(A5),D0
	MOVEA.L	$128(A5),A1
	BSR.W	SUB_6642
	LEA	$14(A7),A7
	EXT.L	D0
LAB_35B2:
	TST.L	D0
	BEQ.W	LAB_3DB6
	LEA	LAB_4FE(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#8,D7
	BRA.W	LAB_3DB6

;flag file by name
LAB_35CA:
	TST.W	$114(A5)
	BNE.W	LAB_3DB6
	MOVEQ	#0,D6
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	LEA	STR_36MFILE_NAME_S_TO_FLAG_0M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEA.L	$2C(A5),A0
	MOVEA.L	A5,A1
	MOVEQ	#$38,D0
	NOT.B	D0
	BSR.W	SUB_2000
	MOVEA.L	$2C(A5),A0
	MOVE.L	A0,D0
LAB_35FA:
	TST.B	(A0)+
	BNE.S	LAB_35FA
	SUBQ.L	#1,A0
	SUBA.L	D0,A0
	MOVE.L	A0,D0
	MOVEQ	#$39,D1
	SUB.L	D1,D0
	MOVEA.L	DOOR_Msg(A5),A0
	MOVEQ	#$D,D1
	MOVE.L	D1,$E0(A0)
	MOVE.L	D0,$80(A7)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg        ;JH_FLAGFILE
	MOVE.L	$80(A7),D0
	TST.L	D0
	BLE.S	LAB_365A
LAB_3624:
	CMPI.L	#$0000000a,$80(A7)
	BLT.S	LAB_3642
	LEA	LAB_52A(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#$A,D0
	SUB.L	D0,$80(A7)
	BRA.S	LAB_3624
LAB_3642:
	TST.L	$80(A7)
	BEQ.S	LAB_365A
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	SUBQ.L	#1,$80(A7)
	BRA.S	LAB_3642
LAB_365A:
	MOVEA.L	A5,A0
	BSR.W	SUB_328A
	MOVEA.L	A5,A0
	BSR.W	SUB_3224

	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2    ;clear screen
	MOVEQ	#8,D7
	BRA.W	LAB_3DAC
	;BRA.W	LAB_3DB6

;flag file by number
LAB_366A:
	BTST	#7,$B1(A5)
	BEQ.W	LAB_3DB6
	MOVEQ	#0,D6
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	LEA	STR_36MFILE_NUMBER_S_TO_FLAG_0M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	LEA	$88(A7),A0
	MOVEA.L	A5,A1
	MOVEQ	#$38,D0
	NOT.B	D0
	BSR.W	SUB_2000        ;get input (file number)
	LEA	$88(A7),A0
	MOVEA.L	A0,A1
LAB_369C:
	TST.B	(A1)+
	BNE.S	LAB_369C
	SUBQ.L	#1,A1
	SUBA.L	A0,A1
	MOVE.L	A1,D0
	MOVEQ	#$37,D1
	SUB.L	D1,D0
	MOVEM.L	D0,$80(A7)
	BLE.S	LAB_36E8
LAB_36B2:
	CMPI.L	#$0000000a,$80(A7)
	BLT.S	LAB_36D0
	LEA	LAB_52A(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#$A,D0
	SUB.L	D0,$80(A7)
	BRA.S	LAB_36B2
LAB_36D0:
	TST.L	$80(A7)
	BEQ.S	LAB_36E8
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	SUBQ.L	#1,$80(A7)
	BRA.S	LAB_36D0
LAB_36E8:
	MOVEA.L	A5,A0
	BSR.W	SUB_328A
	MOVE.L	A5,-(A7)
	CLR.L	-(A7)
	LEA	$90(A7),A0
	MOVEA.L	$12C(A5),A1
	MOVEQ	#0,D0
	BSR.W	SUB_5C18
	MOVEA.L	A5,A0
	BSR.W	SUB_3224
	ADDQ.W	#8,A7
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2    ;clear screen
	MOVEQ	#8,D7
	BRA.W	LAB_3DAC
  ;BRA.W	LAB_3DB6
  
LAB_370C:
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#8,D7
	BRA.W	LAB_3DB6
  
LAB_371E:
	TST.W	$118(A5)
	BEQ.S	LAB_3760
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVEA.L	$128(A5),A1
	MOVEQ	#1,D0
	BSR.W	SUB_6A5A
	LEA	$14(A7),A7
	EXT.L	D0
	BRA.S	LAB_379A
LAB_3760:
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVEA.L	$128(A5),A1
	MOVEQ	#1,D0
	BSR.W	SUB_6642
	LEA	$14(A7),A7
	EXT.L	D0
LAB_379A:
	TST.L	D0
	BEQ.W	LAB_3DB6
	MOVE.L	$128(A5),$134(A5)
	CLR.L	$140(A5)
	MOVEQ	#-1,D0
	MOVE.L	D0,$13C(A5)
	CLR.W	$148(A5)
	CLR.L	$138(A5)
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#8,D7
	BRA.W	LAB_3DB6
LAB_37CA:
	TST.W	$118(A5)
	BEQ.S	LAB_380C
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVEA.L	$128(A5),A1
	MOVEQ	#1,D0
	BSR.W	SUB_6A5A
	LEA	$14(A7),A7
	EXT.L	D0
	BRA.S	LAB_3846
LAB_380C:
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVEA.L	$128(A5),A1
	MOVEQ	#1,D0
	BSR.W	SUB_6642
	LEA	$14(A7),A7
	EXT.L	D0
LAB_3846:
	TST.L	D0
	BEQ.W	LAB_3DB6
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#8,D7
	BRA.W	LAB_3DB6
LAB_385E:
	MOVEQ	#1,D7
	LEA	LAB_4FE(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	BRA.W	LAB_3DB6
LAB_3870:
	TST.W	$118(A5)
	BEQ.S	LAB_38B4
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVE.L	$100(A5),D0
	MOVEA.L	$128(A5),A1
	BSR.W	SUB_6A5A
	LEA	$14(A7),A7
	EXT.L	D0
	BRA.S	LAB_38F0
LAB_38B4:
	LEA	$134(A5),A0
	LEA	$140(A5),A1
	LEA	$13C(A5),A6
	MOVE.L	A6,$24(A7)
	LEA	$148(A5),A6
	MOVE.L	A6,$28(A7)
	LEA	$138(A5),A6
	MOVE.L	A5,-(A7)
	MOVE.L	A6,-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	$30(A7),-(A7)
	MOVE.L	A1,-(A7)
	MOVE.L	$100(A5),D0
	MOVEA.L	$128(A5),A1
	BSR.W	SUB_6642
	LEA	$14(A7),A7
	EXT.L	D0
LAB_38F0:
	TST.L	D0
	BEQ.W	LAB_3DB6
	LEA	LAB_4FE(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#8,D7
	BRA.W	LAB_3DB6
LAB_3908:
	TST.W	D6
	BEQ.S	LAB_391A
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#0,D6
LAB_391A:
	LEA	STR_36MTHESE_ARE_THE_COMMANDS_TH(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33MENTER_32M_33MY_32M_33(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33MC_32M_34M_36MCLEAR_SC(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33MDOWNARROW_32M_33M3_32(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33MUPARROW_32M_33M9_32M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33M7_32M_34M_36MGO_TO_ST(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33M5_32M_34M_36MREDRAW_P(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33MNS_32M_34M_36MTURN_ON(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33M_32M_34M_36MVIEW_THIS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	TST.W	$114(A5)
	BNE.S	LAB_3998
	LEA	STR_32M_33MF_32M_34M_36MFLAG_FIL(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_3998:
	BTST	#7,$B1(A5)
	BEQ.S	LAB_39AC
	LEA	STR_32M_33MR_32M_33M_32M_34M_36M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_39AC:
	LEA	STR_32M_33MK_32M_34M_36MSKIP_DIR(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	TST.W	$10A(A5)
	BEQ.S	LAB_39CA
	LEA	STR_32M_33MS_32M_34M_36MSKIP_CON(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_39CA:
	LEA	STR_32M_33ML_32M_34M_36MRELOAD_D(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33MN_32M_33MQ_32M_34M_36(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	STR_32M_33MCTRL_C_32M_34M_36MQUI(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVE.W	$30(A5),D0
	MOVEQ	#3,D1
	CMP.W	D1,D0
	BHI.S	LAB_3A04
	SUBQ.W	#3,D0
	BNE.S	LAB_3A10
	CMPI.W	#$0026,$32(A5)
	BCS.S	LAB_3A10
LAB_3A04:
	LEA	STR_32M_33MD_32M_34M_36MQUIT_AND(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_3A10:
	TST.W	$154(A5)
	BEQ.W	LAB_3B04
	CLR.W	$82(A7)
	LEA	STR_PPC_3(PC),A0
	LEA	$88(A7),A1
	MOVE.L	(A0)+,(A1)+
	CLR.B	(A1)
	MOVEQ	#0,D5
LAB_3A2A:
	CMP.W	$154(A5),D5
	BCC.W	LAB_3AF2
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	ADDA.L	D0,A0
	MOVEQ	#0,D0
	MOVE.W	(A0),D0
	MOVE.L	D0,-(A7)
	PEA	STR_DSC_HU(PC)
	PEA	$94(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	TST.W	$10A(A5)
	BEQ.S	LAB_3A82
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	MOVEA.L	A0,A1
	ADDA.L	D0,A1
	TST.B	3(A1)
	BEQ.S	LAB_3A82
	MOVE.W	#$0001,$82(A7)
	LEA	STR_0M_3(PC),A1
	BRA.S	LAB_3A86
LAB_3A82:
	LEA	LAB_AE2(PC),A1
LAB_3A86:
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	ADDA.L	D0,A0
	MOVE.B	2(A0),D0
	EXT.W	D0
	EXT.L	D0
	MOVEM.L	D0,$20(A7)
	MOVE.L	A1,$1C(A7)
	MOVE.L	$98(A5),D1
	BEQ.S	LAB_3AB6
	MOVEA.L	D1,A6
	MOVEA.L	$36(A6),A0
	BRA.S	LAB_3AC0
LAB_3AB6:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A6
	MOVEA.L	8(A6),A0
LAB_3AC0:
	LEA	$88(A7),A1
	MOVEA.L	A2,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,-(A7)
	MOVE.L	$24(A7),-(A7)
	MOVE.L	$24(A7),-(A7)
	PEA	STR_32M_33M_C_32M_34M_36M_0M(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$14(A7),A7
	ADDQ.W	#1,D5
	BRA.W	LAB_3A2A
LAB_3AF2:
	TST.W	$82(A7)
	BEQ.S	LAB_3B04
	LEA	STR_36M_CAN_ONLY_BE_USED_IN_YOUR(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_3B04:
	LEA	STR_0M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BTST	#2,$B2(A5)
	BEQ.S	LAB_3B30
	MOVEA.L	A5,A0
	BSR.W	doPause
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#8,D7
	BRA.W	LAB_3DB6
LAB_3B30:
	MOVEA.L	A5,A0
	BSR.W	SUB_3224
	BRA.W	LAB_3DB6

LAB_3B3A:
	MOVEQ	#$44,D0
	CMP.B	$84(A7),D0        ;"D" download
	BNE.S	LAB_3B98
	MOVE.W	$30(A5),D0
	MOVEQ	#3,D1
	CMP.W	D1,D0
	BHI.S	LAB_3B58
	SUBQ.W	#3,D0
	BNE.S	LAB_3B98
	CMPI.W	#$0026,$32(A5)
	BCS.S	LAB_3B98
LAB_3B58:
	TST.W	D6
	BEQ.S	LAB_3B68
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_3B68:
	LEA	STR_DOWNLOAD(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	#$00000274,$E0(A0)
	LEA	LAB_B26(PC),A0
	MOVEA.L	$2C(A5),A1
LAB_3B88:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_3B88
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg        ;RETURNCOMMAND2
	MOVEA.L	A5,A0
	BSR.W	SUB_1D74
LAB_3B98:
	MOVEQ	#0,D5
LAB_3B9A:
	CMP.W	$154(A5),D5
	BCC.W	LAB_3DB6
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	MOVEA.L	A0,A1
	ADDA.L	D0,A1
	MOVE.B	2(A1),D0
	CMP.B	$84(A7),D0      ;find relevant key
	BNE.W	LAB_3DB0
	TST.W	$116(A5)
	BNE.S	LAB_3BCE
	TST.B	3(A1)
	BNE.W	LAB_3D74
LAB_3BCE:
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	ADDA.L	D0,A0
	MOVEQ	#0,D0
	MOVE.W	(A0),D0
	MOVE.L	D0,-(A7)
	PEA	STR_PPC_CMD_HU(PC)
	PEA	$90(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_3BFE
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_3C08
LAB_3BFE:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_3C08:
	LEA	$88(A7),A1
	MOVEA.L	A2,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$80(A7)
	BTST	#7,$B1(A5)
	BEQ.W	LAB_3D1C
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	ADDA.L	D0,A0
	MOVEQ	#0,D0
	MOVE.W	(A0),D0
	MOVE.L	D0,-(A7)
	PEA	STR_PPC_NUM_HU(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_3C54
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_3C5E
LAB_3C54:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_3C5E:
	MOVEA.L	$2C(A5),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A0
	LEA	LAB_118(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.W	LAB_3D1C
	MOVEA.L	$80(A7),A0
	MOVE.L	A0,D0
LAB_3C7C:
	TST.B	(A0)+
	BNE.S	LAB_3C7C
	SUBQ.L	#1,A0
	SUBA.L	D0,A0
	MOVE.L	A0,$2C(A7)
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	MOVE.L	$80(A7),-(A7)
	PEA	STR_36M_0M_36M_FILE_NUMBER_S_0M(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	BSR.W	lineOutput
	MOVEQ	#$3C,D0
	SUB.L	$38(A7),D0
	LEA	$3C(A7),A0
	MOVEA.L	A5,A1
	BSR.W	SUB_2000
	MOVEA.L	A5,A0
	BSR.W	SUB_328A
	MOVEA.L	$8C(A7),A0
	LEA	$94(A7),A1
LAB_3CC4:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_3CC4
	LEA	$94(A7),A0
	LEA	LAB_AE2(PC),A1
	BSR.W	LAB_812C
	ADDQ.L	#1,$38(A7)
	LEA	$94(A7),A0
	MOVE.L	$38(A7),D0
	ADDA.L	D0,A0
	MOVEQ	#$63,D1
	ADD.L	D1,D1
	SUB.L	D0,D1
	MOVE.L	A5,(A7)
	MOVE.L	A0,-(A7)
	MOVE.L	D1,D0
	LEA	$40(A7),A0
	MOVEA.L	$12C(A5),A1
	BSR.W	SUB_5C18
	MOVEA.L	A5,A0
	BSR.W	SUB_3224
	MOVEA.L	$90(A7),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	$98(A7),A0
	MOVEA.L	A5,A1
	BSR.W	SUB_2150
	LEA	$10(A7),A7
	BRA.S	LAB_3D42
LAB_3D1C:
	TST.W	D6
	BEQ.S	LAB_3D2C
	LEA	LAB_23C(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_3D2C:
	MOVEA.L	$80(A7),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$80(A7),A0
	MOVEA.L	A5,A1
	BSR.W	SUB_2150
LAB_3D42:
	LEA	STR_0M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	BTST	#2,$B2(A5)
	BEQ.S	LAB_3D6C
	MOVEA.L	A5,A0
	BSR.W	doPause
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2    ;clear screen
	MOVEQ	#8,D7
	BRA.S	LAB_3DAC
  
LAB_3D6C:
	MOVEA.L	A5,A0
	BSR.W	SUB_3224
	BRA.S	LAB_3DAC
LAB_3D74:
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	LEA	STR_36MTHAT_COMMAND_CAN_ONLY_BE(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEQ	#$3C,D1
	MOVEA.L	A3,A6
	JSR	_LVODelay(A6)	; Delay(ticks) - pause the task for N ticks (1/50s)
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	#$0000020a,$E0(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg        ;BB_PURGELINE
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	MOVEA.L	A5,A0
	BSR.W	SUB_3224
LAB_3DAC:
	MOVEQ	#0,D6
	BRA.S	LAB_3DB6
LAB_3DB0:
	ADDQ.W	#1,D5
	BRA.W	LAB_3B9A
LAB_3DB6:
	TST.L	D7
	BEQ.W	LAB_32BE
	MOVEA.L	DOOR_Msg(A5),A0
	MOVE.L	#$0000020a,$E0(A0)
	MOVEA.L	A5,A0
	BSR.W	sendXimMsg      ;BB_PURGELINE
	MOVE.L	D7,D0
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5-A6
	ADDA.W	#$0134,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_3DDA  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_3DDA:
	MOVEM.L	D7/A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	BTST	#2,$B1(A5)
	BEQ.S	LAB_3E36
	LEA	STR_36MNON_STOP_SCROLLING_ARE_YO(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
LAB_3DFA:
	MOVEA.L	A5,A0
	BSR.W	hotKey
	MOVE.L	D0,D7
	MOVE.B	D7,D0
	EXT.W	D0
	EXT.L	D0
	BSR.W	SUB_5BFE
	MOVE.L	D0,D7
	MOVEQ	#$D,D0
	CMP.B	D0,D7
	BNE.S	LAB_3E16
	MOVEQ	#$59,D7
LAB_3E16:
	MOVEQ	#$59,D0
	CMP.B	D0,D7
	BEQ.S	LAB_3E22
	MOVEQ	#$4E,D0
	CMP.B	D0,D7
	BNE.S	LAB_3DFA
LAB_3E22:
	MOVEA.L	A5,A0
	BSR.W	SUB_3276
	MOVEQ	#$59,D1
	CMP.B	D1,D7
	SEQ	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	BRA.S	LAB_3E38
LAB_3E36:
	MOVEQ	#1,D0
LAB_3E38:
	MOVEM.L	(A7)+,D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_3E3E  -  referenced from 17 call site(s)
; ------------------------------------------------------------------
SUB_3E3E:
	SUBQ.W	#4,A7
	MOVEM.L	D6-D7/A2-A3/A5-A6,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	$20(A7),A2
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	dosbase(A2),$18(A7)
	MOVEQ	#$1E,D0
	CMP.L	D0,D7
	BLE.S	LAB_3E98
	MOVEQ	#$20,D0
	CMP.B	(A5),D0
	BEQ.S	LAB_3E98
	MOVEQ	#$2D,D1
	CMP.B	$19(A5),D1
	BNE.S	LAB_3E98
	CMP.B	DOOR_Msg(A5),D0
	BNE.S	LAB_3E98
	MOVE.B	$1F(A5),D6
	CLR.B	$1F(A5)
	LEA	$17(A5),A0
	MOVEA.L	$12(A3),A1
LAB_3E7E:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_3E7E
	MOVE.B	D6,$1F(A5)
	MOVE.L	A3,D1
	MOVEA.L	$18(A7),A6
	JSR	_LVOStrToDate(A6)	; StrToDate(dtbuf) - parse a string into a date
	TST.L	D0
	BEQ.S	LAB_3E98
	MOVEQ	#1,D0
	BRA.S	LAB_3E9A
LAB_3E98:
	MOVEQ	#0,D0
LAB_3E9A:
	MOVEM.L	(A7)+,D6-D7/A2-A3/A5-A6
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_3EA2  -  referenced from 10 call site(s)
; ------------------------------------------------------------------
SUB_3EA2:
	MOVEM.L	A2-A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	LEA	1(A5),A2
LAB_3EAE:
	MOVE.B	(A2),D0
	BEQ.S	LAB_3EBC
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BEQ.S	LAB_3EBC
	ADDQ.L	#1,A2
	BRA.S	LAB_3EAE
LAB_3EBC:
	TST.B	(A2)
	BEQ.S	LAB_3EDC
	MOVE.L	A2,D0
	MOVE.L	A5,D1
	SUB.L	D1,D0
	MOVE.L	$10(A7),-(A7)
	MOVEA.L	D1,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_3EDC
	MOVEQ	#1,D0
	BRA.S	LAB_3EDE
LAB_3EDC:
	MOVEQ	#0,D0
LAB_3EDE:
	MOVEM.L	(A7)+,A2-A3/A5
	RTS

checkDirListFileSize:
	MOVEM.L	D6-D7/A5,-(A7)
	MOVEA.L	A0,A5
	MOVEQ	#0,D6
	MOVEQ	#$20,D0
	CMP.B	7(A5),D0      ;first character should be a space
	BEQ.S	LAB_3EF8
	MOVEQ	#1,D0
	BRA.W	LAB_3F6C      ;check failed
LAB_3EF8:
	MOVEQ	#0,D7
LAB_3EFA:
	MOVEQ	#$20,D0
	CMP.B	0(A5,D7.L),D0   ;another space
	BNE.S	LAB_3F0C        ;found start of value
	MOVEQ	#7,D0
	CMP.L	D0,D7
	BGE.S	LAB_3F0C        ;max 6 spaces
	ADDQ.L	#1,D7         ;increment counter
	BRA.S	LAB_3EFA        ;go back

LAB_3F0C:
	MOVE.L	D7,D0
	SUBQ.L	#7,D0       ;check number of spaces
	BNE.S	LAB_3F16      ;check ok
	MOVEQ	#1,D0
	BRA.W	LAB_3F6C      ;check fail
LAB_3F16:

	MOVE.B	0(A5,D7.L),D0   ;get character of value
	MOVEQ	#".",D1
	CMP.B	D1,D0
  BEQ.S .skip

	MOVEQ	#$30,D1
	CMP.B	D1,D0
	BLT.S	LAB_3F3E        ;lower than '0'
	MOVEQ	#$39,D1
	CMP.B	D1,D0
	BGT.S	LAB_3F3E        ;higher than '9'

.skip
	MOVEQ	#7,D0
	CMP.L	D0,D7
	BGE.S	LAB_3F3E        ;done

	MOVE.B	0(A5,D7.L),D0
	EXT.W	D0
	EXT.L	D0

	MOVEQ	#".",D1
  CMP.B D1,D0
  BEQ.S .skip2
  
	MOVEQ	#$30,D1
	SUB.L	D1,D0
	ADD.L	D0,D6           ;total up the digits
.skip2
	ADDQ.L	#1,D7         ;increment counter
	BRA.S	LAB_3F16        ;next char

LAB_3F3E:
	MOVEQ	#6,D0
	CMP.L	D0,D7
	BNE.S	LAB_3F5C
	MOVE.B	6(A5),D0
	MOVEQ	#"m",D1         ; is it "m"
	CMP.B	D1,D0
	BEQ.S	LAB_3F54
	MOVEQ	#"M",D1         ; is it "M"
	CMP.B	D1,D0
	BEQ.S	LAB_3F54
	MOVEQ	#$6B,D1         ; is it "k"
	CMP.B	D1,D0
	BEQ.S	LAB_3F54
	MOVEQ	#$4B,D1         ; is it "K"
	CMP.B	D1,D0
	BNE.S	LAB_3F5C
LAB_3F54:
	TST.L	D6
	BEQ.S	LAB_3F5C
	MOVEQ	#0,D0
	BRA.S	LAB_3F6C
LAB_3F5C:
	MOVEQ	#7,D0
	CMP.L	D0,D7
	BLT.S	LAB_3F66
	TST.L	D6
	BNE.S	LAB_3F6A
LAB_3F66:
	MOVEQ	#1,D0
	BRA.S	LAB_3F6C
LAB_3F6A:
	MOVEQ	#0,D0
LAB_3F6C:
	MOVEM.L	(A7)+,D6-D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_3F72  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_3F72:
	SUBA.W	#$0028,A7
	MOVEM.L	D7/A2-A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	A1,$10(A7)
	MOVE.B	#$02,$2A(A7)
	CLR.B	$2B(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$34(A7)
	MOVE.L	A0,$2C(A7)
	LEA	$15(A7),A0
	MOVE.L	A0,$30(A7)
	MOVEA.L	A5,A2
	MOVEA.L	A2,A3
LAB_3FA2:
	MOVE.B	(A3),D0
	BEQ.S	LAB_3FDA
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BNE.S	LAB_3FD6
	MOVE.L	A3,D0
	MOVE.L	A2,D1
	SUB.L	D1,D0
	MOVE.L	$10(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$22(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_3FD2
	MOVE.L	$1E(A7),D0
	CMP.L	D7,D0
	BLT.S	LAB_3FD2
	MOVE.L	A2,D0
	BRA.S	LAB_3FDC
LAB_3FD2:
	LEA	1(A3),A2
LAB_3FD6:
	ADDQ.L	#1,A3
	BRA.S	LAB_3FA2
LAB_3FDA:
	MOVEQ	#0,D0
LAB_3FDC:
	MOVEM.L	(A7)+,D7/A2-A3/A5
	ADDA.W	#$0028,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_3FE6  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_3FE6:
	SUBA.W	#$002c,A7
	MOVEM.L	D6-D7/A2-A3/A5,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	A1,$14(A7)
	MOVEA.L	A5,A2
	ADDA.L	D6,A2
	CLR.L	$3C(A7)
	MOVEQ	#$1E,D0
	CMP.L	D0,D6
	BLE.S	LAB_4080
	MOVE.B	#$02,$2E(A7)
	CLR.B	$2F(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$38(A7)
	MOVE.L	A0,$30(A7)
	LEA	$19(A7),A0
	MOVE.L	A0,$34(A7)
	MOVEA.L	A2,A3
	SUBQ.L	#1,A3
LAB_4026:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BEQ.S	LAB_4034
	CMPA.L	A5,A3
	BLS.S	LAB_4034
	SUBQ.L	#1,A3
	BRA.S	LAB_4026
LAB_4034:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BNE.S	LAB_4080
	MOVEA.L	A3,A2
LAB_403C:
	CMPA.L	A5,A3
	BCS.S	LAB_4080
	CMPA.L	A3,A5
	BEQ.S	LAB_404C
	MOVEQ	#$A,D0
	CMP.B	-1(A3),D0
	BNE.S	LAB_407C
LAB_404C:
	MOVE.L	A2,D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	$14(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$26(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_4078
	MOVE.L	$22(A7),D0
	CMP.L	D7,D0
	BGE.S	LAB_4074
	MOVE.L	$3C(A7),D0
	BRA.S	LAB_4084
LAB_4074:
	MOVE.L	A3,$3C(A7)
LAB_4078:
	MOVEA.L	A3,A2
	SUBQ.L	#1,A2
LAB_407C:
	SUBQ.L	#1,A3
	BRA.S	LAB_403C
LAB_4080:
	MOVE.L	$3C(A7),D0
LAB_4084:
	MOVEM.L	(A7)+,D6-D7/A2-A3/A5
	ADDA.W	#$002c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_408E  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_408E:
	MOVEM.L	D6-D7/A3/A5,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEQ	#-10,D0
	ADD.L	$A4(A3),D0
	CMP.L	D0,D7
	BGE.S	LAB_40B0
	MOVE.L	D7,D0
	MOVEA.L	A5,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_3F72
	BRA.S	LAB_40BC
LAB_40B0:
	MOVE.L	D7,D0
	MOVE.L	D6,D1
	MOVEA.L	A5,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_3FE6
LAB_40BC:
	MOVEM.L	(A7)+,D6-D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_40C2  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_40C2:
	SUBA.W	#$002c,A7
	MOVEM.L	D5-D7/A2-A3/A5,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	A1,$18(A7)
	MOVEA.L	A5,A2
	ADDA.L	D6,A2
	CLR.L	$40(A7)
	MOVEQ	#0,D5
	MOVEQ	#$1E,D0
	CMP.L	D0,D6
	BLE.S	LAB_4156
	MOVE.B	#$02,$32(A7)
	CLR.B	$33(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$3C(A7)
	MOVE.L	A0,$34(A7)
	LEA	$1D(A7),A0
	MOVE.L	A0,$38(A7)
	MOVEA.L	A2,A3
	SUBQ.L	#1,A3
LAB_4104:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BEQ.S	LAB_4112
	CMPA.L	A5,A3
	BLS.S	LAB_4112
	SUBQ.L	#1,A3
	BRA.S	LAB_4104
LAB_4112:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BNE.S	LAB_4156
	MOVEA.L	A3,A2
LAB_411A:
	CMPA.L	A5,A3
	BCS.S	LAB_4156
	CMPA.L	A3,A5
	BEQ.S	LAB_412A
	MOVEQ	#$A,D0
	CMP.B	-1(A3),D0
	BNE.S	LAB_4152
LAB_412A:
	MOVE.L	A2,D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	$18(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$2A(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_414E
	MOVE.L	A3,$40(A7)
	ADDQ.L	#1,D5
	CMP.L	D7,D5
	BEQ.S	LAB_4156
LAB_414E:
	MOVEA.L	A3,A2
	SUBQ.L	#1,A2
LAB_4152:
	SUBQ.L	#1,A3
	BRA.S	LAB_411A
LAB_4156:
	MOVE.L	$40(A7),D0
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5
	ADDA.W	#$002c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4164  -  referenced from 6 call site(s)
; ------------------------------------------------------------------
SUB_4164:
	MOVEM.L	A2-A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A5,A2
LAB_416E:
	MOVE.B	(A5),D0
	BEQ.S	LAB_419C
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BNE.S	LAB_4198
	MOVE.L	A5,D0
	MOVE.L	A2,D1
	SUB.L	D1,D0
	MOVE.L	$10(A7),-(A7)
	MOVEA.L	D1,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_4194
	MOVE.L	A2,D0
	BRA.S	LAB_419E
LAB_4194:
	LEA	1(A5),A2
LAB_4198:
	ADDQ.L	#1,A5
	BRA.S	LAB_416E
LAB_419C:
	MOVE.L	A5,D0
LAB_419E:
	MOVEM.L	(A7)+,A2-A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_41A4  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_41A4:
	MOVEM.L	A2-A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A5,A2
LAB_41AE:
	MOVE.B	(A2),D0
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BEQ.S	LAB_41BE
	TST.B	D0
	BEQ.S	LAB_41BE
	ADDQ.L	#1,A2
	BRA.S	LAB_41AE
LAB_41BE:
	TST.B	(A2)
	BEQ.S	LAB_41DE
	MOVE.L	A2,D0
	MOVE.L	A5,D1
	SUB.L	D1,D0
	MOVE.L	$10(A7),-(A7)
	MOVEA.L	D1,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_41DE
	MOVE.L	A5,D0
	BRA.S	LAB_4210
LAB_41DE:
	SUBQ.L	#1,A5
	MOVEA.L	A5,A2
	SUBQ.L	#1,A5
LAB_41E4:
	MOVEQ	#$A,D0
	CMP.B	(A5),D0
	BNE.S	LAB_420C
	ADDQ.L	#1,A5
	MOVE.L	A2,D0
	MOVE.L	A5,D1
	SUB.L	D1,D0
	MOVE.L	$10(A7),-(A7)
	MOVEA.L	D1,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_4208
	MOVE.L	A5,D0
	BRA.S	LAB_4210
LAB_4208:
	SUBQ.L	#1,A5
	MOVEA.L	A5,A2
LAB_420C:
	SUBQ.L	#1,A5
	BRA.S	LAB_41E4
LAB_4210:
	MOVEM.L	(A7)+,A2-A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4216  -  referenced from 4 call site(s)
; ------------------------------------------------------------------
SUB_4216:
	MOVEM.L	D7/A5,-(A7)
	MOVEA.L	A0,A5
	TST.W	$80(A5)
	BEQ.W	LAB_430C
	TST.W	$86(A5)
	BEQ.S	LAB_4232
	CLR.W	$86(A5)
	BRA.W	LAB_430C
LAB_4232:
	MOVEA.L	A5,A0
	MOVEQ	#7,D0
	BSR.W	SUB_43EC
	MOVE.W	D0,D7
	CMP.B	$84(A5),D7
	BEQ.S	LAB_4232
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_4266
	LEA	$4E(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_4266:
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_4288
	LEA	$54(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_4288:
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_42AA
	LEA	$5A(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_42AA:
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_42CA
	LEA	$60(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_42CA:
	MOVE.L	$AC(A5),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_42EA
	LEA	$66(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_42EA:
	MOVE.L	$AC(A5),D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_4308
	LEA	$72(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_4308:
	MOVE.B	D7,$84(A5)
LAB_430C:
	MOVEM.L	(A7)+,D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4312  -  referenced from 4 call site(s)
; ------------------------------------------------------------------
SUB_4312:
	MOVEM.L	D7/A5,-(A7)
	MOVEA.L	A0,A5
	MOVE.L	$AC(A5),D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_433E
	MOVE.L	$B0(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#1,D1
	CMP.L	D1,D0
	BGT.S	LAB_4354
LAB_433E:
	MOVE.L	$AC(A5),D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_43A2
	BTST	#7,$B1(A5)
	BEQ.S	LAB_43A2
LAB_4354:
	MOVEA.L	A5,A0
	MOVEQ	#7,D0
	BSR.W	SUB_43EC
	MOVE.W	D0,D7
	CMP.B	$84(A5),D7
	BEQ.S	LAB_4354
	MOVE.L	$AC(A5),D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_4382
	LEA	$6C(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_4382:
	MOVE.L	$AC(A5),D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_439E
	LEA	$78(A5),A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_439E:
	MOVE.B	D7,$84(A5)
LAB_43A2:
	MOVEM.L	(A7)+,D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_43A8  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_43A8:
	SUBA.W	#$000c,A7
	MOVEM.L	A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A5),A3
	LEA	$C(A7),A0
	MOVE.L	A0,D1
	MOVEA.L	A3,A6
	JSR	_LVODateStamp(A6)	; DateStamp(buf) - get the current date/time
	MOVE.L	$10(A7),D0
	MOVE.L	D0,D1
	ASL.L	#4,D1
	SUB.L	D0,D1
	ASL.L	#2,D1
	MOVE.L	D1,D0
	ASL.L	#2,D0
	SUB.L	D1,D0
	ASL.L	#3,D0
	ADD.L	D1,D0
	ADD.L	D0,D0
	ADD.L	$14(A7),D0
	MOVE.L	D0,$88(A5)
	MOVEM.L	(A7)+,A3/A5-A6
	ADDA.W	#$000c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_43EC  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
SUB_43EC:
	SUBQ.W	#4,A7
	MOVEM.L	D7/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	$88(A5),D0
	BSR.W	SUB_7E34
	MOVE.L	D0,$88(A5)
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,8(A7)
	MOVE.L	$88(A5),D0
	MOVE.L	8(A7),D1
	BSR.W	SUB_803E
	MOVE.W	D1,D0
	MOVEM.L	(A7)+,D7/A5
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4420  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_4420:
	SUBA.W	#$000c,A7
	MOVEM.L	A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A5),A3
	LEA	$C(A7),A0
	MOVE.L	A0,D1
	MOVEA.L	A3,A6
	JSR	_LVODateStamp(A6)	; DateStamp(buf) - get the current date/time
	MOVE.L	$C(A7),D0
	MOVEM.L	(A7)+,A3/A5-A6
	ADDA.W	#$000c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4448  -  referenced from 5 call site(s)
; ------------------------------------------------------------------
SUB_4448:
	SUBQ.W	#4,A7
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	MOVEQ	#$71,D0
	BSR.W	sendDoorGetValueMsg      ;       ;DT_TIMELASTON
	MOVEA.L	D0,A0
	LEA	4(A7),A1
	BSR.W	SUB_7F30
	MOVE.L	#$f0f36ca0,D0
	ADD.L	4(A7),D0
	MOVE.L	#$00015180,D1
	BSR.W	LAB_800C
	MOVEA.L	(A7)+,A5
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_447A  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_447A:
	SUBA.W	#$001c,A7
	MOVEM.L	D7/A3/A5-A6,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.B	#$02,$1E(A7)
	CLR.B	$1F(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$28(A7)
	MOVE.L	A0,$20(A7)
	MOVE.L	A5,$24(A7)
	MOVE.L	D7,$12(A7)
	MOVE.L	A0,$1A(A7)
	MOVE.L	A0,$16(A7)
	LEA	$12(A7),A0
	MOVE.L	A0,D1
	MOVEA.L	A3,A6
	JSR	_LVODateToStr(A6)	; DateToStr(dtbuf) - format a date into a string
	MOVE.L	A5,D0
	MOVEM.L	(A7)+,D7/A3/A5-A6
	ADDA.W	#$001c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_44C4  -  referenced from 15 call site(s)
; ------------------------------------------------------------------
SUB_44C4:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	BSR.W	SUB_22A0
	LEA	$34(A5),A0
	MOVE.L	A0,-(A7)
	PEA	STR_ARGUMENT_ERROR_TYPE_FOR_HELP(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	MOVEA.L	A5,A0
	BSR.W	SUB_1D74
	LEA	$C(A7),A7
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_44F8  -  referenced from 7 call site(s)
; ------------------------------------------------------------------
SUB_44F8:
	MOVEM.L	D5-D7/A5,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	D6,D5
	SUBQ.L	#1,D5
LAB_4506:
	TST.L	D5
	BMI.S	LAB_451E
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVE.L	0(A5,D0.L),D1
	CMP.L	D7,D1
	BNE.S	LAB_451A
	MOVEQ	#1,D0
	BRA.S	LAB_4520
LAB_451A:
	SUBQ.L	#1,D5
	BRA.S	LAB_4506
LAB_451E:
	MOVEQ	#0,D0
LAB_4520:
	MOVEM.L	(A7)+,D5-D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4526  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_4526:
	SUBA.W	#$01cc,A7
	MOVEM.L	D2/D6-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	dosbase(A3),$1E4(A7)
	MOVE.L	iconbase(A3),$1E0(A7)
	MOVE.B	#$02,$2A(A7)
	CLR.B	$2B(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$34(A7)
	MOVE.L	A0,$2C(A7)
	MOVEQ	#-3,D0
	MOVE.L	D0,4(A5)
	MOVEQ	#2,D0
	MOVE.L	D0,8(A5)
	CLR.W	$10(A5)
	CLR.W	$12(A5)
	MOVEA.L	A3,A0
	MOVEQ	#$7C,D0
	NOT.B	D0
	BSR.W	sendDoorGetValueMsg      ;BB_MAINLINE
	MOVEA.L	D0,A0
	LEA	$118(A7),A1
LAB_4576:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_4576
	LEA	$118(A7),A2
LAB_457E:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BEQ.S	LAB_4598
	TST.B	D0
	BEQ.S	LAB_4598
	EXT.W	D0
	EXT.L	D0
	BSR.W	SUB_5BFE
	MOVE.B	D0,(A2)
	ADDQ.L	#1,A2
	BRA.S	LAB_457E
LAB_4598:
	MOVE.B	(A2),D7
	CLR.B	(A2)
	PEA	$118(A7)
	PEA	STR_DOORUSE(PC)
	PEA	$58(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A3),D0
	BEQ.S	LAB_45BE
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_45C8
LAB_45BE:
	MOVEA.L	$94(A3),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_45C8:
	LEA	$50(A7),A1
	MOVEA.L	$1E0(A7),A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$4C(A7)
	BEQ.W	LAB_466C
	MOVEA.L	D0,A0
	LEA	STR_FILESCAN(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_45F6
	MOVEQ	#1,D0
	MOVE.L	D0,(A5)
	MOVE.L	D0,8(A5)
	BRA.W	LAB_4696
LAB_45F6:
	MOVEA.L	$4C(A7),A0
	LEA	STR_NEWSCAN(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_460E
	MOVEQ	#2,D0
	MOVE.L	D0,(A5)
	BRA.W	LAB_4696
LAB_460E:
	MOVEA.L	$4C(A7),A0
	LEA	STR_REVSCAN(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_462A
	MOVEQ	#3,D0
	MOVE.L	D0,(A5)
	MOVEQ	#4,D0
	MOVE.L	D0,8(A5)
	BRA.S	LAB_4696
LAB_462A:
	MOVEA.L	$4C(A7),A0
	LEA	STR_CONFSCAN(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4646
	MOVEQ	#4,D0
	MOVE.L	D0,(A5)
	MOVE.W	#$0001,$10A(A3)
	BRA.S	LAB_4696
LAB_4646:
	MOVEA.L	A3,A0
	MOVEQ	#1,D0
	BSR.W	SUB_22A0
	PEA	STR_CONFIG_ERROR_TOOLTYPE_INVALI(PC)
	MOVE.L	$2C(A3),-(A7)
	BSR.W	sprintf
	MOVEA.L	A3,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	MOVEA.L	A3,A0
	BSR.W	SUB_1D74
	ADDQ.W	#8,A7
	BRA.S	LAB_4696
LAB_466C:
	MOVEA.L	A3,A0
	MOVEQ	#1,D0
	BSR.W	SUB_22A0
	PEA	$50(A7)
	PEA	STR_CONFIG_ERROR_TOOLTYPE_MISSIN(PC)
	MOVE.L	$2C(A3),-(A7)
	BSR.W	sprintf
	MOVEA.L	A3,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	MOVEA.L	A3,A0
	BSR.W	SUB_1D74
	LEA	$C(A7),A7
LAB_4696:
	MOVE.B	D7,(A2)
LAB_4698:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BNE.S	LAB_46A8
	TST.B	D0
	BEQ.S	LAB_46A8
	ADDQ.L	#1,A2
	BRA.S	LAB_4698
LAB_46A8:
	MOVEQ	#-1,D6
LAB_46AA:
	TST.B	(A2)
	BEQ.W	LAB_4B44
	ADDQ.L	#1,D6
	MOVEQ	#4,D0
	CMP.L	D0,D6
	BGE.W	LAB_4B44
	MOVE.L	A2,$38(A7)
LAB_46BE:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BEQ.S	LAB_46CE
	TST.B	D0
	BEQ.S	LAB_46CE
	ADDQ.L	#1,A2
	BRA.S	LAB_46BE
LAB_46CE:
	MOVE.B	(A2),D7
	CLR.B	(A2)
	MOVEA.L	$38(A7),A0
	LEA	LAB_C98(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_46FA
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	MOVE.L	D0,(A0)
	MOVEQ	#4,D0
	MOVE.L	D0,8(A5)
	BRA.W	LAB_4A7A
LAB_46FA:
	MOVEA.L	$38(A7),A0
	LEA	LAB_C9A(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4732
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	MOVE.L	D0,(A0)
	MOVEQ	#1,D0
	CMP.L	(A5),D0
	BNE.S	LAB_4724
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4724:
	MOVEA.L	A3,A0
	BSR.W	SUB_4448
	MOVE.L	D0,DOOR_Msg(A5)
	BRA.W	LAB_4A7A
LAB_4732:
	MOVEA.L	$38(A7),A0
	LEA	LAB_C9C(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4766
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	MOVE.L	D0,(A0)
	MOVEQ	#1,D0
	CMP.L	(A5),D0
	BNE.S	LAB_475C
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_475C:
	MOVE.L	$A4(A3),DOOR_Msg(A5)
	BRA.W	LAB_4A7A
LAB_4766:
	MOVEA.L	$38(A7),A0
	LEA	LAB_C9E(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_479E
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	MOVE.L	D0,(A0)
	MOVEQ	#1,D0
	CMP.L	(A5),D0
	BNE.S	LAB_4790
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4790:
	MOVE.L	$A4(A3),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,DOOR_Msg(A5)
	BRA.W	LAB_4A7A
LAB_479E:
	MOVEA.L	$38(A7),A0
	LEA	LAB_CA0(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_47C0
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#4,D0
	MOVE.L	D0,(A0)
	BRA.W	LAB_4A7A
LAB_47C0:
	MOVEA.L	$38(A7),A0
	LEA	LAB_CA2(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_47E8
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#4,D0
	MOVE.L	D0,(A0)
	MOVEQ	#-1,D0
	MOVE.L	D0,4(A5)
	BRA.W	LAB_4A7A
LAB_47E8:
	MOVEA.L	$38(A7),A0
	LEA	LAB_CA4(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4810
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#4,D0
	MOVE.L	D0,(A0)
	MOVEQ	#-2,D0
	MOVE.L	D0,4(A5)
	BRA.W	LAB_4A7A
LAB_4810:
	MOVEA.L	$38(A7),A0
	LEA	LAB_CA6(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.S	LAB_4830
	MOVEA.L	$38(A7),A0
	LEA	LAB_CA8(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4848
LAB_4830:
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#2,D0
	MOVE.L	D0,(A0)
	MOVEQ	#6,D0
	MOVE.L	D0,8(A5)
	BRA.W	LAB_4A7A
LAB_4848:
	MOVEA.L	$38(A7),A0
	LEA	LAB_CAA(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4870
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#1,D0
	MOVE.L	D0,(A0)
	MOVEQ	#5,D0
	MOVE.L	D0,8(A5)
	BRA.W	LAB_4A7A
LAB_4870:
	MOVEA.L	$38(A7),A0
	LEA	LAB_CAC(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4898
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#6,D0
	MOVE.L	D0,(A0)
	MOVE.W	#$0001,$108(A3)
	BRA.W	LAB_4A7A
LAB_4898:
	MOVEA.L	$38(A7),A0
	LEA	LAB_CB0(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_48C0
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#5,D0
	MOVE.L	D0,(A0)
	MOVE.W	#$0001,$10(A5)
	BRA.W	LAB_4A7A
LAB_48C0:
	MOVEA.L	$38(A7),A0
	MOVE.B	(A0),D0
	MOVEQ	#$2D,D1
	CMP.B	D1,D0
	BEQ.S	LAB_48D4
	MOVEQ	#$21,D1
	CMP.B	D1,D0
	BNE.W	LAB_4954
LAB_48D4:
	TST.B	1(A0)
	BEQ.S	LAB_494A
	LEA	1(A0),A1
	LEA	DOOR_Msg(A5),A6
	MOVEA.L	A1,A0
	MOVEA.L	A6,A1
	BSR.W	SUB_7F30
	MOVE.L	A2,D1
	SUB.L	$38(A7),D1
	SUBQ.L	#1,D1
	CMP.L	D1,D0
	BNE.S	LAB_494A
	MOVE.L	DOOR_Msg(A5),D0
	TST.L	D0
	BGT.S	LAB_490C
	TST.L	D0
	BNE.S	LAB_494A
	MOVEQ	#$2D,D0
	MOVEA.L	$38(A7),A0
	CMP.B	(A0),D0
	BNE.S	LAB_494A
LAB_490C:
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	MOVE.L	D0,(A0)
	MOVEQ	#1,D0
	CMP.L	(A5),D0
	BNE.S	LAB_4926
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4926:
	MOVEQ	#$2D,D0
	MOVEA.L	$38(A7),A0
	CMP.B	(A0),D0
	BNE.S	LAB_4940
	MOVE.L	$A4(A3),D0
	SUB.L	DOOR_Msg(A5),D0
	MOVE.L	D0,DOOR_Msg(A5)
	BRA.W	LAB_4A7A
LAB_4940:
	MOVEQ	#3,D0
	MOVE.L	D0,8(A5)
	BRA.W	LAB_4A7A
LAB_494A:
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
	BRA.W	LAB_4A7A
LAB_4954:
	MOVE.L	A2,D0
	SUB.L	$38(A7),D0
	SUBQ.L	#8,D0
	BNE.S	LAB_49B0
	MOVEQ	#$2D,D0
	CMP.B	2(A0),D0
	BNE.S	LAB_49B0
	CMP.B	5(A0),D0
	BNE.S	LAB_49A6
	MOVE.L	A0,$30(A7)
	LEA	$1E(A7),A0
	MOVE.L	A0,D1
	MOVEA.L	$1E4(A7),A6
	JSR	_LVOStrToDate(A6)	; StrToDate(dtbuf) - parse a string into a date
	TST.L	D0
	BEQ.S	LAB_49A6
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	MOVE.L	D0,(A0)
	MOVEQ	#1,D0
	CMP.L	(A5),D0
	BNE.S	LAB_499C
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_499C:
	MOVE.L	$1E(A7),DOOR_Msg(A5)
	BRA.W	LAB_4A7A
LAB_49A6:
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
	BRA.W	LAB_4A7A
LAB_49B0:
	MOVE.L	A2,D0
	SUB.L	$38(A7),D0
	SUBQ.L	#5,D0
	BNE.W	LAB_4A44
	MOVEQ	#$2D,D0
	CMP.B	2(A0),D0
	BNE.W	LAB_4A44
	MOVE.L	$A4(A3),$1E(A7)
	MOVEQ	#0,D0
	MOVE.L	D0,$26(A7)
	MOVE.L	D0,$22(A7)
	LEA	$6E(A7),A0
	MOVE.L	A0,$30(A7)
	LEA	$1E(A7),A0
	MOVE.L	A0,D1
	MOVEA.L	$1E4(A7),A6
	JSR	_LVODateToStr(A6)	; DateToStr(dtbuf) - format a date into a string
	PEA	$74(A7)
	MOVE.L	$3C(A7),-(A7)
	PEA	LAB_CB2(PC)
	PEA	$5C(A7)
	BSR.W	sprintf
	LEA	$10(A7),A7
	LEA	$50(A7),A0
	MOVE.L	A0,$30(A7)
	LEA	$1E(A7),A0
	MOVE.L	A0,D1
	JSR	_LVOStrToDate(A6)	; StrToDate(dtbuf) - parse a string into a date
	TST.L	D0
	BEQ.S	LAB_4A3C
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	MOVE.L	D0,(A0)
	MOVEQ	#1,D0
	CMP.L	(A5),D0
	BNE.S	LAB_4A34
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4A34:
	MOVE.L	$1E(A7),DOOR_Msg(A5)
	BRA.S	LAB_4A7A
LAB_4A3C:
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
	BRA.S	LAB_4A7A
LAB_4A44:
	LEA	4(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	$38(A7),A0
	BSR.W	SUB_7F84
	MOVE.L	A2,D1
	SUB.L	$38(A7),D1
	CMP.L	D1,D0
	BNE.S	LAB_4A74
	MOVE.L	4(A5),D0
	TST.L	D0
	BLE.S	LAB_4A74
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#4,D0
	MOVE.L	D0,(A0)
	BRA.S	LAB_4A7A
LAB_4A74:
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4A7A:
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	MOVEA.L	A0,A1
	ADDA.L	D0,A1
	MOVE.L	(A1),D0
	MOVE.L	D6,D1
	BSR.W	SUB_44F8
	TST.W	D0
	BEQ.S	LAB_4A98
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4A98:
	TST.L	D6
	BLE.S	LAB_4ACC
	MOVE.L	$3C(A7),D0
	MOVEQ	#1,D1
	CMP.L	D1,D0
	BEQ.S	LAB_4AC6
	SUBQ.L	#2,D0
	BEQ.S	LAB_4AC6
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	MOVEA.L	A0,A1
	ADDA.L	D0,A1
	CMP.L	(A1),D1
	BEQ.S	LAB_4AC6
	MOVE.L	D6,D0
	ASL.L	#2,D0
	ADDA.L	D0,A0
	MOVEQ	#2,D0
	CMP.L	(A0),D0
	BNE.S	LAB_4ACC
LAB_4AC6:
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4ACC:
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	ADDA.L	D0,A0
	MOVEQ	#3,D0
	CMP.L	(A0),D0
	BNE.S	LAB_4AEA
	CMP.L	(A5),D0
	BEQ.S	LAB_4AE4
	TST.L	D6
	BLE.S	LAB_4AEA
LAB_4AE4:
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4AEA:
	MOVE.L	D6,D1
	LEA	$3C(A7),A0
	MOVEQ	#5,D0
	BSR.W	SUB_44F8
	TST.W	D0
	BEQ.S	LAB_4B2E
	MOVE.L	D6,D1
	LEA	$3C(A7),A0
	MOVEQ	#6,D0
	BSR.W	SUB_44F8
	TST.W	D0
	BEQ.S	LAB_4B2E
	MOVE.L	D6,D0
	ASL.L	#2,D0
	LEA	$3C(A7),A0
	MOVEA.L	A0,A1
	ADDA.L	D0,A1
	MOVEQ	#5,D0
	CMP.L	(A1),D0
	BEQ.S	LAB_4B2E
	MOVE.L	D6,D0
	ASL.L	#2,D0
	ADDA.L	D0,A0
	MOVEQ	#6,D0
	CMP.L	(A0),D0
	BEQ.S	LAB_4B2E
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4B2E:
	MOVE.B	D7,(A2)
LAB_4B30:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BNE.W	LAB_46AA
	TST.B	D0
	BEQ.W	LAB_46AA
	ADDQ.L	#1,A2
	BRA.S	LAB_4B30
LAB_4B44:
	TST.B	(A2)
	BEQ.S	LAB_4B4E
	MOVEA.L	A3,A0
	BSR.W	SUB_44C4
LAB_4B4E:
	MOVEQ	#1,D0
	CMP.L	(A5),D0
	BNE.S	LAB_4B88
	MOVE.L	D6,D0
	ADDQ.L	#1,D0
	LEA	$3C(A7),A0
	MOVEQ	#4,D1
	EXG	D0,D1
	BSR.W	SUB_44F8
	TST.W	D0
	BNE.S	LAB_4B88
	MOVE.L	8(A5),D0
	MOVEQ	#1,D1
	CMP.L	D1,D0
	BEQ.S	LAB_4B76
	SUBQ.L	#4,D0
	BNE.S	LAB_4B88
LAB_4B76:
	MOVEQ	#0,D0
	MOVE.W	D0,$108(A3)
	MOVE.W	D0,$10(A5)
	MOVE.W	#$0001,$12(A5)
	BRA.S	LAB_4BF8
LAB_4B88:
	MOVEQ	#2,D0
	CMP.L	(A5),D0
	BNE.S	LAB_4BD2
	MOVE.L	D6,D0
	ADDQ.L	#1,D0
	LEA	$3C(A7),A0
	MOVEQ	#3,D1
	EXG	D0,D1
	BSR.W	SUB_44F8
	TST.W	D0
	BNE.S	LAB_4BD2
	MOVE.L	D6,D0
	ADDQ.L	#1,D0
	LEA	$3C(A7),A0
	MOVEQ	#4,D1
	EXG	D0,D1
	BSR.W	SUB_44F8
	TST.W	D0
	BNE.S	LAB_4BD2
	MOVE.L	8(A5),D0
	MOVEQ	#2,D1
	CMP.L	D1,D0
	BNE.S	LAB_4BD2
	MOVEQ	#0,D2
	MOVE.W	D2,$108(A3)
	MOVE.W	D2,$10(A5)
	MOVE.W	#$0001,$12(A5)
	BRA.S	LAB_4BF8
LAB_4BD2:
	MOVEQ	#2,D0
	CMP.L	8(A5),D0
	BNE.S	LAB_4BF8
	MOVE.L	D6,D0
	ADDQ.L	#1,D0
	LEA	$3C(A7),A0
	MOVEQ	#3,D1
	EXG	D0,D1
	BSR.W	SUB_44F8
	TST.W	D0
	BNE.S	LAB_4BF8
	MOVEA.L	A3,A0
	BSR.W	SUB_4448
	MOVE.L	D0,DOOR_Msg(A5)
LAB_4BF8:
	MOVEM.L	(A7)+,D2/D6-D7/A2-A3/A5-A6
	ADDA.W	#$01cc,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4C02  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_4C02:
	SUBA.W	#$0054,A7
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVE.L	D0,4(A7)
	LEA	STR_CLS(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#0,D0
	BSR.W	lineOutput2
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	BSR.W	SUB_22A0
	LEA	$34(A5),A0
	MOVE.L	A0,-(A7)
	PEA	STR_DOORS_AQUASCAN_AQUASCAN_HELP(PC)
	PEA	$10(A7)
	BSR.W	sprintf
	LEA	$14(A7),A0
	MOVEA.L	A5,A1
	BSR.W	SUB_1E88
	LEA	STR_0M(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	LEA	$C(A7),A7
	MOVEA.L	(A7)+,A5
	ADDA.W	#$0054,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4C56  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_4C56:
	SUBA.W	#$0024,A7
	MOVEM.L	D2/D4-D7/A3/A5-A6,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A5),A3
	LEA	STR_DOORS_AQUASCAN(PC),A0
	MOVE.L	A0,D1
	MOVEQ	#-2,D2
	MOVEA.L	A3,A6
	JSR	_LVOLock(A6)	; Lock(name,mode) - lock a file or directory
	MOVE.L	D0,D5
	MOVE.L	D5,D0
	TST.L	D0
	BEQ.S	LAB_4CD4
	LEA	STR_DOORS_AQUASCAN_AQUASCANCONFI(PC),A0
	MOVE.L	A0,D1
	JSR	_LVOLock(A6)	; Lock(name,mode) - lock a file or directory
	MOVE.L	D0,$40(A7)
	TST.L	D0
	BEQ.S	LAB_4CD4
	MOVE.L	D0,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	MOVE.L	D5,D1
	JSR	_LVOCurrentDir(A6)	; CurrentDir(lock) - set the current directory lock
	MOVE.L	D0,D4
	MOVE.L	D6,-(A7)
	MOVE.L	D7,-(A7)
	PEA	STR_AQUASCANCONFIG(PC)
	PEA	$2E(A7)
	BSR.W	sprintf
	LEA	$10(A7),A7
	CLR.L	-(A7)
	CLR.L	-(A7)
	LEA	$2A(A7),A0
	MOVE.L	A0,D1
	MOVE.L	A7,D2
	JSR	_LVOSystemTagList(A6)	; SystemTagList(cmd,tags) - run a CLI command (Execute)
	LEA	8(A7),A7
	MOVE.L	D4,D1
	JSR	_LVOCurrentDir(A6)	; CurrentDir(lock) - set the current directory lock
	MOVE.L	D5,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	BRA.S	LAB_4CF2
LAB_4CD4:
	TST.L	D5
	BEQ.S	LAB_4CDE
	MOVE.L	D5,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
LAB_4CDE:
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	SUB_22A0
	LEA	STR_CONFIGURATION_PROGRAM_IS_UNA(PC),A0
	MOVEA.L	A5,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_4CF2:
	MOVEM.L	(A7)+,D2/D4-D7/A3/A5-A6
	ADDA.W	#$0024,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_4CFC  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_4CFC:
	SUBA.W	#$0144,A7
	MOVEM.L	D5-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	$164(A7),A2
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	iconbase(A2),$15C(A7)
	MOVEQ	#0,D5
	CLR.W	$84(A7)
	MOVEA.L	A5,A0
	LEA	$94(A7),A1
LAB_4D1E:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_4D1E
	LEA	$94(A7),A0
	MOVEA.L	A0,A1
LAB_4D28:
	TST.B	(A1)+
	BNE.S	LAB_4D28
	SUBQ.L	#1,A1
	SUBA.L	A0,A1
	MOVE.L	A1,D0
	MOVE.L	D0,D7
	SUBQ.L	#1,D7
	MOVEA.L	A0,A1
	ADDA.L	D7,A1
	CLR.B	(A1)
	MOVEA.L	$15C(A7),A6
	JSR	_LVOGetDiskObject(A6)	; GetDiskObject(name) - load a .info icon (and its tooltypes)
	MOVE.L	D0,$88(A7)
	TST.L	D0
	BEQ.W	LAB_50DC
	MOVEA.L	D0,A0
	MOVEA.L	$36(A0),A0
	LEA	STR_NDIRS(PC),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$90(A7)
	TST.L	D0
	BEQ.W	LAB_50DC
	MOVEA.L	D0,A0
	LEA	$8C(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.W	LAB_50DC
	MOVE.L	$8C(A7),D0
	TST.L	D0
	BLE.W	LAB_50DC
	MOVEA.L	$88(A7),A0
	JSR	_LVOFreeDiskObject(A6)	; FreeDiskObject(diskobj) - free an icon loaded by GetDiskObject
	TST.W	$12(A3)
	BEQ.W	LAB_4ED0
	MOVEQ	#2,D0
	CMP.L	(A3),D0
	BNE.S	LAB_4E04
LAB_4D96:
	MOVEA.L	$2C(A2),A0
	ADDA.W	#$00b4,A0
	MOVE.L	A0,$1C(A7)
	MOVEA.L	A2,A0
	BSR.W	SUB_4448
	MOVEA.L	$1C(A7),A0
	MOVEA.L	dosbase(A2),A1
	BSR.W	SUB_447A
	MOVE.L	D0,-(A7)
	PEA	STR_36MDATE_32M_33MMM_DD_YY_32M(PC)
	MOVE.L	$2C(A2),-(A7)
	BSR.W	sprintf
	MOVEA.L	A2,A0
	MOVEQ	#0,D0
	BSR.W	lineOutput
	LEA	LAB_334(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#$C,D0
	BSR.W	lineInput
	MOVE.L	A2,(A7)
	MOVEA.L	$2C(A2),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_5432
	LEA	$C(A7),A7
	TST.W	D0
	BNE.S	LAB_4DFC
	LEA	STR_ERROR_IN_DATE(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	A2,A0
	BSR.W	SUB_1D74
LAB_4DFC:
	MOVEQ	#5,D0
	CMP.L	8(A3),D0
	BEQ.S	LAB_4D96
LAB_4E04:
	MOVEQ	#1,D0
	CMP.L	(A3),D0
	BNE.S	LAB_4E3A
	MOVEA.L	A2,A0
	MOVEQ	#$7F,D0
	BSR.W	sendDoorGetValueMsg      ;BB_CONFLOCAL
	MOVEA.L	D0,A0
	LEA	$20(A7),A1
LAB_4E18:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_4E18
	LEA	$20(A7),A0
	LEA	STR_FILEHELP(PC),A1
	BSR.W	LAB_812C
	LEA	$20(A7),A0
	MOVEA.L	A2,A1
	BSR.W	SUB_1E88
	MOVEA.L	A2,A0
	MOVEQ	#1,D0
	BSR.W	setNonStop
LAB_4E3A:
	LEA	LAB_334(PC),A0
	TST.W	$112(A2)
	BEQ.S	LAB_4E48
	LEA	STR_32M_33MH_32M_36MOLD(PC),A0
LAB_4E48:
	MOVE.L	A0,-(A7)
	MOVE.L	$90(A7),-(A7)
	PEA	STR_36MDIRECTORIES_32M_33M1_32M(PC)
	MOVE.L	$2C(A2),-(A7)
	BSR.W	sprintf
	MOVEA.L	A2,A0
	MOVEQ	#0,D0
	BSR.W	lineOutput
	LEA	LAB_334(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#8,D0
	BSR.W	lineInput
	MOVEA.L	$2C(A2),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_563A
	LEA	$10(A7),A7
	TST.W	D0
	BNE.S	LAB_4E92
	LEA	STR_ERROR_IN_INPUT(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	A2,A0
	BSR.W	SUB_1D74
LAB_4E92:
	LEA	LAB_334(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	TST.L	8(A3)
	BNE.S	LAB_4EAA
	MOVEA.L	A2,A0
	BSR.W	SUB_1D74
LAB_4EAA:
	MOVEQ	#-1,D0
	CMP.L	4(A3),D0
	BNE.S	LAB_4ECA
	TST.W	$112(A2)
	BNE.S	LAB_4ECA
	LEA	STR_SCANNING_THE_HOLD_DIR_REQUIR(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	A2,A0
	BSR.W	SUB_1D74
LAB_4ECA:
	MOVEQ	#1,D0
	MOVE.L	D0,$104(A2)
LAB_4ED0:
	TST.W	$10A(A2)
	BNE.S	LAB_4F24
	MOVE.L	$98(A2),D0
	BEQ.S	LAB_4EE4
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_4EEE
LAB_4EE4:
	MOVEA.L	$94(A2),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_4EEE:
	LEA	STR_CALLERSLOG(PC),A1
	MOVEA.L	$15C(A7),A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$90(A7)
	TST.L	D0
	BEQ.S	LAB_4F24
	MOVEA.L	D0,A0
	LEA	LAB_126(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_4F24
	PEA	STR_DIRECTORY_SCAN_WITH_AQUASCAN(PC)
	MOVE.L	$2C(A2),-(A7)
	BSR.W	sprintf
	MOVEA.L	A2,A0
	BSR.W	writeToCallersLog
	ADDQ.W	#8,A7
LAB_4F24:
	CLR.W	$114(A2)
	MOVE.L	4(A3),D0
	ADDQ.L	#3,D0
	BEQ.W	LAB_501C
	SUBQ.L	#1,D0
	BEQ.S	LAB_4F8C
	SUBQ.L	#1,D0
	BNE.W	LAB_5068
	MOVE.W	#$0001,$114(A2)
	BCLR	#7,$B1(A2)
	LEA	$94(A7),A0
	ADDA.L	D7,A0
	PEA	STR_HOLD_HELD(PC)
	MOVE.L	A0,-(A7)
	BSR.W	sprintf
	ADDQ.W	#8,A7
LAB_4F5A:
	MOVE.L	$C(A3),-(A7)
	MOVE.L	8(A3),D1
	MOVEA.L	A2,A0
	MOVEQ	#-1,D0
	BSR.W	SUB_56EC
	ADDQ.L	#1,$104(A2)
	MOVE.L	A2,(A7)
	PEA	$88(A7)
	LEA	$9C(A7),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_511E
	MOVE.L	D0,D5
	ADDQ.W	#8,A7
	MOVE.L	D5,D0
	SUBQ.L	#5,D0
	BEQ.S	LAB_4F5A
	BRA.W	LAB_5106
LAB_4F8C:
	MOVEQ	#1,D6
LAB_4F8E:
	MOVE.L	$8C(A7),D0
	CMP.L	D0,D6
	BGT.W	LAB_5106
	CMP.L	D6,D0
	SEQ	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVE.W	D0,$110(A2)
	LEA	$94(A7),A0
	ADDA.L	D7,A0
	MOVE.L	D6,-(A7)
	PEA	STR_DIR(PC)
	MOVE.L	A0,-(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	TST.W	$84(A7)
	BEQ.S	LAB_4FD8
	LEA	LAB_334(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	CLR.W	$84(A7)
	MOVEQ	#1,D0
	MOVE.L	D0,$104(A2)
LAB_4FD8:
	MOVE.L	$C(A3),-(A7)
	MOVE.L	D6,D0
	MOVE.L	8(A3),D1
	MOVEA.L	A2,A0
	BSR.W	SUB_56EC
	ADDQ.L	#1,$104(A2)
	MOVE.L	A2,(A7)
	PEA	$88(A7)
	LEA	$9C(A7),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_511E
	MOVE.L	D0,D5
	ADDQ.W	#8,A7
	MOVE.L	D5,D0
	SUBQ.L	#5,D0
	BEQ.S	LAB_4FD8
	MOVEQ	#1,D0
	CMP.L	D0,D5
	BEQ.W	LAB_5106
	MOVE.L	D5,D0
	SUBQ.L	#3,D0
	BEQ.W	LAB_5106
	ADDQ.L	#1,D6
	BRA.W	LAB_4F8E
LAB_501C:
	LEA	$94(A7),A0
	ADDA.L	D7,A0
	MOVE.L	$8C(A7),-(A7)
	PEA	STR_DIR(PC)
	MOVE.L	A0,-(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
LAB_5034:
	MOVE.L	$C(A3),-(A7)
	MOVE.L	$90(A7),D0
	MOVE.L	8(A3),D1
	MOVEA.L	A2,A0
	BSR.W	SUB_56EC
	ADDQ.L	#1,$104(A2)
	MOVE.L	A2,(A7)
	PEA	$88(A7)
	LEA	$9C(A7),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_511E
	MOVE.L	D0,D5
	ADDQ.W	#8,A7
	MOVE.L	D5,D0
	SUBQ.L	#5,D0
	BEQ.S	LAB_5034
	BRA.W	LAB_5106
LAB_5068:
	MOVE.L	$8C(A7),D0
	MOVE.L	4(A3),D1
	CMP.L	D0,D1
	BLE.S	LAB_5094
	MOVE.L	D0,-(A7)
	PEA	STR_THE_HIGHEST_DIRECTORY_NUMBER(PC)
	MOVE.L	$2C(A2),-(A7)
	BSR.W	sprintf
	MOVEA.L	A2,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	ADDQ.L	#1,$104(A2)
	BRA.S	LAB_5106
LAB_5094:
	LEA	$94(A7),A0
	ADDA.L	D7,A0
	MOVE.L	D1,-(A7)
	PEA	STR_DIR(PC)
	MOVE.L	A0,-(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
LAB_50AA:
	MOVE.L	$C(A3),-(A7)
	MOVE.L	4(A3),D0
	MOVE.L	8(A3),D1
	MOVEA.L	A2,A0
	BSR.W	SUB_56EC
	ADDQ.L	#1,$104(A2)
	MOVE.L	A2,(A7)
	PEA	$88(A7)
	LEA	$9C(A7),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_511E
	MOVE.L	D0,D5
	ADDQ.W	#8,A7
	MOVE.L	D5,D0
	SUBQ.L	#5,D0
	BEQ.S	LAB_50AA
	BRA.S	LAB_5106
LAB_50DC:
	MOVE.L	$88(A7),D0
	BEQ.S	LAB_50FA
	MOVEA.L	D0,A0
	MOVEA.L	$15C(A7),A6
	JSR	_LVOFreeDiskObject(A6)	; FreeDiskObject(diskobj) - free an icon loaded by GetDiskObject
	LEA	STR_NO_FILES_AVAILABLE_IN_THIS_C(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.S	LAB_5106
LAB_50FA:
	LEA	STR_COULDN_T_LOAD_CONFERENCE_ICO(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_5106:
	LEA	STR_0M(PC),A0
	MOVEA.L	A2,A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVE.L	D5,D0
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5-A6
	ADDA.W	#$0144,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_511E  -  referenced from 4 call site(s)
; ------------------------------------------------------------------
SUB_511E:
	SUBA.W	#$000c,A7
	MOVEM.L	D2-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	$38(A7),A2
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	$3C(A7),A1
	MOVEA.L	dosbase(A1),A0
	MOVEQ	#0,D4
	MOVE.L	A0,$30(A7)
	MOVE.L	A5,D1
	MOVEQ	#-2,D2
	MOVEA.L	A0,A6
	JSR	_LVOLock(A6)	; Lock(name,mode) - lock a file or directory
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.W	LAB_53FC
	MOVE.L	D7,D1
	MOVEA.L	$3C(A7),A0
	MOVE.L	$15A(A0),D2
	JSR	_LVOExamine(A6)	; Examine(lock,fib) - get file/dir info into a FileInfoBlock
	TST.L	D0
	BEQ.W	LAB_53E6
	MOVEA.L	$3C(A7),A1
	MOVEA.L	$15A(A1),A0
	MOVE.L	$7C(A0),D0
	MOVE.L	D0,$90(A1)
	BLE.W	LAB_53D0
	MOVE.L	D7,D1
	JSR	_LVOOpenFromLock(A6)	; OpenFromLock(lock) - open a file using an existing lock
	MOVE.L	D0,D6
	TST.L	D6
	BEQ.W	LAB_53BA
	MOVEA.L	$3C(A7),A0
	MOVE.L	$90(A0),D0
	ADDQ.L	#1,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVEA.L	$3C(A7),A0
	MOVE.L	D0,$8C(A0)
	BNE.S	LAB_51BE
	MOVE.L	D6,D1
	MOVEA.L	$30(A7),A6
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
	LEA	STR_OUT_OF_MEMORY(PC),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.W	LAB_5426
LAB_51BE:
	MOVE.L	D0,D2
	MOVE.L	D6,D1
	MOVE.L	$90(A0),D3
	MOVEA.L	$30(A7),A6
	JSR	_LVORead(A6)	; Read(file,buf,len) - read from a file
	MOVE.L	D0,D5
	MOVE.L	D6,D1
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
	MOVEA.L	$3C(A7),A0
	MOVE.L	$90(A0),D0
	CMP.L	D0,D5
	BNE.W	LAB_538E
	MOVEA.L	$8C(A0),A1
	MOVEA.L	A1,A6
	ADDA.L	D0,A6
	CLR.B	(A6)
	CLR.L	$128(A0)
	MOVEQ	#1,D0
	CMP.L	8(A3),D0
	BNE.S	LAB_5214
	MOVEA.L	$8C(A0),A0
	MOVEQ	#$A,D0
	BSR.W	LAB_8114
	TST.L	D0
	BEQ.S	LAB_5214
	MOVEA.L	$3C(A7),A1
	MOVEA.L	$8C(A1),A0
	MOVE.L	A0,$128(A1)
LAB_5214:
	MOVEQ	#2,D0
	CMP.L	8(A3),D0
	BNE.S	LAB_523C
	MOVE.L	$C(A3),D0
	MOVEA.L	$3C(A7),A0
	MOVE.L	$90(A0),D1
	MOVEA.L	$8C(A0),A0
	MOVEA.L	$3C(A7),A1
	BSR.W	SUB_408E
	MOVEA.L	$3C(A7),A0
	MOVE.L	D0,$128(A0)
LAB_523C:
	MOVEQ	#3,D0
	CMP.L	8(A3),D0
	BNE.S	LAB_5264
	MOVE.L	$C(A3),D0
	MOVEA.L	$3C(A7),A0
	MOVE.L	$90(A0),D1
	MOVEA.L	$8C(A0),A0
	MOVEA.L	$3C(A7),A1
	BSR.W	SUB_40C2
	MOVEA.L	$3C(A7),A0
	MOVE.L	D0,$128(A0)
LAB_5264:
	MOVEQ	#4,D0
	CMP.L	8(A3),D0
	BNE.S	LAB_528A
	MOVEA.L	$3C(A7),A0
	MOVE.L	$90(A0),D1
	MOVEA.L	$8C(A0),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	SUB_40C2
	MOVEA.L	$3C(A7),A0
	MOVE.L	D0,$128(A0)
LAB_528A:
	MOVEA.L	$3C(A7),A0
	TST.L	$128(A0)
	BEQ.W	LAB_5380
	MOVE.L	$AC(A0),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_52CE
	LEA	$66(A0),A1
	MOVE.L	A1,$28(A7)
	MOVEQ	#7,D0
	BSR.W	SUB_43EC
	MOVEA.L	$3C(A7),A0
	MOVE.B	D0,$84(A0)
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A0,A1
	MOVEA.L	$28(A7),A0
	BSR.W	SUB_59C8
LAB_52CE:
	LEA	STR_OK(PC),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	MOVEA.L	$3C(A7),A0
	ADDQ.L	#1,$104(A0)
	CLR.L	$130(A0)
	CLR.L	$138(A0)
	CLR.L	$140(A0)
	CLR.L	$144(A0)
	MOVEQ	#-1,D0
	MOVE.L	D0,$13C(A0)
	MOVE.L	D0,$2C(A7)
	CLR.W	$148(A0)
	CLR.W	$14A(A0)
	CLR.W	$14C(A0)
	CLR.W	$14E(A0)
	MOVE.L	$128(A0),$134(A0)
	TST.W	$10(A3)
	BNE.S	LAB_5326
	BTST	#5,$B2(A0)
	BNE.S	LAB_5326
	MOVEQ	#0,D0
	BRA.S	LAB_5328
LAB_5326:
	MOVEQ	#1,D0
LAB_5328:
	MOVE.W	D0,$10C(A0)
	MOVEQ	#4,D0
	CMP.L	8(A3),D0
	BNE.S	LAB_5352
	MOVE.W	#$0001,$118(A0)
	MOVE.L	A0,-(A7)
	MOVE.L	$90(A0),D0
	MOVEA.L	$8C(A0),A0
	LEA	$30(A7),A1
	BSR.W	SUB_2330
	MOVE.L	D0,D4
	ADDQ.W	#4,A7
	BRA.S	LAB_537A
LAB_5352:
	CLR.W	$118(A0)
	MOVE.L	$128(A0),D0
	MOVE.L	D0,D1
	SUB.L	$8C(A0),D1
	MOVE.L	$90(A0),D2
	SUB.L	D1,D2
	MOVE.L	A0,-(A7)
	MOVE.L	D2,D0
	MOVEA.L	$128(A0),A0
	LEA	$30(A7),A1
	BSR.W	SUB_2592
	MOVE.L	D0,D4
	ADDQ.W	#4,A7
LAB_537A:
	MOVE.W	#$0001,(A2)
	BRA.S	LAB_539A
LAB_5380:
	MOVEA.L	A0,A1
	LEA	STR_NOTHING_FOUND(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.S	LAB_539A
LAB_538E:
	MOVEA.L	A0,A1
	LEA	STR_ERROR_READING_DIR_FILE(PC),A0
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_539A:
	MOVEA.L	$3C(A7),A0
	MOVE.L	$90(A0),D0
	ADDQ.L	#1,D0
	MOVEA.L	$8C(A0),A1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
	MOVEA.L	$3C(A7),A0
	CLR.L	$8C(A0)
	BRA.S	LAB_5426
LAB_53BA:
	MOVE.L	D7,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	LEA	STR_ERROR_OPENING_DIR_FILE(PC),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.S	LAB_5426
LAB_53D0:
	MOVE.L	D7,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	LEA	STR_NOTHING_FOUND(PC),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.S	LAB_5426
LAB_53E6:
	MOVE.L	D7,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	LEA	STR_ERROR_READING_DIR_FILE(PC),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.S	LAB_5426
LAB_53FC:
	JSR	_LVOIoErr(A6)	; IoErr() - return the DOS error code of the last failed call
	MOVEQ	#$32,D1
	NOT.B	D1
	CMP.L	D1,D0
	BNE.S	LAB_5418
	LEA	STR_NOTHING_FOUND(PC),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
	BRA.S	LAB_5426
LAB_5418:
	LEA	STR_ERROR_OPENING_DIR_FILE(PC),A0
	MOVEA.L	$3C(A7),A1
	MOVEQ	#1,D0
	BSR.W	lineOutput2
LAB_5426:
	MOVE.L	D4,D0
	MOVEM.L	(A7)+,D2-D7/A2-A3/A5-A6
	ADDA.W	#$000c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5432  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_5432:
	SUBA.W	#$002c,A7
	MOVEM.L	D2-D3/A2-A3/A5-A6,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	$48(A7),A0
	MOVE.L	dosbase(A0),$40(A7)
	MOVE.B	#$02,$2E(A7)
	CLR.B	$2F(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$38(A7)
	MOVE.L	A0,$30(A7)
	MOVEQ	#2,D0
	MOVE.L	D0,8(A3)
	MOVEA.L	A5,A2
LAB_5464:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BNE.S	LAB_5474
	TST.B	D0
	BEQ.S	LAB_5474
	ADDQ.L	#1,A2
	BRA.S	LAB_5464
LAB_5474:
	TST.B	(A2)
	BEQ.W	LAB_5622
	MOVE.L	A2,$3C(A7)
LAB_547E:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BEQ.S	LAB_548E
	TST.B	D0
	BEQ.S	LAB_548E
	ADDQ.L	#1,A2
	BRA.S	LAB_547E
LAB_548E:
	CLR.B	(A2)
	MOVEA.L	$3C(A7),A0
	LEA	LAB_C98(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_54AA
	MOVEQ	#4,D0
	MOVE.L	D0,8(A3)
	BRA.W	LAB_562E
LAB_54AA:
	MOVEA.L	$3C(A7),A0
	LEA	LAB_C9A(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_54CA
	MOVEA.L	$48(A7),A0
	BSR.W	SUB_4448
	MOVE.L	D0,$C(A3)
	BRA.W	LAB_562E
LAB_54CA:
	MOVEA.L	$3C(A7),A0
	LEA	LAB_C9C(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_54E8
	MOVEA.L	$48(A7),A0
	MOVE.L	$A4(A0),$C(A3)
	BRA.W	LAB_562E
LAB_54E8:
	MOVEA.L	$3C(A7),A0
	LEA	LAB_CAA(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_5502
	MOVEQ	#5,D0
	MOVE.L	D0,8(A3)
	BRA.W	LAB_562E
LAB_5502:
	MOVEA.L	$3C(A7),A0
	MOVE.B	(A0),D0
	MOVEQ	#$2D,D1
	CMP.B	D1,D0
	BEQ.S	LAB_5514
	MOVEQ	#$21,D1
	CMP.B	D1,D0
	BNE.S	LAB_557C
LAB_5514:
	TST.B	1(A0)
	BEQ.S	LAB_5576
	LEA	1(A0),A1
	LEA	$C(A3),A6
	MOVEA.L	A1,A0
	MOVEA.L	A6,A1
	BSR.W	SUB_7F30
	MOVE.L	A2,D1
	MOVE.L	D1,D2
	SUB.L	$3C(A7),D2
	SUBQ.L	#1,D2
	CMP.L	D2,D0
	BNE.S	LAB_5576
	MOVE.L	$C(A3),D0
	TST.L	D0
	BGT.S	LAB_5550
	TST.L	D0
	BNE.S	LAB_5576
	MOVEA.L	$3C(A7),A0
	MOVE.B	(A0),D2
	MOVEQ	#$2D,D3
	CMP.B	D3,D2
	BNE.S	LAB_5576
LAB_5550:
	MOVEQ	#$2D,D2
	MOVEA.L	$3C(A7),A0
	CMP.B	(A0),D2
	BNE.S	LAB_556C
	MOVEA.L	$48(A7),A1
	MOVE.L	$A4(A1),D3
	SUB.L	D0,D3
	MOVE.L	D3,$C(A3)
	BRA.W	LAB_562E
LAB_556C:
	MOVEQ	#3,D0
	MOVE.L	D0,8(A3)
	BRA.W	LAB_562E
LAB_5576:
	MOVEQ	#0,D0
	BRA.W	LAB_5630
LAB_557C:
	MOVE.L	A2,D0
	SUB.L	$3C(A7),D0
	SUBQ.L	#8,D0
	BNE.S	LAB_55B6
	MOVEQ	#$2D,D0
	CMP.B	2(A0),D0
	BNE.S	LAB_55B6
	CMP.B	5(A0),D0
	BNE.S	LAB_55B2
	MOVE.L	A0,$34(A7)
	LEA	$22(A7),A0
	MOVE.L	A0,D1
	MOVEA.L	$40(A7),A6
	JSR	_LVOStrToDate(A6)	; StrToDate(dtbuf) - parse a string into a date
	TST.L	D0
	BEQ.S	LAB_55B2
	MOVE.L	$22(A7),$C(A3)
	BRA.S	LAB_562E
LAB_55B2:
	MOVEQ	#0,D0
	BRA.S	LAB_5630
LAB_55B6:
	MOVE.L	A2,D0
	SUB.L	$3C(A7),D0
	SUBQ.L	#5,D0
	BNE.S	LAB_561E
	MOVEQ	#$2D,D0
	CMP.B	2(A0),D0
	BNE.S	LAB_561E
	MOVEA.L	$48(A7),A0
	MOVE.L	$A4(A0),$22(A7)
	MOVEQ	#0,D0
	MOVE.L	D0,$2A(A7)
	MOVE.L	D0,$26(A7)
	LEA	$19(A7),A0
	MOVE.L	A0,$34(A7)
	LEA	$22(A7),A0
	MOVE.L	A0,D1
	MOVEA.L	$40(A7),A6
	JSR	_LVODateToStr(A6)	; DateToStr(dtbuf) - format a date into a string
	MOVEA.L	$3C(A7),A0
	LEA	$19(A7),A1
LAB_55FA:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_55FA
	MOVE.B	#$2d,$1E(A7)
	LEA	$22(A7),A0
	MOVE.L	A0,D1
	JSR	_LVOStrToDate(A6)	; StrToDate(dtbuf) - parse a string into a date
	TST.L	D0
	BEQ.S	LAB_561A
	MOVE.L	$22(A7),$C(A3)
	BRA.S	LAB_562E
LAB_561A:
	MOVEQ	#0,D0
	BRA.S	LAB_5630
LAB_561E:
	MOVEQ	#0,D0
	BRA.S	LAB_5630
LAB_5622:
	MOVEA.L	$48(A7),A0
	BSR.W	SUB_4448
	MOVE.L	D0,$C(A3)
LAB_562E:
	MOVEQ	#1,D0
LAB_5630:
	MOVEM.L	(A7)+,D2-D3/A2-A3/A5-A6
	ADDA.W	#$002c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_563A  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_563A:
	SUBQ.W	#4,A7
	MOVEM.L	A2-A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A5,A2
LAB_5646:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BNE.S	LAB_5656
	TST.B	D0
	BEQ.S	LAB_5656
	ADDQ.L	#1,A2
	BRA.S	LAB_5646
LAB_5656:
	TST.B	(A2)
	BEQ.W	LAB_56DE
	MOVE.L	A2,$C(A7)
LAB_5660:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BEQ.S	LAB_5670
	TST.B	D0
	BEQ.S	LAB_5670
	ADDQ.L	#1,A2
	BRA.S	LAB_5660
LAB_5670:
	CLR.B	(A2)
	MOVEA.L	$C(A7),A0
	LEA	LAB_CA0(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_568A
	MOVEQ	#-3,D0
	MOVE.L	D0,4(A3)
	BRA.S	LAB_56E2
LAB_568A:
	MOVEA.L	$C(A7),A0
	LEA	LAB_CA2(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_56A2
	MOVEQ	#-1,D0
	MOVE.L	D0,4(A3)
	BRA.S	LAB_56E2
LAB_56A2:
	MOVEA.L	$C(A7),A0
	LEA	LAB_CA4(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_56BA
	MOVEQ	#-2,D0
	MOVE.L	D0,4(A3)
	BRA.S	LAB_56E2
LAB_56BA:
	LEA	4(A3),A0
	MOVEA.L	A0,A1
	MOVEA.L	$C(A7),A0
	BSR.W	SUB_7F84
	MOVE.L	A2,D1
	SUB.L	$C(A7),D1
	CMP.L	D1,D0
	BNE.S	LAB_56DA
	MOVE.L	4(A3),D0
	TST.L	D0
	BGT.S	LAB_56E2
LAB_56DA:
	MOVEQ	#0,D0
	BRA.S	LAB_56E4
LAB_56DE:
	CLR.L	8(A3)
LAB_56E2:
	MOVEQ	#1,D0
LAB_56E4:
	MOVEM.L	(A7)+,A2-A3/A5
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_56EC  -  referenced from 4 call site(s)
; ------------------------------------------------------------------
SUB_56EC:
	MOVEM.L	D5-D7/A5,-(A7)
	MOVE.L	$14(A7),D5
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	D6,D0
	SUBQ.L	#4,D0
	BNE.S	LAB_5706
	LEA	STR_REVERSE_SCANNING(PC),A0
	BRA.S	LAB_570A
LAB_5706:
	LEA	STR_SCANNING(PC),A0
LAB_570A:
	MOVEA.L	$2C(A5),A1
LAB_570E:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_570E
	MOVEA.L	$2C(A5),A0
	MOVE.L	A0,D0
LAB_5718:
	TST.B	(A0)+
	BNE.S	LAB_5718
	SUBQ.L	#1,A0
	SUBA.L	D0,A0
	MOVE.L	A0,D0
	MOVEA.L	$2C(A5),A1
	ADDA.L	D0,A1
	MOVEQ	#-1,D0
	CMP.L	D0,D7
	BNE.S	LAB_5734
	LEA	STR_HOLD_DIR(PC),A0
	BRA.S	LAB_5738
LAB_5734:
	LEA	STR_DIR_2(PC),A0
LAB_5738:
	MOVE.L	D7,-(A7)
	MOVE.L	A0,-(A7)
	MOVE.L	A1,-(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	D6,D0
	SUBQ.L	#1,D0
	BEQ.S	LAB_5756
	SUBQ.L	#1,D0
	BEQ.S	LAB_5764
	SUBQ.L	#1,D0
	BEQ.S	LAB_5794
	BRA.S	LAB_57CE
LAB_5756:
	MOVEA.L	$2C(A5),A0
	LEA	STR_FROM_TOP(PC),A1
	BSR.W	LAB_812C
	BRA.S	LAB_57CE
LAB_5764:
	MOVEA.L	$2C(A5),A0
	LEA	STR_FOR(PC),A1
	BSR.W	LAB_812C
	MOVEA.L	$2C(A5),A0
	MOVE.L	A0,D0
LAB_5776:
	TST.B	(A0)+
	BNE.S	LAB_5776
	SUBQ.L	#1,A0
	SUBA.L	D0,A0
	MOVE.L	A0,D0
	MOVEA.L	$2C(A5),A1
	ADDA.L	D0,A1
	MOVEA.L	A1,A0
	MOVE.L	D5,D0
	MOVEA.L	dosbase(A5),A1
	BSR.W	SUB_447A
	BRA.S	LAB_57CE
LAB_5794:
	MOVE.L	D5,D0
	SUBQ.L	#1,D0
	BNE.S	LAB_57A8
	MOVEA.L	$2C(A5),A0
	LEA	STR_FOR_THE_LAST_FILE(PC),A1
	BSR.W	LAB_812C
	BRA.S	LAB_57CE
LAB_57A8:
	MOVEA.L	$2C(A5),A0
	MOVE.L	A0,D0
LAB_57AE:
	TST.B	(A0)+
	BNE.S	LAB_57AE
	SUBQ.L	#1,A0
	SUBA.L	D0,A0
	MOVE.L	A0,D0
	MOVEA.L	$2C(A5),A1
	ADDA.L	D0,A1
	MOVE.L	D5,-(A7)
	PEA	STR_FOR_THE_LAST_FILES(PC)
	MOVE.L	A1,-(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
LAB_57CE:
	MOVEA.L	$2C(A5),A0
	LEA	LAB_102E(PC),A1
	BSR.W	LAB_812C
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	BSR.W	lineOutput
	MOVEM.L	(A7)+,D5-D7/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_57E8  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_57E8:
	SUBQ.W	#4,A7
	MOVEM.L	D2-D3/D6-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A3),A0
	MOVE.L	A0,$20(A7)
	MOVE.L	A5,D1
	MOVE.L	#$000003ed,D2
	MOVEA.L	A0,A6
	JSR	_LVOOpen(A6)	; Open(name,mode) - open a file
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.W	LAB_58C8
	MOVE.L	D7,D1
	MOVEQ	#0,D2
	MOVEQ	#1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVE.L	D7,D1
	MOVEQ	#-1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	ADDQ.L	#1,D0
	MOVE.L	D0,$F2(A3)
	MOVE.L	D2,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVE.L	D0,$CE(A3)
	BEQ.W	LAB_58BE
	MOVE.L	$F2(A3),D1
	SUBQ.L	#1,D1
	MOVE.L	D0,D2
	MOVE.L	D1,D3
	MOVE.L	D7,D1
	MOVEA.L	$20(A7),A6
	JSR	_LVORead(A6)	; Read(file,buf,len) - read from a file
	MOVE.L	$F2(A3),D1
	SUBQ.L	#1,D1
	CMP.L	D1,D0
	BNE.S	LAB_58AA
	MOVEQ	#0,D6
	MOVEA.L	$CE(A3),A0
	MOVEA.L	A0,A1
	ADDA.L	D1,A1
	CLR.B	(A1)
	CLR.L	$CA(A3)
	MOVEA.L	$CE(A3),A2
LAB_586C:
	TST.W	D6
	BNE.S	LAB_58BE
	MOVE.L	$CA(A3),D0
	MOVEQ	#8,D1
	CMP.L	D1,D0
	BGE.S	LAB_58BE
	ADDQ.L	#1,$CA(A3)
	MOVE.L	D0,D1
	ASL.L	#2,D1
	MOVE.L	D1,D0
	ADDI.L	#$000000d2,D0
	MOVE.L	A2,0(A3,D0.L)
LAB_588E:
	MOVE.B	(A2),D0
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BEQ.S	LAB_589E
	TST.B	D0
	BEQ.S	LAB_589E
	ADDQ.L	#1,A2
	BRA.S	LAB_588E
LAB_589E:
	TST.B	(A2)
	BEQ.S	LAB_58A6
	CLR.B	(A2)+
	BRA.S	LAB_586C
LAB_58A6:
	MOVEQ	#1,D6
	BRA.S	LAB_586C
LAB_58AA:
	MOVEA.L	$CE(A3),A1
	MOVE.L	$F2(A3),D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
	CLR.L	$CE(A3)
LAB_58BE:
	MOVE.L	D7,D1
	MOVEA.L	$20(A7),A6
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
LAB_58C8:
	MOVE.L	$CE(A3),D0
	MOVEM.L	(A7)+,D2-D3/D6-D7/A2-A3/A5-A6
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_58D4  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_58D4:
	SUBQ.W	#4,A7
	MOVEM.L	D7/A2-A3/A5,-(A7)
	MOVEA.L	$18(A7),A2
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	MOVEA.L	A3,A1
LAB_58E6:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_58E6
LAB_58EA:
	MOVEA.L	A3,A0
	LEA	LAB_1032(PC),A1
	BSR.W	LAB_80D8
	MOVE.L	D0,$10(A7)
	BEQ.S	LAB_5910
	MOVEQ	#0,D7
LAB_58FC:
	MOVEQ	#8,D0
	CMP.L	D0,D7
	BGE.S	LAB_58EA
	MOVEA.L	$10(A7),A0
	MOVE.B	0(A2,D7.L),0(A0,D7.L)
	ADDQ.L	#1,D7
	BRA.S	LAB_58FC
LAB_5910:
	MOVEM.L	(A7)+,D7/A2-A3/A5
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5918  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_5918:
	SUBQ.W	#4,A7
	MOVEM.L	D2-D3/D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A3),A2
	MOVE.L	A5,D1
	MOVE.L	#$000003ed,D2
	MOVEA.L	A2,A6
	JSR	_LVOOpen(A6)	; Open(name,mode) - open a file
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.W	LAB_59BC
	MOVE.L	D7,D1
	MOVEQ	#0,D2
	MOVEQ	#1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVE.L	D7,D1
	MOVEQ	#-1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	ADDQ.L	#1,D0
	MOVE.L	D0,$FC(A3)
	MOVE.L	D2,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVE.L	D0,$F8(A3)
	BEQ.S	LAB_59B4
	MOVE.L	$FC(A3),D1
	SUBQ.L	#1,D1
	MOVE.L	D0,D2
	MOVE.L	D1,D3
	MOVE.L	D7,D1
	MOVEA.L	A2,A6
	JSR	_LVORead(A6)	; Read(file,buf,len) - read from a file
	MOVE.L	$FC(A3),D1
	SUBQ.L	#1,D1
	CMP.L	D1,D0
	BNE.S	LAB_59A0
	MOVEA.L	$F8(A3),A0
	MOVEA.L	A0,A1
	ADDA.L	D1,A1
	CLR.B	(A1)
	MOVEA.L	$F8(A3),A0
	MOVEQ	#$A,D0
	BSR.W	LAB_8114
	MOVE.L	D0,$1C(A7)
	BEQ.S	LAB_59B4
	MOVEA.L	D0,A0
	CLR.B	(A0)
	BRA.S	LAB_59B4
LAB_59A0:
	MOVEA.L	$F8(A3),A1
	MOVE.L	$FC(A3),D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOFreeMem(A6)	; FreeMem(ptr,size) - free allocated memory
	CLR.L	$F8(A3)
LAB_59B4:
	MOVE.L	D7,D1
	MOVEA.L	A2,A6
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
LAB_59BC:
	MOVE.L	$F8(A3),D0
	MOVEM.L	(A7)+,D2-D3/D7/A2-A3/A5-A6
	ADDQ.W	#4,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_59C8  -  referenced from 17 call site(s)
; ------------------------------------------------------------------
SUB_59C8:
	MOVEM.L	D7/A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	CMPI.L	#$00000007,D0
	BCC.S	LAB_5A52
	ADD.W	D0,D0
	MOVE.W	LAB_59E8(PC,D0.W),D0
	JMP	LAB_59E8+2(PC,D0.W)
LAB_59E8:
	DC.W	(LAB_59F6)-(LAB_59E8+2)	;59e8: 000c
	DC.W	(LAB_5A0C)-(LAB_59E8+2)	;59ea: 0022
	DC.W	(LAB_5A18)-(LAB_59E8+2)	;59ec: 002e
	DC.W	(LAB_5A24)-(LAB_59E8+2)	;59ee: 003a
	DC.W	(LAB_5A30)-(LAB_59E8+2)	;59f0: 0046
	DC.W	(LAB_5A3C)-(LAB_59E8+2)	;59f2: 0052
	DC.W	(LAB_5A48)-(LAB_59E8+2)	;59f4: 005e
LAB_59F6:
	LEA	STR_37M(PC),A0
	TST.W	$7E(A3)
	BEQ.S	LAB_5A04
	LEA	STR_0M(PC),A0
LAB_5A04:
	MOVEA.L	A5,A1
LAB_5A06:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5A06
	BRA.S	LAB_5A52
LAB_5A0C:
	LEA	STR_31M(PC),A0
	MOVEA.L	A5,A1
LAB_5A12:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5A12
	BRA.S	LAB_5A52
LAB_5A18:
	LEA	ansiGreen(PC),A0
	MOVEA.L	A5,A1
LAB_5A1E:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5A1E
	BRA.S	LAB_5A52
LAB_5A24:
	LEA	STR_33M(PC),A0
	MOVEA.L	A5,A1
LAB_5A2A:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5A2A
	BRA.S	LAB_5A52
LAB_5A30:
	LEA	STR_34M(PC),A0
	MOVEA.L	A5,A1
LAB_5A36:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5A36
	BRA.S	LAB_5A52
LAB_5A3C:
	LEA	STR_35M(PC),A0
	MOVEA.L	A5,A1
LAB_5A42:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5A42
	BRA.S	LAB_5A52
LAB_5A48:
	LEA	ansiCyan(PC),A0
	MOVEA.L	A5,A1
LAB_5A4E:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5A4E
LAB_5A52:
	MOVEM.L	(A7)+,D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5A58  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_5A58:
	MOVE.L	A5,-(A7)
	MOVEA.L	A0,A5
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_5A7A
	MOVE.W	#$0001,$80(A5)
	BRA.S	LAB_5A9C
LAB_5A7A:
	LEA	$4E(A5),A0
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5A9C:
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_5AB8
	MOVE.W	#$0001,$80(A5)
	BRA.S	LAB_5AD8
LAB_5AB8:
	LEA	$54(A5),A0
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5AD8:
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_5AF4
	MOVE.W	#$0001,$80(A5)
	BRA.S	LAB_5B14
LAB_5AF4:
	LEA	$5A(A5),A0
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5B14:
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_5B2E
	MOVE.W	#$0001,$80(A5)
	BRA.S	LAB_5B4C
LAB_5B2E:
	LEA	$60(A5),A0
	MOVE.L	$AC(A5),D0
	CLR.W	D0
	SWAP	D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5B4C:
	MOVE.L	$AC(A5),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_5B66
	MOVE.W	#$0001,$80(A5)
	BRA.S	LAB_5B84
LAB_5B66:
	LEA	$66(A5),A0
	MOVE.L	$AC(A5),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5B84:
	MOVE.L	$AC(A5),D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SUBQ.L	#7,D0
	BNE.S	LAB_5B9C
	MOVE.W	#$0001,$80(A5)
	BRA.S	LAB_5BB8
LAB_5B9C:
	LEA	$72(A5),A0
	MOVE.L	$AC(A5),D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5BB8:
	MOVE.L	$AC(A5),D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#7,D1
	CMP.L	D1,D0
	BEQ.S	LAB_5BDA
	LEA	$6C(A5),A0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5BDA:
	MOVE.L	$AC(A5),D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#7,D1
	CMP.L	D1,D0
	BEQ.S	LAB_5BFA
	LEA	$78(A5),A0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.L	D1,D0
	MOVEA.L	A5,A1
	BSR.W	SUB_59C8
LAB_5BFA:
	MOVEA.L	(A7)+,A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5BFE  -  referenced from 7 call site(s)
; ------------------------------------------------------------------
SUB_5BFE:
	MOVE.L	D7,-(A7)
	MOVE.L	D0,D7
	MOVEQ	#$61,D0
	CMP.B	D0,D7
	BLT.S	LAB_5C12
	MOVEQ	#$7A,D0
	CMP.B	D0,D7
	BGT.S	LAB_5C12
	SUBI.B	#$20,D7
LAB_5C12:
	MOVE.B	D7,D0
	MOVE.L	(A7)+,D7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5C18  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_5C18:
	SUBA.W	#$00cc,A7
	MOVEM.L	D5-D7/A2-A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVE.L	A1,$18(A7)
	MOVEQ	#0,D5
	TST.L	$E8(A7)
	BEQ.S	LAB_5C36
	MOVEA.L	$E8(A7),A0
	CLR.B	(A0)
LAB_5C36:
	MOVEA.L	$EC(A7),A0
	TST.W	$F6(A0)
	SNE	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVE.L	$130(A0),D1
	SUB.L	D0,D1
	BEQ.W	LAB_5CD6
	MOVEA.L	A5,A0
	LEA	$1C(A7),A1
LAB_5C56:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5C56
	MOVEA.L	$EC(A7),A0
	TST.W	$118(A0)
	BEQ.S	LAB_5C74
	MOVEA.L	A0,A1
	MOVEA.L	$11A(A1),A0
	TST.B	(A0)
	BNE.S	LAB_5C74
	MOVE.B	$11E(A1),(A0)
	MOVEQ	#1,D5
LAB_5C74:
	LEA	$1C(A7),A3
LAB_5C78:
	TST.B	(A3)
	BEQ.S	LAB_5CC8
	MOVEA.L	A3,A2
LAB_5C7E:
	MOVE.B	(A2),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BNE.S	LAB_5C8E
	TST.B	D0
	BEQ.S	LAB_5C8E
	ADDQ.L	#1,A2
	BRA.S	LAB_5C7E
LAB_5C8E:
	TST.B	(A2)
	BEQ.S	LAB_5CC4
	LEA	1(A2),A3
LAB_5C96:
	MOVE.B	(A3),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BEQ.S	LAB_5CA6
	TST.B	D0
	BEQ.S	LAB_5CA6
	ADDQ.L	#1,A3
	BRA.S	LAB_5C96
LAB_5CA6:
	MOVE.B	(A3),D6
	CLR.B	(A3)
	MOVE.L	$EC(A7),-(A7)
	MOVE.L	$EC(A7),-(A7)
	MOVE.L	D7,D0
	MOVEA.L	A2,A0
	MOVEA.L	$20(A7),A1
	BSR.W	SUB_5CE0
	ADDQ.W	#8,A7
	MOVE.B	D6,(A3)
	BRA.S	LAB_5C78
LAB_5CC4:
	MOVEA.L	A2,A3
	BRA.S	LAB_5C78
LAB_5CC8:
	TST.W	D5
	BEQ.S	LAB_5CD6
	MOVEA.L	$EC(A7),A1
	MOVEA.L	$11A(A1),A0
	CLR.B	(A0)
LAB_5CD6:
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5
	ADDA.W	#$00cc,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5CE0  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_5CE0:
	SUBA.W	#$0010,A7
	MOVEM.L	D5-D7/A2-A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.W	#$0001,$24(A7)
	MOVEA.L	$30(A7),A0
	TST.W	$F6(A0)
	SNE	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVE.L	$130(A0),D1
	SUB.L	D0,D1
	MOVEM.L	D1,$20(A7)
	MOVEQ	#$2D,D0
	CMP.B	(A5),D0
	BNE.S	LAB_5D4A
	MOVEQ	#1,D6
	TST.B	1(A5)
	BEQ.S	LAB_5D44
	LEA	1(A5),A0
	LEA	$18(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_5D3C
	MOVE.L	$18(A7),D0
	TST.L	D0
	BLE.S	LAB_5D3C
	MOVE.L	D0,D5
	BRA.W	LAB_5DE0
LAB_5D3C:
	CLR.W	$24(A7)
	BRA.W	LAB_5DE0
LAB_5D44:
	MOVE.L	D1,D5
	BRA.W	LAB_5DE0
LAB_5D4A:
	MOVEA.L	A5,A2
LAB_5D4C:
	MOVE.B	(A2),D0
	MOVEQ	#$2D,D1
	CMP.B	D1,D0
	BEQ.S	LAB_5D5C
	TST.B	D0
	BEQ.S	LAB_5D5C
	ADDQ.L	#1,A2
	BRA.S	LAB_5D4C
LAB_5D5C:
	TST.B	(A2)
	BEQ.S	LAB_5DBE
	CLR.B	(A2)
	MOVEA.L	A5,A0
	LEA	$18(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_5DB4
	MOVE.L	$18(A7),D0
	TST.L	D0
	BLE.S	LAB_5DB4
	MOVE.L	D0,D6
	TST.B	1(A2)
	BEQ.S	LAB_5DA2
	LEA	1(A2),A0
	LEA	$18(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_5D9C
	MOVE.L	$18(A7),D0
	TST.L	D0
	BLE.S	LAB_5D9C
	MOVE.L	D0,D5
	BRA.S	LAB_5DB8
LAB_5D9C:
	CLR.W	$24(A7)
	BRA.S	LAB_5DB8
LAB_5DA2:
	MOVE.L	$20(A7),D0
	CMP.L	D0,D6
	BHI.S	LAB_5DAE
	MOVE.L	D0,D5
	BRA.S	LAB_5DB8
LAB_5DAE:
	CLR.W	$24(A7)
	BRA.S	LAB_5DB8
LAB_5DB4:
	CLR.W	$24(A7)
LAB_5DB8:
	MOVE.B	#$2d,(A2)
	BRA.S	LAB_5DE0
LAB_5DBE:
	MOVEA.L	A5,A0
	LEA	$18(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_5DDA
	MOVE.L	$18(A7),D0
	TST.L	D0
	BLE.S	LAB_5DDA
	MOVE.L	D0,D5
	MOVE.L	D5,D6
	BRA.S	LAB_5DE0
LAB_5DDA:
	MOVEQ	#0,D0
	MOVE.W	D0,$24(A7)
LAB_5DE0:
	TST.W	$24(A7)
	BEQ.S	LAB_5E2E
	MOVE.L	$20(A7),D0
	CMP.L	D0,D6
	BLS.S	LAB_5DFE
	CMP.L	D0,D5
	BLS.S	LAB_5DFA
	MOVEQ	#0,D1
	MOVE.W	D1,$24(A7)
	BRA.S	LAB_5E04
LAB_5DFA:
	MOVE.L	D0,D6
	BRA.S	LAB_5E04
LAB_5DFE:
	CMP.L	D0,D5
	BLS.S	LAB_5E04
	MOVE.L	D0,D5
LAB_5E04:
	TST.W	$24(A7)
	BEQ.S	LAB_5E2E
	CMP.L	D5,D6
	BLS.S	LAB_5E18
	MOVE.L	D6,D0
	MOVE.L	D5,D6
	MOVE.L	D0,D5
	MOVE.L	D0,$1C(A7)
LAB_5E18:
	MOVE.L	$30(A7),-(A7)
	MOVE.L	D7,-(A7)
	MOVE.L	D6,D0
	MOVE.L	D5,D1
	MOVEA.L	A3,A0
	MOVEA.L	$34(A7),A1
	BSR.W	SUB_5E38
	ADDQ.W	#8,A7
LAB_5E2E:
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5
	ADDA.W	#$0010,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5E38  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_5E38:
	SUBA.W	#$000c,A7
	MOVEM.L	D2/D4-D7/A2-A3/A5,-(A7)
	MOVE.L	$30(A7),D5
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	$34(A7),A2
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	$130(A2),$28(A7)
	MOVEA.L	A3,A0
LAB_5E58:
	TST.B	(A0)+
	BNE.S	LAB_5E58
	SUBQ.L	#1,A0
	SUBA.L	A3,A0
	MOVE.L	D7,D4
	MOVE.L	A0,$20(A7)
LAB_5E66:
	CMP.L	D6,D4
	BHI.W	LAB_5F38
	MOVE.W	$118(A2),D0
	BEQ.S	LAB_5E7E
	MOVE.L	$130(A2),D1
	MOVE.L	D1,D2
	ADD.L	D2,D2
	SUB.L	D4,D2
	BRA.S	LAB_5E80
LAB_5E7E:
	MOVE.L	D4,D2
LAB_5E80:
	TST.W	D0
	BEQ.S	LAB_5E94
	MOVE.L	$130(A2),D0
	MOVE.L	D0,D1
	ADD.L	D1,D1
	MOVE.L	$28(A7),D0
	SUB.L	D0,D1
	BRA.S	LAB_5E98
LAB_5E94:
	MOVE.L	$28(A7),D1
LAB_5E98:
	MOVE.L	D2,D0
	MOVEA.L	A5,A0
	MOVEA.L	A2,A1
	BSR.W	SUB_5F42
	MOVEA.L	D0,A5
	MOVE.L	A5,$24(A7)
LAB_5EA8:
	MOVEQ	#$20,D0
	MOVEA.L	$24(A7),A0
	CMP.B	(A0),D0
	BEQ.S	LAB_5EB8
	ADDQ.L	#1,$24(A7)
	BRA.S	LAB_5EA8
LAB_5EB8:
	MOVEA.L	$24(A7),A0
	CLR.B	(A0)
	MOVE.L	A3,D0
	BEQ.S	LAB_5F0C
	MOVEA.L	A5,A0
LAB_5EC4:
	TST.B	(A0)+
	BNE.S	LAB_5EC4
	SUBQ.L	#1,A0
	SUBA.L	A5,A0
	MOVE.L	A0,D0
	MOVE.L	$20(A7),D1
	ADD.L	D1,D0
	CMP.L	D5,D0
	BHI.S	LAB_5F26
	MOVEA.L	A3,A0
	ADDA.L	D1,A0
	MOVEA.L	A5,A1
LAB_5EDE:
	MOVE.B	(A1)+,(A0)+
	BNE.S	LAB_5EDE
	MOVEA.L	A5,A0
LAB_5EE4:
	TST.B	(A0)+
	BNE.S	LAB_5EE4
	SUBQ.L	#1,A0
	SUBA.L	A5,A0
	MOVE.L	A0,D0
	ADD.L	D0,$20(A7)
	MOVE.L	$20(A7),D0
	CMP.L	D5,D0
	BGE.S	LAB_5F26
	MOVEA.L	A3,A0
	ADDA.L	D0,A0
	ADDQ.L	#1,$20(A7)
	LEA	LAB_AE2(PC),A1
LAB_5F06:
	MOVE.B	(A1)+,(A0)+
	BNE.S	LAB_5F06
	BRA.S	LAB_5F26
LAB_5F0C:
	MOVEA.L	A5,A0
	MOVEA.L	$2C(A2),A1
LAB_5F12:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_5F12
	MOVEA.L	$C(A2),A0
	MOVEQ	#$D,D0
	MOVE.L	D0,$E0(A0)
	MOVEA.L	A2,A0
	BSR.W	sendXimMsg        ;JH_FLAGFILE
LAB_5F26:
	MOVEA.L	$24(A7),A0
	MOVE.B	#$20,(A0)
	MOVE.L	D4,$28(A7)
	ADDQ.L	#1,D4
	BRA.W	LAB_5E66
LAB_5F38:
	MOVEM.L	(A7)+,D2/D4-D7/A2-A3/A5
	ADDA.W	#$000c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_5F42  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_5F42:
	SUBA.W	#$002c,A7
	MOVEM.L	D5-D7/A2-A3/A5,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVE.L	A1,$1C(A7)
	MOVE.L	D6,D5
	MOVE.B	#$02,$36(A7)
	CLR.B	$37(A7)
	SUBA.L	A1,A1
	MOVE.L	A1,$40(A7)
	MOVE.L	A1,$38(A7)
	LEA	$21(A7),A1
	MOVE.L	A1,$3C(A7)
	MOVE.L	A0,$18(A7)
	CMP.L	D7,D6
	BLS.S	LAB_5FC4
	MOVEA.L	A0,A5
	SUBQ.L	#1,A5
	MOVEA.L	A5,A3
	SUBQ.L	#1,A5
LAB_5F80:
	LEA	1(A5),A0
	MOVEA.L	$1C(A7),A1
	CMPA.L	$8C(A1),A0
	BEQ.S	LAB_5F94
	MOVEQ	#$A,D0
	CMP.B	(A5),D0
	BNE.S	LAB_5FC0
LAB_5F94:
	LEA	1(A5),A0
	MOVE.L	A3,D0
	MOVE.L	A5,D1
	SUB.L	D1,D0
	SUBQ.L	#1,D0
	MOVE.L	A1,-(A7)
	LEA	$2E(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_5FBE
	SUBQ.L	#1,D5
	CMP.L	D7,D5
	BNE.S	LAB_5FBE
	LEA	1(A5),A0
	MOVE.L	A0,D0
	BRA.S	LAB_6010
LAB_5FBE:
	MOVEA.L	A5,A3
LAB_5FC0:
	SUBQ.L	#1,A5
	BRA.S	LAB_5F80
LAB_5FC4:
	CMP.L	D7,D6
	BCC.S	LAB_600C
	MOVEA.L	$18(A7),A5
LAB_5FCC:
	MOVEQ	#$A,D0
	CMP.B	(A5),D0
	BEQ.S	LAB_5FD6
	ADDQ.L	#1,A5
	BRA.S	LAB_5FCC
LAB_5FD6:
	ADDQ.L	#1,A5
	MOVEA.L	A5,A2
LAB_5FDA:
	MOVEQ	#$A,D0
	CMP.B	(A5),D0
	BNE.S	LAB_6008
	MOVE.L	A5,D0
	MOVE.L	A2,D1
	SUB.L	D1,D0
	MOVE.L	$1C(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$2E(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_6004
	ADDQ.L	#1,D5
	CMP.L	D7,D5
	BNE.S	LAB_6004
	MOVE.L	A2,D0
	BRA.S	LAB_6010
LAB_6004:
	LEA	1(A5),A2
LAB_6008:
	ADDQ.L	#1,A5
	BRA.S	LAB_5FDA
LAB_600C:
	MOVE.L	$18(A7),D0
LAB_6010:
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5
	ADDA.W	#$002c,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_601A  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_601A:
	SUBA.W	#$0018,A7
	MOVEM.L	D6-D7/A3/A5-A6,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	MOVEA.L	iconbase(A5),A3
	LEA	STR_PPC(PC),A0
	LEA	$14(A7),A1
	MOVEQ	#4,D0
LAB_6036:
	MOVE.B	(A0)+,(A1)+
	DBF	D0,LAB_6036
	MOVEQ	#$12,D0
	MOVEQ	#0,D1
	LEA	$19(A7),A0
LAB_6044:
	MOVE.B	D1,(A0)+
	DBF	D0,LAB_6044
	MOVE.B	D7,D0
	EXT.W	D0
	EXT.L	D0
	SUBQ.L	#3,D0
	BLT.W	LAB_611C
	CMPI.L	#$00000057,D0
	BGE.W	LAB_611C
	ADD.W	D0,D0
	MOVE.W	LAB_606A(PC,D0.W),D0
	JMP	LAB_606A+2(PC,D0.W)
LAB_606A:
	DC.W	(LAB_6118)-(LAB_606A+2)	;606a: 00ac
	DC.W	(LAB_6118)-(LAB_606A+2)	;606c: 00ac
	DC.W	(LAB_6118)-(LAB_606A+2)	;606e: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;6070: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6072: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;6074: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;6076: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6078: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;607a: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;607c: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;607e: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;6080: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6082: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6084: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6086: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6088: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;608a: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;608c: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;608e: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6090: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6092: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6094: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6096: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6098: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;609a: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;609c: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;609e: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60a0: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60a2: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60a4: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60a6: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60a8: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60aa: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60ac: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60ae: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60b0: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60b2: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60b4: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60b6: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60b8: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60ba: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60bc: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60be: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60c0: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60c2: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60c4: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60c6: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60c8: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60ca: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60cc: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60ce: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60d0: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60d2: 00ac
	DC.W	(LAB_6118)-(LAB_606A+2)	;60d4: 00ac
	DC.W	(LAB_6118)-(LAB_606A+2)	;60d6: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60d8: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60da: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60dc: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60de: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60e0: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60e2: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60e4: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60e6: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60e8: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60ea: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60ec: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60ee: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60f0: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60f2: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60f4: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60f6: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;60f8: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;60fa: 00ac
	DC.W	(LAB_6118)-(LAB_606A+2)	;60fc: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;60fe: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;6100: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;6102: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6104: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;6106: 00ac
	DC.W	(LAB_6118)-(LAB_606A+2)	;6108: 00ac
	DC.W	(LAB_6118)-(LAB_606A+2)	;610a: 00ac
	DC.W	(LAB_611C)-(LAB_606A+2)	;610c: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;610e: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6110: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6112: 00b0
	DC.W	(LAB_611C)-(LAB_606A+2)	;6114: 00b0
	DC.W	(LAB_6118)-(LAB_606A+2)	;6116: 00ac
LAB_6118:
	MOVEQ	#1,D0
	BRA.S	LAB_6190
LAB_611C:
	MOVEQ	#$44,D0
	CMP.B	D0,D7
	BNE.S	LAB_613C
	MOVE.W	$30(A5),D0
	MOVEQ	#3,D1
	CMP.W	D1,D0
	BHI.S	LAB_6138
	SUBQ.W	#3,D0
	BNE.S	LAB_613C
	CMPI.W	#$0026,$32(A5)
	BCS.S	LAB_613C
LAB_6138:
	MOVEQ	#1,D0
	BRA.S	LAB_6190
LAB_613C:
	SUBQ.W	#1,D6
	BEQ.S	LAB_618E
	MOVEQ	#0,D0
	MOVE.W	D6,D0
	MOVE.L	D0,-(A7)
	PEA	STR_KEY_HU(PC)
	PEA	$20(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_6164
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_616E
LAB_6164:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_616E:
	LEA	$14(A7),A1
	MOVEA.L	A3,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A0
	MOVE.B	(A0),D1
	EXT.W	D1
	EXT.L	D1
	MOVE.L	D1,D0
	BSR.W	SUB_5BFE
	CMP.B	D0,D7
	BNE.S	LAB_613C
	MOVEQ	#1,D0
	BRA.S	LAB_6190
LAB_618E:
	MOVEQ	#0,D0
LAB_6190:
	MOVEM.L	(A7)+,D6-D7/A3/A5-A6
	ADDA.W	#$0018,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_619A  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_619A:
	SUBA.W	#$0024,A7
	MOVEM.L	D5-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	iconbase(A5),A3
	LEA	STR_PPC_2(PC),A0
	LEA	$20(A7),A1
	MOVEQ	#4,D0
LAB_61B2:
	MOVE.B	(A0)+,(A1)+
	DBF	D0,LAB_61B2
	MOVEQ	#$12,D0
	MOVEQ	#0,D1
	LEA	$25(A7),A0
LAB_61C0:
	MOVE.B	D1,(A0)+
	DBF	D0,LAB_61C0
	MOVEQ	#1,D7
	CLR.W	$154(A5)
	MOVEA.L	A5,A0
	MOVEQ	#$69,D0
	BSR.W	sendDoorGetValueMsg      ;DT_SECSTATUS
	MOVEA.L	D0,A0
	LEA	$3C(A7),A1
	BSR.W	SUB_7F84
LAB_61DE:
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_CMD_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_6202
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_620C
LAB_6202:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_620C:
	LEA	$20(A7),A1
	MOVEA.L	A3,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A2
	MOVE.L	A2,D0
	BEQ.W	LAB_64CA
	MOVE.B	(A2),D0
	BEQ.S	LAB_6228
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BNE.S	LAB_624A
LAB_6228:
	PEA	$20(A7)
	PEA	STR_ERROR_IN_TOOLTYPE(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	MOVEQ	#0,D0
	BRA.W	LAB_6638
LAB_624A:
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_KEY_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_626E
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_6278
LAB_626E:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_6278:
	LEA	$20(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A2
	MOVE.L	A2,D0
	BEQ.W	LAB_64A2
	TST.B	(A2)
	BEQ.S	LAB_6292
	TST.B	1(A2)
	BEQ.S	LAB_62B4
LAB_6292:
	PEA	$20(A7)
	PEA	STR_ERROR_IN_TOOLTYPE(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	MOVEQ	#0,D0
	BRA.W	LAB_6638
LAB_62B4:
	MOVE.B	(A2),D0
	EXT.W	D0
	EXT.L	D0
	BSR.W	SUB_5BFE
	EXT.W	D0
	EXT.L	D0
	MOVEQ	#0,D1
	MOVE.W	D7,D1
	MOVEA.L	A5,A0
	BSR.W	SUB_601A
	TST.W	D0
	BEQ.S	LAB_62F2
	PEA	$20(A7)
	PEA	STR_ERROR_IN_TOOLTYPE_KEY_IS_ALR(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	MOVEQ	#0,D0
	BRA.W	LAB_6638
LAB_62F2:
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_ACS_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_6316
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_6320
LAB_6316:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_6320:
	LEA	$20(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A2
	MOVE.L	A2,D0
	BEQ.W	LAB_64A2
	MOVEA.L	A2,A0
	LEA	$38(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BNE.S	LAB_6360
	PEA	$20(A7)
	PEA	STR_ERROR_IN_TOOLTYPE(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	MOVEQ	#0,D0
	BRA.W	LAB_6638
LAB_6360:
	MOVE.L	$3C(A7),D0
	CMP.L	$38(A7),D0
	BLT.S	LAB_636E
	ADDQ.W	#1,$154(A5)
LAB_636E:
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_DSC_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_6392
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_639C
LAB_6392:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_639C:
	LEA	$20(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A2
	MOVE.L	A2,D0
	BEQ.W	LAB_64A2
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_CNF_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_63D0
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_63DA
LAB_63D0:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_63DA:
	LEA	$20(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A2
	MOVE.L	A2,D0
	BEQ.W	LAB_64A2
	MOVEA.L	A2,A0
	LEA	LAB_118(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.S	LAB_6428
	MOVEA.L	A2,A0
	LEA	LAB_126(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.S	LAB_6428
	PEA	$20(A7)
	PEA	STR_ERROR_IN_TOOLTYPE(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	MOVEQ	#0,D0
	BRA.W	LAB_6638
LAB_6428:
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_NUM_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_644C
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_6456
LAB_644C:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_6456:
	LEA	$20(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A2
	MOVE.L	A2,D0
	BEQ.S	LAB_64A2
	MOVEA.L	A2,A0
	LEA	LAB_118(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.S	LAB_64A2
	MOVEA.L	A2,A0
	LEA	LAB_126(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BEQ.S	LAB_64A2
	PEA	$20(A7)
	PEA	STR_ERROR_IN_TOOLTYPE(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	MOVEQ	#0,D0
	BRA.W	LAB_6638
LAB_64A2:
	MOVE.L	A2,D0
	BNE.S	LAB_64C8
	PEA	$20(A7)
	PEA	STR_MISSING_TOOLTYPE_IN_CONFIG(PC)
	MOVE.L	$2C(A5),-(A7)
	BSR.W	sprintf
	MOVEA.L	A5,A0
	MOVEQ	#1,D0
	BSR.W	lineOutput
	LEA	$C(A7),A7
	MOVEQ	#0,D0
	BRA.W	LAB_6638
LAB_64C8:
	ADDQ.W	#1,D7
LAB_64CA:
	MOVE.L	A2,D0
	BNE.W	LAB_61DE
	SUBQ.W	#1,D7
	MOVE.W	D7,D6
	MOVE.W	$154(A5),D0
	BEQ.W	LAB_6636
	SWAP	D0
	CLR.W	D0
	SWAP	D0
	MOVE.L	D0,D1
	ASL.L	#2,D1
	MOVE.L	D1,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVE.L	D0,$156(A5)
	BEQ.W	LAB_6632
	MOVEQ	#0,D5
	MOVEQ	#1,D7
LAB_64FE:
	CMP.W	D6,D7
	BHI.W	LAB_6636
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_ACS_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_6528
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_6532
LAB_6528:
	MOVEA.L	$94(A5),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_6532:
	LEA	$20(A7),A1
	MOVEA.L	A3,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A0
	LEA	$38(A7),A1
	BSR.W	SUB_7F84
	MOVE.L	$3C(A7),D0
	CMP.L	$38(A7),D0
	BLT.W	LAB_662C
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_KEY_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	ADDA.L	D0,A0
	MOVE.L	A0,$1C(A7)
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_658A
	MOVEA.L	D0,A0
	MOVEA.L	$36(A0),A1
	BRA.S	LAB_6592
LAB_658A:
	MOVEA.L	$94(A5),A0
	MOVEA.L	8(A0),A1
LAB_6592:
	MOVEA.L	A1,A0
	LEA	$20(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A0
	MOVE.B	(A0),D1
	EXT.W	D1
	EXT.L	D1
	MOVE.L	D1,D0
	BSR.W	SUB_5BFE
	MOVEA.L	$1C(A7),A0
	MOVE.B	D0,2(A0)
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	ADDA.L	D0,A0
	MOVE.W	D7,(A0)
	MOVEQ	#0,D0
	MOVE.W	D7,D0
	MOVE.L	D0,-(A7)
	PEA	STR_CNF_HU(PC)
	PEA	$2C(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	SWAP	D5
	CLR.W	D5
	SWAP	D5
	MOVE.L	D5,D0
	ASL.L	#2,D0
	MOVEA.L	$156(A5),A0
	ADDA.L	D0,A0
	MOVE.L	A0,$1C(A7)
	MOVE.L	$98(A5),D0
	BEQ.S	LAB_65FC
	MOVEA.L	D0,A0
	MOVEA.L	$36(A0),A1
	BRA.S	LAB_6604
LAB_65FC:
	MOVEA.L	$94(A5),A0
	MOVEA.L	8(A0),A1
LAB_6604:
	MOVEA.L	A1,A0
	LEA	$20(A7),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVEA.L	D0,A0
	LEA	LAB_118(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	SNE	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVEA.L	$1C(A7),A0
	MOVE.B	D0,3(A0)
	ADDQ.W	#1,D5
LAB_662C:
	ADDQ.W	#1,D7
	BRA.W	LAB_64FE
LAB_6632:
	CLR.W	$154(A5)
LAB_6636:
	MOVEQ	#1,D0
LAB_6638:
	MOVEM.L	(A7)+,D5-D7/A2-A3/A5-A6
	ADDA.W	#$0024,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_6642  -  referenced from 4 call site(s)
; ------------------------------------------------------------------
SUB_6642:
	SUBA.W	#$0044,A7
	MOVEM.L	D2-D3/D5-D7/A2-A3/A5,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A0,A5
	CLR.L	$60(A7)
	MOVEQ	#0,D6
	CLR.W	$5C(A7)
	CLR.L	$30(A7)
	MOVE.B	#$02,$40(A7)
	CLR.B	$41(A7)
	SUBA.L	A0,A0
	MOVE.L	A0,$4A(A7)
	MOVE.L	A0,$42(A7)
	LEA	$27(A7),A0
	MOVE.L	A0,$46(A7)
	MOVEA.L	(A5),A3
	MOVEA.L	A3,A0
	MOVE.L	$78(A7),-(A7)
	MOVE.L	A1,$24(A7)
	LEA	$38(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.W	LAB_673E
	MOVEA.L	$20(A7),A0
	CMPA.L	A3,A0
	BNE.S	LAB_66A2
	MOVEA.L	A3,A1
	MOVE.L	A1,$30(A7)
LAB_66A2:
	MOVE.L	$34(A7),D0
	MOVEA.L	$6C(A7),A1
	MOVE.L	(A1),D1
	CMP.L	D0,D1
	BEQ.S	LAB_66EC
	MOVEA.L	$78(A7),A1
	MOVE.L	$CA(A1),D1
	MOVEA.L	$68(A7),A1
	MOVE.L	(A1),D2
	CMP.L	D1,D2
	BGE.S	LAB_66EC
	MOVEA.L	$78(A7),A1
	TST.L	$CE(A1)
	BEQ.S	LAB_66EC
	MOVEA.L	$70(A7),A1
	TST.W	(A1)
	BEQ.S	LAB_66D8
	MOVEQ	#0,D3
	MOVE.W	D3,(A1)
LAB_66D8:
	MOVEA.L	$78(A7),A1
	MOVE.L	$CA(A1),D0
	MOVE.L	D0,D1
	MOVEA.L	$68(A7),A1
	SUB.L	(A1),D1
	ADD.L	D1,D7
	BRA.S	LAB_66FA
LAB_66EC:
	MOVEA.L	$78(A7),A1
	MOVE.L	$CA(A1),D1
	MOVEA.L	$68(A7),A1
	MOVE.L	D1,(A1)
LAB_66FA:
	MOVEA.L	$78(A7),A1
	MOVE.L	$F8(A1),D0
	BEQ.S	LAB_670E
	MOVEA.L	$70(A7),A1
	TST.W	(A1)
	BNE.S	LAB_670E
	ADDQ.L	#1,D7
LAB_670E:
	TST.L	D0
	BNE.S	LAB_671A
	MOVEQ	#0,D0
	MOVEA.L	$70(A7),A1
	MOVE.W	D0,(A1)
LAB_671A:
	MOVE.L	A3,$60(A7)
	MOVE.L	$34(A7),D5
	TST.L	$30(A7)
	BEQ.W	LAB_6848
	MOVEA.L	$68(A7),A1
	MOVE.L	(A1),$54(A7)
	MOVEA.L	$70(A7),A1
	MOVE.W	(A1),$58(A7)
	BRA.W	LAB_6848
LAB_673E:
	MOVEA.L	(A5),A0
	MOVEA.L	$20(A7),A1
	CMPA.L	A0,A1
	BNE.S	LAB_674E
	MOVEQ	#0,D0
	BRA.W	LAB_6A50
LAB_674E:
	MOVEA.L	A0,A2
	SUBQ.L	#1,A2
	MOVEA.L	A2,A3
LAB_6754:
	MOVEA.L	$20(A7),A0
	CMPA.L	A0,A3
	BCS.W	LAB_67F8
	CMPA.L	A3,A0
	BEQ.S	LAB_676C
	MOVEQ	#$A,D0
	CMP.B	-1(A3),D0
	BNE.W	LAB_67F2
LAB_676C:
	ADDQ.L	#1,D6
	MOVE.L	A2,D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	$78(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$38(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_67EE
	SUB.L	D6,D7
	BGT.S	LAB_67DC
	BEQ.S	LAB_6790
	MOVEA.L	A2,A3
LAB_6790:
	SUBQ.L	#1,A3
LAB_6792:
	TST.L	D7
	BEQ.S	LAB_67A6
	ADDQ.L	#1,A3
LAB_6798:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BEQ.S	LAB_67A2
	ADDQ.L	#1,A3
	BRA.S	LAB_6798
LAB_67A2:
	ADDQ.L	#1,D7
	BRA.S	LAB_6792
LAB_67A6:
	ADDQ.L	#1,A3
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	CMPA.L	A2,A3
	SCS	D0
	NEG.B	D0
	EXT.W	D0
	EXT.L	D0
	MOVEA.L	$70(A7),A0
	MOVE.W	D0,(A0)
	MOVE.L	$34(A7),D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	MOVE.L	A3,(A5)
	MOVE.L	D6,D0
	SUBQ.L	#1,D0
	BNE.S	LAB_67D6
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
LAB_67D6:
	MOVEQ	#1,D0
	BRA.W	LAB_6A50
LAB_67DC:
	MOVE.L	A3,$60(A7)
	MOVEQ	#0,D6
	MOVE.L	$34(A7),D5
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
	BRA.S	LAB_67F8
LAB_67EE:
	MOVEA.L	A3,A2
	SUBQ.L	#1,A2
LAB_67F2:
	SUBQ.L	#1,A3
	BRA.W	LAB_6754
LAB_67F8:
	TST.L	$60(A7)
	BNE.S	LAB_6848
	MOVEA.L	$78(A7),A0
	TST.W	$10C(A0)
	BEQ.S	LAB_680E
	MOVEQ	#0,D0
	BRA.W	LAB_6A50
LAB_680E:
	SUB.L	D6,D7
	BGE.S	LAB_682A
	MOVEA.L	A2,A3
	SUBQ.L	#1,A3
LAB_6816:
	TST.L	D7
	BEQ.S	LAB_682A
	ADDQ.L	#1,A3
LAB_681C:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BEQ.S	LAB_6826
	ADDQ.L	#1,A3
	BRA.S	LAB_681C
LAB_6826:
	ADDQ.L	#1,D7
	BRA.S	LAB_6816
LAB_682A:
	ADDQ.L	#1,A3
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEQ	#-1,D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	MOVE.L	A3,(A5)
	MOVEQ	#1,D0
	BRA.W	LAB_6A50
LAB_6848:
	SUBQ.L	#1,A3
	MOVEA.L	A3,A2
LAB_684C:
	MOVEA.L	$20(A7),A0
	CMPA.L	A0,A3
	BCS.W	LAB_6978
	CMPA.L	A3,A0
	BEQ.S	LAB_6864
	MOVEQ	#$A,D0
	CMP.B	-1(A3),D0
	BNE.W	LAB_6972
LAB_6864:
	ADDQ.L	#1,D6
	MOVE.L	A2,D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	$78(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$38(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BNE.S	LAB_6894
	CMPA.L	$20(A7),A3
	BNE.W	LAB_696E
	MOVEQ	#1,D0
	MOVEQ	#-1,D1
	MOVE.L	D1,$34(A7)
	MOVE.W	D0,$5C(A7)
LAB_6894:
	MOVEA.L	$78(A7),A0
	TST.W	$10C(A0)
	BEQ.S	LAB_68A0
	MOVEQ	#1,D6
LAB_68A0:
	TST.L	$F8(A0)
	BEQ.S	LAB_68C4
	SUBQ.L	#1,D7
	BNE.S	LAB_68C4
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEA.L	$6C(A7),A0
	MOVE.L	D5,(A0)
	MOVEA.L	$60(A7),A3
	BRA.W	LAB_6978
LAB_68C4:
	MOVE.L	$34(A7),D0
	CMP.L	D5,D0
	BNE.S	LAB_68D2
	TST.W	$5C(A7)
	BEQ.S	LAB_6902
LAB_68D2:
	MOVEA.L	$78(A7),A0
	TST.L	$CE(A0)
	BEQ.S	LAB_6902
	SUB.L	$CA(A0),D7
	BGT.S	LAB_6902
	MOVE.L	D7,D0
	NEG.L	D0
	MOVEA.L	$68(A7),A0
	MOVE.L	D0,(A0)
	MOVEQ	#0,D7
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEQ	#-1,D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$60(A7),A3
	BRA.S	LAB_6978
LAB_6902:
	SUB.L	D6,D7
	BGT.S	LAB_6958
	BEQ.S	LAB_690C
	MOVEA.L	A2,A3
	BRA.S	LAB_6918
LAB_690C:
	TST.W	$5C(A7)
	BNE.S	LAB_6918
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
LAB_6918:
	SUBQ.L	#1,A3
LAB_691A:
	TST.L	D7
	BEQ.S	LAB_692E
	ADDQ.L	#1,A3
LAB_6920:
	MOVEQ	#$A,D0
	CMP.B	(A3),D0
	BEQ.S	LAB_692A
	ADDQ.L	#1,A3
	BRA.S	LAB_6920
LAB_692A:
	ADDQ.L	#1,D7
	BRA.S	LAB_691A
LAB_692E:
	ADDQ.L	#1,A3
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVE.L	$78(A7),-(A7)
	MOVEA.L	A3,A0
	LEA	$38(A7),A1
	BSR.W	SUB_3EA2
	MOVEA.L	$74(A7),A0
	MOVE.W	D0,(A0)
	ADDQ.W	#4,A7
	MOVE.L	$34(A7),D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	BRA.S	LAB_6978
LAB_6958:
	TST.W	$5C(A7)
	BNE.S	LAB_6964
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
LAB_6964:
	MOVE.L	A3,$60(A7)
	MOVEQ	#0,D6
	MOVE.L	$34(A7),D5
LAB_696E:
	MOVEA.L	A3,A2
	SUBQ.L	#1,A2
LAB_6972:
	SUBQ.L	#1,A3
	BRA.W	LAB_684C
LAB_6978:
	TST.L	D7
	BEQ.W	LAB_69FE
	MOVE.L	$78(A7),-(A7)
	MOVEA.L	$24(A7),A0
	LEA	$38(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_69E8
	MOVEA.L	$20(A7),A3
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEQ	#-1,D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$78(A7),A0
	TST.L	$F8(A0)
	BEQ.S	LAB_69C8
	SUBQ.L	#1,D7
	BNE.S	LAB_69C8
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$6C(A7),A0
	MOVE.L	$34(A7),(A0)
LAB_69C8:
	TST.L	D7
	BEQ.S	LAB_69FE
	MOVEA.L	$78(A7),A0
	TST.L	$CE(A0)
	BEQ.S	LAB_69FE
	SUB.L	$CA(A0),D7
	BGT.S	LAB_69FE
	MOVE.L	D7,D1
	NEG.L	D1
	MOVEA.L	$68(A7),A0
	MOVE.L	D1,(A0)
	BRA.S	LAB_69FE
LAB_69E8:
	ADDQ.L	#1,A3
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEQ	#-1,D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
LAB_69FE:
	MOVEA.L	$30(A7),A0
	CMPA.L	A3,A0
	BNE.S	LAB_6A4C
	MOVEA.L	$78(A7),A0
	TST.L	$CE(A0)
	BEQ.S	LAB_6A3C
	MOVE.L	A0,-(A7)
	MOVEA.L	A3,A0
	LEA	$38(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	MOVEA.L	$6C(A7),A0
	MOVE.L	(A0),D0
	CMP.L	$34(A7),D0
	BEQ.S	LAB_6A3C
	MOVE.L	$54(A7),D0
	MOVEA.L	$68(A7),A0
	CMP.L	(A0),D0
	BEQ.S	LAB_6A3C
	MOVE.L	A3,(A5)
	MOVEQ	#1,D0
	BRA.S	LAB_6A50
LAB_6A3C:
	MOVE.W	$58(A7),D0
	MOVEA.L	$70(A7),A0
	CMP.W	(A0),D0
	BNE.S	LAB_6A4C
	MOVEQ	#0,D0
	BRA.S	LAB_6A50
LAB_6A4C:
	MOVE.L	A3,(A5)
	MOVEQ	#1,D0
LAB_6A50:
	MOVEM.L	(A7)+,D2-D3/D5-D7/A2-A3/A5
	ADDA.W	#$0044,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_6A5A  -  referenced from 4 call site(s)
; ------------------------------------------------------------------
SUB_6A5A:
	SUBA.W	#$0040,A7
	MOVEM.L	D2-D3/D5-D7/A2-A3/A5-A6,-(A7)
	MOVE.L	D0,D7
	MOVE.L	A1,$28(A7)
	CLR.L	$60(A7)
	MOVEQ	#0,D6
	CLR.L	$54(A7)
	CLR.W	$52(A7)
	MOVE.B	#$02,$44(A7)
	CLR.B	$45(A7)
	SUBA.L	A1,A1
	MOVE.L	A1,$4E(A7)
	MOVE.L	A1,$46(A7)
	LEA	$2F(A7),A1
	MOVE.L	A1,$4A(A7)
	MOVEA.L	$78(A7),A6
	MOVEA.L	$11A(A6),A1
	MOVE.L	A0,$24(A7)
	TST.B	(A1)
	BNE.S	LAB_6AAC
	MOVE.B	$11E(A6),(A1)
	MOVE.W	#$0001,$52(A7)
LAB_6AAC:
	MOVEA.L	(A0),A5
	MOVEA.L	A5,A0
	LEA	1(A0),A2
LAB_6AB4:
	MOVEQ	#$A,D0
	CMP.B	(A2),D0
	BEQ.S	LAB_6ABE
	ADDQ.L	#1,A2
	BRA.S	LAB_6AB4
LAB_6ABE:
	MOVE.L	A2,D0
	MOVE.L	A5,D1
	SUB.L	D1,D0
	MOVE.L	$78(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$3C(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.W	LAB_6B88
	MOVEA.L	$28(A7),A0
	CMPA.L	A5,A0
	BNE.S	LAB_6AE8
	MOVEA.L	A5,A0
	MOVE.L	A0,$54(A7)
LAB_6AE8:
	MOVE.L	$38(A7),D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	(A0),D1
	CMP.L	D0,D1
	BEQ.S	LAB_6B32
	MOVEA.L	$78(A7),A0
	MOVE.L	$CA(A0),D1
	MOVEA.L	$68(A7),A0
	MOVE.L	(A0),D2
	CMP.L	D1,D2
	BGE.S	LAB_6B32
	MOVEA.L	$78(A7),A0
	TST.L	$CE(A0)
	BEQ.S	LAB_6B32
	MOVEA.L	$70(A7),A0
	TST.W	(A0)
	BEQ.S	LAB_6B1E
	MOVEQ	#0,D3
	MOVE.W	D3,(A0)
LAB_6B1E:
	MOVEA.L	$78(A7),A0
	MOVE.L	$CA(A0),D0
	MOVE.L	D0,D1
	MOVEA.L	$68(A7),A0
	SUB.L	(A0),D1
	ADD.L	D1,D7
	BRA.S	LAB_6B40
LAB_6B32:
	MOVEA.L	$78(A7),A0
	MOVE.L	$CA(A0),D1
	MOVEA.L	$68(A7),A0
	MOVE.L	D1,(A0)
LAB_6B40:
	MOVEA.L	$78(A7),A0
	MOVE.L	$F8(A0),D0
	BEQ.S	LAB_6B54
	MOVEA.L	$70(A7),A0
	TST.W	(A0)
	BNE.S	LAB_6B54
	ADDQ.L	#1,D7
LAB_6B54:
	TST.L	D0
	BNE.S	LAB_6B60
	MOVEQ	#0,D0
	MOVEA.L	$70(A7),A0
	MOVE.W	D0,(A0)
LAB_6B60:
	MOVE.L	A5,$60(A7)
	MOVE.L	$38(A7),D5
	TST.L	$54(A7)
	BEQ.S	LAB_6B7E
	MOVEA.L	$68(A7),A0
	MOVE.L	(A0),$5C(A7)
	MOVEA.L	$70(A7),A0
	MOVE.W	(A0),$58(A7)
LAB_6B7E:
	MOVEA.L	$74(A7),A0
	ADDQ.L	#1,(A0)
	BRA.W	LAB_6C40
LAB_6B88:
	MOVEA.L	$24(A7),A0
	MOVEA.L	(A0),A2
	SUBQ.L	#1,A2
	MOVEA.L	A2,A5
LAB_6B92:
	MOVEA.L	$78(A7),A1
	MOVEA.L	$8C(A1),A0
	CMPA.L	A5,A0
	BEQ.S	LAB_6BA8
	MOVEQ	#$A,D0
	CMP.B	-1(A5),D0
	BNE.W	LAB_6C3A
LAB_6BA8:
	SUBQ.L	#1,D7
	MOVE.L	A2,D0
	MOVE.L	A5,D1
	SUB.L	D1,D0
	MOVE.L	A1,-(A7)
	MOVEA.L	D1,A0
	LEA	$3C(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.S	LAB_6C0A
	TST.L	D7
	BNE.S	LAB_6C00
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	MOVE.W	#$0001,(A0)
	MOVE.L	$38(A7),D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$24(A7),A0
	MOVE.L	A5,(A0)
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
	MOVE.W	$52(A7),D0
	BEQ.S	LAB_6BFA
	MOVEA.L	$78(A7),A1
	MOVEA.L	$11A(A1),A0
	CLR.B	(A0)
LAB_6BFA:
	MOVEQ	#1,D0
	BRA.W	LAB_6EC8
LAB_6C00:
	MOVE.L	A5,$60(A7)
	MOVE.L	$38(A7),D5
	BRA.S	LAB_6C40
LAB_6C0A:
	TST.L	D7
	BNE.S	LAB_6C36
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEA.L	$24(A7),A0
	MOVE.L	A5,(A0)
	TST.W	$52(A7)
	BEQ.S	LAB_6C30
	MOVEA.L	$78(A7),A1
	MOVEA.L	$11A(A1),A0
	CLR.B	(A0)
LAB_6C30:
	MOVEQ	#1,D0
	BRA.W	LAB_6EC8
LAB_6C36:
	MOVEA.L	A5,A2
	SUBQ.L	#1,A2
LAB_6C3A:
	SUBQ.L	#1,A5
	BRA.W	LAB_6B92
LAB_6C40:
	LEA	1(A2),A3
	MOVEA.L	A3,A5
LAB_6C46:
	MOVE.B	(A5),D0
	BEQ.S	LAB_6C74
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BNE.S	LAB_6C70
	ADDQ.L	#1,D6
	MOVE.L	A5,D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	$78(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$3C(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BNE.S	LAB_6C74
	LEA	1(A5),A3
LAB_6C70:
	ADDQ.L	#1,A5
	BRA.S	LAB_6C46
LAB_6C74:
	TST.B	(A5)
	BNE.S	LAB_6C7A
	ADDQ.L	#1,D6
LAB_6C7A:
	MOVEA.L	$78(A7),A0
	TST.W	$10C(A0)
	BEQ.S	LAB_6C86
	MOVEQ	#1,D6
LAB_6C86:
	ADD.L	D6,D7
	MOVEQ	#0,D6
	MOVEA.L	$60(A7),A5
	ADDQ.L	#1,A5
LAB_6C90:
	MOVEQ	#$A,D0
	CMP.B	(A5),D0
	BEQ.S	LAB_6C9A
	ADDQ.L	#1,A5
	BRA.S	LAB_6C90
LAB_6C9A:
	MOVEA.L	A5,A2
	LEA	1(A2),A3
	MOVEA.L	A3,A0
	LEA	1(A0),A5
LAB_6CA6:
	MOVE.B	(A5),D0
	BEQ.W	LAB_6D96
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BNE.W	LAB_6D90
	ADDQ.L	#1,D6
	MOVE.L	A5,D0
	MOVE.L	A3,D1
	SUB.L	D1,D0
	MOVE.L	$78(A7),-(A7)
	MOVEA.L	D1,A0
	LEA	$3C(A7),A1
	BSR.W	SUB_3E3E
	ADDQ.W	#4,A7
	TST.W	D0
	BEQ.W	LAB_6D8C
	MOVEA.L	$78(A7),A0
	TST.W	$10C(A0)
	BEQ.S	LAB_6CDE
	MOVEQ	#1,D6
LAB_6CDE:
	SUB.L	D6,D7
	BGT.S	LAB_6D1E
	MOVEA.L	$60(A7),A5
	BEQ.S	LAB_6D02
LAB_6CE8:
	ADDQ.L	#1,A5
LAB_6CEA:
	MOVEQ	#$A,D0
	CMP.B	(A5),D0
	BEQ.S	LAB_6CF4
	ADDQ.L	#1,A5
	BRA.S	LAB_6CEA
LAB_6CF4:
	ADDQ.L	#1,D7
	BNE.S	LAB_6CE8
	ADDQ.L	#1,A5
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	BRA.S	LAB_6D10
LAB_6D02:
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
	MOVEA.L	$70(A7),A0
	MOVE.W	#$0001,(A0)
LAB_6D10:
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$6C(A7),A0
	MOVE.L	D5,(A0)
	BRA.S	LAB_6D96
LAB_6D1E:
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
	MOVEA.L	$78(A7),A0
	TST.L	$F8(A0)
	BEQ.S	LAB_6D4A
	SUBQ.L	#1,D7
	BNE.S	LAB_6D4A
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEA.L	$6C(A7),A0
	MOVE.L	D5,(A0)
	MOVEA.L	$60(A7),A5
	BRA.S	LAB_6D96
LAB_6D4A:
	MOVE.L	$38(A7),D0
	CMP.L	D0,D5
	BEQ.S	LAB_6D82
	MOVEA.L	$78(A7),A0
	TST.L	$CE(A0)
	BEQ.S	LAB_6D82
	SUB.L	$CA(A0),D7
	BGT.S	LAB_6D82
	MOVE.L	D7,D1
	NEG.L	D1
	MOVEA.L	$68(A7),A0
	MOVE.L	D1,(A0)
	MOVEQ	#0,D7
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEQ	#-1,D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$60(A7),A5
	BRA.S	LAB_6D96
LAB_6D82:
	MOVE.L	A3,$60(A7)
	MOVEQ	#0,D6
	MOVE.L	$38(A7),D5
LAB_6D8C:
	LEA	1(A5),A3
LAB_6D90:
	ADDQ.L	#1,A5
	BRA.W	LAB_6CA6
LAB_6D96:
	TST.L	D7
	BEQ.W	LAB_6E5E
	MOVEA.L	$78(A7),A0
	TST.W	$10C(A0)
	BEQ.S	LAB_6DAA
	MOVEQ	#1,D6
	BRA.S	LAB_6DAC
LAB_6DAA:
	ADDQ.L	#1,D6
LAB_6DAC:
	SUB.L	D6,D7
	BGT.S	LAB_6DEC
	MOVEA.L	$60(A7),A5
	BEQ.S	LAB_6DD0
LAB_6DB6:
	ADDQ.L	#1,A5
LAB_6DB8:
	MOVEQ	#$A,D0
	CMP.B	(A5),D0
	BEQ.S	LAB_6DC2
	ADDQ.L	#1,A5
	BRA.S	LAB_6DB8
LAB_6DC2:
	ADDQ.L	#1,D7
	BNE.S	LAB_6DB6
	ADDQ.L	#1,A5
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	BRA.S	LAB_6DDE
LAB_6DD0:
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
	MOVEA.L	$70(A7),A0
	MOVE.W	#$0001,(A0)
LAB_6DDE:
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$6C(A7),A0
	MOVE.L	D5,(A0)
	BRA.S	LAB_6E5E
LAB_6DEC:
	MOVEA.L	$74(A7),A0
	SUBQ.L	#1,(A0)
	MOVEA.L	$78(A7),A0
	TST.L	$F8(A0)
	BEQ.S	LAB_6E18
	SUBQ.L	#1,D7
	BNE.S	LAB_6E18
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEA.L	$6C(A7),A0
	MOVE.L	D5,(A0)
	MOVEA.L	$60(A7),A5
	BRA.S	LAB_6E5E
LAB_6E18:
	MOVEA.L	$78(A7),A0
	TST.L	$CE(A0)
	BEQ.S	LAB_6E46
	SUB.L	$CA(A0),D7
	BGT.S	LAB_6E46
	MOVE.L	D7,D0
	NEG.L	D0
	MOVEA.L	$68(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEQ	#-1,D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
	MOVEA.L	$60(A7),A5
	BRA.S	LAB_6E5E
LAB_6E46:
	MOVEA.L	$60(A7),A5
	MOVEA.L	$68(A7),A0
	CLR.L	(A0)
	MOVEA.L	$70(A7),A0
	CLR.W	(A0)
	MOVEQ	#-1,D0
	MOVEA.L	$6C(A7),A0
	MOVE.L	D0,(A0)
LAB_6E5E:
	TST.W	$52(A7)
	BEQ.S	LAB_6E6E
	MOVEA.L	$78(A7),A1
	MOVEA.L	$11A(A1),A0
	CLR.B	(A0)
LAB_6E6E:
	MOVEA.L	$54(A7),A0
	CMPA.L	A5,A0
	BNE.S	LAB_6EC0
	MOVEA.L	$78(A7),A0
	TST.L	$CE(A0)
	BEQ.S	LAB_6EB0
	MOVE.L	A0,-(A7)
	MOVEA.L	A5,A0
	LEA	$3C(A7),A1
	BSR.W	SUB_3EA2
	ADDQ.W	#4,A7
	MOVEA.L	$6C(A7),A0
	MOVE.L	(A0),D0
	CMP.L	$38(A7),D0
	BEQ.S	LAB_6EB0
	MOVE.L	$5C(A7),D0
	MOVEA.L	$68(A7),A0
	CMP.L	(A0),D0
	BEQ.S	LAB_6EB0
	MOVEA.L	$24(A7),A0
	MOVE.L	A5,(A0)
	MOVEQ	#1,D0
	BRA.S	LAB_6EC8
LAB_6EB0:
	MOVE.W	$58(A7),D0
	MOVEA.L	$70(A7),A0
	CMP.W	(A0),D0
	BNE.S	LAB_6EC0
	MOVEQ	#0,D0
	BRA.S	LAB_6EC8
LAB_6EC0:
	MOVEA.L	$24(A7),A0
	MOVE.L	A5,(A0)
	MOVEQ	#1,D0
LAB_6EC8:
	MOVEM.L	(A7)+,D2-D3/D5-D7/A2-A3/A5-A6
	ADDA.W	#$0040,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_6ED2  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_6ED2:
	SUBQ.W	#8,A7
	MOVEM.L	D2-D3/D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A5),A3
	MOVEA.L	iconbase(A5),A0
	MOVE.L	A0,$20(A7)
	LEA	STR_DOORS_AQUASCAN_AQUASCAN(PC),A0
	MOVEA.L	$20(A7),A6
	JSR	_LVOGetDiskObject(A6)	; GetDiskObject(name) - load a .info icon (and its tooltypes)
	MOVE.L	D0,$98(A5)
	BEQ.S	LAB_6EFE
	MOVEQ	#1,D0
	BRA.W	LAB_7092
LAB_6EFE:
	LEA	STR_DOORS_AQUASCAN_AQUASCAN_CONF(PC),A0
	MOVE.L	A0,D1
	MOVE.L	#$000003ed,D2
	MOVEA.L	A3,A6
	JSR	_LVOOpen(A6)	; Open(name,mode) - open a file
	MOVE.L	D0,D7
	TST.L	D7
	BEQ.W	LAB_7090
	MOVEQ	#$10,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVE.L	D0,$94(A5)
	BEQ.W	LAB_7088
	MOVEA.L	D0,A0
	CLR.L	(A0)
	MOVEA.L	$94(A5),A0
	CLR.L	8(A0)
	MOVE.L	D7,D1
	MOVEQ	#0,D2
	MOVEQ	#1,D3
	MOVEA.L	A3,A6
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVEA.L	$94(A5),A0
	MOVE.L	A0,$1C(A7)
	MOVE.L	D7,D1
	MOVEQ	#-1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVEA.L	$1C(A7),A0
	MOVE.L	D0,4(A0)
	BEQ.W	LAB_7088
	MOVEA.L	$94(A5),A0
	MOVE.L	4(A0),D0
	ADDQ.L	#1,D0
	MOVE.L	D0,4(A0)
	MOVEA.L	$94(A5),A0
	MOVE.L	A0,$1C(A7)
	MOVE.L	D2,D1
	MOVE.L	4(A0),D0
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVEA.L	$1C(A7),A0
	MOVE.L	D0,(A0)
	TST.L	D0
	BEQ.W	LAB_7088
	MOVEA.L	$94(A5),A0
	MOVE.L	4(A0),D0
	SUBQ.L	#1,D0
	MOVE.L	D0,D3
	MOVE.L	D7,D1
	MOVE.L	(A0),D2
	MOVEA.L	A3,A6
	JSR	_LVORead(A6)	; Read(file,buf,len) - read from a file
	MOVEA.L	$94(A5),A0
	MOVE.L	4(A0),D1
	SUBQ.L	#1,D1
	CMP.L	D1,D0
	BNE.W	LAB_7088
	MOVE.L	4(A0),D0
	SUBQ.L	#1,D0
	MOVEA.L	(A0),A1
	ADDA.L	D0,A1
	CLR.B	(A1)
	MOVEA.L	$94(A5),A0
	MOVEQ	#1,D0
	MOVE.L	D0,$C(A0)
	MOVEA.L	$94(A5),A0
	MOVEA.L	(A0),A2
LAB_6FD2:
	MOVE.B	(A2),D0
	BEQ.S	LAB_6FEE
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BNE.S	LAB_6FEA
	MOVEA.L	$94(A5),A0
	MOVE.L	$C(A0),D0
	ADDQ.L	#1,D0
	MOVE.L	D0,$C(A0)
LAB_6FEA:
	ADDQ.L	#1,A2
	BRA.S	LAB_6FD2
LAB_6FEE:
	MOVEA.L	$94(A5),A0
	MOVE.L	$C(A0),D0
	ADDQ.L	#1,D0
	MOVE.L	D0,D1
	ASL.L	#2,D1
	MOVE.L	A0,$1C(A7)
	MOVE.L	D1,D0
	MOVEQ	#0,D1
	MOVEA.L	ABSEXECBASE.W,A6
	JSR	_LVOAllocMem(A6)	; AllocMem(size,flags) - allocate memory from the system pool
	MOVEA.L	$1C(A7),A0
	MOVE.L	D0,8(A0)
	BEQ.S	LAB_7088
	MOVEA.L	$94(A5),A0
	MOVEQ	#1,D0
	MOVE.L	D0,$C(A0)
	MOVEA.L	$94(A5),A0
	MOVEA.L	8(A0),A1
	MOVE.L	(A0),(A1)
	MOVEA.L	$94(A5),A0
	MOVEA.L	(A0),A2
LAB_7030:
	MOVE.B	(A2),D0
	BEQ.S	LAB_7068
	MOVEQ	#$A,D1
	CMP.B	D1,D0
	BNE.S	LAB_7064
	CLR.B	(A2)+
LAB_703C:
	MOVEQ	#$20,D0
	CMP.B	(A2),D0
	BNE.S	LAB_7046
	ADDQ.L	#1,A2
	BRA.S	LAB_703C
LAB_7046:
	MOVEA.L	$94(A5),A0
	MOVE.L	$C(A0),D0
	MOVE.L	D0,D1
	ADDQ.L	#1,D1
	MOVE.L	D1,$C(A0)
	MOVE.L	D0,D1
	ASL.L	#2,D1
	MOVEA.L	8(A0),A1
	ADDA.L	D1,A1
	MOVE.L	A2,(A1)
	SUBQ.L	#1,A2
LAB_7064:
	ADDQ.L	#1,A2
	BRA.S	LAB_7030
LAB_7068:
	MOVEA.L	$94(A5),A0
	MOVE.L	$C(A0),D0
	MOVE.L	D0,D1
	ASL.L	#2,D1
	MOVEA.L	8(A0),A1
	ADDA.L	D1,A1
	CLR.L	(A1)
	MOVE.L	D7,D1
	MOVEA.L	A3,A6
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
	MOVEQ	#1,D0
	BRA.S	LAB_7092
LAB_7088:
	MOVE.L	D7,D1
	MOVEA.L	A3,A6
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
LAB_7090:
	MOVEQ	#0,D0
LAB_7092:
	MOVEM.L	(A7)+,D2-D3/D7/A2-A3/A5-A6
	ADDQ.W	#8,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_709A  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
SUB_709A:
	MOVEM.L	A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A5,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_70C0
	MOVEA.L	A5,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_71EA
	MOVEA.L	A5,A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7278
	MOVEM.L	(A7)+,A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_70C0  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_70C0:
	MOVEM.L	A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$f0000000,D0
	MOVE.L	4(A5),D1
	ANDI.L	#$0fffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	ANDI.L	#$0f000000,D0
	ANDI.L	#$f0ffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#4,D0
	ANDI.L	#$00f00000,D0
	ANDI.L	#$ff0fffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	ANDI.L	#$0000000f,D0
	SWAP	D0
	CLR.W	D0
	ANDI.L	#$000f0000,D0
	ANDI.L	#$fff0ffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	4(A3),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$0000f000,D0
	ANDI.W	#$0fff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	4(A3),D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	LSL.L	#8,D0
	ANDI.L	#$00000f00,D0
	ANDI.W	#$f0ff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	4(A3),D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	LSL.L	#4,D0
	ANDI.L	#$000000f0,D0
	ANDI.W	#$ff0f,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	4(A3),D0
	ANDI.L	#$0000000f,D0
	ANDI.L	#$0000000f,D0
	ANDI.W	#$fff0,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVEM.L	(A7)+,A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_71EA  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_71EA:
	MOVEM.L	A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$f0000000,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$0fffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	ANDI.L	#$0f000000,D0
	ANDI.L	#$f0ffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#7,D0
	ANDI.L	#$00000001,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#7,D0
	ANDI.L	#$00800000,D0
	ANDI.L	#$ff7fffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVEM.L	(A7)+,A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7278  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7278:
	MOVEM.L	A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#6,D0
	ANDI.L	#$00000001,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#6,D0
	ANDI.L	#$00400000,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$ffbfffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#5,D0
	ANDI.L	#$00000001,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#5,D0
	ANDI.L	#$00200000,D0
	ANDI.L	#$ffdfffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#4,D0
	ANDI.L	#$00000001,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#4,D0
	ANDI.L	#$00100000,D0
	ANDI.L	#$ffefffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#3,D0
	ANDI.L	#$00000001,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#3,D0
	ANDI.L	#$00080000,D0
	ANDI.L	#$fff7ffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#2,D0
	ANDI.L	#$00000001,D0
	SWAP	D0
	CLR.W	D0
	LSL.L	#2,D0
	ANDI.L	#$00040000,D0
	ANDI.L	#$fffbffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	LSL.L	#8,D0
	LSL.L	#6,D0
	ANDI.L	#$0003c000,D0
	ANDI.L	#$fffc3fff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	LSR.L	#8,D0
	LSR.L	#5,D0
	ANDI.L	#$00000001,D0
	LSL.L	#8,D0
	LSL.L	#5,D0
	ANDI.L	#$00002000,D0
	ANDI.W	#$dfff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$00000001,D0
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$00001000,D0
	ANDI.W	#$efff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	LSR.L	#8,D0
	LSR.L	#3,D0
	ANDI.L	#$00000001,D0
	LSL.L	#8,D0
	LSL.L	#3,D0
	ANDI.L	#$00000800,D0
	ANDI.W	#$f7ff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	8(A3),D0
	LSR.L	#8,D0
	LSR.L	#2,D0
	ANDI.L	#$00000001,D0
	LSL.L	#8,D0
	LSL.L	#2,D0
	ANDI.L	#$00000400,D0
	ANDI.W	#$fbff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVEM.L	(A7)+,A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_73FE  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_73FE:
	SUBA.W	#$0034,A7
	MOVEM.L	D2/D5-D7/A3/A5-A6,-(A7)
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEQ	#0,D5
LAB_740E:
	ADDQ.L	#1,D5
	MOVE.L	D5,-(A7)
	MOVE.L	A5,-(A7)
	PEA	STR_DOORS_AQUASCAN_AQUASCAN_2(PC)
	PEA	$2A(A7)
	BSR.W	sprintf
	LEA	$10(A7),A7
	LEA	$1E(A7),A0
	MOVE.L	A0,D1
	MOVEQ	#-2,D2
	MOVEA.L	A3,A6
	JSR	_LVOLock(A6)	; Lock(name,mode) - lock a file or directory
	MOVE.L	D0,D6
	TST.L	D6
	BEQ.S	LAB_7440
	MOVE.L	D6,D1
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
	BRA.S	LAB_7442
LAB_7440:
	SUBQ.L	#1,D5
LAB_7442:
	TST.L	D6
	BEQ.S	LAB_744A
	CMP.L	D7,D5
	BLT.S	LAB_740E
LAB_744A:
	MOVE.L	D5,D0
	MOVEM.L	(A7)+,D2/D5-D7/A3/A5-A6
	ADDA.W	#$0034,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7456  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7456:
	MOVEM.L	D2-D3/D5-D7/A3/A5-A6,-(A7)
	MOVEA.L	A0,A5
	MOVEA.L	dosbase(A5),A3
	LEA	STR_DOORS_AQUASCAN_AQUASCAN_USER(PC),A0
	MOVEA.L	dosbase(A5),A1
	MOVEQ	#-2,D0
	MOVEQ	#4,D1
	BSR.W	SUB_7BD8
	MOVE.L	D0,D7
	MOVE.L	D7,D0
	TST.L	D0
	BEQ.W	LAB_74FA
	MOVE.L	D7,D1
	MOVEA.L	A3,A6
	JSR	_LVOOpenFromLock(A6)	; OpenFromLock(lock) - open a file using an existing lock
	MOVE.L	D0,D6
	MOVE.L	D6,D0
	TST.L	D0
	BEQ.S	LAB_74FA
	MOVE.L	D6,D1
	MOVEQ	#0,D2
	MOVEQ	#1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVE.L	D6,D1
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVE.L	D0,D5
	MOVE.L	$150(A5),D0
	MOVE.L	D0,D1
	ASL.L	#4,D1
	CMP.L	D1,D5
	BCS.S	LAB_74E6
	SUBQ.L	#1,D0
	MOVE.L	D0,D1
	ASL.L	#4,D1
	MOVE.L	D1,D2
	MOVE.L	D6,D1
	MOVEQ	#-1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	LEA	$A8(A5),A0
	MOVE.L	A0,D2
	MOVE.L	D6,D1
	MOVEQ	#$10,D3
	JSR	_LVORead(A6)	; Read(file,buf,len) - read from a file
	CMP.L	D3,D0
	BNE.S	LAB_74D8
	LEA	$A8(A5),A0
	MOVEA.L	A5,A1
	BSR.W	SUB_7518
	TST.W	D0
	BNE.S	LAB_74F2
LAB_74D8:
	LEA	$A8(A5),A0
	LEA	$B8(A5),A1
	BSR.W	SUB_709A
	BRA.S	LAB_74F2
LAB_74E6:
	LEA	$A8(A5),A0
	LEA	$B8(A5),A1
	BSR.W	SUB_709A
LAB_74F2:
	MOVE.L	D6,D1
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
	BRA.S	LAB_7512
LAB_74FA:
	TST.L	D7
	BEQ.S	LAB_7506
	MOVE.L	D7,D1
	MOVEA.L	A3,A6
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
LAB_7506:
	LEA	$A8(A5),A0
	LEA	$B8(A5),A1
	BSR.W	SUB_709A
LAB_7512:
	MOVEM.L	(A7)+,D2-D3/D5-D7/A3/A5-A6
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7518  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7518:
	MOVEM.L	A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A3,A0
	MOVEQ	#$64,D0
	BSR.W	sendDoorGetValueMsg      ;DT_NAME
	MOVEA.L	$2C(A3),A0
	TST.B	(A0)
	BNE.S	LAB_7536
	LEA	1(A0),A1
	CLR.B	(A1)
LAB_7536:
	MOVEA.L	$2C(A3),A0
	MOVEA.L	A0,A1
	ADDQ.L	#1,A1
	TST.B	(A1)
	BNE.S	LAB_7548
	LEA	2(A0),A1
	CLR.B	(A1)
LAB_7548:
	MOVEA.L	$2C(A3),A0
	MOVE.B	(A5),D0
	CMP.B	(A0),D0
	BNE.S	LAB_757A
	LEA	1(A0),A1
	MOVE.B	1(A5),D0
	CMP.B	(A1),D0
	BNE.S	LAB_757A
	LEA	2(A0),A1
	MOVE.B	2(A5),D0
	CMP.B	(A1),D0
	BNE.S	LAB_757A
	BSR.W	SUB_7582
	MOVE.B	3(A5),D1
	CMP.B	D0,D1
	BNE.S	LAB_757A
	MOVEQ	#1,D0
	BRA.S	LAB_757C
LAB_757A:
	MOVEQ	#0,D0
LAB_757C:
	MOVEM.L	(A7)+,A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7582  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
SUB_7582:
	MOVEM.L	D7/A3/A5,-(A7)
	MOVEA.L	A0,A5
	MOVEQ	#0,D7
	MOVEA.L	A5,A3
LAB_758C:
	MOVE.B	(A3),D0
	BEQ.S	LAB_759A
	EXT.W	D0
	EXT.L	D0
	ADD.L	D0,D7
	ADDQ.L	#1,A3
	BRA.S	LAB_758C
LAB_759A:
	MOVE.L	D7,D0
	MOVEQ	#0,D1
	NOT.B	D1
	AND.L	D1,D0
	MOVEM.L	(A7)+,D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_75A8  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_75A8:
	MOVEM.L	D2/A2-A3/A5,-(A7)
	MOVEA.L	$14(A7),A2
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	4(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#7,D1
	CMP.L	D1,D0
	BLE.S	LAB_7604
	CMPA.L	A3,A5
	BNE.S	LAB_75D4
	MOVEQ	#0,D0
	BRA.S	LAB_75E6
LAB_75D4:
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
LAB_75E6:
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$f0000000,D0
	MOVE.L	4(A5),D2
	ANDI.L	#$0fffffff,D2
	OR.L	D0,D2
	MOVE.L	D2,4(A5)
LAB_7604:
	MOVE.L	4(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	CMP.L	D1,D0
	BLE.S	LAB_764C
	CMPA.L	A3,A5
	BNE.S	LAB_7620
	MOVEQ	#0,D0
	BRA.S	LAB_7630
LAB_7620:
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
LAB_7630:
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	ANDI.L	#$0f000000,D0
	MOVE.L	4(A5),D2
	ANDI.L	#$f0ffffff,D2
	OR.L	D0,D2
	MOVE.L	D2,4(A5)
LAB_764C:
	MOVE.L	4(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	CMP.L	D1,D0
	BLE.S	LAB_7694
	CMPA.L	A3,A5
	BNE.S	LAB_7668
	MOVEQ	#0,D0
	BRA.S	LAB_7678
LAB_7668:
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
LAB_7678:
	SWAP	D0
	CLR.W	D0
	LSL.L	#4,D0
	ANDI.L	#$00f00000,D0
	MOVE.L	4(A5),D2
	ANDI.L	#$ff0fffff,D2
	OR.L	D0,D2
	MOVE.L	D2,4(A5)
LAB_7694:
	MOVE.L	4(A5),D0
	CLR.W	D0
	SWAP	D0
	ANDI.L	#$0000000f,D0
	CMP.L	D1,D0
	BLE.S	LAB_76D6
	CMPA.L	A3,A5
	BNE.S	LAB_76AE
	MOVEQ	#0,D0
	BRA.S	LAB_76BC
LAB_76AE:
	MOVE.L	4(A3),D0
	CLR.W	D0
	SWAP	D0
	ANDI.L	#$0000000f,D0
LAB_76BC:
	SWAP	D0
	CLR.W	D0
	ANDI.L	#$000f0000,D0
	MOVE.L	4(A5),D2
	ANDI.L	#$fff0ffff,D2
	OR.L	D0,D2
	MOVE.L	D2,4(A5)
LAB_76D6:
	MOVE.L	4(A5),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	CMP.L	D1,D0
	BLE.S	LAB_7716
	CMPA.L	A3,A5
	BNE.S	LAB_76F0
	MOVEQ	#0,D0
	BRA.S	LAB_76FE
LAB_76F0:
	MOVE.L	4(A3),D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
LAB_76FE:
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$0000f000,D0
	MOVE.L	4(A5),D2
	ANDI.W	#$0fff,D2
	OR.L	D0,D2
	MOVE.L	D2,4(A5)
LAB_7716:
	MOVE.L	4(A5),D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
	CMP.L	D1,D0
	BLE.S	LAB_7750
	CMPA.L	A3,A5
	BNE.S	LAB_772E
	MOVEQ	#0,D0
	BRA.S	LAB_773A
LAB_772E:
	MOVE.L	4(A3),D0
	LSR.L	#8,D0
	ANDI.L	#$0000000f,D0
LAB_773A:
	LSL.L	#8,D0
	ANDI.L	#$00000f00,D0
	MOVE.L	4(A5),D2
	ANDI.W	#$f0ff,D2
	OR.L	D0,D2
	MOVE.L	D2,4(A5)
LAB_7750:
	MOVE.L	4(A5),D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	CMP.L	D1,D0
	BLE.S	LAB_778A
	CMPA.L	A3,A5
	BNE.S	LAB_7768
	MOVEQ	#0,D0
	BRA.S	LAB_7774
LAB_7768:
	MOVE.L	4(A3),D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
LAB_7774:
	LSL.L	#4,D0
	ANDI.L	#$000000f0,D0
	MOVE.L	4(A5),D2
	ANDI.W	#$ff0f,D2
	OR.L	D0,D2
	MOVE.L	D2,4(A5)
LAB_778A:
	MOVE.L	4(A5),D0
	ANDI.L	#$0000000f,D0
	CMP.L	D1,D0
	BLE.S	LAB_77BE
	CMPA.L	A3,A5
	BNE.S	LAB_77A0
	MOVEQ	#0,D0
	BRA.S	LAB_77AA
LAB_77A0:
	MOVE.L	4(A3),D0
	ANDI.L	#$0000000f,D0
LAB_77AA:
	ANDI.L	#$0000000f,D0
	MOVE.L	4(A5),D1
	ANDI.W	#$fff0,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
LAB_77BE:
	MOVE.L	8(A5),D0
	CLR.W	D0
	SWAP	D0
	LSR.L	#8,D0
	LSR.L	#4,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#0,D1
	MOVE.B	$C9(A2),D1
	CMP.L	D1,D0
	BLE.S	LAB_77EA
	MOVEQ	#0,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$0fffffff,D1
	MOVE.L	D1,8(A5)
LAB_77EA:
	MOVEQ	#0,D0
	MOVE.B	$C8(A2),D0
	ADDQ.L	#1,D0
	MOVE.L	8(A5),D1
	CLR.W	D1
	SWAP	D1
	LSR.L	#8,D1
	ANDI.L	#$0000000f,D1
	CMP.L	D0,D1
	BGT.S	LAB_7812
	TST.L	D1
	BNE.S	LAB_7828
	BTST	#7,9(A5)
	BEQ.S	LAB_7828
LAB_7812:
	MOVE.L	#$01000000,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$f0ffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
LAB_7828:
	MOVE.L	8(A5),D0
	LSR.L	#8,D0
	LSR.L	#6,D0
	ANDI.L	#$0000000f,D0
	MOVEQ	#8,D1
	CMP.L	D1,D0
	BLE.S	LAB_784C
	MOVEQ	#0,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$fffc3fff,D1
	MOVE.L	D1,8(A5)
LAB_784C:
	MOVEM.L	(A7)+,D2/A2-A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7852  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7852:
	SUBQ.W	#8,A7
	MOVEM.L	A2-A3/A5-A6,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	iconbase(A3),A2
	LEA	STR_FILE_NAME(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$f0000000,D0
	MOVE.L	4(A5),D1
	ANDI.L	#$0fffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	LEA	STR_FILE_TEST(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	ANDI.L	#$0f000000,D0
	MOVE.L	4(A5),D1
	ANDI.L	#$f0ffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	LEA	STR_FILE_SIZE(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	SWAP	D0
	CLR.W	D0
	LSL.L	#4,D0
	ANDI.L	#$00f00000,D0
	MOVE.L	4(A5),D1
	ANDI.L	#$ff0fffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	LEA	STR_FILE_DATE(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	SWAP	D0
	CLR.W	D0
	ANDI.L	#$000f0000,D0
	MOVE.L	4(A5),D1
	ANDI.L	#$fff0ffff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	LEA	STR_FILE_DESC(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$0000f000,D0
	MOVE.L	4(A5),D1
	ANDI.W	#$0fff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	LEA	STR_SEPARATOR(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	LSL.L	#8,D0
	ANDI.L	#$00000f00,D0
	MOVE.L	4(A5),D1
	ANDI.W	#$f0ff,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	LEA	STR_NUKE_SIZE(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	LSL.L	#4,D0
	ANDI.L	#$000000f0,D0
	MOVE.L	4(A5),D1
	ANDI.W	#$ff0f,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	LEA	STR_FILE_NUMBER(PC),A0
	MOVEA.L	A3,A1
	BSR.W	SUB_7AE2
	ANDI.L	#$0000000f,D0
	MOVE.L	4(A5),D1
	ANDI.W	#$fff0,D1
	OR.L	D0,D1
	MOVE.L	D1,4(A5)
	MOVE.L	$98(A3),D0
	BEQ.S	LAB_7986
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_7990
LAB_7986:
	MOVEA.L	$94(A3),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_7990:
	LEA	STR_DATE_LINE(PC),A1
	MOVEA.L	A2,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$14(A7)
	TST.L	D0
	BEQ.S	LAB_79B8
	MOVEA.L	D0,A0
	LEA	$10(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_79B8
	MOVE.L	$10(A7),D0
	TST.L	D0
	BPL.S	LAB_79BE
LAB_79B8:
	MOVEQ	#0,D0
	MOVE.L	D0,$10(A7)
LAB_79BE:
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	LSL.L	#4,D0
	ANDI.L	#$f0000000,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$0fffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	MOVE.L	$98(A3),D0
	BEQ.S	LAB_79EA
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_79F4
LAB_79EA:
	MOVEA.L	$94(A3),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_79F4:
	LEA	STR_SEPARATOR(PC),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$14(A7)
	TST.L	D0
	BEQ.S	LAB_7A1A
	MOVEA.L	D0,A0
	LEA	$10(A7),A1
	BSR.W	SUB_7F84
	TST.L	D0
	BEQ.S	LAB_7A1A
	MOVE.L	$10(A7),D0
	TST.L	D0
	BPL.S	LAB_7A20
LAB_7A1A:
	MOVEQ	#0,D0
	MOVE.L	D0,$10(A7)
LAB_7A20:
	SWAP	D0
	CLR.W	D0
	LSL.L	#8,D0
	ANDI.L	#$0f000000,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$f0ffffff,D1
	OR.L	D0,D1
	MOVE.L	D1,8(A5)
	BCLR	#$17,D1
	MOVE.L	D1,8(A5)
	MOVE.L	$98(A3),D0
	BEQ.S	LAB_7A52
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_7A5C
LAB_7A52:
	MOVEA.L	$94(A3),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_7A5C:
	LEA	STR_FILE_NUMBERS(PC),A1
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$14(A7)
	TST.L	D0
	BEQ.S	LAB_7A80
	MOVEA.L	D0,A0
	LEA	LAB_126(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7A80
	BSET	#7,9(A5)
LAB_7A80:
	BCLR	#6,9(A5)
	BSET	#5,9(A5)
	BSET	#4,9(A5)
	BCLR	#3,9(A5)
	BSET	#2,9(A5)
	MOVEQ	#0,D0
	MOVE.L	8(A5),D1
	ANDI.L	#$fffc3fff,D1
	MOVE.L	D1,8(A5)
	BCLR	#$D,D1
	MOVE.L	D1,8(A5)
	BCLR	#$C,D1
	MOVE.L	D1,8(A5)
	BCLR	#$B,D1
	MOVE.L	D1,8(A5)
	BSET	#$A,D1
	MOVE.L	D1,8(A5)
	MOVE.L	A3,-(A7)
	MOVEA.L	A5,A0
	MOVEA.L	A0,A1
	BSR.W	SUB_75A8
	ADDQ.W	#4,A7
	MOVEM.L	(A7)+,A2-A3/A5-A6
	ADDQ.W	#8,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7AE2  -  referenced from 8 call site(s)
; ------------------------------------------------------------------
SUB_7AE2:
	SUBA.W	#$0024,A7
	MOVEM.L	A2-A3/A5-A6,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	iconbase(A3),A2
	MOVE.L	A5,-(A7)
	PEA	STR_COLOUR(PC)
	PEA	$1A(A7)
	BSR.W	sprintf
	LEA	$C(A7),A7
	MOVE.L	$98(A3),D0
	BEQ.S	LAB_7B12
	MOVEA.L	D0,A1
	MOVEA.L	$36(A1),A0
	BRA.S	LAB_7B1C
LAB_7B12:
	MOVEA.L	$94(A3),A0
	MOVEA.L	A0,A1
	MOVEA.L	8(A1),A0
LAB_7B1C:
	LEA	$12(A7),A1
	MOVEA.L	A2,A6
	JSR	_LVOFindToolType(A6)	; FindToolType(toolarray,name) - look up an icon tooltype
	MOVE.L	D0,$30(A7)
	BEQ.W	LAB_7BCC
	MOVEA.L	D0,A0
	LEA	STR_WHITE(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7B40
	BRA.W	LAB_7BCE
LAB_7B40:
	MOVEA.L	$30(A7),A0
	LEA	LAB_11E8(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7B54
	MOVEQ	#1,D0
	BRA.S	LAB_7BCE
LAB_7B54:
	MOVEA.L	$30(A7),A0
	LEA	STR_GREEN(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7B68
	MOVEQ	#2,D0
	BRA.S	LAB_7BCE
LAB_7B68:
	MOVEA.L	$30(A7),A0
	LEA	STR_YELLOW(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7B7C
	MOVEQ	#3,D0
	BRA.S	LAB_7BCE
LAB_7B7C:
	MOVEA.L	$30(A7),A0
	LEA	STR_BLUE(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7B90
	MOVEQ	#4,D0
	BRA.S	LAB_7BCE
LAB_7B90:
	MOVEA.L	$30(A7),A0
	LEA	STR_VIOLET(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7BA4
	MOVEQ	#5,D0
	BRA.S	LAB_7BCE
LAB_7BA4:
	MOVEA.L	$30(A7),A0
	LEA	STR_CYAN(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7BB8
	MOVEQ	#6,D0
	BRA.S	LAB_7BCE
LAB_7BB8:
	MOVEA.L	$30(A7),A0
	LEA	STR_RANDOM(PC),A1
	BSR.W	SUB_7E58
	TST.L	D0
	BNE.S	LAB_7BCC
	MOVEQ	#7,D0
	BRA.S	LAB_7BCE
LAB_7BCC:
	MOVEQ	#0,D0
LAB_7BCE:
	MOVEM.L	(A7)+,A2-A3/A5-A6
	ADDA.W	#$0024,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7BD8  -  referenced from 2 call site(s)
; ------------------------------------------------------------------
SUB_7BD8:
	MOVEM.L	D2/D4-D7/A3/A5-A6,-(A7)
	MOVE.L	D1,D6
	MOVE.L	D0,D7
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEQ	#0,D4
LAB_7BE6:
	MOVE.L	A5,D1
	MOVE.L	D7,D2
	MOVEA.L	A3,A6
	JSR	_LVOLock(A6)	; Lock(name,mode) - lock a file or directory
	MOVE.L	D0,D5
	TST.L	D5
	BEQ.S	LAB_7BFA
	MOVE.L	D5,D0
	BRA.S	LAB_7C18
LAB_7BFA:
	JSR	_LVOIoErr(A6)	; IoErr() - return the DOS error code of the last failed call
	MOVEQ	#$32,D1
	NOT.B	D1
	CMP.L	D1,D0
	BNE.S	LAB_7C0A
	MOVEQ	#0,D0
	BRA.S	LAB_7C18
LAB_7C0A:
	MOVEQ	#$14,D1
	JSR	_LVODelay(A6)	; Delay(ticks) - pause the task for N ticks (1/50s)
	ADDQ.L	#1,D4
	CMP.L	D6,D4
	BLT.S	LAB_7BE6
	MOVEQ	#0,D0
LAB_7C18:
	MOVEM.L	(A7)+,D2/D4-D7/A3/A5-A6
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7C1E  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7C1E:
	SUBA.W	#$00c8,A7
	MOVEM.L	D2-D3/D5-D7/A2-A3/A5-A6,-(A7)
	MOVEA.L	$F0(A7),A2
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.L	dosbase(A2),$E8(A7)
	MOVEQ	#1,D5
	CLR.W	$E4(A7)
	MOVEA.L	A3,A0
	LEA	$36(A7),A1
LAB_7C40:
	MOVE.B	(A0)+,(A1)+
	BNE.S	LAB_7C40
	LEA	$36(A7),A0
	LEA	STR_AQUASCAN_CONFDATA(PC),A1
	BSR.W	LAB_812C
	LEA	$36(A7),A0
	MOVEA.L	dosbase(A2),A1
	MOVEQ	#-2,D0
	MOVEQ	#4,D1
	BSR.W	SUB_7BD8
	MOVE.L	D0,D7
	MOVE.L	D7,D0
	TST.L	D0
	BEQ.W	LAB_7D24
	MOVE.L	D7,D1
	MOVEA.L	$E8(A7),A6
	JSR	_LVOOpenFromLock(A6)	; OpenFromLock(lock) - open a file using an existing lock
	MOVE.L	D0,D6
	MOVE.L	D6,D0
	TST.L	D0
	BEQ.W	LAB_7D24
	MOVE.L	D6,D1
	LEA	$26(A7),A0
	MOVE.L	A0,D2
	MOVEQ	#$10,D3
	JSR	_LVORead(A6)	; Read(file,buf,len) - read from a file
	CMP.L	D3,D0
	BNE.S	LAB_7D0C
	LEA	$D4(A7),A0
	MOVEA.L	A5,A1
	BSR.W	SUB_7D3E
	MOVEA.L	D2,A0
	LEA	$D4(A7),A1
	BSR.W	SUB_7D80
	TST.W	D0
	BEQ.S	LAB_7D06
	MOVE.L	D6,D1
	MOVEQ	#0,D2
	MOVEQ	#1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVE.L	D6,D1
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVE.L	$150(A2),D1
	MOVE.L	D1,D2
	ASL.L	#2,D2
	MOVEQ	#$10,D3
	ADD.L	D3,D2
	MOVE.L	D0,$CC(A7)
	CMP.L	D2,D0
	BCS.S	LAB_7D0C
	SUBQ.L	#1,D1
	MOVE.L	D1,D0
	ASL.L	#2,D0
	ADD.L	D3,D0
	MOVE.L	D0,D2
	MOVE.L	D6,D1
	MOVEQ	#-1,D3
	JSR	_LVOSeek(A6)	; Seek(file,pos,mode) - seek within a file
	MOVE.L	D6,D1
	LEA	$D0(A7),A0
	MOVE.L	A0,D2
	MOVEQ	#4,D3
	JSR	_LVORead(A6)	; Read(file,buf,len) - read from a file
	SUBQ.L	#4,D0
	BNE.S	LAB_7D0C
	MOVEA.L	D2,A0
	MOVEA.L	A2,A1
	BSR.W	SUB_7DB8
	TST.W	D0
	BEQ.S	LAB_7D0C
	TST.B	$D3(A7)
	BEQ.S	LAB_7D0C
	MOVEQ	#0,D5
	BRA.S	LAB_7D0C
LAB_7D06:
	MOVE.W	#$0001,$E4(A7)
LAB_7D0C:
	MOVE.L	D6,D1
	JSR	_LVOClose(A6)	; Close(file) - close a file handle
	TST.W	$E4(A7)
	BEQ.S	LAB_7D32
	LEA	$36(A7),A0
	MOVE.L	A0,D1
	JSR	_LVODeleteFile(A6)	; DeleteFile(name) - delete a file
	BRA.S	LAB_7D32
LAB_7D24:
	TST.L	D7
	BEQ.S	LAB_7D32
	MOVE.L	D7,D1
	MOVEA.L	$E8(A7),A6
	JSR	_LVOUnLock(A6)	; UnLock(lock) - free a lock obtained from Lock()
LAB_7D32:
	MOVE.W	D5,D0
	MOVEM.L	(A7)+,D2-D3/D5-D7/A2-A3/A5-A6
	ADDA.W	#$00c8,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7D3E  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7D3E:
	MOVEM.L	D6-D7/A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEQ	#0,D6
	MOVEQ	#0,D7
LAB_7D4A:
	MOVEQ	#$F,D0
	CMP.L	D0,D7
	BGE.S	LAB_7D70
	TST.W	D6
	BEQ.S	LAB_7D5A
	CLR.B	0(A5,D7.L)
	BRA.S	LAB_7D6C
LAB_7D5A:
	MOVE.B	0(A3,D7.L),D0
	MOVE.B	D0,0(A5,D7.L)
	SEQ	D1
	NEG.B	D1
	EXT.W	D1
	EXT.L	D1
	MOVE.L	D1,D6
LAB_7D6C:
	ADDQ.L	#1,D7
	BRA.S	LAB_7D4A
LAB_7D70:
	MOVEA.L	A3,A0
	BSR.W	SUB_7582
	MOVE.B	D0,$F(A5)
	MOVEM.L	(A7)+,D6-D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7D80  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7D80:
	MOVEM.L	D7/A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVE.B	$F(A5),D0
	CMP.B	$F(A3),D0
	BEQ.S	LAB_7D96
	MOVEQ	#0,D0
	BRA.S	LAB_7DB2
LAB_7D96:
	MOVEQ	#0,D7
LAB_7D98:
	MOVEQ	#$F,D0
	CMP.L	D0,D7
	BGE.S	LAB_7DB0
	MOVE.B	0(A5,D7.L),D0
	CMP.B	0(A3,D7.L),D0
	BEQ.S	LAB_7DAC
	MOVEQ	#0,D0
	BRA.S	LAB_7DB2
LAB_7DAC:
	ADDQ.L	#1,D7
	BRA.S	LAB_7D98
LAB_7DB0:
	MOVEQ	#1,D0
LAB_7DB2:
	MOVEM.L	(A7)+,D7/A3/A5
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7DB8  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7DB8:
	MOVEM.L	A3/A5,-(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	MOVEA.L	A3,A0
	MOVEQ	#$64,D0
	BSR.W	sendDoorGetValueMsg      ;DT_NAME
	MOVEA.L	$2C(A3),A0
	TST.B	(A0)
	BNE.S	LAB_7DD6
	LEA	1(A0),A1
	CLR.B	(A1)
LAB_7DD6:
	MOVEA.L	$2C(A3),A0
	MOVE.B	(A5),D0
	CMP.B	(A0),D0
	BNE.S	LAB_7DFC
	LEA	1(A0),A1
	MOVE.B	1(A5),D0
	CMP.B	(A1),D0
	BNE.S	LAB_7DFC
	BSR.W	SUB_7582
	MOVE.B	2(A5),D1
	CMP.B	D0,D1
	BNE.S	LAB_7DFC
	MOVEQ	#1,D0
	BRA.S	LAB_7DFE
LAB_7DFC:
	MOVEQ	#0,D0
LAB_7DFE:
	MOVEM.L	(A7)+,A3/A5
	RTS
	JMP	LAB_800C
	JMP	LAB_8114
	JMP	SUB_803E
	JMP	LAB_80D8
	JMP	sprintf
	JMP	LAB_812C
; ------------------------------------------------------------------
; Subroutine SUB_7E28  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7E28:
	LEA	4(A7),A0
	MOVE.L	A0,D0
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7E30  -  referenced from 6 call site(s)
; ------------------------------------------------------------------
SUB_7E30:
	MOVEA.L	A0,A7
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_7E34  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7E34:
	MOVE.L	D0,D1
LAB_7E36:
	ADD.L	D0,D0
	BHI.S	LAB_7E40
	EORI.L	#$1d872b41,D0
LAB_7E40:
	CMP.L	D0,D1
	BNE.S	LAB_7E4C
	ADDQ.L	#1,D0
	JMP	LAB_7E36
LAB_7E4C:
	RTS
	DS.W	1
	MOVEA.L	4(A7),A0
	MOVEA.L	8(A7),A1
; ------------------------------------------------------------------
; Subroutine SUB_7E58  -  referenced from 44 call site(s)
; ------------------------------------------------------------------
SUB_7E58:
	MOVEQ	#0,D0
	MOVEQ	#0,D1
LAB_7E5C:
	MOVE.B	(A0)+,D0
	MOVE.B	(A1)+,D1
	CMPI.B	#$61,D0
	BLT.S	LAB_7E70
	CMPI.B	#$7a,D0
	BGT.S	LAB_7E70
	SUBI.B	#$20,D0
LAB_7E70:
	CMPI.B	#$61,D1
	BLT.S	LAB_7E80
	CMPI.B	#$7a,D1
	BGT.S	LAB_7E80
	SUBI.B	#$20,D1
LAB_7E80:
	SUB.L	D1,D0
	BNE.S	LAB_7E88
	TST.B	D1
	BNE.S	LAB_7E5C
LAB_7E88:
	RTS
	DS.W	1
	MOVE.L	8(A7),D0
	MOVEA.L	4(A7),A0
; ------------------------------------------------------------------
; Subroutine SUB_7E94  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7E94:
	LINK	A5,#-12
	MOVEA.L	A7,A1
LAB_7E9A:
	MOVEQ	#$A,D1
	JSR	SUB_803E(PC)
	ADDI.W	#$0030,D1
	MOVE.B	D1,(A1)+
	TST.L	D0
	BNE.S	LAB_7E9A
	MOVE.L	A1,D0
LAB_7EAC:
	MOVE.B	-(A1),(A0)+
	CMPA.L	A1,A7
	BNE.S	LAB_7EAC
	CLR.B	(A0)
	SUB.L	A7,D0
	UNLK	A5
	RTS
	DC.W	$0000
	MOVE.L	8(A7),D0
	MOVEA.L	4(A7),A0
; ------------------------------------------------------------------
; Subroutine SUB_7EC4  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7EC4:
	LINK	A5,#-12
	MOVEA.L	A7,A1
LAB_7ECA:
	MOVE.L	D0,D1
	ANDI.W	#$0007,D1
	ADDI.W	#$0030,D1
	MOVE.B	D1,(A1)+
	LSR.L	#3,D0
	BNE.S	LAB_7ECA
	MOVE.L	A1,D0
LAB_7EDC:
	MOVE.B	-(A1),(A0)+
	CMPA.L	A1,A7
	BNE.S	LAB_7EDC
	CLR.B	(A0)
	SUB.L	A7,D0
	UNLK	A5
	RTS
	DC.W	$0000
STR_0123456789ABCDEF:
	DC.B	"0123456789abcdef /",0
	DC.B	$08
	MOVEA.L	4(A7),A0
; ------------------------------------------------------------------
; Subroutine SUB_7F04  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7F04:
	SUBQ.W	#8,A7
	MOVEA.L	A7,A1
LAB_7F08:
	MOVE.W	D0,D1
	ANDI.W	#$000f,D1
	MOVE.B	STR_0123456789ABCDEF(PC,D1.W),(A1)+
	LSR.L	#4,D0
	BNE.S	LAB_7F08
	MOVE.L	A1,D0
LAB_7F18:
	MOVE.B	-(A1),(A0)+
	CMPA.L	A1,A7
	BNE.S	LAB_7F18
	CLR.B	(A0)
	SUB.L	A1,D0
	ADDQ.W	#8,A7
	RTS
	DC.W	$0000
	MOVEA.L	4(A7),A0
	MOVEA.L	8(A7),A1
; ------------------------------------------------------------------
; Subroutine SUB_7F30  -  referenced from 3 call site(s)
; ------------------------------------------------------------------
SUB_7F30:
	MOVEM.L	D2-D3/A2,-(A7)
	MOVEA.L	A0,A2
	MOVEQ	#0,D1
	MOVE.L	D1,D0
	MOVE.L	D1,D3
	CMPI.B	#$2b,(A0)
	BEQ.S	LAB_7F4A
	CMPI.B	#$2d,(A0)
	BNE.S	LAB_7F4C
	MOVEQ	#1,D3
LAB_7F4A:
	ADDQ.W	#1,A0
LAB_7F4C:
	MOVE.B	(A0)+,D0
	SUBI.B	#$30,D0
	BLT.S	LAB_7F6E
	CMPI.B	#$09,D0
	BGT.S	LAB_7F6E
	MOVE.L	D1,D2
	ASL.L	#2,D1
	ADD.L	D2,D1
	ADD.L	D1,D1
	TST.B	D3
	BNE.S	LAB_7F6A
	ADD.L	D0,D1
	BRA.S	LAB_7F4C
LAB_7F6A:
	SUB.L	D0,D1
	BRA.S	LAB_7F4C
LAB_7F6E:
	MOVE.L	D1,(A1)
	MOVE.L	A0,D0
	SUB.L	A2,D0
	SUBQ.L	#1,D0
	MOVEM.L	(A7)+,D2-D3/A2
	RTS
	MOVEA.L	4(A7),A0
	MOVEA.L	8(A7),A1
; ------------------------------------------------------------------
; Subroutine SUB_7F84  -  referenced from 23 call site(s)
; ------------------------------------------------------------------
SUB_7F84:
	MOVEM.L	D2-D3/A2,-(A7)
	MOVEA.L	A0,A2
	MOVEQ	#0,D1
	MOVE.L	D1,D0
	MOVE.L	D1,D3
	CMPI.B	#$2b,(A0)
	BEQ.S	LAB_7F9E
	CMPI.B	#$2d,(A0)
	BNE.S	LAB_7FA0
	MOVEQ	#1,D3
LAB_7F9E:
	ADDQ.W	#1,A0
LAB_7FA0:
	MOVE.B	(A0)+,D0
	SUBI.B	#$30,D0
	BLT.S	LAB_7FC2
	CMPI.B	#$09,D0
	BGT.S	LAB_7FC2
	MOVE.L	D1,D2
	ASL.L	#2,D1
	ADD.L	D2,D1
	ADD.L	D1,D1
	TST.B	D3
	BNE.S	LAB_7FBE
	ADD.L	D0,D1
	BRA.S	LAB_7FA0
LAB_7FBE:
	SUB.L	D0,D1
	BRA.S	LAB_7FA0
LAB_7FC2:
	MOVE.L	D1,(A1)
	MOVE.L	A0,D0
	SUB.L	A2,D0
	SUBQ.L	#1,D0
	MOVEM.L	(A7)+,D2-D3/A2
	RTS
	RTS
	NOP
	MOVEA.L	4(A7),A0
; ------------------------------------------------------------------
; Subroutine SUB_7FD8  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_7FD8:
	MOVE.L	A3,-(A7)
	MOVEA.L	A0,A1
	MOVEA.L	A1,A3
	BRA.S	LAB_8000
LAB_7FE0:
	LEA	$2D(A4),A0
	MOVEQ	#0,D0
	MOVE.B	(A3),D0
	BTST	#1,0(A0,D0.L)
	BEQ.S	LAB_7FFA
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVEQ	#$20,D0
	SUB.L	D0,D1
	BRA.S	LAB_7FFE
LAB_7FFA:
	MOVEQ	#0,D1
	MOVE.B	D0,D1
LAB_7FFE:
	MOVE.B	D1,(A3)+
LAB_8000:
	TST.B	(A3)
	BNE.S	LAB_7FE0
	MOVE.L	A1,D0
	MOVEA.L	(A7)+,A3
	RTS
	NOP
LAB_800C:
	TST.L	D0
	BPL.W	LAB_802E
	NEG.L	D0
	TST.L	D1
	BPL.W	LAB_8024
	NEG.L	D1
	BSR.W	SUB_803E
	NEG.L	D1
	RTS
LAB_8024:
	BSR.W	SUB_803E
	NEG.L	D0
	NEG.L	D1
	RTS
LAB_802E:
	TST.L	D1
	BPL.W	SUB_803E
	NEG.L	D1
	BSR.W	SUB_803E
	NEG.L	D0
	RTS
; ------------------------------------------------------------------
; Subroutine SUB_803E  -  referenced from 5 call site(s)
; ------------------------------------------------------------------
SUB_803E:
	MOVE.L	D2,-(A7)
	SWAP	D1
	MOVE.W	D1,D2
	BNE.W	LAB_8068
	SWAP	D0
	SWAP	D1
	SWAP	D2
	MOVE.W	D0,D2
	BEQ.W	LAB_8058
	DIVU	D1,D2
	MOVE.W	D2,D0
LAB_8058:
	SWAP	D0
	MOVE.W	D0,D2
	DIVU	D1,D2
	MOVE.W	D2,D0
	SWAP	D2
	MOVE.W	D2,D1
	MOVE.L	(A7)+,D2
	RTS
LAB_8068:
	MOVE.L	D3,-(A7)
	MOVEQ	#$10,D3
	CMPI.W	#$0080,D1
	BCC.W	LAB_8078
	ROL.L	#8,D1
	SUBQ.W	#8,D3
LAB_8078:
	CMPI.W	#$0800,D1
	BCC.W	LAB_8084
	ROL.L	#4,D1
	SUBQ.W	#4,D3
LAB_8084:
	CMPI.W	#$2000,D1
	BCC.W	LAB_8090
	ROL.L	#2,D1
	SUBQ.W	#2,D3
LAB_8090:
	TST.W	D1
	BMI.W	LAB_809A
	ROL.L	#1,D1
	SUBQ.W	#1,D3
LAB_809A:
	MOVE.W	D0,D2
	LSR.L	D3,D0
	SWAP	D2
	CLR.W	D2
	LSR.L	D3,D2
	SWAP	D3
	DIVU	D1,D0
	MOVE.W	D0,D3
	MOVE.W	D2,D0
	MOVE.W	D3,D2
	SWAP	D1
	MULU	D1,D2
	SUB.L	D2,D0
	BCC.W	LAB_80BC
	SUBQ.W	#1,D3
	ADD.L	D1,D0
LAB_80BC:
	MOVEQ	#0,D1
	MOVE.W	D3,D1
	SWAP	D3
	ROL.L	D3,D0
	SWAP	D0
	EXG	D0,D1
	MOVE.L	(A7)+,D3
	MOVE.L	(A7)+,D2
	RTS
	DS.W	1
	MOVEA.L	4(A7),A0
	MOVEA.L	8(A7),A1
LAB_80D8:
	MOVEM.L	A2-A3,-(A7)
	TST.B	(A0)
	BEQ.S	LAB_80FA
	BRA.S	LAB_80EC
LAB_80E2:
	TST.B	(A2)
	BEQ.S	LAB_80FA
	ADDQ.L	#1,A0
	TST.B	(A0)
	BEQ.S	LAB_80FA
LAB_80EC:
	MOVEA.L	A0,A2
	MOVEA.L	A1,A3
LAB_80F0:
	TST.B	(A3)
	BEQ.S	LAB_8102
	CMPM.B	(A2)+,(A3)+
	BNE.S	LAB_80E2
	BRA.S	LAB_80F0
LAB_80FA:
	MOVEQ	#0,D0
	MOVEM.L	(A7)+,A2-A3
	RTS
LAB_8102:
	MOVE.L	A0,D0
	MOVEM.L	(A7)+,A2-A3
	RTS
	DS.W	1
	MOVEA.L	4(A7),A0
	MOVE.L	8(A7),D0
LAB_8114:
	CMP.B	(A0),D0
	BEQ.S	LAB_8120
	TST.B	(A0)+
	BNE.S	LAB_8114
	MOVEQ	#0,D0
	RTS
LAB_8120:
	MOVE.L	A0,D0
	RTS
	MOVEA.L	8(A7),A1
	MOVEA.L	4(A7),A0
LAB_812C:
	MOVE.L	A0,D0
LAB_812E:
	TST.B	(A0)+
	BNE.S	LAB_812E
	SUBQ.L	#1,A0
LAB_8134:
	MOVE.B	(A1)+,(A0)+
	BNE.S	LAB_8134
	RTS
	DS.W	1
	MOVEA.L	8(A7),A1
	MOVEA.L	4(A7),A0
	MOVE.L	$C(A7),D0
; ------------------------------------------------------------------
; Subroutine SUB_8148  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_8148:
	MOVE.L	A0,D1
	TST.L	D0
	BLE.S	LAB_8164
	CMPA.L	A1,A0
	BCS.S	LAB_815E
	ADDA.L	D0,A1
	ADDA.L	D0,A0
LAB_8156:
	MOVE.B	-(A1),-(A0)
	SUBQ.L	#1,D0
	BNE.S	LAB_8156
	BRA.S	LAB_8164
LAB_815E:
	MOVE.B	(A1)+,(A0)+
	SUBQ.L	#1,D0
	BNE.S	LAB_815E
LAB_8164:
	MOVE.L	D1,D0
	RTS
	MOVE.L	4(A7),D0
	MOVEA.L	8(A7),A0
LAB_8170:
	LEA	(A0),A1
	ADDQ.L	#1,(A1)+
	MOVEA.L	(A1),A0
	ADDQ.L	#1,(A1)+
	MOVE.B	D0,(A0)
	RTS
sprintf:
	SUBQ.W	#8,A7
	MOVEA.L	$C(A7),A0
	CLR.L	(A7)
	MOVE.L	A0,4(A7)
	PEA	$14(A7)
	MOVE.L	$14(A7),-(A7)
	LEA	LAB_8170(PC),A0
	LEA	8(A7),A1
	BSR.W	SUB_863C
	MOVEA.L	$C(A7),A0
	ADDQ.W	#8,A7
	CLR.B	(A0)
	MOVE.L	(A7),D0
	ADDQ.W	#8,A7
	RTS
	NOP
	MOVEA.L	4(A7),A0
	MOVEA.L	8(A7),A1
	MOVE.L	$C(A7),4(A7)
	MOVE.L	$10(A7),8(A7)
; ------------------------------------------------------------------
; Subroutine SUB_81C0  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_81C0:
	SUBA.W	#$0048,A7
	MOVEM.L	D2/D4-D7/A2-A3/A5,-(A7)
	MOVEA.L	$70(A7),A5
	MOVE.L	A0,$28(A7)
	CLR.B	$5B(A7)
	CLR.B	$46(A7)
	CLR.B	$47(A7)
	CLR.B	$64(A7)
	MOVE.B	#$20,$5A(A7)
	CLR.L	$4C(A7)
	MOVEQ	#-1,D0
	MOVE.L	D0,$60(A7)
	CLR.B	$5C(A7)
	MOVEQ	#0,D7
	MOVEQ	#0,D6
	LEA	$32(A7),A2
	MOVEA.L	A1,A3
	BRA.S	LAB_826C
LAB_8200:
	MOVEA.L	$28(A7),A0
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	MOVEQ	#$20,D1
	SUB.L	D1,D0
	BLT.S	LAB_8274
	CMPI.L	#$00000011,D0
	BGE.S	LAB_8274
	ADD.W	D0,D0
	MOVE.W	LAB_8220(PC,D0.W),D0
	JMP	LAB_8220+2(PC,D0.W)
LAB_8220:
	DC.W	(LAB_8252)-(LAB_8220+2)	;8220: 0030
	DC.W	(LAB_8274)-(LAB_8220+2)	;8222: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;8224: 0052
	DC.W	(LAB_825A)-(LAB_8220+2)	;8226: 0038
	DC.W	(LAB_8274)-(LAB_8220+2)	;8228: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;822a: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;822c: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;822e: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;8230: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;8232: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;8234: 0052
	DC.W	(LAB_824A)-(LAB_8220+2)	;8236: 0028
	DC.W	(LAB_8274)-(LAB_8220+2)	;8238: 0052
	DC.W	(LAB_8242)-(LAB_8220+2)	;823a: 0020
	DC.W	(LAB_8274)-(LAB_8220+2)	;823c: 0052
	DC.W	(LAB_8274)-(LAB_8220+2)	;823e: 0052
	DC.W	(LAB_8262)-(LAB_8220+2)	;8240: 0040
LAB_8242:
	MOVE.B	#$01,$5B(A7)
	BRA.S	LAB_8268
LAB_824A:
	MOVE.B	#$01,$46(A7)
	BRA.S	LAB_8268
LAB_8252:
	MOVE.B	#$01,$47(A7)
	BRA.S	LAB_8268
LAB_825A:
	MOVE.B	#$01,$64(A7)
	BRA.S	LAB_8268
LAB_8262:
	MOVE.B	#$30,$5A(A7)
LAB_8268:
	ADDQ.L	#1,$28(A7)
LAB_826C:
	MOVEA.L	$28(A7),A0
	TST.B	(A0)
	BNE.S	LAB_8200
LAB_8274:
	MOVEQ	#1,D0
	CMP.B	$5B(A7),D0
	BNE.S	LAB_8282
	MOVE.B	#$20,$5A(A7)
LAB_8282:
	MOVEQ	#$2A,D1
	MOVEA.L	$28(A7),A0
	CMP.B	(A0),D1
	BNE.S	LAB_82A6
	MOVEA.L	(A3),A1
	ADDQ.L	#4,(A3)
	MOVE.L	(A1),D1
	MOVE.L	D1,$4C(A7)
	BGE.S	LAB_82A0
	NEG.L	$4C(A7)
	MOVE.B	D0,$5B(A7)
LAB_82A0:
	ADDQ.L	#1,$28(A7)
	BRA.S	LAB_82B2
LAB_82A6:
	LEA	$4C(A7),A1
	BSR.W	SUB_7F84
	ADD.L	D0,$28(A7)
LAB_82B2:
	MOVEA.L	$28(A7),A0
	MOVE.B	(A0),D0
	MOVEQ	#$2E,D1
	CMP.B	D1,D0
	BNE.S	LAB_8300
	ADDQ.L	#1,$28(A7)
	MOVEQ	#$2A,D0
	MOVEA.L	$28(A7),A0
	CMP.B	(A0),D0
	BNE.S	LAB_82E4
	MOVEA.L	(A3),A0
	ADDQ.L	#4,(A3)
	MOVE.L	(A0),D0
	MOVE.L	D0,$60(A7)
	BGE.S	LAB_82DE
	MOVEQ	#-1,D0
	MOVE.L	D0,$60(A7)
LAB_82DE:
	ADDQ.L	#1,$28(A7)
	BRA.S	LAB_82FA
LAB_82E4:
	LEA	$60(A7),A1
	BSR.W	SUB_7F84
	MOVE.L	D0,D5
	BNE.S	LAB_82F6
	CLR.L	$60(A7)
	BRA.S	LAB_82FA
LAB_82F6:
	ADD.L	D5,$28(A7)
LAB_82FA:
	MOVE.B	#$20,$5A(A7)
LAB_8300:
	MOVEA.L	$28(A7),A0
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	MOVEQ	#$4C,D1
	SUB.L	D1,D0
	BEQ.S	LAB_8322
	MOVEQ	#$1C,D1
	SUB.L	D1,D0
	BEQ.S	LAB_831A
	SUBQ.L	#4,D0
	BEQ.S	LAB_8322
	BRA.S	LAB_832C
LAB_831A:
	MOVE.B	#$02,$5C(A7)
	BRA.S	LAB_8328
LAB_8322:
	MOVE.B	#$01,$5C(A7)
LAB_8328:
	ADDQ.L	#1,$28(A7)
LAB_832C:
	MOVEA.L	$28(A7),A0
	ADDQ.L	#1,A0
	MOVEA.L	$28(A7),A1
	MOVE.B	(A1),D0
	MOVEQ	#0,D1
	MOVE.B	D0,D1
	MOVE.B	D0,$20(A7)
	MOVE.L	A0,$22(A7)
	MOVEQ	#$50,D0
	SUB.L	D0,D1
	BLT.W	LAB_8554
	CMPI.L	#$00000029,D1
	BGE.W	LAB_8554
	ADD.W	D1,D1
	MOVE.W	LAB_8360(PC,D1.W),D1
	JMP	LAB_8360+2(PC,D1.W)
LAB_8360:
	DC.W	(LAB_847A)-(LAB_8360+2)	;8360: 0118
	DC.W	(LAB_8554)-(LAB_8360+2)	;8362: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8364: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8366: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8368: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;836a: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;836c: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;836e: 01f2
	DC.W	(LAB_848C)-(LAB_8360+2)	;8370: 012a
	DC.W	(LAB_8554)-(LAB_8360+2)	;8372: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8374: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8376: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8378: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;837a: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;837c: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;837e: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8380: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8382: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8384: 01f2
	DC.W	(LAB_8542)-(LAB_8360+2)	;8386: 01e0
	DC.W	(LAB_83D4)-(LAB_8360+2)	;8388: 0072
	DC.W	(LAB_8554)-(LAB_8360+2)	;838a: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;838c: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;838e: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8390: 01f2
	DC.W	(LAB_83D4)-(LAB_8360+2)	;8392: 0072
	DC.W	(LAB_8554)-(LAB_8360+2)	;8394: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8396: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;8398: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;839a: 01f2
	DC.W	(LAB_83B2)-(LAB_8360+2)	;839c: 0050
	DC.W	(LAB_848C)-(LAB_8360+2)	;839e: 012a
	DC.W	(LAB_847A)-(LAB_8360+2)	;83a0: 0118
	DC.W	(LAB_8554)-(LAB_8360+2)	;83a2: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;83a4: 01f2
	DC.W	(LAB_850E)-(LAB_8360+2)	;83a6: 01ac
	DC.W	(LAB_8554)-(LAB_8360+2)	;83a8: 01f2
	DC.W	(LAB_848C)-(LAB_8360+2)	;83aa: 012a
	DC.W	(LAB_8554)-(LAB_8360+2)	;83ac: 01f2
	DC.W	(LAB_8554)-(LAB_8360+2)	;83ae: 01f2
	DC.W	(LAB_848C)-(LAB_8360+2)	;83b0: 012a
LAB_83B2:
	MOVEQ	#2,D0
	CMP.B	$5C(A7),D0
	BNE.S	LAB_83C8
	MOVEA.L	(A3),A0
	ADDQ.L	#4,(A3)
	MOVEA.L	(A0),A1
	MOVE.L	(A5),D0
	MOVE.W	D0,(A1)
	BRA.W	LAB_8604
LAB_83C8:
	MOVEA.L	(A3),A0
	ADDQ.L	#4,(A3)
	MOVEA.L	(A0),A1
	MOVE.L	(A5),(A1)
	BRA.W	LAB_8604
LAB_83D4:
	MOVEA.L	(A3),A0
	ADDQ.L	#4,(A3)
	MOVE.L	(A0),D4
	BPL.S	LAB_83E0
	MOVEQ	#1,D7
	NEG.L	D4
LAB_83E0:
	TST.L	D7
	BEQ.S	LAB_83F0
	LEA	$33(A7),A2
	MOVE.B	#$2d,$32(A7)
	BRA.S	LAB_8412
LAB_83F0:
	TST.B	$46(A7)
	BEQ.S	LAB_8402
	LEA	$33(A7),A2
	MOVE.B	#$2b,$32(A7)
	BRA.S	LAB_8412
LAB_8402:
	TST.B	$47(A7)
	BEQ.S	LAB_8414
	LEA	$33(A7),A2
	MOVE.B	#$20,$32(A7)
LAB_8412:
	MOVEQ	#1,D6
LAB_8414:
	MOVE.L	D4,D0
	MOVEA.L	A2,A0
	BSR.W	SUB_7E94
LAB_841C:
	MOVE.L	D0,D5
LAB_841E:
	MOVE.L	$60(A7),D0
	BNE.S	LAB_842A
	TST.L	D4
	BEQ.W	LAB_8604
LAB_842A:
	MOVE.L	$60(A7),D0
	BPL.S	LAB_8436
	MOVEQ	#1,D1
	MOVE.L	D1,$60(A7)
LAB_8436:
	MOVE.L	$60(A7),D4
	SUB.L	D5,D4
	BLE.S	LAB_845A
	MOVEA.L	A2,A0
	ADDA.L	D4,A0
	MOVE.L	D5,D0
	MOVEA.L	A2,A1
	BSR.W	SUB_8148
	MOVEQ	#$30,D1
	MOVEA.L	A2,A0
LAB_844E:
	CMPI.W	#$10c1,D0
	SUBQ.L	#1,D4
	BCC.S	LAB_844E+2
	MOVE.L	$60(A7),D5
LAB_845A:
	ADD.L	D5,D6
	SUBQ.L	#1,D5
	BNE.W	LAB_855A
	MOVE.B	(A2),D5
	CMP.B	$5A(A7),D5
	BNE.W	LAB_855A
	TST.L	$60(A7)
	BNE.W	LAB_855A
	CLR.B	(A2)
	BRA.W	LAB_855A
LAB_847A:
	MOVE.L	$60(A7),D0
	BPL.S	LAB_8486
	MOVEQ	#8,D0
	MOVE.L	D0,$60(A7)
LAB_8486:
	MOVE.B	#$01,$5C(A7)
LAB_848C:
	MOVEQ	#2,D0
	CMP.B	$5C(A7),D0
	BNE.S	LAB_84A0
	MOVEA.L	(A3),A0
	ADDQ.L	#4,(A3)
	MOVE.L	(A0),D0
	MOVEQ	#0,D4
	MOVE.W	D0,D4
	BRA.S	LAB_84A6
LAB_84A0:
	MOVEA.L	(A3),A0
	ADDQ.L	#4,(A3)
	MOVE.L	(A0),D4
LAB_84A6:
	MOVE.B	$20(A7),D0
	MOVEQ	#$75,D1
	CMP.B	D1,D0
	BEQ.W	LAB_8414
	MOVEQ	#$6F,D1
	CMP.B	D1,D0
	BNE.S	LAB_84D6
	TST.B	$64(A7)
	BEQ.S	LAB_84CA
	LEA	$33(A7),A2
	MOVE.B	#$30,$32(A7)
	MOVEQ	#1,D6
LAB_84CA:
	MOVE.L	D4,D0
	MOVEA.L	A2,A0
	BSR.W	SUB_7EC4
	BRA.W	LAB_841C
LAB_84D6:
	TST.B	$64(A7)
	BEQ.S	LAB_84EE
	MOVE.B	#$30,$32(A7)
	LEA	$34(A7),A2
	MOVE.B	#$78,$33(A7)
	MOVEQ	#2,D6
LAB_84EE:
	MOVE.L	D4,D0
	MOVEA.L	A2,A0
	BSR.W	SUB_7F04
	MOVE.L	D0,D5
	BTST	#5,$20(A7)
	BNE.W	LAB_841E
	LEA	$32(A7),A0
	BSR.W	SUB_7FD8
	BRA.W	LAB_841E
LAB_850E:
	MOVEA.L	(A3),A0
	ADDQ.L	#4,(A3)
	MOVEA.L	(A0),A3
	MOVE.L	A3,D0
	BNE.S	LAB_8522
	MOVEQ	#-1,D0
	LEA	NullPointerText(PC),A3
	MOVE.L	D0,$60(A7)
LAB_8522:
	MOVEA.L	A3,A0
LAB_8524:
	TST.B	(A0)+
	BNE.S	LAB_8524
	SUBQ.L	#1,A0
	SUBA.L	A3,A0
	MOVE.L	A0,D5
	MOVE.L	$60(A7),D0
	BMI.S	LAB_8538
	CMP.L	D5,D0
	BLE.S	LAB_853C
LAB_8538:
	MOVE.L	D5,$60(A7)
LAB_853C:
	MOVE.L	$60(A7),D6
	BRA.S	LAB_855E
LAB_8542:
	MOVEA.L	(A3),A0
	MOVEQ	#1,D6
	ADDQ.L	#4,(A3)
	MOVE.L	(A0),D0
	MOVE.B	D0,$32(A7)
	CLR.B	$33(A7)
	BRA.S	LAB_855A
LAB_8554:
	MOVEQ	#0,D0
	BRA.W	LAB_8608
LAB_855A:
	LEA	$32(A7),A3
LAB_855E:
	MOVE.L	$4C(A7),D0
	CMP.L	D6,D0
	BGE.S	LAB_856E
	MOVEQ	#0,D1
	MOVE.L	D1,$4C(A7)
	BRA.S	LAB_8572
LAB_856E:
	SUB.L	D6,$4C(A7)
LAB_8572:
	MOVEA.L	$6C(A7),A2
	TST.B	$5B(A7)
	BEQ.S	LAB_859A
	BRA.S	LAB_8586
LAB_857E:
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	MOVE.B	(A3)+,D0
	JSR	(A2)
LAB_8586:
	SUBQ.L	#1,D6
	BGE.S	LAB_857E
	BRA.S	LAB_8592
LAB_858C:
	MOVEA.L	A5,A0
	MOVEQ	#$20,D0
	JSR	(A2)
LAB_8592:
	SUBQ.L	#1,$4C(A7)
	BGE.S	LAB_858C
	BRA.S	LAB_8604
LAB_859A:
	TST.L	D7
	BNE.S	LAB_85AA
	TST.B	$47(A7)
	BNE.S	LAB_85AA
	TST.B	$46(A7)
	BEQ.S	LAB_85F0
LAB_85AA:
	MOVE.B	(A3),D0
	MOVEQ	#$20,D1
	CMP.B	D1,D0
	BEQ.S	LAB_85BE
	MOVEQ	#$2B,D2
	CMP.B	D2,D0
	BEQ.S	LAB_85BE
	MOVEQ	#$2D,D2
	CMP.B	D2,D0
	BNE.S	LAB_85F0
LAB_85BE:
	TST.L	D6
	BMI.S	LAB_85F0
	CMP.B	$5A(A7),D1
	BNE.S	LAB_85DA
	BRA.S	LAB_85D4
LAB_85CA:
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	MOVE.B	$5A(A7),D0
	JSR	(A2)
LAB_85D4:
	SUBQ.L	#1,$4C(A7)
	BGE.S	LAB_85CA
LAB_85DA:
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	MOVE.B	(A3)+,D0
	JSR	(A2)
	SUBQ.L	#1,D6
	BRA.S	LAB_85F0
LAB_85E6:
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	MOVE.B	$5A(A7),D0
	JSR	(A2)
LAB_85F0:
	SUBQ.L	#1,$4C(A7)
	BGE.S	LAB_85E6
	BRA.S	LAB_8600
LAB_85F8:
	MOVEA.L	A5,A0
	MOVEQ	#0,D0
	MOVE.B	(A3)+,D0
	JSR	(A2)
LAB_8600:
	SUBQ.L	#1,D6
	BGE.S	LAB_85F8
LAB_8604:
	MOVE.L	$22(A7),D0
LAB_8608:
	MOVEM.L	(A7)+,D2/D4-D7/A2-A3/A5
	ADDA.W	#$0048,A7
	RTS
NullPointerText:
	DC.B	"***NULL POINTER***",0
	DS.B	1
	NOP
	MOVEA.L	4(A7),A0
	MOVEA.L	8(A7),A1
	MOVE.L	$C(A7),4(A7)
	MOVE.L	$10(A7),8(A7)
; ------------------------------------------------------------------
; Subroutine SUB_863C  -  referenced from 1 call site(s)
; ------------------------------------------------------------------
SUB_863C:
	SUBQ.W	#4,A7
	MOVEM.L	D7/A3/A5,-(A7)
	MOVE.L	$18(A7),$C(A7)
	MOVEA.L	A1,A3
	MOVEA.L	A0,A5
	BRA.S	LAB_8682
LAB_864E:
	MOVEQ	#$25,D0
	CMP.B	D0,D7
	BNE.S	LAB_867A
	MOVEA.L	$14(A7),A0
	CMP.B	(A0),D0
	BNE.S	LAB_8662
	ADDQ.L	#1,$14(A7)
	BRA.S	LAB_867A
LAB_8662:
	MOVE.L	A3,-(A7)
	MOVE.L	A5,-(A7)
	LEA	$14(A7),A1
	BSR.W	SUB_81C0
	ADDQ.W	#8,A7
	TST.L	D0
	BEQ.S	LAB_867A
	MOVE.L	D0,$14(A7)
	BRA.S	LAB_8682
LAB_867A:
	MOVEA.L	A3,A0
	MOVEQ	#0,D0
	MOVE.B	D7,D0
	JSR	(A5)
LAB_8682:
	MOVEA.L	$14(A7),A0
	MOVE.B	(A0)+,D7
	MOVE.L	A0,$14(A7)
	TST.B	D7
	BNE.S	LAB_864E
	MOVEM.L	(A7)+,D7/A3/A5
	ADDQ.W	#4,A7
	RTS



; ======================================================================
; Uninitialised data section - runtime variables/buffers (zero-filled)
; ======================================================================
	SECTION S_1,DATA

SECSTRT_1:
	DC.B	"$VER: AquaScan 1.1 (25.08.26) - Aquarius/OTL & REbEL/QTX",0,0
	DC.B	"         (((((                  H"
	DC.L	$10101010,$10101010,$10101010,$10101084
	DC.L	$84848484,$84848484,$84101010,$10101010
	DC.L	$81818181,$81810101,$01010101,$01010101
	DC.L	$01010101,$01010101,$01011010,$10101010
	DC.L	$82828282,$82820202,$02020202,$02020202
	DC.L	$02020202,$02020202,$02021010,$10102000
	DC.B	0
	DS.B	1
	DS.L	$1F
	DS.W	1
	DC.B	0
	DS.B	1
	END