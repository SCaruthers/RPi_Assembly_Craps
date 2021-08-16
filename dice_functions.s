/* 
 * dice_functions.s
 * 
 * Copyright 2021  S. Caruthers
 * 
 * Subroutines for multiple dice game functions
 *      print2dice - to print two dice in ASCII text
 *      println    - prints a newline character
 *      printtab   - prints a tab character
*       printbs    - prints a backspace character
 *      clrscrn    - prints chars to "clear" screen
 *
 *
 */
 
@ -----------------------------------
@   Text Section -- SUBROUTINES
@ -----------------------------------

        .text
        .extern srand                   @ point to external C functions
        .extern rand                    @ so anyone can call it
        .global seedRandom              @ make functions global for others to call        
        .global rollDie
        .global rollDice
        .global print2dice 
        .global print_die   
        .global animate_die          
        .global clrscrn                
        .global redText                 @ subroutines for text attributes:
        .global pinkText        
        .global greenText
        .global yellowText
        .global whiteText
        .global whiteBldText
        .global resetText
        .global printbs
        .global println

.equ    D_COL, 10                       @ # columns in a die
.equ    D_ROW, 5                        @ # rows in a die
.equ    ANI_FRAMES, 20                  @ # frames to an animation of rolling die
.equ    ANI_DELAY, 40                   @ delay time in ms between animation frames
.equ    sys_nanosleep, 162              @ high-resolution sleep interrupt



@-----------------------------
@ msSleep - Macro to sleep ms milliseconds
@                   Input Parameters are ms

.MACRO  msSleep     ms
                push   {r0-r2}
                mov       r2, #\ms
            1:
                ldr       r0, =timespecsec
                ldr       r1, =timespecsec
                mov       r7, #sys_nanosleep
                svc       0
                subs      r2, #1
                bhi       1b
                pop     {r0-r2}
.ENDM



@-----------------------------
@ print_die -- print a die in ASCII text
@
@ Inputs:
@      r0, (r4) - value of die to print
@      r1       - column for die to be printed
@
@ Outputs:
@      none (all registers preserved)

 print_die:
                push    {r0-r8, lr}     @ preserve all registers (including r0, r1!)
                
                bl      yellowText      @ print the dice in yellow 
                mov     r4, r0          @ store parameter die value
                sub     r4, #1          @ subtract one for 0 index
                
                sub     r5, r1, #1      @ store column destination (w zero index)
                
                mov     r8, #(D_COL*D_ROW)
                mul     r4, r8                  @ calc index (ptr to die number)
                
                ldr     r8, =die1               @ point to first die in array
                add     r8, r8, r4              @ point to actual die to print
                mov     r3, #0                  @ initialize row counter
                
                
        print_die_loop:
                ldr     r1, =blankspace         @ point to space chars
                mov     r2, r5                  @ length of spaces to print
                mov     r0, #1                  @ stdout
                mov     r7, #4                  @ linux call to print 
                svc     0
                
                mov     r1, r8                  @ point to 1st die to print
                mov     r2, #D_COL              @ length to print
                mov     r0, #1                  @ stdout
                mov     r7, #4                  @ linux call to print 
                svc     0

                bl      println                 @ print newline
                
                add     r8, #D_COL              @ inc to next row in first die
                add     r3, #1                  @ inc row counter
                cmp     r3, #D_ROW              @ done with all rows?
                bne     print_die_loop          @ if not, continue
                bl      println
                
                bl      resetText               @ return text color to default
                pop     {r0-r8, pc}

@-----------------------------
@ animate_die -- print a die multiple times to simulate rolling
@
@ Inputs:
@      r0 - value of die to print
@      r1 - column for die to be printed
@
@ Outputs:
@      none
@
@ Requires print_die(r0,r1) to be called repeatedly, so preserve r0, r1 as pass through

 animate_die:
                push    {r0-r7, lr}
                
                mov     r4, r0                  @ save original r0 in r4
                mov     r5, r1                  @ save original r1 in r5
                mov     r6, #ANI_FRAMES         @ number of animated frames
                
                cmp     r6, #0                  @ are there 0 frames?
                beq     animate_exit            @ then just exit (last print)
        animate_loop:
                bl      rollDie                 @ put random die # in r0
                mov     r1, r5                  @ restore position of die
                bl      print_die
                                                @ return cursor to top of die
                ldr     r1, =cursor_up_die      @ point to chars to move cursor up
                mov     r2, #(lencup-cursor_up_die)              @ length to print
                mov     r0, #1                  @ stdout
                mov     r7, #4                  @ linux call to print 
                svc     0
                msSleep ANI_DELAY               @ wait for next frame
                
                subs    r6, #1                  @ decrement animation frame counter
                bne     animate_loop            @ loop until 0
                
        
        animate_exit:
                mov     r0, r4                  @ restore original values
                mov     r1, r5  
                bl      print_die               @ and final print.
                pop     {r0-r7, pc}             @ and return

        
