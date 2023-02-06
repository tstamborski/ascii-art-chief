bits 16
cpu 286

org 0x100

%define FILETYPE_BIN 0x00
%define FILETYPE_COM 0x01
%define FILETYPE_TXT 0x02
%define FILETYPE_UNKNOWN 0xff

init:
	mov ax, 0x03
	int 0x10
	mov dx,cs
	mov ds,dx
	mov dx,0xb800
	mov es,dx

	call flushdata
	call showcursor

mainloop:
	call readkeyboard
	jmp mainloop

exit:
	mov ax, 0x0003
	int 0x10
	mov ah, 0x01
	mov cx, 0x0607
	int 0x10
	xor ax, ax
	int 0x20
	
showcursor:
	mov ah, 0x01
	mov cx, 0x0007
	int 0x10
	ret

hidecursor:
	mov ah, 0x01
	mov cx, 0x2007
	int 0x10
	ret

readkeyboard:
	mov ah,0x00
	int 0x16

	cmp ah, 0x0f ;tab
	je showpalette
	cmp ah, 0x01 ;esc
	je showmenu
	cmp ah, 0x48
	je cursorup
	cmp ah, 0x50
	je cursordown
	cmp ah, 0x4b
	je cursorleft
	cmp ah, 0x4d
	je cursorright
	cmp ah, 0x1c ;enter
	je putprevchar
	cmp ah, 0x0e ;backspace
	je jumpprevdiff
	cmp ah, 0x3b ;F1
	je showasciiinput

	cmp al, 0x20
	jb .fend
	call putchar

	.fend:
	ret

setfgcolor:
	;al <- kolor znakow
	mov bl, [attr]
	and bl,0xf0
	or bl,al
	mov [attr],bl
	ret

setbgcolor:
	;al <- kolor tla
	mov bl, [attr]
	and bl,0x0f
	shl al,4
	or bl,al
	mov [attr],bl
	ret

jumpprevdiff:
	xor bh,bh
	mov ah,0x03
	int 0x10
	cmp dl,0
	je .fend
	
	xor bh,bh
	mov ah,0x08
	int 0x10
	mov [tmp],al

	.loop:
	call cursorleft
	xor bh,bh
	mov ah,0x08
	int 0x10
	cmp al,[tmp]
	jne .fend
	xor bh,bh
	mov ah,0x03
	int 0x10
	cmp dl,0
	jne .loop

	.fend:
	ret

newfile:
	mov cx,80*25
	mov ax,0x0720
	mov di,data
	.loop:
	mov [di],ax
	inc di
	inc di
	loop .loop
	ret

str2upper:
	;si -> adres stringa
	;[si] <- nowy string
	mov al,[si]
	.loop:
	cmp al,'a'
	jb .skip
	cmp al,'z'
	ja .skip
	sub al,0x20
	.skip:
	mov [si],al
	inc si
	mov al,[si]
	cmp al,0x00
	jne .loop
	
	ret

checkfileext:
	;al -> typ pliku
	;+zmienia filename na wielkie litery
	mov si,filename
	call str2upper

	call .findext
	mov al,[si]
	cmp al,'C'
	jne .notcom
	inc si
	mov al,[si]
	cmp al,'O'
	jne .notcom
	inc si
	mov al,[si]
	cmp al,'M'
	je .com
	.notcom:

	call .findext
	mov al,[si]
	cmp al,'B'
	jne .notbin
	inc si
	mov al,[si]
	cmp al,'I'
	jne .notbin
	inc si
	mov al,[si]
	cmp al,'N'
	je .bin
	.notbin:

	call .findext
	mov al,[si]
	cmp al,'T'
	jne .unknown
	inc si
	mov al,[si]
	cmp al,'X'
	jne .unknown
	inc si
	mov al,[si]
	cmp al,'T'
	je .txt
	jmp .unknown

	.bin:
	mov al,FILETYPE_BIN
	ret
	.com:
	mov al,FILETYPE_COM
	ret
	.txt:
	mov al,FILETYPE_TXT
	ret
	.unknown:
	mov al,FILETYPE_UNKNOWN
	ret

	.findext:
	mov si,filename
	.findloop:
	mov al,[si]
	inc si
	cmp al,'.'
	jne .findloop
	ret

