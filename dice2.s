/* 
 * dice2.s
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
        mov     r8, r0              @ put 1st result of roll in r8
        mov     r9, r1              @ put 2nd result of roll in r9
        bl      print2dice          @ print ascii art of two dice
        
        mov     r2, r9              @ r2 <- r9
        mov     r1, r8              @ r1 <- r8, for printing

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
