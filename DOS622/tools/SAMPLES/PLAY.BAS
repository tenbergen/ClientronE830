'This is a command line wave file player to be used with DOSSOUND.COM
'it is intended as short example how to use the functions of this
'driver
'
defint a-z

'color 15,1 'white on blue

'no file entered
if command$="" then
        shell "dir *.wav /w"
        print
	print "Please enter the wave file name after the program!"
        end
end if

'read file entered at the command line into buffer
dim buffer as asciiz * 512
buffer=command$+repeat$(511,chr$(0)) 'clear

'play the file entered on the command line with dossound.com
reg 1,&H0101 'ax
reg 8,varseg(buffer)
reg 4,varptr(buffer)
call interrupt &H64 'dossound

if (reg(0) and 1) > 0 then 'carry set?
	print
        if reg(1) = 1 then print "File not found"
        if reg(2) = 2 then print "File still playing"
        print
        end
else
	fp_flag=1 'file is playing now
end if

gosub readstatus

print "Enter: S = stop, P = pause, L = loop, "+chr$(24)+" = volume+, "+chr$(25)+" = volume- "

print "Bytes played: ";
xpos=pos(0) 'save current cursor position
ypos=csrlin

'loop to query the keyboard for commands entered
while 1
mykey$=inkey$
select case mykey$
	case chr$(27) 'esc
                reg 1,&H1000 'ax
                reg 2,&H0202 'bx 'reset volume if changed
                call interrupt &H64 'dossound
        	color 7,0 : cls : end
        case "l","L" 'loop
                loopflag = loopflag xor 1
                reg 1,&H2200 'ax
                reg 2,loopflag 'bx
                call interrupt &H64 'dossound
        case "p","P" 'play/pause
                pauseflag = pauseflag xor 1
                reg 1,&H2000 'ax
                reg 2,pauseflag 'bx
                call interrupt &H64 'dossound
        case "s","S" 'stop
                reg 1,&H2100 'ax
                call interrupt &H64 'dossound
                print : print "Terminated"
                end
        case chr$(0)+"P",chr$(0)+"H" 'change volume
                if mykey$=chr$(0)+"H" then 'cursor up
                   volume=volume-&H0101
                else
                   volume=volume+&H0101
                end if
                if volume<&H0101 then volume=&H0101
                if volume>&H1F1F then volume=&H1F1F
                reg 1,&H1000 'ax
                reg 2,volume 'bx
                call interrupt &H64 'dossound
end select

'read how many bytes played and print them to the screen
def seg = esseg
filecurrent???=peekl(dioff)
locate ypos,xpos
print using "###,###,###"; filecurrent???;

'has the entire file been played?
def seg = esseg
fp_flag = peek(dioff+8)
if fp_flag=0 then
   print :  print "File played"
   end
end if

wend 'end of keyboard loop *****

end

'*************************************************************************
readstatus:
'get file information from dossound
reg 1,&H0300 'ax
call interrupt &H64 'dossound

channels=reg(4) 'DX
shift right channels,8 'get DH
samplesize=reg(4) and &H00FF 'get DL
samplerate??=reg(5) 'SI
esseg=reg(9) 'ES
dioff=reg(6) 'DI
def seg = esseg
filecurrent???=peekl(dioff)
def seg = esseg
filesize???=peekl(dioff+4)
gosub fileinformation 'output the information got
return
'*************************************************************************
fileinformation:
'display audio file information
print "Playing file: "+left$(buffer,40)+"               "
print ltrim$(str$(samplerate??))+" khz"+str$(samplesize)+" bit ";
if channels=2 then
	print "Stereo  ";
else
	print "Mono  ";
end if
print "Filesize: ";
print using "###,###,###"; filesize???;
print "  "
return
'*************************************************************************