savefile:
	call showfileinput
	cmp cl,0
	je .fend

	call checkfileext
	cmp al, FILETYPE_BIN
	je .asbin
	cmp al, FILETYPE_COM
	je .ascom
	jmp .asbin

	.ascom:
	call saveascom
	jnc .ok
	jmp .err
	.asbin:
	call saveasbin
	jnc .ok

	.err:
	mov si,saveerrmsg
	call showmessage
	ret
	.ok:
	mov si,saveokmsg
	call showmessage
	.fend:
	ret

saveascom:
	xor cx,cx
	mov dx,filename
	mov ah,0x3c
	int 0x21
	jc .fend

	mov bx,ax
	mov cx, (SELF_EXEC_END-SELF_EXEC_BEGIN)
	mov dx, SELF_EXEC_BEGIN
	mov ah, 0x40
	int 0x21
	
	mov ah,0x3e
	int 0x21
	.fend:
	ret

saveasbin:
	xor cx,cx
	mov dx,filename
	mov ah,0x3c
	int 0x21
	jc .fend

	mov bx,ax
	mov cx, 80*25*2
	mov dx, data
	mov ah, 0x40
	int 0x21
	
	mov ah,0x3e
	int 0x21
	.fend:
	ret

loadfile:
	call showfileinput
	cmp cl,0
	je .fend

	call checkfileext
	cmp al, FILETYPE_BIN
	je .asbin
	cmp al, FILETYPE_COM
	je .ascom
	jmp .asbin

	.ascom:
	call loadfromcom
	jnc .ok
	jmp .err
	.asbin:
	call loadfrombin
	jnc .ok

	.err:
	mov si,loaderrmsg
	call showmessage
	ret
	.ok:
	.fend:
	ret

loadfromcom:
	xor al,al
	mov dx,filename
	mov ah,0x3d
	int 0x21
	jc .fend

	mov bx,ax
	mov cx,0xffff
	mov dx,-(80*25*2)
	mov al,2
	mov ah, 0x42
	int 0x21
	mov cx, 80*25*2
	mov dx, data
	mov ah, 0x3f
	int 0x21
	
	mov ah,0x3e
	int 0x21
	.fend:
	ret

loadfrombin:
	xor al,al
	mov dx,filename
	mov ah,0x3d
	int 0x21
	jc .fend

	mov bx,ax
	mov cx, 80*25*2
	mov dx, data
	mov ah, 0x3f
	int 0x21
	
	mov ah,0x3e
	int 0x21
	.fend:
	ret

putprevchar:
	mov al,[prevchar]
putchar:
	;al <- znak do wypisania w miejscu kursora
	call writechar
	call cursorright
	ret
	
writechar:
	mov [prevchar], al

	mov ah, 0x03
	xor bh,bh
	int 0x10
	xor ax,ax
	mov al,dh
	mov cx,80
	push dx
	mul cx
	pop dx
	and dx,0x00ff
	add ax,dx
	mov cx,2
	mul cx
	mov di,ax
	mov al,[prevchar]
	mov ah,[attr]
	mov [es:di],ax

	add di,data
	mov [di],ax

	ret

putstr:
	;si <- adres stringa (zakonczonego null)
	mov al,[si]
	cmp al,0x00
	jne .loop
	ret
	.loop:
	mov bh,[page]
	mov cx,1
	mov al,[si]
	mov ah,0x0a
	int 0x10
	call cursorright
	inc si
	mov al,[si]
	cmp al,0x00
	jne .loop
	ret

putmenustr:
	;si <- adres stringa (zakonczonego null)
	mov bl,[menuattr0]
	mov [tmp],bl

	.loop:
	mov bh,[page]
	mov cx,1
	mov al,[si]
	mov bl,[tmp]
	mov ah,0x09
	int 0x10
	cmp al,'['
	jne .nobracket0
	mov bl,[menuattr2]
	mov [tmp],bl
	.nobracket0:
	call cursorright
	inc si
	mov al,[si]
	cmp al,']'
	jne .nobracket1
	mov bl,[menuattr0]
	mov [tmp],bl
	.nobracket1:
	cmp al,0x00
	jne .loop
	ret

