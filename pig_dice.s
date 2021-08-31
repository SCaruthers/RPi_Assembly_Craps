@ 
@ pig_dice.s 
@   Written in ARM Assembly by S. Caruthers, 2021
@   Basic dice game of Pig
@   Requires functions in dice_functions.s
@
@   Registers used consistently:
@       r5  -  Current player total score (banked + hand)
@       r6  -  Current Player: 0 = Human, 1 = Computer
@
@   Assemble the program using Gnu C Compiler:
@       gcc -o pig pig_dice.s dice_functions.s
@
@   Execute the program using command:
@       ./pig
@
@   Due to ASCI graphics, the terminal is assumed
@   to be using a monospaced font and is at least 
@   50 cols wide by 28 rows tall.

@ Define my Raspberry Pi
        .cpu    cortex-a53
        .fpu    neon-fp-armv8

@ -----------------------------------
@   Constants
@ -----------------------------------

.equ STDOUT, 1                           @ Linux output console
.equ EXIT,   1                           @ Linux syscall
.equ WRITE,  4                           @ Linux syscall
.equ sys_nanosleep, 162                  @ high-resolution sleep
.equ HUMAN, 0                            @ Flag for Human Player
.equ ROLL, 1                             @ Flag to roll again
.equ HOLD, 2                             @ Flag to hold and bank hand 


@ -----------------------------------
@   Data Section
@ -----------------------------------

    .data
    .balign 4

@ Strings for messages, printf and scanf formats:

ascii_banner1:
                  .ascii "     _     _.....__     _   _       \n"
                  .ascii "  '-(-'  .'        '.  | \\_/ |      \n"
                  .ascii "     `'-/            \\/       \\     \n"
                  .ascii "       |              `    6 6 |_   \n"
                  .ascii "       |                      /..\\  \n"
                  .ascii "        \\         |         ,_\\__/  \n"
                  .ascii "         /       /     /  __.--'    \n"
                  .ascii "        <     .-;'----`\\  \\ \\       \n"
                  .ascii "         \\   \\  \\       \\  \\ \\      \n"
                  .asciz "          \\___\\__\\       \\__\\_\\     \n\n"
ascii_banner2:
                  .ascii "           ██████╗ ██╗ ██████╗     \n"
                  .ascii "           ██╔══██╗██║██╔════╝     \n"
                  .ascii "           ██████╔╝██║██║  ███╗    \n"
                  .ascii "           ██╔═══╝ ██║██║   ██║    \n"
                  .ascii "           ██║     ██║╚██████╔╝    \n"
                  .asciz "           ╚═╝     ╚═╝ ╚═════╝     \n\n"
welcome_msg:      .ascii "\033[1;97mWelcome to the Dice Game of Pig!!\n\033[0m"
                  .ascii "The goal is to be the first to total 100 points.\n"
                  .ascii "Points are earned by rolling the die repeatedly.\n"     
                  .ascii "For each roll, the amount is added to the total\n"
                  .ascii "for the hand.  You can HOLD at any time to lock in\n"
                  .ascii "the total for the hand.  But if you roll a 1, you\n"
                  .ascii "lose the points for the hand.  Keep repeating\n"
                  .asciz "until the banked total is 100 or more.\n\n"
cont_string:      .asciz "Hit <Enter> to continue..."
human_turn_str:   .asciz "    Human's Turn             \n\n"
comp_turn_str:    .asciz "    Computer's Turn          \n\n"
comp_think_str:   .asciz "    Computer is rolling...   \n\033[K\n\033[K\n\033[K"
comp_holds_str:   .asciz "    Computer holds...        \n\033[K\n\033[K\n\033[K"
human_win_msg:    .asciz "\033[20;1H\007\033[1;32m\n\n            !! You Win !!\n\n"
comp_win_msg:     .asciz "\033[20;1H\033[1;31m\n\n            Computer Wins\n\n"
erase_string:     .asciz "\033[F\033[K \n"   @ go to previous line & delete it
int_format:       .asciz "%d"
roll_choice_str:  .ascii "What would you like to do?\n"
                  .ascii "1. Roll Again                  \n"
                  .ascii "2. Hold and Bank Hand          \n"
                  .asciz "   Enter the # of your choice: "
roll_choice:      .int   0

   @ Constructs for player score printout.
   @ _asc is actually the location to write the value as ascii string.
