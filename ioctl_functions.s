/* 
 * ioctl_functions.s
 * 
 * Copyright 2021  S. Caruthers
 * 
 * Subroutines for multiple ioctl functions
 *      print2dice - to print two dice in ASCII text
 *      println    - prints a newline character
 *      printtab   - prints a tab character
 *      printbs    - prints a backspace character
 *      clrscrn    - prints chars to "clear" screen
 *
 *
 */
 
 @ Define my Raspberry Pi
        .cpu    cortex-a53
        .fpu    neon-fp-armv8

@ -----------------------------------
@   Data Sections
@ -----------------------------------

@ -----------------------------------
@   Constants   
@ -----------------------------------

.equ STDIN,  0                           @ Linux input console
.equ STDOUT, 1                           @ Linux output console
.equ EXIT,   1                           @ Linux syscall
.equ READ,   3                           @ Linux syscall
.equ WRITE,  4                           @ Linux syscall
.equ IOCTL,  54                          @ Linux syscall for SYS_IOCTL


.equ TIOCGWINSZ, 0x5413                  @ IOCTL command string for term size

@ -----------------------------------
@       Structure Sizes 
@ -----------------------------------

    .struct 0
term_s_lines:
    .struct term_s_lines + 2
term_s_cols:
    .struct term_s_cols + 2
term_s_filler:
    .struct term_s_filler + 12
term_fin:
 
@ -----------------------------------
@       Initialized data
@ -----------------------------------

.data
szMessResult:              .asciz "Terminal lines : %i  cols : %i \n"
szMessError:               .asciz "\033[31mError in IOCTL.\n"
szCarriageReturn:          .asciz "\n"


/* UnInitialized data */
.bss 
.align 4
stTerminal:     .skip term_fin      @ Terminal structure


@ -----------------------------------
@   Text Section -- and SUBROUTINES
@ -----------------------------------

        .text

        .global getWinSz              @ make functions global for others to call        
        .global checkWinSz


@-----------------------------
@ getWinSz -- perform IOCTL call to get terminal size
@
@ Inputs:
@      none
@      (r2) points to a structure to store Terminal Size
@      Uses defined names above
@
@ Outputs:
@      none (all registers preserved)
@      fills structure stTerminal with rows, columns as 2 byte values

 getWinSz:
        push    {r0-r2, r7, lr}
        mov r0, #STDIN                      @ standard console
        mov r1, #TIOCGWINSZ                 @ IOCTL command to get term info
        ldr r2, =stTerminal                 @ point to terminal structure
        mov r7, #IOCTL                      @ linux sys_ioctl call
        svc 0
                                            @ structure should be populated, but...
        cmp r0, #0                          @ did it return an error?
        bne gws_error_quit                      @ if so, just quit 
                                                @ otherwise, continue to return
        pop     {r0-r2, r7, pc}
        
  gws_error_quit:
        mov r2, r0                         @ save error code in r0 to r2
        ldr r0, =szMessError               @ print the error message
        bl my_print
        mov r0, r2                         @ restore error code to return it to OS
        mov r7, #EXIT                      @ request to exit program, not gracefully!
        svc 0                              @ perform system call


@-----------------------------
@ CheckWinSz -- confirms terminal size is of sufficient size
@
@ Inputs:
@      r0 = minimum # lines
@      r1 = minimum # cols
@
@ Outputs:
@      r0 = 0 for OK, -1 for NOT OK 
@       (all other registers preserved)

 checkWinSz:
        push    {r2-r3, lr}
        
        @ first read the terminal size        
        bl  getWinSz
        
        ldr r2, =stTerminal                 @ point to terminal structure
        
        @ now read lines and cols, comparing to parameters
        ldrh r3, [r2, #term_s_lines]            @ read # lines
        cmp  r3, r0                             @ compare to r1 (min lines)
        blt  cws_not_OK                         @ if less, then not OK
        
        ldrh r3, [r2, #term_s_cols]             @ read # cols
        cmp  r3, r1                             @ compare to r2 (min cols)
        blt  cws_not_OK                         @ if less, then not OK
        
        mov  r0, #0                             @ else, OK, so return 0
        pop     {r2-r3, pc}
        
 cws_not_OK:
        mov r0, #-1                             @ set r0 to -1 for FAIL and return
        pop     {r2-r3, pc}
        


/******************************************************************/
/*     display text of unknown size                               */ 
/******************************************************************/
/* r0 contains the address of the message */
my_print:                                        

    push {r0,r1,r2,r7,lr}                       @ save  registers 
    mov r2,#0                                   @ counter length */
1:                                              @ loop length calculation
    ldrb r1,[r0,r2]                             @ read octet start position + index 
    cmp r1,#0                                   @ if 0 its over
    addne r2,r2,#1                              @ else add 1 in the length
    bne 1b                                      @ and loop 
                                                @ so here r2 contains the length of the message 
    mov r1,r0                                   @ address message in r1 
    mov r0,#STDOUT                              @ code to write to the standard output Linux
    mov r7, #WRITE                              @ code call system "write" 
    svc #0                                      @ call system
    pop {r0,r1,r2,r7,lr}                        @ restore registers
    bx lr                                       @ return