putstrlist:
	;arg0 (w) <- x
	;arg1 (w) <- y
	;si <- adres pierwszego stringa
	;cx <- dlugosc listy
	mov bp,sp
	mov dh,[bp+4]
	mov dl,[bp+2]
	xor bh,bh
	mov ah,0x02
	int 0x10
	.loop:
	push cx
	;call putstr
	call putmenustr
	xor bh,bh
	mov ah,0x03
	int 0x10
	inc dh
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	inc si
	pop cx
	loop .loop
	ret 4

cursorup:
	mov ah, 0x03
	mov bh, [page]
	int 0x10
	
	dec dh
	cmp dh, 0x00
	jge .skip
	mov dh, 24
	.skip:
	mov ah,0x02
	int 0x10

	ret

cursordown:
	mov ah, 0x03
	mov bh, [page]
	int 0x10
	
	inc dh
	cmp dh, 25
	jl .skip
	xor dh,dh
	.skip:
	mov ah,0x02
	int 0x10

	ret

cursorleft:
	mov ah, 0x03
	mov bh, [page]
	int 0x10
	
	dec dl
	cmp dl, 0x00
	jge .skip
	mov dl, 79
	.skip:
	mov ah,0x02
	int 0x10

	ret

cursorright:
	mov ah, 0x03
	mov bh, [page]
	int 0x10

	mov bh, [page]
	inc dl
	xor ax, ax
	mov al, dl
	mov cl, 80
	div cl
	mov dl, ah
	mov ah, 0x02
	int 0x10
	ret

cursornext:
	mov ah, 0x03
	mov bh, [page]
	int 0x10

	inc dl
	cmp dl, 80
	jb .skip
	xor dl, dl
	inc dh
	cmp dh, 25
	jb .skip
	xor dh, dh
	.skip:
	mov ah, 0x02
	int 0x10
	ret

flushdata:
	mov cx, 80*25
	mov si, data
	xor di,di

	.loop:
	mov ax,[si]
	mov [es:di],ax
	add si,2
	add di,2
	loop .loop

	ret

gethexbyte:
	;[prevchar] -> wartosc pobrana od uzytkownika
	;cx -> liczba pobranych znakow
	call showcursor

	xor cx,cx
	mov [prevchar],cl
	
	.keyloop:
	push cx
	.keyloop2:
	mov ah,0x00
	int 0x16
	cmp ah,0x01 ;esc
	je .funcexit
	cmp al,0x39
	ja .not09
	cmp al,0x30
	jb .not09
	jmp .do09
	.not09:
	cmp al,0x66
	ja .notAF
	cmp al,0x61
	jb .notAF
	jmp .doAF
	.notAF:
	cmp al,0x46
	ja .keyloop2
	cmp al,0x41
	jb .keyloop2
	jmp .doaf

	.funcexit:
	pop cx
	jmp .funcend
	.do09:
	mov cx,1
	mov ah,0x0a
	int 0x10
	sub al,0x30
	pop cx
	jmp .do
	.doAF:
	mov cx,1
	mov ah,0x0a
	int 0x10
	sub al,0x57
	pop cx
	jmp .do
	.doaf:
	mov cx,1
	mov ah,0x0a
	int 0x10
	sub al,0x37
	pop cx
	.do:
	cmp cx,0
	jne .dosecond
	shl al,4
	mov [prevchar],al
	push cx
	xor bh,bh
	mov ah,0x03
	int 0x10
	inc dl
	mov ah,0x02
	int 0x10
	pop cx
	inc cx
	jmp .keyloop
	.dosecond:
	mov bl,[prevchar]
	or bl,al
	mov [prevchar],bl
	inc cx
	
	.funcend:
	push cx
	call hidecursor
	pop cx
	ret

showabout:
%define X1 16
%define Y1 8
%define X2 62
%define Y2 13
	call flushdata

	push Y2
	push X2
	push Y1
	push X1
	call drawframe

	xor bh,bh
	mov dh,Y1
	mov dl,X1+2
	mov ah,0x02
	int 0x10
	mov si,aboutstr
	call putstr

	mov cx,4
	mov si,aboutstr0
	push Y1+1
	push X1+3
	call putstrlist

	mov ah,0x07
	int 0x21

	ret