@-----------------------------
@ print2dice -- print 2 dice in ASCII text
@
@ Inputs:
@      r0, (r4) - value of 1st die
@      r1, (r5) - value of 2nd die
@
@ Outputs:
@      none

 print2dice:
                push    {r4-r12, lr}
                
                bl      yellowText      @ print the dice in yellow 
                mov     r4, r0          @ store parameter die value
                mov     r5, r1          @ store parameter die value
                sub     r4, #1          @ subtract one for 0 index
                sub     r5, #1          @ subtract one for 0 index
                
                mov     r8, #(D_COL*D_ROW)
                mul     r4, r8              @ calc index (ptr to die number)
                mul     r5, r8              @ calc index (ptr to die number)
                
                @ for first die
                ldr     r8, =die1               @ point to first die in array
                add     r8, r8, r4              @ point to die to print
                mov     r3, #0                  @ row counter
                
                @ for second die
                ldr     r9, =die1               @ point to second die in array
                add     r9, r9, r5              @ point to die to print
        p2d_loop:
                mov     r1, r8                  @ point to 1st die to print
                mov     r2, #D_COL              @ length to print
                mov     r0, #1                  @ stdout
                mov     r7, #4                  @ linux call to print 
                svc     0
                bl      printtab                @ print tab
                
                mov     r1, r9                  @ point to 2nd die to print
                mov     r2, #D_COL              @ length to print
                mov     r0, #1                  @ stdout
                mov     r7, #4                  @ linux call to print 
                svc     0
                bl      println                 @ print newline
                
                add     r8, #D_COL              @ inc to next row in first die
                add     r9, #D_COL              @ inc to next row in second die
                add     r3, #1                  @ inc row counter
                cmp     r3, #D_ROW              @ done with all rows?
                bne     p2d_loop                @ if not, continue
                bl      println
                
                bl      resetText               @ return text color to default
                pop     {r4-r12, pc}
 
@ -----------------------------------
@   seedRandom(): seed the rand number generator
seedRandom:
                @ seed the random number generator
                @ based on the time as a seed.
                push    {r0, r1, lr}    @ protect r0 and r1, just in case
                mov     r0, #0
                bl      time            @ get the time into r0
                mov     r1, r0          @ put time in r1 to pass as param
                bl      srand           @ call c-function srand()
                pop     {r0, r1, pc}    @ return

@ -----------------------------------
@   rollDie(): roll a single die
rollDie:
                @ return a random number (1-6) in r0
                @ called from rollDice, so dont mess with r1-r3!

                push    {r1-r5, lr}     @ protect r4, r5
                mov     r4, #6          @ limit of random number is 6
                mov     r0, #0
                bl      rand 
                mov     r5, #0xFF       @ r5 <- b11111111
                and     r0, r0, r5      @ limit result to 7
                cmp     r0, r4
                blt     r_done          @ if result < limit, then we are done
            r_loop:
                subs    r0, r0, r4      @   keep subtracting r4 until we can no longer
                cmp     r0, r4
                bge     r_loop          @   gives r0 % r4 (remainder) which ranges 0 < r4
            r_done:
                add     r0, r0, #1      @ makes from 1 to 6
                pop     {r1-r5, pc}    @ return


