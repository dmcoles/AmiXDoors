
                  - ConfTop II Updated Conference Top Uploaders-
                     
      This is a direct drop in replacement for Conftop 2.3 (c)1994 Mystic.

      It is completely rewritten from scratch to be fully y2k compliant and
      able to handle much larger weekly top uploads than the original.

      It has most of the same functionality and handles the same tooltypes as
      ConfTop 2.3 with the exception of the following options which are not
      implenmented at this time:

          PLAYPEN_<node>=<dir>
          EXCLUDE_<num>=<user/slot>
          SHARE_DATA=<confpath>
          
      The method of installation and configuration is the same as with ConfTop 2.3
      so the original documentation has been included with this release and the only
      changes that have been made are to include the new ctop executable and to update
      the config files to point to this instead of the old executable.

      The old convert and usereditor tool have been removed as they are not applicable
      to this version.

      It should be noted that this tool uses a different file format for tracking the
      users uploads in each conference so the old conftop 2.3 data will not automatically
      be transfered over. I have included a tool called ctopconv which is a CLI tool
      that can be used to transfer the data from the old datafile 'conftop.data' to the
      new 'ctop.data'
      
      the command template is:  confpath/a, top/s, last/s, current/s 
      
      So if you wish to convert each conference to the new format you should run this from
      cli for each conference and the 3 options TOP, LAST, CURRENT allow you to import the
      record TOP uploaders, LAST period top uploader record and CURRENT weekly uploader stats.
      
      Please contact me if you find any issues with this tool
      
      - REbEL /QTX -
      