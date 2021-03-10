->Discord announce door

MODULE 'AEDoor'                 /* Include libcalls & constants */

MODULE	'socket'
MODULE	'net/socket'
MODULE	'net/netdb'
MODULE	'net/in'
MODULE 'amissl'
MODULE 'amisslmaster'
MODULE 'dos/dos_lib'

/*
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/amissl.h>
#include <proto/amisslmaster.h>
#include <proto/socket.h>

#include <amissl/amissl.h>
#include <libraries/amisslmaster.h>
#include <libraries/amissl.h>
*/


CONST AMISSLMASTER_MIN_VERSION=4
CONST AMISSL_CURRENT_VERSION=6

CONST TAG_DONE=0

CONST SSL_VERIFY_PEER=1
CONST SSL_VERIFY_FAIL_IF_NO_PEER_CERT=2

CONST	BIO_NOCLOSE=$0
CONST	BIO_FP_TEXT=$10

CONST OPENSSL_LINE=0

CONST BIO_SET_FILE_PTR=$6a ->dont know what this is

CONST OPENSSL_INIT_LOAD_SSL_STRINGS=$200000
CONST OPENSSL_INIT_LOAD_CRYPTO_STRINGS=2

DEF amiSSL_SocketBase = $80000001
DEF amiSSL_ErrNoPtr = $8000000B

DEF errno

DEF aemode=FALSE,diface,strfield:LONG

PROC main()
  DEF bbsname[255]:STRING
  DEF username[255]:STRING
  DEF doorPort[20]:STRING
  DEF myargs:PTR TO LONG,rdargs
  DEF logOn=TRUE

  myargs:=[0,0,0]:LONG

  IF rdargs:=ReadArgs('BBSNAME/A,USERNAME/A,OFF/S',myargs,NIL)
    IF myargs[0]<>NIL 
      StrCopy(bbsname,myargs[0],255)
    ENDIF
    IF myargs[1]<>NIL 
      StrCopy(username,myargs[1],255)
    ENDIF
    IF myargs[2]<>NIL 
      logOn:=(myargs[2]=0)
    ENDIF

    FreeArgs(rdargs)
  ELSE
    IF (StrLen(arg)>0)
      StringF(doorPort,'\s\s','AEDoorPort',arg)
      IF FindPort(doorPort)
        IF aedoorbase:=OpenLibrary('AEDoor.library',1)
          diface:=CreateComm(arg[])     /* Establish Link   */
          IF diface<>0
            aemode:=TRUE
            strfield:=GetString(diface)  /* Get a pointer to the JHM_String field. Only need to do this once */
          ENDIF
        ENDIF
      ENDIF
    ENDIF
    IF aemode=FALSE THEN RETURN
  ENDIF
  

  IF aemode
    getAEStringValue(JH_BBSNAME,bbsname)
    getAEStringValue(DT_NAME,username)
  ENDIF

  IF (EstrLen(bbsname)>0) AND (EstrLen(username)>0) THEN postcomment(username,bbsname,logOn)

  IF diface<>0 THEN DeleteComm(diface)        /* Close Link w /X  */
  IF aedoorbase<>0 THEN CloseLibrary(aedoorbase)
ENDPROC

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

PROC postcomment(userName:PTR TO CHAR, bbsName:PTR TO CHAR,logOn)
  DEF senddata
  DEF linedata
  DEF serverHost[255]:STRING
  DEF webhook[200]:STRING

  StrCopy(serverHost,'discordapp.com')

  cleanstr(userName)
  cleanstr(bbsName)

  linedata:=String(1000) 
  StringF(linedata,'{"username": "/X Announce Bot","avatar_url": "", "content": "\s has just logged \s \s"}',userName,IF logOn THEN 'on to' ELSE 'off of',bbsName)

  senddata:=String(EstrLen(linedata)+500)

  ->test server  
  StrCopy(webhook,'/api/webhooks/693819073754300477/mlQqqtAbY3Htgd2f9qr9D47bvhrSl6cJ0xnz_AWtMRrG30DGPSb3jPQkk7mfKMNH31-Z')

  ->live server
  ->/api/webhooks/696016981039513620/GRpMVZkWyWU0tFWshK4Q0Jcnj4iqaw2RFGYP_J2lzh7NCZ_zggnLjCCcw-v8IUhVx1YC
  
  StringF(senddata,'POST \s?wait=true HTTP/1.0\b\nHost:\s\b\nContent-Type: application/json\b\nContent-Length: \d\b\n\b\n',webhook, serverHost,EstrLen(linedata))
  StrAdd(senddata,linedata)

  DisposeLink(linedata)
  httpsRequest(senddata)
  DisposeLink(senddata)
