'Real Mode DOS wave file player by Georg Potthast 2009
'to be used with the DOSSound driver
'
defint a-z

'check if dossound is installed
def seg = 0
farseg=peeki(&H64*4+2)
faroff=peeki(&H64*4)
def seg = farseg
if peek$(faroff+2,8) <> "DOSSOUND" then	print "DOSSOUND not installed" : end

'color definitions
fcolor=0 'black
bcolor=15 'bright white
objcolor=1 'blue
keycolor=4 'red
progresscolor=4 'red
invertcolor=10 '14 'yellow

dim filearray$(22)
dim buffer as asciiz * 512
buffer=repeat$(511,chr$(0)) 'clear

selectbar=1 'default

'read vendor/device/installed-flag
reg 1,&H4000 'ax
call interrupt &H64 'dossound
ds_flag=reg(1) 'is dossound installed? - &H4453h = yes
if reg(2)<5 then sb_flag=1

'read current volume
reg 1,&H1001 'ax
call interrupt &H64 'dossound
volume=reg(2)

if sbflag=0 then
'check for bass/treble support
reg 1,&H3000 'ax
reg 4,&H0    'DX - reset register
call interrupt &H64 'dossound
if (reg(1) AND &H0004) > 0 then 'is bit 2 set for optional bass/treble support?
        bt_support=1
        'read current treblebass value - default &H0F0F
        reg 1,&H3000 'ax
        reg 4,8      'dx
        call interrupt &H64 'dossound
        treblebass=reg(1)
end if
end if 'sbflag

filelistlength=18
if bt_support=1 then filelistlength=14

gosub showscreen

gosub showwavefiles

while 1
mykey$=inkey$
select case mykey$
	case chr$(27) 'esc
                reg 1,&H1000 'ax
                reg 2,&H0202 'bx 'reset if changed by balance
                call interrupt &H64 'dossound
        	color 7,0 : cls : end
        case chr$(0)+"P" 'cursor down
        	incr selectbar
                'if selectbar>maxfiles then selectbar=maxfiles
                gosub showwavefiles
        case chr$(0)+"H" 'cursor up
        	decr selectbar
                'if selectbar=0 then selectbar=1
                gosub showwavefiles
	case chr$(13)
                  buffer=filearray$(selectbar)
                  if instr(buffer,".WAV") then
                        if ds_flag = &H4453 then
                           gosub loadthefile
	                else
        	          locate 19,3 : print "DOSSound not installed";
	                end if
                  else
                        chdir rtrim$(buffer)
                        selectbar=1
                        shiftdown=0
                        gosub showwavefiles
                  end if
        case "l","L" 'loop
        	loopflag = loopflag xor 1
                reg 1,&H2200 'ax
                reg 2,loopflag 'bx
                call interrupt &H64 'dossound
                gosub showbuttons
        case "p","P" 'play/pause
                pauseflag = pauseflag xor 1
                reg 1,&H2000 'ax
                reg 2,pauseflag 'bx
                call interrupt &H64 'dossound
                if (reg(0) and 1) > 0 then 'carry set?
	                pauseflag = pauseflag xor 1 'set pauseflag to old setting
                end if
                gosub showbuttons
        case "m","M" 'mute
                muteflag = muteflag xor 1
                reg 1,&H1000 'ax
                if muteflag=1 then
                	reg 2,&H3F3F 'bx
                else
			reg 2,volume 'bx
                end if
                call interrupt &H64 'dossound
                gosub showbuttons
        case "s","S" 'stop
                reg 1,&H2100 'ax
                call interrupt &H64 'dossound
                fileplaying=0

                pauseflag=0
                reg 1,&H2000 'ax
                reg 2,pauseflag 'bx
                call interrupt &H64 'dossound

                muteflag=0
                reg 1,&H1000 'ax
		reg 2,volume 'bx
                call interrupt &H64 'dossound

                loopflag=0
                reg 1,&H2200 'ax
                reg 2,loopflag 'bx
                call interrupt &H64 'dossound

                gosub showbuttons

        case "v","V" 'change volume
                if mykey$="V" then
                   volume=volume-&H0101
                else
                   volume=volume+&H0101
                end if
                if volume<&H0101 then volume=&H0101
                if volume>&H1F1F then volume=&H1F1F
                volumesave=volume
                volume=volume+balance 'balance=0 for default
                leftvol=volume AND &HFF00
                rightvol=volume AND &H00FF
                if leftvol>&H1F00 then leftvol=&H1F00
                if rightvol>&H1F then rightvol=&H1F
                volume=leftvol+rightvol

                reg 1,&H1000 'ax
                reg 2,volume 'bx
                call interrupt &H64 'dossound
                volume=volumesave

		objx=rulersetx+2
		objy=rulersettop
		objwidth=20
		rulerpos=volume/&H1F1F*100 '50 'in percent
		gosub drawruler

        case "b","B" 'change balance

        if mykey$="b" then
        	if (balance AND &HFF00) > 0 then
                   balance=balance-&H0100
                else
	           balance=balance+&H0001
                   if (balance AND &H00FF) > &H1E then balance=balance-1
               end if
        else
        	if (balance AND &H00FF) > 0 then
                   balance=balance-&H0001
                else
                   balance=balance+&H0100
                   if (balance AND &HFF00) > &H1E00 then balance=balance-&H0100
                end if
        end if

                volumesave=volume
                rotate right balance,8 'the values of balance dampen, so inverted
                volume=volume+balance 'balance=0 for default
                rotate left balance,8
                leftvol=volume AND &HFF00
                rightvol=volume AND &H00FF
                if leftvol>&H1F00 then leftvol=&H1F00
                if rightvol>&H1F then rightvol=&H1F
                volume=leftvol+rightvol
                reg 1,&H1000 'ax
                reg 2,volume 'bx
                call interrupt &H64 'dossound
                volume=volumesave
		objx=rulersetx+2
		objy=rulersettop+2
		objwidth=20
                leftbal=balance AND &HFF00
                rightbal=balance AND &H00FF
                if balance=&H0101 or balance=0 or balance=&H01 or balance=&H100 then
                	rulerpos=50
                elseif leftbal<&H0100 then
                	rulerpos=rightbal/&H1F*50+50
                else
                	shift right leftbal,8
                        rulerpos=50-leftbal/&H1F*50
                end if
		gosub drawruler

        case "t","T" 'change treble
            if bt_support=1 then
                if mykey$="T" then
                   if (treblebass AND &H00FF) > 0 then treblebass=treblebass-&H01
                else
                   if (treblebass AND &H00FF) < &H1F then treblebass=treblebass+&H01
                end if
                reg 1,&H3100 'ax
                reg 4,8      'dx
                reg 3,treblebass 'cx
                call interrupt &H64 'dossound

		objx=rulersetx+2
		objy=rulersettop+4
		objwidth=20
		rulerpos=(treblebass AND &H00FF)/&H1F*100 '50 'in percent
		gosub drawruler
             end if 'bt_support
        case "d","D" 'change bass
             if bt_support=1 then
                if mykey$="D" then
                   if (treblebass AND &HFF00) > 0 then treblebass=treblebass-&H0100
                else
                   if (treblebass AND &HFF00) < &H1F00 then treblebass=treblebass+&H0100
                end if
                reg 1,&H3100 'ax
                reg 4,8      'dx
                reg 3,treblebass   'cx
                call interrupt &H64 'dossound

		objx=rulersetx+2
		objy=rulersettop+6
		objwidth=20
		rulerpos=(treblebass AND &HFF00)/&H1F00*100 '50 'in percent
		gosub drawruler
             end if 'bt_support
        case else
               'nothing to be done