plyr_score:       .int  0          @ actual int values of scores
comp_score:       .int  0          @ for player and computer
hand_score:       .int  0
plyr_score_str:   .ascii "\033[12;5HYour Score: "
plyr_score_asc:   .asciz "0      "
plyr_score_prog:  .ascii "\033[12;23H"
plyr_score_bar:   .asciz "|----------|"
comp_score_str:   .ascii "\033[13;5HComp Score: "
comp_score_asc:   .asciz "0      "
comp_score_prog:  .ascii "\033[13;23H"
comp_score_bar:   .asciz "|----------|\n"
curr_play_window: .asciz "\033[14;1H"
curr_hand_str:    .ascii "\033[19;12HCurrent Hand: "
hand_score_asc:   .asciz "0      "    
query_window:     .asciz "\033[21;1H"


timespec:                           @ time structure for sleep
    timespecsec:    .word   0
    timespecnano:   .word   1000000

@ -----------------------------------
@   Code Section
@ -----------------------------------

    .text
    .global main                    @ make main callable by all

@ -----------------------------------
@   Code Section -- MACROS
@ -----------------------------------

@-----------------------------
@ modulo - Macro to calculate the remainder between two numbers
@                   Input Parameters are
@                       the dividend register (numerator) and 
@                       the divisor register (denominator)
@                   Output Parameter
@                       r0 : the return register (to hold remainder) 

.MACRO  modulo      dividend, divisor
                udiv     r0, \dividend, \divisor @ calculate qutotient -> r0
                mul      r0, r0, \divisor        @ temp to find remain -> r0
                sub      r0, \dividend, r0       @ remainder -> r0
.ENDM

@-----------------------------
@ msSleep - Macro to sleep ms milliseconds
@                   Input Parameters are ms

.MACRO  msSleep     ms
                push      {r0-r2,r7}
                mov       r2, #\ms
            1:
                ldr       r0, =timespecsec
                ldr       r1, =timespecsec
                mov       r7, #sys_nanosleep
                svc       0
                subs      r2, #1
                bhi       1b
                pop       {r0-r2,r7}
.ENDM

@ -----------------------------------
@   Code Section -- Main
@ -----------------------------------

@ -----------------------------------
@   main:  Dice game of PIG
@           param: none
@           requires functions in dice_functions.s
@           returns: nothing

