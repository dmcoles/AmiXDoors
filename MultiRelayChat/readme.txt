                         - - - Multi Relay Chat - - -

This is a conversion of the original MRC by StackFault of Phenom Productions.

It is a cross platform chat client where bbs users can meet and chat.

It requires Ami-Express 5.4.0 or higher.

INSTALLATION GUIDE

Step 1: Setup the BBS multiplexer client
  This process is responsible to communicate with the server
  and maintain that connection open

  * Copy the mrc_client folder (containing mrc_client and mrc_client.cfg) to
    your hard drive in a suitable place.
    
  * Edit your bbs information in the mrc_client.cfg
  
  * Setup mrc_client to run automatically (from user-startup or however you prefer).
  
  * The following command must be used to start mrc_client:

         mrc_client mrc.bottomlessabyss.net 5000

  
  * If everything goes well, you should have the client connected to
    the server and ready to process chat clients requests
  
  * You will be informed at start if you are not running the latest
    version of the client.

  * The server will now disconnect clients that are 2 version or more
    behind the latest, to ensure all users are experiencing the best
    possible experience.

Step 2: Setup the mrc_door in /X
  This is the interface the user sees when in the chatrooms

  * Copy the contents of the doors/mrc folder to bbs:doors/mrc area

  * Copy the contents of the bbscmd folder to bbs:commands/bbscmd area

MRC can now be started from /X using MRC at the menu prompt.

MRCSTAT1 and MRCSTAT2 produce two different styles of status screen that
can be added to your logon script or bulletins.


******************************************************************************

This door requires aedoor.library which can be downloaded from the aminet:

   http://aminet.net/package/dev/misc/aedoor28
   
******************************************************************************

Release History

19-May-2021 - Initial release version

Written by Darren Coles (c) 2021