@ -----------------------------------
@   rollDice(r0): roll multiple dice
rollDice:
        @ rolls r0 number of dice (from 1 to 4, 0 returns 1 roll)
        @ return a random number (1-6) in r0, r1, r2, r3
        @ destroys r0 - r3 !! (even if calling r0 < 4)
    
        push    {r6, lr}
        
        mov     r6, r0          @ r6 <- number of dice
        cmp     r6, #4
        movgt   r6, #4          @ r6 <- min(r6, 4)
        
    dice_loop:
        bl      rollDie         @ r0 <- rand # (1-6)
        sub     r6, r6, #1      @ decrement counter
        cmp     r6, #0
        ble     dice_done       @ since user could have passed 0, ble vs bne
        mov     r3, r2          @ shift all the results across registers
        mov     r2, r1
        mov     r1, r0
        bal     dice_loop
    dice_done:
        pop     {r6, pc}

 
 @-----------------------------
 @ println - Subroutine to print newline
 println:
                push    {r0-r8, lr}
                ldr     r1, =newline
                mov     r2, #1
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}

 
 @-----------------------------
 @ printtab - Subroutine to print tab character
 printtab:
                push    {r0-r8, lr}
                ldr     r1, =tabchar
                mov     r2, #1
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}

 @-----------------------------
 @ printbs - Subroutine to print backspace character
 printbs:
                push    {r0-r8, lr}
                ldr     r1, =backsp
                mov     r2, #1
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}

 @-----------------------------
 @ clrscrn - Subroutine to print form feed character
 clrscrn:
                push    {r0-r8, lr}
                ldr     r1, =formfeed
                @ldr     r2, =lenff
                @sub     r2, r2, r1
                mov     r2, #(lenff-formfeed)
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}

@-----------------------------
@ changeText - Macro to change text to given color or reset
@                   Used in following subroutines
@                   Parameters are the color to change to (or reset)
@                   and the length of the control code sequence
.MACRO  changeText      color_str, str_len
                push    {r0-r8, lr}
                ldr     r1, =\color_str
                mov     r2, #\str_len
                mov     r0, #0
                mov     r7, #4
                svc     0
                pop     {r0-r8, pc}
.ENDM

                
@-----------------------------
@ colorText - Subroutines (via macros) to change text to color
redText:
                changeText      redtext_str, (lenredt-redtext_str)
pinkText:
                changeText      pinktext_str, (lenpinkt-pinktext_str)
greenText:
                changeText      greentext_str, (lengrnt-greentext_str)
yellowText:
                changeText      yellowtext_str, (lenylwt-yellowtext_str)
whiteBldText:   
                changeText      whtbldtext_str, (lenwbt-whtbldtext_str)
whiteText:      
                changeText      whitetext_str, (lenwt-whitetext_str)
resetText:
                changeText      resettext_str, (lenrstt-resettext_str)



 
@ -----------------------------------
@   Data Section 
@ -----------------------------------

    .data
    .balign 4

die1:           .ascii  "  ------- "
                .ascii  " |       |"
                .ascii  " |   o   |"
                .ascii  " |       |"
                .ascii  "  ------- "

die2:           .ascii  "  ------- "
                .ascii  " | o     |"
                .ascii  " |       |"
                .ascii  " |     o |"
                .ascii  "  ------- "

die3:           .ascii  "  ------- "
                .ascii  " | o     |"
                .ascii  " |   o   |"
                .ascii  " |     o |"
                .ascii  "  ------- "

die4:           .ascii  "  ------- "
                .ascii  " | o   o |"
                .ascii  " |       |"
                .ascii  " | o   o |"
                .ascii  "  ------- "

die5:           .ascii  "  ------- "
                .ascii  " | o   o |"
                .ascii  " |   o   |"
                .ascii  " | o   o |"
                .ascii  "  ------- "

die6:           .ascii  "  ------- "
                .ascii  " | o   o |"
                .ascii  " | o   o |"
                .ascii  " | o   o |"
                .ascii  "  ------- "
blankspace:     .asciz  "                                        " @ a string of spaces for positioning die
newline:        .asciz  "\n"
tabchar:        .asciz  "\t"
backsp:         .asciz  "\b"
formfeed:       .asciz  "\033[H\033[2J"
lenff:          .word   0           @ must follow formfeed to calc len
redtext_str:    .asciz  "\033[1;31m"
lenredt:        .word   0
pinktext_str:   .asciz  "\033[1;31m"
lenpinkt:       .word   0
greentext_str:  .asciz  "\033[1;32m"
lengrnt:        .word   0
yellowtext_str: .asciz  "\033[1;33m"
lenylwt:        .word   0
whitetext_str:  .asciz  "\033[0;97m"
lenwt:          .word   0
whtbldtext_str: .asciz  "\033[1;97m"
lenwbt:         .word   0
resettext_str:  .asciz  "\033[0m"       @ Sytem Default
lenrstt:        .word   0
cursor_up_die:                          @ create a string of cursor up characters depending on size of die
.REPT    D_ROW+1
                .ascii "\033[F"    
.endr
lencup:         .asciz ""
                .balign 4
timespec:                           @ time structure for sleep
    timespecsec:    .word   0
    timespecnano:   .word   1000000

                .balign 4
                
