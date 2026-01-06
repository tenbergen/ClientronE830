
; FASM (R) code | 754 Bytes
; FASM DOSSOUND example (R)
; (CL) 2009-04-27 by DOS386 | Abuse at your own risk !!!

; System requirements:
; - AC97 compatible sound card/chip
; - At least 80386 CPU - I doubt you can ever find an 80286 with AC97 ;-)
; - "DOSSOUND" driver by Georg Potthast from 2009-04-28 or newer
; - FreeDOS 1.1, EDR-DOS 7.01.08, RxDOS 7.30 or compatible
; - At least ONE valid, mono or stereo, 8bps or 16bps WAV file

; WARNING: This toy does one arguably exotic task very well !!!!!!!!!!!!!!!!

; http://board.flatassembler.net/topic.php?t=????

; ----------------------------------------------------------------------

define pope  pop
define popef popf

macro movntq mdst, msrc {
  if mdst eq cs
    err "CS is not a valid destination"
  end if
  if mdst in <ds,es,ss> & msrc in <cs,ds,es,ss>
    push  msrc
    pope  mdst
  else
    if mdst in <ax,bx,cx,dx,si,di,bp> & msrc eq 0
      xor  mdst, mdst
    else
      mov  mdst, msrc
    end if
  end if
} ; endmacro

macro cmpntq minp, mref {
  if minp in <bl,cl,dl,ah,bh,ch,dh,ax,bx,cx,dx,si,di,bp,ecx> & mref eq 0
    test minp, minp
  else
    cmp  minp, mref
  end if
} ; endmacro

; ----------------------------------------------------------------------

format binary as "COM"
use16
org $0100

; AH=1 - Play Wave File
; DS:DX = segment:offset of filename ASCIIZ
; AL=0 play synchronously | AL=1 play asynchronously
; return:
; AL = handle of opened file
; Carry flag set on return if error. Error codes in AL:
; AL=1 file not found | AL=2 previous file still playing

; AH=3 Query Status
; EBX = number of bytes played
; ECX = total length in bytes of the wave file
; DL = 8 or 16 for sample length of last file
; DH = 1 for mono, 2 for stereo | SI = sample rate
; ES:DI = far pointer to number of bytes played - 4 bytes
; ES:DI+4  = far po to total number of bytes in wav file - 4 bytes
; ES:DI+8  = far po to a flag indicating a file is currently playing - 1 byte
; ES:DI+9  = far po to a flag indicating pause is set - 1 byte
; ES:DI+10 = far po to a flag indicating loop is set - 1 byte

; AH=$10 - Specify Volume
; BX = volume for the left and right speaker in hex
; A value of zero provides the maximum volume. The value of $0101 will
; reduce the volume by -1.5 db for both speakers while $0208 will reduce
; the volume for the left speaker by -3 db and for the right by -12 db.
; $1F is the maximum attenuation. So $1F1F will virtually mute - COOL :-D

; AH=$20 - Pause / Close
; BX=0 - resume a paused AC97 controller
; BX=1 - pause AC97 controller

; AH=$21 - Stop Terminates the AC97 controller playing and closes the file.

; AH=$22 - Loop
; BX=0 - stop loop
; BX=1 - restart playing the audio file each time the end of file is reached

; AH=$30 - Read Codec Register Value
; DX = number of codec register to return
; AX or EAX = value currently stored in requested codec register

; AH=$31 - Write Codec Register Value
; DX = number of codec register to write to
; CX = value to store in requested codec register

; AH=$40 - Return Vendor/Device
; BX = AC97 vendor ID | CX = AC97 device ID
; DX = $6D50 DOSSound ID

; [8086]

        cld
        mov    ax, $7202      ; 3   -> 3
        push   ax
        popef                 ; % This is not 100% safe from "V86" mess,
        pushf                 ; % but sufficient here
        pope   bx             ; 4x1 -> 7
        cmp    ax, bx         ; 2   -> 9
        je     short cpu_ok   ; 2   -> 11 | OK we have at least 80386
        call   llabort
        db     "At least 80386 required",0
        ;---------------------------------

