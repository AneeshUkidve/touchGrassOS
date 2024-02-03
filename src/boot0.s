[bits 16]
[org 0x0600]

_start:
    cli;
    xor ax, ax;
    mov ds, ax;
    mov es, ax;
    mov ss, ax;
    mov sp, ax;

    .Relocate:
        mov cx, 256;
        mov si, 0x7c00;
        mov di, 0x600;
        rep movsw;
    
    jmp 0:MBRbootStart

MBRbootStart:
    sti;
    mov BYTE [bootDrive], dl
    mov bx, bootMessage
    mov ah, 0x0e
    mov cx, findVBR
    jmp printMsg

printMsg:
    mov al, [bx]
    cmp al, 0
    je jumpToCx
    int 0x10
    inc bx
    jmp printMsg

jumpToCx:
    jmp cx

findVBR:
    mov bx, bootSector
    mov cl, 1
    mov al, [bx]
    search:
        test al, 0x80
        jnz VBRfound
        cmp cl, 4
        jge noBootFound
        add cl, 1
        add bx, 0x10
        mov al, [bx]
        jmp search
    VBRfound:
        mov ah, 0x0e
        mov al, 'S'
        int 0x10
        prepVBRdataPacket:
            add bx, 11                        ;LBA address offset
            mov eax, [bx]
            ;cmp ax, 1;
            ;jne debug
            mov [VBRaddressLBA], eax
            add bx, 4                        
            mov ax, [bx]
            mov [VBRsectorsNo], ax
        checkIfLBA:
            clc
            mov ah, 0x41
            mov bx, 0x55aa
            mov dl, 0x80
            int 0x13
            jc useCHS
            mov ah, 0x0e
            mov bx, LBAmessage
            mov cx, useLBA
            jmp printMsg
        useLBA:
            clc
            mov si, VBRdataPacket
            mov ah, 0x42
            mov dl, [bootDrive]
            int 0x13
            jc diskReadError
            cmp ah, 0
            jne diskReadError
            jmp verifyVBR
debug:
    mov al, ah
    mov ah, 0x0e
    ;mov al, 'D'
    add al, 48
    int 0x10
    jmp Count

useCHS:
    mov ah, 0x0e
    mov al, 'C'
    int 0x10
    jmp Count

verifyVBR:
    cmp WORD [0x7DFE], 0xAA55
    jne verifyError
    jmp 0:0x7c00

verifyError:
    mov ah, 0x0e
    mov al, 'V'
    int 0x10
    jmp Count

diskReadError:
    mov ah, 0x0e
    mov al, 'E'
    int 0x10
    jmp Count
noBootFound:
    mov ah, 0x0e
    mov cx, Count
    mov bx, noBootMsg
    jmp printMsg

bootDrive:
    db 0
bootMessage:
    db "MBR booted", 0xa, 0xd, 0;
LBAmessage:
    db "Using LBA addressing", 0xa, 0xd, 0;
noBootMsg:
    db "F", 0xa, 0xd, 0;

ALIGN 4
VBRdataPacket:
    db 0x10         ;Size of packet
    db 0            ;Always 0
    VBRsectorsNo: 
        dw 1       ;Number of sectors to read 
    dw 0x7c00       ;Where in memory 0:7xc00
    dw 0            ;In which memory page
    VBRaddressLBA:
        dd 1        ;Lower 32 bits of LBA address
        dd 0        ;Upper 16 bits of "----------", Damn

Count:
    mov ah, 0x0e
    mov al, ($-$$)-100
    int 0x10

times 0x1bc-($-$$) db 0;    Padding till disk entries
db 0, 0;                    reserved
bootSector:
    db 0x80;                Active (bootable)
    db 0, 2, 0;             H C S of first sector in partition
    db 0x7f;                Custom filesystem
    db 0, 11, 0;            H C S of last sector in partition
    db 0, 0, 0, 1;          LBA of first sector
    db 0, 0, 0, 1;         number of sectors in partition
kernelSector times 16 db 0
deviceStorage times 16 db 0
unused times 16 db 0
db 0x55, 0xAA;