showmenu:
%define X1 29
%define Y1 8
%define X2 49
%define Y2 16
	xor bh,bh
	mov ah,0x03
	int 0x10
	push dx

	call hidecursor
	
	push Y2
	push X2
	push Y1
	push X1
	call drawframe

	xor bh,bh
	mov dh,Y1
	mov dl,X1+6
	mov ah,0x02
	int 0x10
	mov si,menustr
	call putstr

	mov cx,5
	mov si,menustr0
	push Y1+2
	push X1+7
	call putstrlist

	.keyloop:
	mov ah,0x00
	int 0x16
	cmp ah,0x01 ;esc
	je .fend
	cmp ah,0x31 ;n
	je .newfile
	cmp ah,0x26 ;l
	je .loadfile
	cmp ah,0x1f ;s
	je .savefile
	cmp ah,0x18 ;o
	je .about
	cmp ah,0x2d ;x
	je exit
	jmp .keyloop
	
	.fend:
	call flushdata
	pop dx
	xor bh,bh
	mov ah,0x02
	int 0x10
	call showcursor
	ret
	.about:
	call showabout
	jmp .fend
	.newfile:
	call newfile
	jmp .fend
	.loadfile:
	call loadfile
	jmp .fend
	.savefile:
	call savefile
	jmp .fend

showasciiinput:
%define X1 32
%define Y1 10
%define X2 41
%define Y2 12
	xor bh,bh
	mov ah,0x03
	int 0x10
	push dx

	call hidecursor
	call flushdata
	
	push Y2
	push X2
	push Y1
	push X1
	call drawframe

	push Y1+1
	push X1+6
	mov cx,2
	call drawfield

	xor bh,bh
	mov dh,Y1
	mov dl,X1+1
	mov ah,0x02
	int 0x10
	mov si,asciistr
	call putstr

	xor bh,bh
	mov dh,Y1+1
	mov dl,X1+1
	mov ah,0x02
	int 0x10
	mov si,hexstr
	call putstr

	mov dh,Y1+1
	mov dl,X1+6
	mov ah,0x02
	int 0x10
	call gethexbyte
	push cx

	call flushdata
	pop cx
	pop dx
	xor bh,bh
	mov ah,0x02
	int 0x10
	cmp cx,2
	jb .fend
	call putprevchar

	.fend:
	call showcursor
	ret

showpalette:
	xor bh,bh
	mov ah,0x03
	int 0x10
	push dx

	call showfgpalette

	pop dx
	xor bh,bh
	mov ah,0x02
	int 0x10
	ret

showfgpalette:
%define X1 20
%define Y1 7
%define X2 52
%define Y2 16
	call hidecursor
	call flushdata

	push Y2
	push X2
	push Y1
	push X1
	call drawframe

	mov dh,Y1
	mov dl,X1+10
	mov ah,0x02
	int 0x10
	mov si,fgstr
	call putstr

	mov si,fgpalettestr0
	mov cx,8
	push Y1+1
	push X1+1
	call putstrlist

	.keyloop:
	mov ah,0x00
	int 0x16
	
	cmp ah,0x01 ;esc
	je .funcend
	cmp ah,0x0f ;tab
	je showbgpalette
	cmp al,0x39
	ja .not09
	cmp al,0x30
	jb .not09
	jmp .do09
	.not09:
	cmp al,0x66
	ja .notAF
	cmp al,0x61
	jb .notAF
	jmp .doAF
	.notAF:
	cmp al,0x46
	ja .keyloop
	cmp al,0x41
	jb .keyloop
	jmp .doaf

	.do09:
	sub al,0x30
	call setfgcolor
	jmp .funcend
	
	.doAF:
	sub al,0x57
	call setfgcolor
	jmp .funcend

	.doaf:
	sub al,0x37
	call setfgcolor

	.funcend:
	call flushdata
	call showcursor
	ret

showbgpalette:
%define X1 20
%define Y1 7
%define X2 48
%define Y2 12
	call hidecursor
	call flushdata

	push Y2
	push X2
	push Y1
	push X1
	call drawframe

	mov dh,Y1
	mov dl,X1+8
	mov ah,0x02
	int 0x10
	mov si,bgstr
	call putstr

	mov si,bgpalettestr0
	mov cx,4
	push Y1+1
	push X1+1
	call putstrlist

	.keyloop:
	mov ah,0x00
	int 0x16
	
	cmp ah,0x01 ;esc
	je .funcend
	cmp ah,0x0f ;tab
	je showfgpalette
	cmp al,0x39
	ja .keyloop
	cmp al,0x30
	jb .keyloop

	sub al,0x30
	call setbgcolor
	
	.funcend:
	call flushdata
	call showcursor
	ret