; [80386]

cpu_ok:
        call   @f

        db     1,"FASM "
xxsigi: db     "DOSSOUND example (R)",1
        db     "(CL) 2009-04-27 by DOS386 | Abuse at your own risk !!!",1,1,0
xxwav:  db     "*.WAV",0

@@:     pope   si
        call   ssprintsi

        mov    si, $82

        cmp    byte [$80], 2
        ja     short got_args

        call   @f
        db     "No args",1,0
@@:     pope   si
        call   ssprintsi
        mov    si, xxwav

got_args:
        mov    di, bbabuf
        mov    cl, 80
        call   sscopy         ; DX - slash
        mov    [vvslash], dx

        mov    dx, bbabuf
        mov    cx, $37        ; Att
        mov    ax, $4E00      ; Fifi
        int    $21            ; $15 att | $1A size | $1E name
        jnc    short got_file

is_dir:
        call   llabort
        db     "No WAV file",0
        ;---------------------

got_file:
        test   word [$95], $10
        jnz    is_dir         ; What fool allowed naming a subdir "XXX.WAV" ??
        cmp    word [$9C], 0
        jne    short size_ok
        cmp    word [$9A], 1023
        ja     short size_ok
        call   llabort
        db     "Empty (or almost) WAV file",0
        ;------------------------------------

size_ok:
        mov    si, $9E
        mov    di, [vvslash]
        mov    cl, 13
        call   sscopy         ; DX - slash

        call   ssquo
        mov    si, bbabuf
        call   ssprintsi
        call   ssquo
        call   sseol

        movntq ax, 0
        mov    ds, ax
        mov    si, $0190
        lodsw                 ; AX off
        mov    [cs:vvoff], ax
        xchg   dx, ax         ; DX off | AX ???
        lodsw                 ; AX seg
        mov    si, dx         ; SI off | DX off
        mov    [cs:vvseg], ax
        mov    ds, ax         ; DS:SI found stuff
        mov    di, xxsigi     ; ES:DI reference string
        lodsw                 ; Skip JMP SHORT
        mov    cx, 4
        repe   cmpsw
        je     short ds_found

        movntq ds, cs
        call   llabort
        db     "Driver not found",0
        ;--------------------------

ds_found:
        lodsw                 ; Y & M
        xchg   dx, ax         ; DL Y | DH M
        lodsb
        mov    bh, al         ; BH D
        movntq ds, cs

        call   @f
        db     "Driver found at: $",0
@@:     pope   si
        call   ssprintsi

        mov    ax, [vvseg]
        call   sshex16
        mov    ax, $243A
        call   ssdchar
        mov    ax, [vvoff]
        call   sshex16
        call   sseol

        cmp    dl, 9
        jb     short f_d
        cmp    dl, 50
        ja     short f_d
        cmp    dh, 1
        jb     short f_d
        cmp    dh, 12
        ja     short f_d
        cmp    bh, 1
        jb     short f_d
        cmp    bh, 32
        jb     short g_d

f_d:    call   llabort
        db     "Faulty date",0
        ; quasi-pass

; [8086]

llabort:
        pope   si
        call   ssprintsi
        call   sseol
        jmp    near give_up
        ;------------------

; [80386]

g_d:
        call   @f
        db     "Date: 20",0
@@:     pope   si
        call   ssprintsi

        mov    al, dl         ; Y
        call   ssdec99
        mov    al, 45
        call   ssonecharal
        mov    al, dh         ; M
        call   ssdec99
        mov    al, 45
        call   ssonecharal
        mov    al, bh         ; D
        call   ssdec99
        call   sseol

        mov    ah, 3
        int    $64
        cmpntq ecx, 0
        je     short idle_d
        cmp    ebx, ecx
        je     short idle_d

        mov    ah, 1
        call   status_d
        db     "Busy",1,0

idle_d:
        mov    ah, 0
        call   status_d
        db     "Idle",1,0

