SET CTCM=C:\CTCM
C:\CTCM\CTCU /S /W=C:\WINDOWS
C:\WINDOWS\net start
viruscan\scan /adl /clean
LH /L:0;2,45456 /S C:\WINDOWS\SMARTDRV.EXE /X 1024 128 
@ECHO OFF
PROMPT $p$g
set mouse=C:\Mouse
LH /L:0;2,24336 /S C:\Mouse\mouse.exe /Q
PATH C:\WINDOWS;C:\DOS;C:\WP51\
SET TEMP=C:\DOS
rem navypass
rem cls
rem win
