'Sample for filling the DOSSound buffers externally by an application
'
'enter the file to play on the command line
'
defint a-z

filename$=command$ 'has to be a 16 bit stereo PCM wave file!
if filename$="" then input "Please enter file name: ",filename$

print : print "Playing file: " filename$

reg 1,&H0300 'ax 'read status
call interrupt &H64 'dossound
esseg=reg(9) 'ES
dioff=reg(6) 'DI

def seg = esseg
nrbuffer?=peekl(dioff+11)
oldnrbuffer?=nrbuffer?
print "First buffer number: " nrbuffer?

open filename$ for binary as #1

'read buffer pointers
reg 1,&H5000 'ax
call interrupt &H64 'dossound
audioseg1=reg(2)
audiosize=reg(3)
audioseg2=audioseg1+audiosize
audiosize=audiosize*16 'make bytes

print "Buffer1: " hex$(audioseg1) " Buffer2: " hex$(audioseg2) " Buffersize: " hex$(audiosize)
get$ #1,44,buffer$ 'start after header
samplerate=cvi(mid$(buffer$,25,2))

if cvi(mid$(buffer$,23,2)) <> 2 then print "Error - file does not use two channels" : end
if cvi(mid$(buffer$,35,2)) <> 16 then print "Error - file does not use 16 bit samples" : end

print "Next buffer numbers: ";
get$ #1,audiosize,buffer$

def seg = audioseg1
poke$ 0,left$(buffer$,audiosize)
def seg

get$ #1,audiosize,buffer$
def seg = audioseg2
poke$ 0,left$(buffer$,audiosize)
def seg

'start playing
reg 1,&H5100 'ax
reg 2,samplerate  'bx
call interrupt &H64 'dossound

get$ #1,audiosize,buffer$ 'preload

while not eof(1)
def seg = esseg
nrbuffer?=peekl(dioff+11)
def seg

if nrbuffer?<>oldnrbuffer? then
	print trim$(str$(nrbuffer?));
        oldnrbuffer?=nrbuffer?
        if nrbuffer?=1 then 'fill opposite buffer
		def seg = audioseg1
        else
 	       def seg = audioseg2
        end if
	poke$ 0,left$(buffer$,audiosize)
	def seg
	get$ #1,audiosize,buffer$ 'preload
end if
wend

delay 1

'stop playing
reg 1,&H2100 'ax
call interrupt &H64 'dossound

end