ENDPROC

PROC httpsRequest(request:PTR TO CHAR)

	DEF buffer[4096]:STRING; /* This should be dynamically allocated */
  DEF bufsize=4096
	DEF is_ok = FALSE
  DEF server_cert: LONG ->PTR TO X509
  DEF ctx: LONG ->PTR TO SSL_CTX
  DEF bio_err: LONG ->PTR TO BIO
  DEF ssl: LONG ->PTR TO SSL
  DEF sock=0,ssl_err=0,ciph=0,sn,meth
  DEF str[255]:STRING

  IF (init())
	
		/* Basic intialization. Next few steps (up to SSL_new()) need
		 * to be done only once per AmiSSL opener.
		 */
     
     OpENSSL_init_ssl(0,NIL) 		->SSLeay_add_ssl_algorithms();   -$67C8(a6)
     OpENSSL_init_ssl(OPENSSL_INIT_LOAD_SSL_STRINGS OR OPENSSL_INIT_LOAD_CRYPTO_STRINGS, NIL) ->SSL_load_error_strings();

		/* Note: BIO writing routines are prepared for NULL BIO handle */
		IF((bio_err:=BiO_new(BiO_s_file())) <> NIL) THEN BiO_ctrl(bio_err, BIO_SET_FILE_PTR, BIO_NOCLOSE OR BIO_FP_TEXT, Output()); ->BiO_set_fp_amiga(bio_err, Output(), BIO_NOCLOSE OR BIO_FP_TEXT);

		/* Get a new SSL context */
    meth:=TlS_client_method()
    ctx:=SsL_CTX_new(meth)
    IF(ctx <> NIL)
			/* Basic certificate handling. OpenSSL documentation has more
			 * information on this.
			 */
			SsL_CTX_set_default_verify_paths(ctx);
			SsL_CTX_set_verify(ctx, SSL_VERIFY_PEER OR SSL_VERIFY_FAIL_IF_NO_PEER_CERT,NIL);

			/* The following needs to be done once per socket */
			IF((ssl:=SsL_new(ctx)) <> NIL)
			

				/* Connect to the HTTPS server, directly or through a proxy */
					->sock:=connectToServer('162.159.134.233',443);
          sock:=connectToServer('discordapp.com',443);

				/* Check if connection was established */
				IF (sock >= 0)

					/* Associate the socket with the ssl structure */
					SsL_set_fd(ssl, sock)

					/* Perform SSL handshake */
					IF((ssl_err:=SsL_connect(ssl)) >= 0)
            ciph:=SsL_get_current_cipher(ssl)          

						/* Certificate checking. This example is *very* basic */
						IF((server_cert:=SsL_get_peer_certificate(ssl)))


              sn:=Xx509_get_subject_name(server_cert)
							IF((str:=Xx509_NAME_oneline(sn, 0, 0)))
								CrYPTO_free(str,'', OPENSSL_LINE); ->CrYPTO_free(str,OPENSSL_FILE, OPENSSL_LINE);
							ELSE
								WriteF('Warning: couldn''t read subject name in certificate!\n');
              ENDIF

							IF((str:=Xx509_NAME_oneline(Xx509_get_issuer_name(server_cert),0, 0)) <> NIL)
								CrYPTO_free(str,'', OPENSSL_LINE); ->CrYPTO_free(str,OPENSSL_FILE, OPENSSL_LINE);
							ELSE
								WriteF('Warning: couldn''t read issuer name in certificate!\n');
              ENDIF

							Xx509_free(server_cert);

							/* Send a HTTP request. Again, this is just
							 * a very basic example.
							 */
							IF ((ssl_err:=SsL_write(ssl, request, StrLen(request))) > 0)
								/* Dump everything to output */
								WHILE ((ssl_err:=SsL_read(ssl, buffer,bufsize - 1)) > 0)
									WriteF(buffer)
                ENDWHILE

								Flush(Output());

								/* This is not entirely true, check
								 * the SSL_read documentation
								 */
								is_ok:=(ssl_err = 0);
							ELSE
								WriteF('Couldn''t write request!\n');
              ENDIF
						ELSE
							WriteF('Couldn''t get server certificate!\n');
            ENDIF
					ELSE
						WriteF('Couldn''t establish SSL connection!\n');
          ENDIF

					/* If there were errors, print them */
					IF (ssl_err < 0) THEN ErR_print_errors(bio_err);

					/* Send SSL close notification and close the socket */
					SsL_shutdown(ssl);
					CloseSocket(sock);
				ELSE
					WriteF('Couldn''t connect to host!\n');
        ENDIF
        
				SsL_free(ssl);
			ELSE
				WriteF('Couldn''t create new SSL handle!\n');
      ENDIF

			SsL_CTX_free(ctx);
		ELSE
			WriteF('Couldn''t create new context!\n');
    ENDIF

		cleanup();
	ENDIF

	->return(is_ok ? RETURN_OK : RETURN_ERROR);