end select

if fileplaying=1 then
	objx=2
	objy=20
	objwidth=47
        gosub progressbar 'update plus read filecurrent???

        locate 19,4
        print "Bytes played:";
        print using "###,###,###"; filecurrent???;
        locate 19,30
        currtime???=timer-starttime???
        print "Min:Secs played:";
        print using "##"; currtime???\60;
        print ":";
        print using "##"; currtime??? MOD 60;

        'check pause flag setting
	def seg = esseg
	if pauseflag <> peek(dioff+9) then
           pauseflag = peek(dioff+9)
           gosub showbuttons 'show correct status
        end if
        'check loop flag setting
	def seg = esseg
	if loopflag <> peek(dioff+10) then
           loopflag = peek(dioff+10)
           gosub showbuttons 'show correct status
        end if

'    if (filecurrent??? >= filesize???) and (loopflag=0) then

	def seg = esseg
	if fileplaying <> peek(dioff+8) then
		if loopflag=0 then
                	fileplaying=0
	        	gosub showbuttons
                end if
	end if
end if

wend

end
'*************************************************************************
loadthefile:
                reg 1,&H0101 'ax
                reg 8,varseg(buffer)
                reg 4,varptr(buffer)
                call interrupt &H64 'dossound
                if (reg(0) and 1) > 0 then 'carry set?
                    if reg(1) = 1 then
                        locate 16,4
                        buffer="File not found"
                        print "Playing file: "+left$(buffer,40)+"               ";
                        goto endelse
                    elseif reg(1) = 2 then
                        goto endelse
                    end if
                end if 'carry set?
                gosub readstatus
                fileplaying=1
                starttime???=timer
                gosub fileinformation
                gosub showbuttons
