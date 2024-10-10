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
    ;Clear out 512 DWORDS from 0x700 - 0xEFF
    mov cx, 512
    mov di, 0x700
    xor eax, eax
    rep stosd

    ;For some reason lidt instruction refused to run, Could not diagnose the issue 
    ;decided to load idt right after the switch, in the kernel

    jmp A20_line


;If A20 is disabled (default behavior in older systems), the address is wrapped around
;i.e 0xFFFF:0x0010 is the same as 0x0000:0x0000
;we will check if this has happened

;In order to do that we
; 1) Push everything on stack (save current state)
; 2) Push the byte at 0x0000:0x0500 and 0xFFFF:0x0510 on the stack
; 3) Write a 0x00 at 0x0000:0x0500
; 4) Write a 0xff at 0xFFFF:0x0510
; 5) check if the byte at 0x0000:0x0500 is 0xff
; If it is, then memory has wrapped around => A20 is disabled
; 6) restore the bytes at both the locations from the stack
; make a conditional jump and restore everything back to previous state

check_a20:     
    pushf
    push ds
    push es
    push di
    push si
 
    cli
    xor ax, ax   ; ax = 0
    mov es, ax
 
    not ax      ; ax = 0xFFFF
    mov ds, ax
 
    mov di, 0x0500
    mov si, 0x0510
 
    mov al, byte [es:di]
    push ax
 
    mov al, byte [ds:si]
    push ax
 
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF
 
    cmp byte [es:di], 0xFF
 
    pop ax
    mov byte [ds:si], al
 
    pop ax
    mov byte [es:di], al
 
    mov ax, 0
    je check_a20_exit
    mov ax, 1

check_a20_exit:
    pop si
    pop di
    pop es
    pop ds
    popf
    cli
    ret
    
 
A20_line:
    ;Check if it is enabled already
    call check_a20
    cmp ax, 1
    je A20success

    ;Try the BIOS method
    mov ax, 0x2401
    int 0x15
    call check_a20
    cmp ax, 1
    je A20success

    
    ;Try enabling it through the keyboard controller
    call keyboardCommandWait
    mov al, 0xad
    out 0x64, al                ;Disable keyboard

    call keyboardCommandWait
    mov al, 0xd0
    out 0x64, al                ;Say I want input

    call keyboardDataWait
    in al, 0x60                 ;get input  
    push eax                    ;store it

    call keyboardCommandWait
    mov al, 0xd1                ;Say I wanna write something
    out 0x64, al

    call keyboardCommandWait
    pop eax
    or al, 2                    ;take the stored input, set the second bit
    out 0x60, al                ;write to the keyboard controller

    call keyboardCommandWait
    mov al, 0xae        
    out 0x64, al                ;Enable keyboard
    
    call check_a20
    cmp ax, 1
    je A20success


    ;Try the fast A20 method
    in al, 0x92
    or al, 2
    out 0x92, al
    call check_a20
    cmp ax, 1
    je A20success
    

    ;If nothing has worked, give up
    jmp A20failure

keyboardCommandWait:
    in al, 0x64
    test al, 2              ;second bit set => it is busy, can't recieve command rn
    jnz keyboardCommandWait
    ret

keyboardDataWait:
    in al, 0x64
    test al, 1              ;first bit set => it has data => lessgoooooo
    jz keyboardDataWait
    ret

A20success:
    mov cx, makeTheSwitch   
    mov ah, 0x0e
    mov bx, A20successMsg
    jmp printMsg

A20failure:
    mov cx, end
    mov ah, 0x0e
    mov bx, A20failureMsg
    jmp printMsg

makeTheSwitch:              ;Switch to 32 bit protected mode
    cli
    mov eax, cr0
    ;or eax, 1
    mov cr0, eax
    ;With that we are officially in protected mode, now we do a jump
    ;To make the processor dump its queue of of prefetched 16 bit instructions
    jmp 0x08:setUpEnvironment


successMessage:
    db 0xa, 0xd, "VBR Booted Succesfully", 0x0a, 0x0d, 0;
A20successMsg:
    db "A20 line enabled successfully", 0xa, 0xd, 0;
A20failureMsg:
    db "A20 line could not be enabled, exiting", 0xa, 0xd, 0;
greatSuccess:
    db "Great Success", 0xa, 0xd, 0;

idtptr:
    dw 0x800    ;Size of table
    dd 0x700    ;Where is it
gdtptr:
    dw 47       ;size(GDT) - 1
    dd 0xF00    ;location of GDT

idtdump:
    dw 0x0
    dd 0x0

bootDrive:
    db 0

[bits 32]
setUpEnvironment:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x2ffff ;Stack location, arbitrary right now (Change)
    

end:
    db 0
times 5118-($-$$) db 0
dw 0xaa55