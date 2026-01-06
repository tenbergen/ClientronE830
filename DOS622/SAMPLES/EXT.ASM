;Sample to fill the buffers of DOSSound by an external application
;
;compile with: TASM ext.asm
;              TLINK /t ext
;
         .MODEL TINY            ;COM file
         .CODE
         ORG 100h
Start:   
        ;call readstatus
        mov ax,0300h            ;read status
        int 64h                 ;dossound
        mov statusseg,es
        mov statusoff,di

        mov ax,es:[di+11]       ;read current buffer number
	mov nrbuffer,al
	mov oldnrbuffer,al

        mov ax,5000h            ;read buffer pointers
        int 64h                 ;dossound
	mov audioseg1,bx
	mov audiosize,cx
        mov audioseg2,bx        ;bx=audioseg1
        add audioseg2,cx        ;cx=audiosize
        shl audiosize,4         ;mul 16 - make bytes from segment value

        mov  ah,3Dh
        xor  al,al
        mov  dx,OFFSET Filename
        int  21h                ;open wave file

        mov  filehandle,ax      ;save handle 

        mov  ah,3Fh
        mov  bx,filehandle
        mov  cx,44              ;read wave file header
        mov  dx,0
        push ds
        push audioseg1          ;use as tmp storage
        pop  ds
        int  21h                ;read data
        mov  bx,24              ;position of sample rate in header
        mov  ax,ds:[bx]
        mov  cs:samplerate, ax
        pop  ds                 ;restore ds

        ;fill first two buffers

        mov  ah,3Fh
        mov  bx,filehandle
        mov  cx,audiosize
        mov  dx,0               ;offset is zero
        push ds
        push audioseg1          ;first buffer
        pop  ds                 ;ds = audioseg1
        int  21h                ;read data
        pop  ds                 ;restore ds

        mov  ah,3Fh
        mov  bx,filehandle
        mov  cx,audiosize
        mov  dx,0
        push ds
        push audioseg2          ;second buffer
        pop  ds                 ;ds = audioseg2
        int  21h                ;read data
        pop  ds                 ;restore ds
        
        mov ax,5100h            ;start playing
        mov bx,samplerate       
        int 64h                 ;dossound

playloop:
        mov ax,statusseg
	mov es,ax
        mov di,statusoff
	mov ax,es:[di+11]
	mov nrbuffer,al

        cmp oldnrbuffer,al      ;al=nrbuffer
	je playloop

        mov oldnrbuffer,al      ;al=nrbuffer

        mov  ah,3Fh             ;prepare reading of next buffer
        mov  bx,filehandle
        mov  cx,audiosize
        mov  dx,0
        push ds

	cmp nrbuffer,0
        je  fill2               ;fill opposite buffer, here audioseg2
        push audioseg1          ;first buffer
        pop  ds                 ;ds = audioseg1
	jmp filled
fill2:
        push audioseg2          ;second buffer
        pop  ds                 ;ds = audioseg2
filled:
        int  21h                ;read data
        pop  ds                 ;restore ds

        cmp ax,0                ;eof?
        je filedone

jmp playloop

filedone:
        mov ax,2100h            ;stop playing
        int 64h                 ;dossound

        mov  ah,3Eh
        int  21h                ;close file

        mov  ah,4Ch
        int  21h                ;terminate program

;********************************************

readstatus proc near
        mov ax,0300h
        int 64h ;dossound
        mov statusseg,es
        mov statusoff,di
ret
readstatus endp

;data ***************************************

filename db "moon.wav",0
filehandle dw 0
samplerate dw 0 ;22050
audioseg1 dw 0
audioseg2 dw 0
audiosize dw 0
nrbuffer db 0
oldnrbuffer db 0
statusseg dw 0
statusoff dw 0

;********************************************

         END Start




		    