endelse:
		objx=2
		objy=20
		locate objy+1,objx+1
                color bcolor
		print string$(47," "); ;'clear old bar

return
'*************************************************************************
readstatus:
reg 1,&H0300 'ax
call interrupt &H64 'dossound

channels=reg(4)
shift right channels,8 'get dh
samplesize=reg(4) and &H00FF 'get dl
samplerate??=reg(5) 'si
esseg=reg(9)
dioff=reg(6)
def seg = esseg
filecurrent???=peekl(dioff)
def seg = esseg
filesize???=peekl(dioff+4)
'dossound extends these file formats - get proper eof
'- no more
'if channels=1 then filesize???=filesize???*2
'if samplesize=8 then filesize???=filesize???*2
ttt=0
return

'*************************************************************************
showwavefiles:
'loads and displays wave files and directories in current directory
i=0
redim filearray$(22)
if selectbar > filelistlength then
	shiftdown=shiftdown+1 'shiftdown is the factor the files are scrolled down
        selectbar=filelistlength
elseif selectbar = 0 then
	decr shiftdown
        if shiftdown < 0 then shiftdown = 0
        selectbar = 1
end if
array insert filearray$(1) 'shift all elements up one
filearray$(1)=dir$("*.wav",0)
if filearray$(1) <> "" then
  for i=2 to 1+filelistlength+shiftdown
    array insert filearray$(1) 'shift all elements up one
    filearray$(1)=dir$
    if filearray$(1)="" then exit for
  next i
end if

'directories
'filearray$(1)=".." 'do below at top of list
incr i              'incr for ".."
filearray$(1)=dir$("*.",16)
incr i
for i = i to 1+filelistlength+shiftdown
array insert filearray$(1) 'shift all elements up one
filearray$(1)=dir$
if filearray$(1)="" then exit for
next i
maxfiles=i-1

'invert array
if maxfiles<1+filelistlength then
	array sort filearray$(1) for 1+filelistlength
        for i=1 to 1+filelistlength
	        if filearray$(1)="" then array delete filearray$(1)
        next i
	array insert filearray$(0) 'shift all elements up one
else
  for i=1 to 1+filelistlength
        	filearray$(i-1)=filearray$(1+filelistlength)
        	array insert filearray$(i)
  next i
  array insert filearray$(0)
end if
filearray$(1)=".." 'add to top of list now

'display the entries in the filearray$()
for i=1 to filelistlength
locate 1+i,54
if selectbar=i then color bcolor,objcolor
if (instr(filearray$(i),".WAV")=0) and (filearray$(i)<>"") then
  	print " " filearray$(i) "\" string$(23-len(filearray$(i))," ");
else
	print " " filearray$(i) string$(24-len(filearray$(i))," ");
end if
color objcolor,bcolor
next i
return
'************************************************************************
showscreen:
color fcolor,bcolor
cls

gosub showtitle

'draw rulerset - volume, balance, (and optional) treble, bass ***********
'rulerx defines left border
rulersetx=54 '8
objwidth=20 'same for all

rulersettop=21
if bt_support=1 then rulersettop=17

if sb_flag=0 then
locate rulersettop,rulersetx
color keycolor
print "V";
objx=rulersetx+2
objy=rulersettop
objcolor=1
'rulerpos=50 'in percent
rulerpos=volume/&H3F3F*100 '50 'in percent
gosub drawruler
color keycolor
locate rulersettop,rulersetx+objwidth+4
print "v";
locate rulersettop+1,rulersetx-3+objwidth/2
color fcolor
print "+ Volume -";

locate rulersettop+2,rulersetx
color keycolor
print "B";
objx=rulersetx+2
objy=rulersettop+2
objcolor=1
rulerpos=50 'in percent
gosub drawruler
color keycolor
locate rulersettop+2,rulersetx+objwidth+4
print "b";
locate rulersettop+3,rulersetx-3+objwidth/2
color fcolor
print chr$(17)+" Balance "+chr$(16);

end if 'sb_flag

if bt_support=1 then

locate rulersettop+4,rulersetx
color keycolor
print "T";
objx=rulersetx+2
objy=rulersettop+4
objcolor=1
rulerpos=50 'in percent
gosub drawruler
color keycolor
locate rulersettop+4,rulersetx+objwidth+4
print "t";
locate rulersettop+5,rulersetx-3+objwidth/2
color fcolor
print "+ Treble -";

locate rulersettop+6,rulersetx
color keycolor
print "D";
objx=rulersetx+2
objy=rulersettop+6
objcolor=1
rulerpos=50 'in percent
gosub drawruler
color keycolor
locate rulersettop+6,rulersetx+objwidth+4
print "d";
locate rulersettop+7,rulersetx-2+objwidth/2
color fcolor
print "+ Bass -";