showmessage:
	;si <- adres stringa zakonczonego 0x00
	push bp
	mov bp,sp

	push si ;bp-2

	call getstrlen
	and cx,0x00ff
	mov ax,cx
	mov cl,2
	div cl
	and ax,0x00ff
	push ax ;bp-4

	call flushdata

	mov cx,14
	push cx ;y2
	mov cx,39
	mov ax,[bp-4]
	add cx,ax
	add cx,2
	push cx ;x2
	mov cx,10
	push cx ;y1
	mov cx,39
	mov ax,[bp-4]
	sub cx,ax
	sub cx,2
	push cx ;x1
	call drawframe

	mov cx,39
	mov ax,[bp-4]
	sub cx,ax
	mov dl,cl
	mov dh,12
	xor bh,bh
	mov ah,0x02
	int 0x10
	mov si,[bp-2]
	call putstr

	mov ah,0x07
	int 0x21

	mov sp,bp
	pop bp
	ret

showfileinput:
	;filename -> nazwa pliku pobrana od uzytkownika
	;cl -> dlugosc nazwy
%define X1 80/2-20/2
%define Y1 24/2-2
%define X2 80/2+20/2
%define Y2 24/2
	call flushdata

	push Y2
	push X2
	push Y1
	push X1
	call drawframe

	mov dh,Y1
	mov dl,X1+4
	mov ah,0x02
	int 0x10
	mov si,filenamestr
	call putstr

	push Y1+1
	push X1+4
	mov cx,13
	call drawfield

	push Y1+1
	push X1+4
	call getfilename
	ret

getfilename:
	;arg0 (w) <- x
	;arg1 (w) <- y
	;filename -> nazwa pliku pobrana od uzytkownika
	;cl -> dlugosc nazwy pliku
	mov bp,sp
	call showcursor

	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	mov si,filename
	call putstr

	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10

	.keyloop:
	mov ah,0x00
	int 0x16
	cmp ah,0x1c ;enter
	je .fend
	cmp ah,0x01 ;esc
	je .cancel
	cmp ah,0x4b ;left
	je .left
	cmp ah,0x4d ;right
	je .right
	cmp ah,0x0e ;backspace
	je .backspace
	cmp ah,0x53 ;del
	je .del
	cmp ah,0x47 ;home
	je .home
	cmp ah,0x4f ;end
	je .end
	cmp al,'_'
	je .char
	cmp al,'-'
	je .char
	cmp al,'.'
	je .char
	cmp al,'z'
	ja .keyloop
	cmp al,'0'
	jb .keyloop
	cmp al,'9'
	jbe .char
	cmp al,'A'
	jb .keyloop
	cmp al,'Z'
	jbe .char
	cmp al,'a'
	jb .keyloop
	jmp .char
	
	.char:
	call getfilenamelen
	cmp cl,12
	jae .keyloop
	xor bh,bh
	mov ah,0x03
	int 0x10
	push dx
	sub dl,[bp+2]
	call putfilenamechar
	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	mov si,filename
	call putstr
	pop dx
	xor bh,bh
	mov ah,0x02
	int 0x10
	jmp .right

	.left:
	xor bh,bh
	mov ah,0x03
	int 0x10
	cmp dl,[bp+2]
	je .keyloop
	dec dl
	xor bh,bh
	mov ah,0x02
	int 0x10
	jmp .keyloop

	.right:
	xor bh,bh
	mov ah,0x03
	int 0x10
	call getfilenamelen
	sub dl,[bp+2]
	cmp dl,cl
	jae .keyloop
	xor bh,bh
	mov ah,0x03
	int 0x10
	inc dl
	xor bh,bh
	mov ah,0x02
	int 0x10
	jmp .keyloop

	.backspace:
	xor bh,bh
	mov ah,0x03
	int 0x10
	push dx
	sub dl,[bp+2]
	dec dl
	call delfilenamechar
	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	mov si,emptystr
	call putstr
	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	mov si,filename
	call putstr
	pop dx
	xor bh,bh
	mov ah,0x02
	int 0x10
	jmp .left

	.del:
	xor bh,bh
	mov ah,0x03
	int 0x10
	push dx
	sub dl,[bp+2]
	call delfilenamechar
	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	mov si,emptystr
	call putstr
	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	mov si,filename
	call putstr
	pop dx
	xor bh,bh
	mov ah,0x02
	int 0x10
	jmp .keyloop

	.home:
	mov dh,[bp+4]
	mov dl,[bp+2]
	mov ah,0x02
	int 0x10
	jmp .keyloop

	.end:
	call getfilenamelen
	mov dh,[bp+4]
	mov dl,[bp+2]
	add dl,cl
	mov ah,0x02
	int 0x10
	jmp .keyloop

	.cancel:
	call truncfilename
	.fend:
	call hidecursor
	call getfilenamelen
	ret 4