ENDPROC


PROC cleanstr(sourcestring)
  replacestr(sourcestring,'\\','\\\\')
  replacestr(sourcestring,'"','\\"')
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

/* Open and initialize AmiSSL */
PROC init()
	DEF is_ok = FALSE
  DEF tags:PTR TO LONG

  socketbase:=OpenLibrary('bsdsocket.library', 4)
	IF (socketbase=NIL)
		WriteF('Couldn''t open bsdsocket.library v4!\n')
    cleanup()
    RETURN FALSE
  ENDIF

  amisslmasterbase:=OpenLibrary('amisslmaster.library',AMISSLMASTER_MIN_VERSION)
	IF (amisslmasterbase=NIL)
		WriteF('Couldn''t open amisslmaster.library v\d!\n',AMISSLMASTER_MIN_VERSION);
    cleanup()
    RETURN FALSE
  ENDIF

	IF (InitAmiSSLMaster(AMISSL_CURRENT_VERSION, TRUE))=NIL
		WriteF('AmiSSL version is too old!\n');
    cleanup()
    RETURN FALSE
  ENDIF

  amisslbase:=OpenAmiSSL()
	IF (amisslbase=NIL)
    WriteF('Couldn''t open AmiSSL!\n');
    cleanup()
    RETURN FALSE
  ENDIF

  tags:=NEW [amiSSL_ErrNoPtr,{errno},amiSSL_SocketBase,socketbase,TAG_DONE]:LONG
  IF (InitAmiSSLA(tags) <> 0)
    END tags[5]
		WriteF('Couldn''t initialize AmiSSL!\n');
    cleanup()
    RETURN FALSE
  ENDIF
  END tags

	->ELSEIF (InitAmiSSLA(AmiSSL_ErrNoPtr, {errno}, amiSSL_SocketBase, socketbase, TAG_DONE) <> 0)
  ->		WriteF('Couldn''t initialize AmiSSL!\n');
  is_ok:=TRUE;

	IF(is_ok=FALSE) THEN cleanup(); /* This is safe to call even if something failed above */

ENDPROC is_ok

PROC cleanup()
	IF (amisslbase)
		CleanupAmiSSLA([TAG_DONE]);
		CloseAmiSSL();
		amisslbase:=NIL
	ENDIF

	CloseLibrary(amisslmasterbase);
	amisslmasterbase:=NIL;

	CloseLibrary(socketbase);
	socketbase:=NIL;
ENDPROC

/* Connect to the specified server, either directly or through the specified
 * proxy using HTTP CONNECT method.
 */

PROC connectToServer(host:PTR TO CHAR, port)
  DEF addr: PTR TO sockaddr_in
	DEF buffer[1024]:STRING; /* This should be dynamically alocated */
  DEF hostAddr: PTR TO LONG
  DEF hostEnt: PTR TO hostent

  DEF bsize=1024
	DEF is_ok = FALSE;
  DEF s1, s2
	DEF sock=NIL;
  DEF len

	/* Create a socket and connect to the server */
	IF ((sock:=Socket(AF_INET, SOCK_STREAM, 0)) >= 0)
		->memset(&addr, 0, sizeof(addr));
    NEW addr
		addr.sin_family:=AF_INET;

    hostEnt:=GetHostByName(host)
    hostAddr:=hostEnt.h_addr_list[]
    hostAddr:=hostAddr[]

    addr.sin_addr:=hostAddr[] /* This should be checked against INADDR_NONE */
    addr.sin_port:=port->htons(port);

		IF (Connect(sock, addr, SIZEOF sockaddr_in) >= 0)
			/* For proxy connection, use SSL tunneling. First issue a HTTP CONNECT
			 * request and then proceed as with direct HTTPS connection.
			 */
      is_ok:=TRUE
		ELSE
      WriteF('Couldn''t connect to server\n');
    ENDIF
    END addr
		IF (is_ok=FALSE)
			CloseSocket(sock);
			sock:=-1;
    ENDIF
	ENDIF

ENDPROC sock