status_d:
        pope   si
        call   ssprintsi
        cmp    ah, 1
        je     short give_up

        mov    ah, $10
        mov    bx, $1010
        int    $64            ; Vol

        mov    ax, $0101      ; Mode
        mov    dx, bbabuf     ; Address of filespec
        int    $64            ; Play ass'y
        jnc    short error_d

        call   status_p
        db     "Error",1,0
error_d:
        mov    ah, 1
        call   status_p
        db     "Playing now",1,0

status_p:
        pope   si
        call   ssprintsi

; [8086]

give_up:
        call   sseol
        mov    ax, $4C00
        int    $21
        ;---------

sscopy:
        mov    dx, di
copy_loop:
        cmpntq cl, 0
        je     short copy_done
        lodsb
        cmpntq al, 0
        je     short copy_done
        cmp    al, 32
        jb     short copy_done
        cmp    al, 126
        ja     short copy_done
        call   ssupper
        cmp    al, 47
        jne    short @f
        mov    al, 92
@@:     stosb
        dec    cl
        cmp    al, 92
        je     short sscopy
        jmp    short copy_loop
        ;---------------------
copy_done:
        mov    al, 0
        stosb
        ret
        ;----

ssdec99:
        mov    ah, 0
        mov    bl, 10
        div    bl
        call   ssconvertdec1dig
        call   ssonecharal
        mov    al, ah
        call   ssconvertdec1dig
        jmp    short ssonecharal
        ;-----------------------

sshex16:
        push   cx

        mov    cx, 1028     ; "MOVNTQ CL, 4" + "MOVNTQ CH, 4"
@@:     rol    ax, cl       ; 8086 compatible, after 4 ROL's original back
        push   ax
        and    al, $0F
        cmp    al, 10       ; Now must be and is AL<=15 | Decimal "10" !!!
        sbb    al, $69      ; Securely Bugged Backup
        das                 ; Digital Attack System | ASCII result in AL
        call   ssonecharal
        pope   ax
        dec    ch           ; & No LOO'p on CH :-(
        jnz    short @b     ; &

        pope   cx
        ret
        ;----

; SSCONVERTDEC1DIG            ; Works on AL

ssconvertdec1dig:
        cmp    al, 10
        jb     short @f
        mov    al, 15         ; "?"
@@:     add    al, 48
        ret
        ;----

; SSUPPER                     ; UPPERcase on AL

ssupper:
        cmp    al, 122        ; "z"
        ja     short @f       ; Not a letter
        cmp    al, 97         ; "a"
        jb     short @f       ; Not lowercase
        sub    al, 32
@@:     ret
        ;----

ssquo:  mov   al, 34
        jmp   short ssonecharal
        ;----------------------

; EOL & CHAR SUB's

sseol:
        push  ax
        mov   ax, $0A0D
        call  ssdchar
        pope  ax
        ret
        ;----

ssdchar:
        call  ssonecharal
        mov   al, ah
        ; and pass

; SSONECHARAL

; One char | Input: AL
; All registers preserved, optionally including flags [-] !!!

ssonecharal:

        ; pushf            ; opt
        push   ax
        push   bx
        ; push   dx

        mov    ah, $0E        ; "TTY" BIOS service, char in AL
        movntq bx, 0
        int    $10            ; BIOS screen stuff

        ; mov    dl, al
        ; mov    ah, 2        ; DOS service, char in DL
        ; int    $21          ; Here

        ; pope   dx
        pope   bx
        pope   ax
        ; popef            ; opt

        ret
        ;----

; SSPRINTSI

; Input in SI
; Converts value of 1 to EOL

ssprintsi:
        push   ax
        push   si
pickchar:
        lodsb
        cmp    al, 0
        je     short sisi_done
        cmp    al, 1
        jne    short @f
        mov    al, $0D
        call   ssonecharal
        mov    al, $0A
@@:     call   ssonecharal
        jmp    short pickchar
        ;--------------------
sisi_done:
        pope   si
        pope   ax
        ret
        ;----

vvseg:   dw ?
vvoff:   dw ?
vvslash: dw ?
bbabuf:  rb 256

; END.