getfilenamelen:
	mov si,filename
getstrlen:
	;si <- adres stringa
	;cl -> dlugosc stringa
	xor cl,cl
	.loop:
	mov bl,[si]
	cmp bl,0x00
	je .fend
	inc si
	inc cl
	jmp .loop
	.fend:
	ret

truncfilename:
	mov al,0x00
	mov cx,12
	mov di,filename
	.loop:
	mov [di],al
	inc di
	loop .loop
	ret
	
delfilenamechar:
	;dl <- indeks
	;filename -> zmieniona nazwa pliku
	cmp dl,12
	jae .fend

	mov si,filename
	xor cx,cx
	mov cl,dl
	add si,cx
	mov di,si
	inc si
	.loop:
	mov bl,[si]
	mov [di],bl
	cmp bl,0x00
	je .fend
	inc si
	inc di
	jmp .loop

	.fend:
	ret

putfilenamechar:
	;dl <- indeks
	;al <- znak
	;filename -> zmieniona nazwa pliku
	call getfilenamelen
	cmp cl,12
	jae .fend

	cmp dl,12
	jae .fend

	mov cx,12
	mov di,tmp
	mov bl,0x00
	.trunctmp:
	mov [di],bl
	inc di
	loop .trunctmp

	xor cx,cx
	mov cl,dl
	mov di,tmp
	mov si,filename
	add si,cx
	.f2tmp:
	mov bl,[si]
	mov [di],bl
	inc si
	inc di
	inc cx
	cmp cx,12
	jb .f2tmp
	
	mov di,filename
	xor cx,cx
	mov cl,dl
	add di,cx
	mov [di],al

	inc di
	mov si,tmp
	mov bl,[si]
	.tmp2f:
	mov [di],bl
	inc si
	inc di
	mov bl,[si]
	cmp bl,0x00
	jne .tmp2f
	
	.fend:
	ret

drawfield:
	;arg0 (w) <- x
	;arg1 (w) <- y
	;cx <- dlugosc pola
	mov bp,sp
	push bp

	xor bh,bh
	mov dl,[bp+2]
	mov dh,[bp+4]
	mov ah,0x02
	int 0x10

	mov bl,[menuattr1]
	mov al,0x20
	mov ah,0x09
	int 0x10

	pop bp
	ret 4