end if 'bt_support

gosub showbuttons

'filebox ***********
objx=53
objy=1
objwidth=26
objheight=24
objcolor=1
gosub drawbox

objy=20
if bt_support=1 then objy=16
gosub drawseparationline

return
'*************************************************************************
showbuttons:
'go,pause,stop,loop,mute buttons ***********
for j=0 to 4
objx=2+j*10
objy=23
objwidth=8
objheight=2
objcolor=1
gosub drawbox
next j

keycolor=4
objx=4
objy=24
if fileplaying=1 then color ,invertcolor
buttontext$="Play "+chr$(16)
gosub buttontextl
color ,bcolor

objx=14
objy=24
if pauseflag=1 then color ,invertcolor
buttontext$="Pause"
gosub buttontextl
color ,bcolor

objx=24
objy=24
buttontext$="Stop"
gosub buttontextl
color ,bcolor

objx=34
objy=24
if loopflag=1 then color ,invertcolor
buttontext$="Loop"
gosub buttontextl
color ,bcolor

objx=44
objy=24
if muteflag=1 then color ,invertcolor
buttontext$="Mute"
gosub buttontextl
color ,bcolor
return

'*************************************************************************
fileinformation:
'file information
color fcolor,bcolor
locate 16,4
print "Playing file: "+left$(buffer,40)+"               ";
locate 18,3
print str$(samplerate??)+" khz "+str$(samplesize)+" bit ";
locate ,22
if channels=2 then
	print "Stereo  ";
else
	print "Mono  ";
end if
locate ,29
print " Filesize: ";
print using "###,###,###"; filesize???;
print "  ";
return
'*************************************************************************
buttontextl:
locate objy,objx
color keycolor
print left$(buttontext$,1);
color fcolor
print mid$(buttontext$,2);
return
'*************************************************************************
progressbar:
'objx, objy, objwidth, rulerpos, objcolor
objheight=2
objwidth=objwidth+1
gosub drawbox

if fileplaying=1 then
	def seg = esseg
	filecurrent???=peekl(dioff)
	if filecurrent???>0 then
        	rulerpos=filecurrent???/filesize???*100 'in percent
                if oldrulerpos+5<rulerpos then 'looped? +5 to avoid flicker
                   color bcolor
                   locate objy+1,objx+1
		   print string$(47," "); ;'clear old bar
                   color objcolor
                end if
                oldrulerpos=rulerpos
		objwidth=objwidth-1
		locate objy+1,objx+1
		color progresscolor
		print string$(objwidth*rulerpos/100,219);
                if (objwidth*rulerpos/100+1)<objwidth then 'print note not at end
			locate objy+1,objx+1+objwidth*rulerpos/100
			color 15,progresscolor
			print chr$(13); 'chr$(219);
                end if
        end if 'filecurrent???
end if 'fileplaying
color fcolor,bcolor
return
'*************************************************************************
drawruler:
'objx, objy, objwidth, rulerpos, objcolor
color objcolor
locate objy,objx
print chr$(17)+string$(objwidth-1,196)+chr$(16);
locate objy,objx+objwidth*rulerpos/100
print chr$(254);
return
'*************************************************************************
drawbox:
'objx, objy, objwidth, objheight, objcolor
color objcolor
locate objy,objx
'upper border
print chr$(218)+string$(objwidth-1,196)+chr$(191);
for i=1 to objheight-1
locate objy+i,objx
print chr$(179);
locate objy+i,objx+objwidth
print chr$(179);
next i
'lower border
locate objy+objheight,objx
print chr$(192)+string$(objwidth-1,196)+chr$(217);
return

'*************************************************************************
drawseparationline:
locate objy,objx
print chr$(195)+string$(objwidth-1,196)+chr$(180);
return
'*************************************************************************
showtitle:

objy=7
objx=10
objwidth=28
objheight=6
gosub drawbox

objy=12
columnheight=3
for objx=12 to 37 step 2
if objx>30 then
	decr columnheight
elseif objx>25 then
	incr columnheight
elseif objx>20 then
	decr columnheight
elseif objx>18 then
	incr columnheight
elseif objx<13 then
	incr columnheight
else
decr columnheight
end if
gosub drawcolumn
next objx

color fcolor
locate 7,18
print chr$(175)+" D O S A M P "+chr$(174);

return
'*************************************************************************
drawcolumn:
'for title image
locate objy,objx
color invertcolor
for i=1 to columnheight+1
print chr$(219);
locate objy-i,objx
if i>columnheight-3 then color 14
if i=columnheight then color 4
next i
return
'*************************************************************************