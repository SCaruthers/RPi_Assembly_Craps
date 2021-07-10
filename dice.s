/* 
 * dice.s
 * 
 * Copyright 2021  S. Caruthers
 * 
 * 
 */
 
@ -----------------------------------
@   Data Section
@ -----------------------------------


    .data
    .balign 4

.equ   NUM_DICE,    2
.equ   NUM_ROLLS,   4


newline:        .asciz "\n"
str_format:     .asciz "%s"
roll_message:   .asciz "Rolls:\t%u\t%u\n"
cont_string:    .asciz "Hit Enter to Continue..."

dummy_string:   .space 256

                

@ -----------------------------------
@   Code Section
@ -----------------------------------

    .text
    .global main
    .extern printf
    .extern srand
    .extern rand
    
@ -----------------------------------
@   main: Example to roll some dice
@           param: none
@           returns: nothing
main:

        push    {ip, lr}            @ push return address and ip for alignment

        bl      seedRandom          @ call the function to seed random number
        
        ldr     r0, =cont_string
        bl      printf
        bl      waitEnter        
        bl      clrscrn

        mov     r0, #NUM_DICE       @ set r0 as param # dice to roll 
        mov     r6, #NUM_ROLLS      @ set counter
    loop:
        
        bl      rollDice
        mov     r8, r0
        mov     r9, r1
        bl      print2dice
        
        mov     r2, r9              @ r2 <- r1
        mov     r1, r8              @ r1 <- r0, for printing
        @mov     r1, r6              @ put roll # in r1
        @mov     r2, r0              @ put roll result in r2
        ldr     r0, =roll_message 
        bl      printf
        
        @mov     r1, r6              @ put roll # in r1
        @mov     r2, r0              @ put roll result in r2
        
        sub     r6, #1
        cmp     r6, #0
        bne     loop
        
        pop     {ip, pc}            @ return
        

@ -----------------------------------
@   Code Section -- Subroutines
@ -----------------------------------

@ -----------------------------------
@   seedRandom(): seed the rand number generator
seedRandom:
        @ seed the random number generator
        @ based on the time as a seed.
        push    {r0, r1, lr}    @ protect r0 and r1
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
    
@ -----------------------------------
@   waitEnter(): prompts user to hit Enter, then waits
waitEnter:
        @ param:  expects r0 to point to prompt string
        @ returns nothing, and does not use anything the user inputs
        @ relies on dummy string address to hold user input.
        
        push    {r1-r4, lr}         @ protect some of the registers from printf, scanf 
        
        ldr     r0, =dummy_string     @ point to format for scanf('%s')
        @ldr     r1, =dummy_string   @ point to where to put user input 
        bl      gets 
    
        pop     {r1-r4, pc}