drawframe:
	;arg0 (w) <- x1
	;arg1 (w) <- y1
	;arg2 (w) <- x2
	;arg3 (w) <- y2
	push bp
	mov bp,sp

	mov dl,[bp+4]
	mov dh,[bp+6]
	mov bh,[page]
	mov ah,0x02
	int 0x10
	
	mov cx,[bp+10]
	sub cx,[bp+6]
	inc cx
	.loop0:
	push cx
	mov cx,[bp+8]
	sub cx,[bp+4]
	inc cx
	mov ah, 0x09
	mov al, 0x20
	mov bl, [menuattr0]
	int 0x10
	pop cx
	inc dh
	mov ah, 0x02
	int 0x10
	loop .loop0
	
	mov dl,[bp+4]
	mov dh,[bp+6]
	mov ah,0x02
	int 0x10
	mov cx,1
	mov al,0xc9
	mov ah,0x09
	int 0x10
	mov dl,[bp+8]
	mov dh,[bp+6]
	mov ah,0x02
	int 0x10
	mov cx,1
	mov al,0xbb
	mov ah,0x09
	int 0x10
	mov dl,[bp+4]
	mov dh,[bp+10]
	mov ah,0x02
	int 0x10
	mov cx,1
	mov al,0xc8
	mov ah,0x09
	int 0x10
	mov dl,[bp+8]
	mov dh,[bp+10]
	mov ah,0x02
	int 0x10
	mov cx,1
	mov al,0xbc
	mov ah,0x09
	int 0x10

	mov dl,[bp+4]
	inc dl
	mov dh,[bp+6]
	mov ah,0x02
	int 0x10
	mov cx,[bp+8]
	sub cx,[bp+4]
	dec cx
	mov al,0xcd
	mov ah,0x09
	int 0x10
	mov dl,[bp+4]
	inc dl
	mov dh,[bp+10]
	mov ah,0x02
	int 0x10
	mov cx,[bp+8]
	sub cx,[bp+4]
	dec cx
	mov al,0xcd
	mov ah,0x09
	int 0x10

	mov cx,[bp+10]
	sub cx,[bp+6]
	dec cx
	mov dl,[bp+4]
	mov dh,[bp+6]
	inc dh
	.loop1:
	mov ah, 0x02
	int 0x10
	push cx
	mov cx,1
	mov ah, 0x09
	mov al, 0xba
	mov bl, [menuattr0]
	int 0x10
	pop cx
	inc dh
	loop .loop1

	mov cx,[bp+10]
	sub cx,[bp+6]
	dec cx
	mov dl,[bp+8]
	mov dh,[bp+6]
	inc dh
	.loop2:
	mov ah, 0x02
	int 0x10
	push cx
	mov cx,1
	mov ah, 0x09
	mov al, 0xba
	mov bl, [menuattr0]
	int 0x10
	pop cx
	inc dh
	loop .loop2

	mov sp,bp
	pop bp
	ret 8
	
;///////////// DANE ///////////////

menuattr0:
	db 0x17
menuattr1:
	db 0x70
menuattr2:
	db 0x1e
page:
	db 0x00
prevchar:
	db 0x20
attr:
	db 0x07
tmp:
	times 13 db 0x00
filename:
	times 12 db 0x00
	db 0x00

fgstr:
	db " Foreground ",0x00
bgstr:
	db " Background ",0x00
asciistr:
	db " ASCII ",0x00
hexstr:
	db " Hex: ",0x00
menustr:
	db " Menu ",0x00
aboutstr:
	db " About... ",0x00
filenamestr:
	db " Filename: ",0x00
emptystr:
	times 13 db 0x20
	db 0x00

saveokmsg:
	db "Saved successfully!",0x00
saveerrmsg:
loaderrmsg:
	db "Error! Access denied!",0x00
fgpalettestr0:
	db "[0] Black   [8] Bright Black",0x00
	db "[1] Blue    [9] Bright Blue",0x00
	db "[2] Green   [A] Bright Green",0x00
	db "[3] Cyan    [B] Bright Cyan",0x00
	db "[4] Red     [C] Bright Red",0x00
	db "[5] Magenta [D] Bright Magenta",0x00
	db "[6] Brown   [E] Yellow",0x00
	db "[7] White   [F] Bright Wite",0x00

bgpalettestr0:
	db "[0] Black   [4] Red",0x00
	db "[1] Blue    [5] Magenta",0x00
	db "[2] Green   [6] Brown",0x00
	db "[3] Cyan    [7] White",0x00

menustr0:
	db "[N]ew  ",0x00
	db "[L]oad ",0x00
	db "[S]ave ",0x00
	db "Ab[o]ut",0x00
	db "E[x]it ",0x00

aboutstr0:
	db "Ascii-Art Chief",0x00
	db "ver. 0.2",0x00
	db "Copyright (c) 2023 by Tobiasz Stamborski",0x00
	db "Ascii-Art editor for MS-DOS.",0x00

SELF_EXEC_BEGIN:
	mov ax, 0x03
	int 0x10
	mov dx,0xb800
	mov es,dx

	mov ah, 0x01
	mov cx, 0x2007
	int 0x10

	mov cx, 80*25
	mov si, (data-SELF_EXEC_BEGIN+0x100)
	xor di,di
	.loop:
	mov ax,[si]
	mov [es:di],ax
	add si,2
	add di,2
	loop .loop

	mov ah,0x07
	int 0x21

	mov ax, 0x0003
	int 0x10
	mov ah, 0x01
	mov cx, 0x0607
	int 0x10
	xor ax, ax
	int 0x20

align 16

data:
	times 80*25 db 0x20, 0x07

SELF_EXEC_END:

