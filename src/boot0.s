[bits 16]
[org 0x0500]

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
        mov di, 0x500;
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
    mov bx, ActivePartition
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
        prepVBRdataPacket:
            add bx, 8;                  LBA Address offset
            mov DWORD eax, [bx]
            mov [VBRaddressLBA], eax
            mov WORD [VBRsectorsNo], 10 ;number of sectors to load (VBR size)

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

useCHS:
    mov ah, 0x0e
    mov al, 'C'
    int 0x10
    jmp end

verifyVBR:
    cmp WORD [0x8FFE], 0xAA55
    jne verifyError
    mov dl, [bootDrive]
    jmp 0:0x7c00

verifyError:
    mov ah, 0x0e
    mov al, 'V'
    int 0x10
    jmp end

diskReadError:
    mov ah, 0x0e
    mov al, 'E'
    int 0x10
    jmp end
noBootFound:
    mov ah, 0x0e
    mov cx, end
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
        dw 0        ;Number of sectors to read 
    dw 0x7c00       ;Where in memory 0:7xc00
    dw 0            ;In which memory page
    VBRaddressLBA:
        dd 0        ;Lower 32 bits of LBA address
        dd 0        ;Upper 16 bits of "----------", Damn

end times 0x1bc-($-$$) db 0;    Padding till disk entries
db 0, 0;                    reserved
;PARTITION TABLE IS """NOT""" ALIGNED ON 4 BYTE BOUNDARY
;IT IS ENCODED IN LITTLE ENDIAN
ActivePartition:                
    db 0x80;                Active (bootable)
    db 0, 2, 0;             H C S of first sector in partition
    db 0x7f;                Custom filesystem
    db 0, 11, 0;            H C S of last sector in partition
    dd 1;                   LBA of first sector
    dd 1000;                number of sectors in partition
kernelSector times 16 db 0
deviceStorage times 16 db 0
unused times 16 db 0
db 0x55, 0xAA;