/* 
 * print2dice.s
 * 
 * Copyright 2021  S. Caruthers
 * 
 * Subroutine to print two dice
 *
 * Inputs:
 *      r0, r4 - value of 1st die
 *      r1, r5 - value of 2nd die
 *
 * Outputs:
 *      none
 *
 */
 
@ -----------------------------------
@   Text Section
@ -----------------------------------

        .text
        
        .equ    D_COL, 9
        .equ    D_ROW, 5
        
 .global print2dice
 
 print2dice:
                push    {r4-r12, lr}
                
                mov     r4, r0          @ store parmeter die value
                mov     r5, r1          @ store parmeter die value
                sub     r4, #1          @ subtract one for 0 index
                sub     r5, #1          @ subtract one for 0 index
                
                mov     r8, #(D_COL*D_ROW)
                mul     r4, r8              @ calc index of die number
                mul     r5, r8              @ calc index of die number
                
                @ print form feed 
                bl printff
                
                @ for first die
                ldr     r8, =die1               @ point to first die in array
                add     r8, r8, r4              @ point to die to print
                mov     r3, #0                  @ row counter
                
                @ for second die
                ldr     r9, =die1               @ point to second die in array
                add     r9, r9, r5              @ point to die to print
        loop:
                mov     r1, r8                  @ point to 1st die to print
                mov     r2, #D_COL              @ length to print
                mov     r0, #1                  @ stdout
                mov     r7, #4                  @ linux call to print 
                svc     0
                bl      printtab                @ print tab
                
                mov     r1, r9                  @ point to 1st die to print
                mov     r2, #D_COL              @ length to print
                mov     r0, #1                  @ stdout
                mov     r7, #4                  @ linux call to print 
                svc     0
                bl      println                 @ print newline
                
                add     r8, #D_COL              @ inc to next row in first die
                add     r9, #D_COL              @ inc to next row in second die
                add     r3, #1                  @ inc row counter
                cmp     r3, #D_ROW              @ done with all rows?
                bne     loop                    @ if not, continue
                bl      println
                
                
                pop     {r4-r12, pc}
 
 
 @-----------------------------
 @ Subroutine to print newline
 
 println:
                push    {r0-r8, lr}
                ldr     r1, =newline
                mov     r2, #1
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}

 
 @-----------------------------
 @ Subroutine to print tab character
 
 printtab:
                push    {r0-r8, lr}
                ldr     r1, =tabchar
                mov     r2, #1
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}

 @-----------------------------
 @ Subroutine to print form feed character
 
 printff:
                push    {r0-r8, lr}
                ldr     r1, =formfeed
                @ldr     r2, =lenff
                @sub     r2, r2, r1
                mov     r2, #(lenff-formfeed)
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}
                
 
@ -----------------------------------
@   Data Section
@ -----------------------------------


    .data
    .balign 4

die1:           .ascii  " ------- "
                .ascii  "|       |"
                .ascii  "|   o   |"
                .ascii  "|       |"
                .ascii  " ------- "
                
die2:           .ascii  " ------- "
                .ascii  "| o     |"
                .ascii  "|       |"
                .ascii  "|     o |"
                .ascii  " ------- "

die3:           .ascii  " ------- "
                .ascii  "| o     |"
                .ascii  "|   o   |"
                .ascii  "|     o |"
                .ascii  " ------- "

die4:           .ascii  " ------- "
                .ascii  "| o   o |"
                .ascii  "|       |"
                .ascii  "| o   o |"
                .ascii  " ------- "

die5:           .ascii  " ------- "
                .ascii  "| o   o |"
                .ascii  "|   o   |"
                .ascii  "| o   o |"
                .ascii  " ------- "

die6:           .ascii  " ------- "
                .ascii  "| o   o |"
                .ascii  "| o   o |"
                .ascii  "| o   o |"
                .ascii  " ------- "

newline:        .asciz  "\n"
tabchar:        .asciz  "\t"
formfeed:       .asciz  "\033[H\033[2J"
lenff:          .byte   0
