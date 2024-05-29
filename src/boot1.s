[bits 16]
[org 0x7c00]
mov [bootDrive], dl
mov ah, 0x0e
mov bx, successMessage
mov cx, LoadGDT
printMsg:
    mov al, [bx]
    cmp al, 0
    je jumpToCx
    int 0x10
    inc bx
    jmp printMsg
jumpToCx:
    jmp cx

LoadGDT:
    cli

    writeTable:
        mov ax, 0
        mov es, ax
        mov di, 0x800

        nullDesc:
            mov WORD es:[di], 0
            mov WORD es:[di+2], 0
            mov WORD es:[di+4], 0
            mov WORD es:[di+6], 0
        add di, 8
        kernelCode:
            mov WORD es:[di], 0xffff        ;segment limit
            mov WORD es:[di+2], 0           ;base 15:0
            mov BYTE es:[di+4], 0           ;base 23:15 
            mov BYTE es:[di+5], 10011010b   ;present(1)-privilege(00)-alwaysOne(1)-code(1)-non_conforming(0)-readable(1)-beingAccessedRN(0)
            mov BYTE es:[di+6], 11001111b   ;Granularity(1)-size32bit(1)-alwaysZero(00)-limitbits(1111)
            mov BYTE es:[di+7], 0           ;base 31:24
        add di, 8
        kernelData:
            mov WORD es:[di], 0xffff        ;segment limit
            mov WORD es:[di+2], 0           ;base 15:0
            mov BYTE es:[di+4], 0           ;base 23:15 
            mov BYTE es:[di+5], 10010010b   ;present(1)-privilege(00)-alwaysOne(1)-data(0)-growUpwards(0)-writeable(1)-beingAccessedRN(0)
            mov BYTE es:[di+6], 11001111b   ;Granularity(1)-size32bit(1)-alwaysZero(00)-limitbits(1111)
            mov BYTE es:[di+7], 0           ;base 31:24
        add di, 8
        userCode:
            mov WORD es:[di], 0xffff        ;segment limit
            mov WORD es:[di+2], 0           ;base 15:0
            mov BYTE es:[di+4], 0           ;base 23:15 
            mov BYTE es:[di+5], 11111010b   ;present(1)-privilege(00)-alwaysOne(1)-code(1)-non_conforming(0)-readable(1)-beingAccessedRN(0)
            mov BYTE es:[di+6], 11001111b   ;Granularity(1)-size32bit(1)-alwaysZero(00)-limitbits(1111)
            mov BYTE es:[di+7], 0           ;base 31:24
        add di, 8
        userData:
            mov WORD es:[di], 0xffff        ;segment limit
            mov WORD es:[di+2], 0           ;base 15:0
            mov BYTE es:[di+4], 0           ;base 23:15 
            mov BYTE es:[di+5], 11110010b   ;present(1)-privilege(00)-alwaysOne(1)-data(0)-growUpwards(0)-writeable(1)-beingAccessedRN(0)
            mov BYTE es:[di+6], 11001111b   ;Granularity(1)-size32bit(1)-alwaysZero(00)-limitbits(1111)
            mov BYTE es:[di+7], 0           ;base 31:24
        add di, 8
        taskStateSegment:
            mov WORD es:[di], 104
            mov WORD es:[di+2], 0x1000
            mov BYTE es:[di+4], 0
            mov BYTE es:[di+5], 0x89
            mov BYTE es:[di+6], 0x40
            mov BYTE es:[di+7], 0

    lgdt [gdtptr]
    jmp setUpTSS

setUpTSS:
    ;clear destination
    mov cx, 52
    mov di, 0x1000
    xor ax, ax
    rep stosw

    ;set Value of ESP0          (empty stack pointer of kernel level i.e. ring 0)
    mov DWORD es:[di+4], 0x7ffff
    ;set value of SS0           (segment selector offset for kernelData)
    mov WORD  es:[di+8], 0x10
    ;set value of IOBP          (Archaic thing no longer necessary?)
    mov WORD es:[di+108], 104

    ;THE LOADING OF TSS TAKES PLACE IN PROTECTED MODE, NOT REAL MODE, WHICH IS WHY IT WASNT DONE HERE

    jmp loadIDT

loadIDT:
    ;We shall simply reserve 2048 bytes for our IDT, the table can then be filled in once we're in the kernel
    ;Clear out 512 DWORDS from 0x700 - 0xF00
    mov cx, 512
    mov di, 0x700
    xor eax, eax
    rep stosd

    lidt [idtptr]   ;Load
    mov ah, 0x0e
    mov al, "L"
    int 0x10
    jmp end
    ; mov cx, end
    ; mov ah, 0x0e
    ; mov bx, greatSuccess
    ; jmp printMsg
successMessage:
    db 0xa, 0xd, "VBR Booted Succesfully", 0x0a, 0x0d, 0;
greatSuccess:
    db "Great Success", 0xa, 0xd, 0;
idtptr:
    dw 2047     ;Size of table
    dd 0x700    ;Where is it
gdtptr:
    dw 47       ;size(GDT) - 1
    dd 0xF00    ;location of GDT

bootDrive:
    db 0
end:
    db 0
times 5118-($-$$) db 0
dw 0xaa55