main:

        push    {ip, lr}            @ push return address and ip for alignment
        
         @ Initialize things:
         bl     seedRandom          @ call function to seed random number generator
         bl     clrscrn             @ clear the screen

         @ Print Banner and Welcome Message:
         bl     pinkText            @ make banner text pink
         ldr    r0, =ascii_banner1  @ point to graphic banner part 1
         bl     my_print            @ and print it.
         ldr    r0, =ascii_banner2  @ point to graphic banner part 2
         bl     my_print            @ and print it.
        
         bl     resetText            @ make Welcome text system default
         ldr    r0, =welcome_msg     @ point to the welcome message
         bl     my_print

         bl     waitEnter           @ wait for user to clear welcome screen

         @ Print Inital Score Screen Banner:
         bl     clrscrn             @ clear the screen
         bl     pinkText            @ make banner text pink
         ldr    r0, =ascii_banner1  @ point to graphic banner part 1
         bl     my_print            @ and print it.
         bl     resetText           @ return to system default font

         @ Initialize Progress Bars & Print Scores...
         bl     update_human_score  @ ...for human
         bl     update_comp_score   @ ...and computer
         
         
   top_loop:
   
         @ Randomly choose first player by rolling die.
         @ If 1-3, the Human goes first, else, Computer
         @ Then print who it is
         
         bl    rollDie               @ r0 gets value 
         cmp   r0, #3
         movle r6, #HUMAN            @ if <= 3, then Human (0)
         movgt r6, #(HUMAN+1)        @ if >3, then Computer (1)

   new_player_loop:
         bl    println
         cmp   r6, #HUMAN           @ Depending on which player
         ldreq r0, =human_turn_str  @ pick the right string
         ldrne r0, =comp_turn_str   
         bleq  greenText            @ make text green for human, and
         blne  pinkText             @ pink for computer
         bl    my_print             @ and print it.
         bl    resetText
         
         bl    waitEnter
         
         @ zero out current hand score before starting
         bl    zero_hand_total
         
         @ Get current player score into r5 to check for running total > 100
         cmp   r6, #HUMAN
         ldreq r5, =plyr_score      @ point to the right variable
         ldrne r5, =comp_score
         ldr   r5, [r5]             @ load score into r5
         
   curr_hand_loop:
         ldr   r0, =curr_play_window
         bl    my_print             @ move cursor to same spot each time 
         
         bl    rollDie              @ roll a Die and put value in r0
         
         @ Print the die (with animation):
         mov   r1, #14              @ column to put die into
         bl    animate_die
         
         cmp   r0, #1               @ was the roll a 1?
         beq   quit_hand            @ if so, this hand is over
                                    @ else,
         add   r5, r5, r0           @ add roll to temporary running total Score
         bl    calc_hand_total      @ add this roll to the current hand and return in r0 
         bl    print_hand_score
         
         @ Has player reached 100? If so, end play
         cmp   r5, #100             @ has player exceeded 100 for the win?
         bge   its_a_winner         @ If so, quit 
         
         @ Get player decision to bank or roll 
         mov   r0, r6               @ put current player into r0 for call
         bl    get_action_choice    @ go to general routine to get choice in r0:
                                    @ 1 means keep rolling (#ROLL)
                                    @ 2 means bank and quit (#HOLD)
         cmp   r0, #HOLD
         beq   hold_bank_hand       @ if 2, bank it                            
 
         bal   curr_hand_loop       @ else, roll again
         
   hold_bank_hand:
         mov   r0, r6            @ put current player in r0
         bl    update_player_score
         
   quit_hand:      
         msSleep  500                  @ pause 1/2 sec
         bl    zero_hand_total
         bl    print_hand_score
         ldr   r0, =(erase_string+3)   @ point to erase to end of line
         bl    my_print
         
         eor   r6, r6, #1              @ XOR with 1 to toggle Player
         bal   new_player_loop
         
   its_a_winner:
         mov   r0, r6                  @ put current player into r0
         bl    update_player_score
         bl    show_winner_message     @ print the right message
         
         msSleep 2000                  @ wait 2s in case calling window will close
         pop   {ip, pc}

 
@ -----------------------------------
@   Code Section -- Subroutines
@ -----------------------------------

@ -----------------------------------
@   waitEnter(): prompts user to hit Enter, then waits

waitEnter:
        @ param:  nothing
        @ returns nothing, and does not use anything the user inputs
        @ relies on two strings in memory.  One for the prompt, the other to erase it.
        
        push    {r0-r4, lr}             @ protect some of the registers 
        
        ldr     r0, =cont_string        @ print the prompt string
        bl      my_print

    wait_char_loop:
        bl      getchar
        cmp     r0, #0x0A               @ did user type more than <enter> ?
        bne     wait_char_loop          @ keep reading characters until CR.
        
        ldr     r0, =erase_string       @ erase the prompt 
        bl      my_print
    
        pop     {r0-r4, pc}
        

@ -----------------------------------
@   display text using svc (with size calculation)         
       
my_print:
      @ param: r0 contains the address of the null-terminated string
      @ returns nothing
      
       push    {r0,r1,r2,r7,lr}                 @ save  registers 
       mov     r2,#0                            @ counter length */
  my_print_loop:                                @ loop length calculation
       ldrb    r1,[r0,r2]                       @ read octet start position + index 
       cmp     r1,#0                            @ if 0 it is over
       addne   r2,r2,#1                         @ else add 1 to the length
       bne     my_print_loop                    @ and loop 
                                                @ so here r2 contains the length of the message 
       mov     r1,r0                            @ address message in r1 
       mov     r0, #STDOUT                      @ code to write to the standard output Linux
       mov     r7, #WRITE                       @ code call system "write" 
       svc #0                                   @ call system
       pop     {r0,r1,r2,r7,pc}                 @ restore registers & return


@ -----------------------------------
@     convert an unsigned int into ascii string  

my_itoa:               
      @ Input:                                                         
      @      r0 contains the integer                                   
      @      r1 contains the address of buffer for string output              
      @ Output:                                                        
      @      r0 contains # of characters in string                     
      @      [r1] address of buffer contains null terminated string    
      @ Warning:                                                       
      @      r1 must point to an address with enough allocated memory  
      @      such that it can hold a string long enough for the number 
      @      of digits in the int to be converted.                     
      @      No error checking for this is present!!                   

        push    {r1-r5, lr}
        mov     r2, #10                     @ use base 10 
        mov     r3, r0                      @ hold the number 
        mov     r4, r1                      @ hold the buffer address 
        mov     r5, #1                      @ counter for num chars
    itoa_loop1:
        modulo  r3, r2                      @ get remainder in r0
        add     r0, r0, #'0'                @ add to ascii '0'
        push    {r0}                        @ least sig digit, save it
        udiv    r3, r3, r2                     
        cmp     r3, #0
        beq     itoa_quit                   @ if result is zero, done extracting
        add     r5, #1                      @ otherwise, add one to counter
        bal     itoa_loop1                  @ and go do another digit
    itoa_quit:
        mov     r0, r5                      @ first save the count of digits to return
    itoa_loop2:
        pop     {r3}                        @ get the saved digits and 
        strb    r3, [r4],#1                 @ put into buffer, inc pointer
        subs    r5, #1                      @ decrement digit count
        beq     itoa_exit                   @ if zero, we are done so exit 
        bal     itoa_loop2                  @ otherwise get the next
    itoa_exit:
        mov     r3, #0
        strb    r3, [r4]                    @ put a null terminator 
        pop     {r1-r5, pc}

@ -----------------------------------
@     update the Current Player Score and Display it

update_player_score:
   @ Params:   
   @     r0 - Current Player, 0 = Human, 1 = Computer (typically from r6)
   @ Outputs:
   @     Returns nothing
   @     Updates the global variable for the Player Score
   @     then, calls the appropriate subrouting to update screen
   @
   @  Protects all registers, including r0
   
         push     {r0-r4, lr}
         
         @ First retrieve the score for current hand 
         ldr      r4, =hand_score
         ldr      r4, [r4]
         
         @ now figure out which player and go to that section
         cmp      r0, #HUMAN              @ if player is NOT human (0),
         bne      comp_player_calc        @ then go to comp section,
                                          @ otherwise continue to human
      human_player_calc:
         @ add current score to players total score, then update screen
         ldr      r1, =plyr_score         @ player is human
         ldr      r2, [r1]                @ get player score
         add      r2, r2, r4              @ add current hand to it
         str      r2, [r1]                @ put it back to memory
         bl       update_human_score      @ then update screen
         bal      exit_update_player_score
      
      comp_player_calc:
         @ add current score to players total score, then update screen
         ldr      r1, =comp_score         @ player is computer
         ldr      r2, [r1]                @ get player score
         add      r2, r2, r4              @ add current hand to it
         str      r2, [r1]                @ put it back to memory
         bl       update_comp_score       @ then update screen
         
      exit_update_player_score:
         pop      {r0-r4, pc}

@ -----------------------------------
@     update the Score and progress bar for Human Player

update_human_score:
   @ Params: none, but relies on global variables of plyr_score and bar
   @ Returns nothing, but updates screen with Player current score and progress bar
   
         push   {r0-r1, lr}
         
         @ Update Progress Bars & Print Scores (after converting int to ascii):
         ldr    r0, =plyr_score
         ldr    r0, [r0]               @ put score into r0, and
         ldr    r1, =plyr_score_bar    @ progress bar into r1
         bl     update_progress_bar

         ldr    r1, =plyr_score_asc    @ point to score string
         bl     my_itoa                @ assume r0 still holds score!

         ldr    r0, =plyr_score_str    @ point to player score string construct
         bl     my_print
         ldr    r0, =plyr_score_prog   @ point to progress bar
         bl     my_print
         
         pop    {r0-r1, pc}


@ -----------------------------------
@     update the Score and progress bar for Computer Player

update_comp_score:
   @ Params: none, but relies on global variables of comp_score and bar
   @ Returns nothing, but updates screen with Computers current score and progress bar
   
         push  {r0-r1, lr}
         
         ldr    r0, =comp_score
         ldr    r0, [r0]               @ put score into r0, and
         ldr    r1, =comp_score_bar    @ progress bar into r1
         bl     update_progress_bar

         ldr    r1, =comp_score_asc    @ point to score string
         bl     my_itoa                @ assume r0 still holds score!

         ldr    r0, =comp_score_str    @ point to comp score str construct
         bl     my_print
         ldr    r0, =comp_score_prog   @ point to progress bar
         bl     my_print
         
         pop   {r0-r1, pc}


@ -----------------------------------
@     update the Score progress bar

update_progress_bar:
      @ Params:
      @      r0 contains the score                                    
      @      r1 contains the address of the string with progress bar to be updated 
      @ Returns nothing and preserves all registers
      
      @ Progress bar is a string of 12 characters.
      @ Char [0] and [11] are the end points, Chars [1] - [10] are % progress markers
      @ Since winning score is 100, there is 1 marker per 10 points.
      @ Bar extends per decade at 11, 21, etc.  
      @ At game end, there is an exception that bar should be 100% at r0=100
      
         push     {r0-r4, lr}
         
         mov      r3, #0                     @ reset counter for # of 10s
         mov      r4, #'#'                   @ hold character for progress bar
   
         @ count the number of "tens" in the score.
         @ but first, check the special case of r0 = 100
         
         cmp      r0, #100                   @ is score exactly 100?
         bne      upb_count_loop             @ if not, then do the right thing
         mov      r3, #10                    @ if it is, just set the bar to 10
         bal      upb_update_loop            @ and quit.
         
   upb_count_loop:
         subs     r0, #10                    @ subtract 10 from score
         ble      upb_done_count             @ if <= 0, then we are done
         add      r3, r3, #1                 @ otherwise, add one to counter
         cmp      r3, #10                    @ Error check: if already 10, 
         beq      upb_done_count             @ ...then quit 
         bal      upb_count_loop             @ else, go back and repeat
   
   upb_done_count:
         cmp      r3, #0                     @ if counter is 0, nothing to do
         beq      upb_exit
   
   upb_update_loop:
         strb     r4, [r1, r3]               @ put "progress" char at location r3 inside string
         subs     r3, #1                     @ then decrement counter and repeat...
         bne      upb_update_loop            @ if not equal to 0
      
   upb_exit:
         pop      {r0-r4, pc}

@ -----------------------------------
@     Update the total of current Hand

calc_hand_total:
   @ Params:
   @        r0 contains the current roll to add to the sum
   @        uses global addresses for:
   @           int hand_score
   @           string hand_score_asc
   @ Returns:
   @        r0 contains the new total for the hand, 
   @           also updates the glogal variables
   
         push     {r1-r2, lr}              @ protect everything except r0
      
         ldr      r1, =hand_score          @ point to current score
         ldr      r2, [r1]                 @ and put it in r2
      
         add      r0, r0, r2               @ add current roll to current sum
         mov      r2, r0                   @ store a copy in r2
      
         str      r0, [r1]                 @ put it back in global
         ldr      r1, =hand_score_asc      @ point to string global of score
         bl       my_itoa                  @ and put the new sum, r0, in

         mov      r0, r2                   @ move it back to r0 for return 
         pop      {r1-r2, pc}
      
@ -----------------------------------
@    Zero out the total of current Hand

zero_hand_total:
   @ Params:
   @     none
   @ Returns nothing
   
         push  {r0-r1, lr}
         mov   r0, #0
         ldr   r1, =hand_score            @ store 0 in hand_score int variable
         str   r0, [r1]
         ldr   r1, =hand_score_asc
         bl    my_itoa                    @ and in the string variable
         pop   {r0-r1, pc}
         
@ -----------------------------------
@    Print out the total of current Hand
         
print_hand_score:
         push  {r0-r1, lr}
         bl    whiteBldText         
         ldr   r0, =curr_hand_str   @ point to string for current hand score
         bl    my_print
         bl    resetText
         ldr   r0, =(erase_string+3)   @ point to erase to end of line
         bl    my_print

         pop   {r0-r1, pc}

@ -----------------------------------
@     General subroutines to get decision to bank or roll

get_action_choice:
   @ Params: 
   @     r0 - current player (from r6)
   @ Returns:
   @     r0 - Choice (1 to roll, 2 to hold)
   @     Independent of player (Human or Computer)

         push  {r1-r2, lr}
         cmp   r0, #HUMAN           @ is the current user Human?
         beq   gac_human            @ if yes, go ask the results
         bne   gac_computer         @ else, go get computer response
    
   gac_human:
         bl    get_user_choice      
         bal   gac_exit
   gac_computer:
         bl    get_comp_choice      
         
   gac_exit:
         @ r0 should have the choice
         pop   {r1-r2, pc}

@ -----------------------------------

get_user_choice:
         push  {r1-r2, lr}
         
   guc_loop:
         @ Ask user to bank or roll again
         ldr   r0, =query_window    @ point to string to locate quesitons
         bl    my_print 
         ldr   r0, =roll_choice_str @ point to string to ask what to do
         bl    my_print 
         
         @ get choice into global variable
         ldr     r1, =roll_choice    @ ptr for answer
         ldr     r0, =int_format     
         bl      scanf               @ user response in [r1], (get it later)
         
   clear_buffer:                     @ scanf leaves \n in buffer, so
         bl      getchar             @ go through the buffer, before exit
         cmp     r0, #0x0A           @ is it a CR ?
         bne     clear_buffer        @ keep reading characters until CR.

         @ Erase the questions
         ldr   r0, =query_window
         bl    my_print
         ldr   r0, =(erase_string+3)   @ point to erase to end of line
         bl    my_print 
         bl    my_print
         bl    my_print
         bl    my_print
         bl    my_print

         @ get user choice back in r0 to return
         ldr   r0, =roll_choice
         ldr   r0, [r0]
         
         @ do some error checking
         cmp   r0, #0                  @ if <= 0, error.  
         ble   guc_loop                @ ask again
         cmp   r0, #2                  @ if >2, error
         bgt   guc_loop                @ ask again
         
         pop   {r1-r2, pc}             @ otherwise, just return
         
@ -----------------------------------

get_comp_choice:
         push  {r1-r3, lr}
         
         @ Print a message about computer turn
         ldr   r0, =query_window    @ point to string to locate message
         bl    my_print 
         ldr   r0, =comp_think_str @ point to string to print
         bl    my_print 
         msSleep  400
         
         @ Read the global variables of interest
         ldr   r1, =hand_score   @ get current hand...
         ldr   r1, [r1]          @ into r1
         ldr   r2, =comp_score   @ get computers score...
         ldr   r2, [r2]          @ into r2
         ldr   r3, =plyr_score   @ get opponent score...
         ldr   r3, [r3]          @ into r3.
         
         @ Here is the logic to roll or hold:
         @ Generally, hold if hand is >20.
         @ But, if opponent is about to win, always roll (within reason).  
             
         @@ Check if this is a long roll streak and never go beyond 48!
         cmp   r1, #48           @ do not press your luck beyond 48
         movge r1, #HOLD         @ If curr hand >= 48, hold 
         bge   gcc_logic_done    @ and exit 
               
         @@ Check if opponent is about to win...
         cmp   r3, #90           @ if opponent will win next hand,  
         movge r1, #ROLL         @ then set choice to roll 
         bge   gcc_logic_done    @ and exit 
                  
         @@ Check if my score is low, and be slightly more aggressive
         @@ Otherwise, always hold when roll gets to 20
         cmp   r2, #10           @ if comp score is < 10, 
         movle r3, #25           @   then keep rolling until 25
         movgt r3, #20           @   otherwise, use 20 as the cut off
         cmp   r1, r3            @ is it the threshold set above?
         movlt r1, #ROLL         @ if <20, roll again
         movge r1, #HOLD         @ if >=20, bank it
         
      gcc_logic_done:
         cmp   r1, #ROLL         @ if not rolling, print hold message
         beq   skip_hold_msg
         ldr   r0, =query_window
         bl    my_print
         ldr   r0, =comp_holds_str     @ point to computer holding str...
         bl    my_print
         msSleep  1000
         
   skip_hold_msg:      
         @ Erase the message
         ldr   r0, =query_window
         bl    my_print
         ldr   r0, =(erase_string+3)   @ point to erase to end of line
         bl    my_print 
         bl    my_print
         bl    my_print
         bl    my_print

         mov   r0, r1            @ put choice from r1 into r0 to return
         
         pop   {r1-r3, pc}

@ -----------------------------------
@    Print out the WINNER message for current player (in r0)
 
show_winner_message:
   @ Params:
   @     r0 - has the value for player (from r6)
   @ Returns nothing, but prints message to screen
         push  {r0-r1, lr}

         cmp   r0, #HUMAN
         ldreq r0, =human_win_msg
         ldrne r0, =comp_win_msg
         bl    my_print
         bl     resetText  

         pop   {r0-r1, pc}
