                                    Global Last Callers Door

Installing:


GLCUpdater
----------

Add an entry in your logoff script for each active node to trigger the glcupdater that will send the information to the global last callers server.

GLCUpdater BBSNAME/A, CALLERSLOG/A, IGNORELOCAL/S, IGNORESYSOP/S, IGNORESYSOPUSER/S, PROCESSALL/S

BBSNAME - mandatory parameter with the name of your bbs as you want it to appear in the global callers log
CALLERSLOG - mandatory parameter specifying the path to the callers log for the node.
IGNORELOCAL - optional flag to tell the updater not to record information about local logons (eg logon using F2 in /X)
IGNORESYSOP - optional flag to tell the updater not to record information about local sysop logons (eg logon using F1 in /X)
IGNORESYSOPUSER - optional flag to tell the updater not to record information about all logons for user #1
PROCESSALL - optional flag which should not be used in a script but can be used (once only!) to back populate all old calls from your callers log

so a typical example might look something like this

GLCUpdater PHANTASM bbs:node1/callerslog IGNORELOCAL IGNORESYSOP


GLCViewer
---------

This part can be insalled as a standard /X Door (see glc.info in bbscmd). If it is run this way it will request the most up to date callers
log from the server and display its output to /X. This can take a small amount of time (around 1 second assuming the server is up but may be
longer if it is down for some reason).

If this delay causes frustration it is also possible to run the viewer from a script and the output will be displayed to the cli window so you
can redirect the output to a file which can be displayed to the user as part of a bulletin or from mci script. You could for example run the
viewer from the loggoff script or from a scheduled/cron task at a regular interval. The glcviewer requires no parameters when run in this way.

GLCViewer - filtering output
----------------------------

Optionally GLCViewer can also be run (only from script mode) with a parameter to indicate that you wish to filter the output to only include
one particular BBS. Running it like this:

   GLCViewer BBSNAME "mybbs"
   
Will produce an output only containing the entries for "mybbs" and the bbsname column will be remove and the user locations will be shown instead.
Older versions of the door did not populate the location - so these entries may be blank initially.

GLCViewer - Configuration file
------------------------------

Most of the configuration entries you will not need to touch but there are some options that will allow you to customise the output in the way
prefer.

LINES=20 - This will determine the number of lines to display in the output. This can be set to AUTO if running as a door and it will read the
users screen height setting.

SCREENCLEAR=NO - Should it send a screen clear ansi code before displaying the output

STYLE=4 - Choose between 4 styles (1-4) (two different headers and two different footers) (comma seperated list for random choice)

CENTRENAME=1 - Turn on the option to display the user names centred.

TimeZone Information

This version of global last callers handles timezones and is able to record and display the last callers list
as you would expect to see it in your time zone.

You need to copy over the updated GLCViewer and GLCUpdater and then go here and find your preferred time zone:

https://support.microsoft.com/en-gb/help/973627/microsoft-time-zone-index-values

Once you have this you need to add it to the GLCViewer.cfg something like this:

TIMEZONE=GMT Standard Time

This will make GLCUpdater tell the backend server what timezone you are in when recording the last calls and
it will also make GLCViewer apply your timezone when viewing the last callers list.
