@ Various macros to help with debugging

@ These macros preserve all registers.
@ Beware they will change the CPSR

.macro  printReg    reg
        push        {r0-r4, lr}     @ save registers
        mov         r2, R\reg       @ for %d
        mov         r3, R\reg       @ for %x
        mov         r1, #\reg       
        add         r1, #'0'        @ for %c
        ldr         r0, =ptfStr     @ printf format str
        bl          printf          @ call printf
        pop         {r0-r4, lr} 
.endm

.macro  printStr    str 
        push        {r0-r4, lr}     @ save registers
        ldr         r0, =1f         @ load print str
        bl          printf          @ call printf
        pop         {r0-r4, lr}    
        b           2f              @ skip over string
    1:  .asciz      "\str\n"
        .align  4
    2:
.endm

.data
ptfStr: .asciz      "R%c = %16d, 0x%08x\n"
.align 4
.text 
