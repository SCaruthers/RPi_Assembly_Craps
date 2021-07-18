@ 
@ craps.s 
@   Written in ARM Assembly by S. Caruthers, 2021
@   Basic dice game of craps with simple Pass / No Pass betting.
@   Requires functions in dice_functions.s
@
@   Registers used consistently:
@       r6  - current roll value (before payout routines) 
@       r8  - point after come out roll 
@       r9  - payout odds (currently, only 0, 1, or 2)
@       r10 - flag for Pass / NoPass bet (== cur_pass_bet)
@
@   Assemble the program using Gnu C Compiler:
@       gcc -o craps craps.s dice_functions.s
@
@   Execute the program using command:
@       ./craps
@
@   Due to ASCI graphics, the terminal is assumed
@   to be using a monospaced font.


@ -----------------------------------
@   Data Section
@ -----------------------------------

    .data
    .balign 4

@ Assembler Constants:
.equ   NUM_DICE,    2           @ always roll with 2 dice 
.equ   NUM_ROLLS,   1           @ always roll only once
.equ   PASS,        0           @ Flag value for Pass bet
.equ   NO_PASS,     1           @ Flag value for NO Pass bet

@ Strings for messages, printf and scanf formats:

ascii_banner:   .ascii " ██████╗██████╗  █████╗ ██████╗ ███████╗██╗\n"
                .ascii "██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██║\n"
                .ascii "██║     ██████╔╝███████║██████╔╝███████╗██║\n"
                .ascii "██║     ██╔══██╗██╔══██║██╔═══╝ ╚════██║╚═╝\n"
                .ascii "╚██████╗██║  ██║██║  ██║██║     ███████║██╗\n"
                .asciz " ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝\n"
welcome_msg:    .ascii "Welcome to the game of craps!\n\n"
                .ascii "You are starting with $100 in your bank.\n"
                .ascii "With each game, you can bet any whole dollar amount,\n"
                .ascii "up to your entire bank balance.\n\n"
                .asciz "The game ends when you place a $0 bet, or you lose all your money.\n\n"
newline:        .asciz "\n"          
bankBal_str:    .asciz "Your bank balance is\033[1;37m $%d\033[0m.\n"
bet_message:    .asciz "How much do you bet (in whole dollars)? "
bet_invalid:    .asciz "That is an invalid bet!\n"
pass_message:   .ascii "Are you betting that you will have:\n"
                .ascii "\t1. Winning roll (aka, Pass)\n"
                .ascii "\t2. Losing roll (aka, No Pass)\n"
                .asciz "\tEnter the number of your choice: "
roll_winner:    .asciz "That is a winning roll.\n"
roll_loser:     .asciz "That is a losing roll.\n"
roll_tie:       .asciz "That roll is a tie, with no payout.\n"
point_message:  .asciz "That is point.  \nKeep rolling until you get %d or 7.\n"
win_message:    .asciz "You WIN your bet!  You get $%d.\n\n"
lose_message:   .asciz "You LOSE your bet of $%d.\n\n"
roll_message:   .asciz "Your roll is %u.\n"
quit_message:   .asciz "\nOk.\nYou started with $100 and are leaving with $%d.\n%s Thanks for playing!\n\n"
congrats_msg:   .asciz "Congratulations!!"
too_bad_msg:    .asciz "Better luck next time."
cont_string:    .asciz "Hit <Enter> to roll again..."
erase_string:   .asciz "\r                            \n"
bankrupt_msg:   .asciz "You lost all your money!\nBye Bye.\n"
int_format:     .asciz "%d"

wallet:         .word  100      @ amount of money the player has
cur_bet:        .word  0        @ variable for current bet
cur_pass_bet:   .word  0        @ flag for Pass (=0) or no Pass (=1)


@ -----------------------------------
@   Code Section
@ -----------------------------------

    .text
    .global main                    @ make main callable by all

@ -----------------------------------
@   main: Game of craps
@           param: none
@           requires functions in dice_functions.s
@           returns: nothing

main:

        push    {ip, lr}            @ push return address and ip for alignment
        
        mov     r9, #0              @ r9 = zero multiplier for winnings payout

        bl      seedRandom          @ call function to seed random number generator
        bl      clrscrn             @ clear the screen
        
        mov     r0, #3
        mov     r1, #4              @ load "dice" with 3 and 4 for opening graphic
        bl      print2dice
        
        bl      greenText           @ make banner text green
        ldr     r0, =ascii_banner   @ point to graphic banner
        bl      printf 
        
        bl      resetText           @ reset text to default color
        ldr     r0, =welcome_msg    @ point to welcome message to print 
        bl      printf
        
    game_start:
        mov     r8, #0              @ Zero out Point (as flag going into loop)
        bl      print_bank          @ print amount in bank, returns amount in r0
        cmp     r0, #0              @ is the amount $0?
        beq     end_zero_loser      @ You have no money!
        
        bl      get_bet             @ set globals and return bet val (r0), pass (r1)  
        cmp     r0, #0              @ did player bet 0 (i.e., "quit")
        beq     end_quitter         @ if so, jump to quit message  
        mov     r10, r1             @ put Pass bet flag in r10 for working
        
        ldr     r1, =wallet         @ subtract bet (r0) from wallet
        ldr     r2, [r1]
        sub     r2, r0              @ already tested that r0 < r2
        str     r2, [r1]            @ put reduced amount back in wallet
    
    open_roll:
        bl      waitEnter           @ ask for user to continue
        
        mov     r0, #NUM_DICE       @ set r0 as param # dice to roll 
        bl      rollDice            @ returns 2 dice in r0, r1
        mov     r4, r0              @ put 1st result of roll in r4 to save
        mov     r5, r1              @ put 2nd result of roll in r5 to save
        bl      print2dice          @ print ascii art of two dice
        
        mov     r6, r4              @ calc sum of roll
        add     r6, r5              @ in r6 for set point 
        mov     r1, r6              @ and in r1 for printing
        ldr     r0, =roll_message 
        bl      printf
        
        @ Have we rolled already?  If not, process. 
        cmp     r8, #0
        bne     point_compare       @ If r8 <> 0, then skip
        mov     r8, r6              @ if 0, then set the point and continue
        
        @ Check outcome of come out roll.
        @   Natural: 7 or 11 (winning)
        @   Craps: 2, 3, 12 (losing, or tie)
        @   Set Point: anything else (keep Point in r8)
        cmp     r8, #7              @ Natural?
        beq     roll_is_winner  
        cmp     r8, #11
        beq     roll_is_winner
        cmp     r8, #2              @ Craps?
        beq     roll_is_loser
        cmp     r8, #3
        beq     roll_is_loser
        cmp     r8, #12             @ Tie (or not!)
        beq     roll_is_tie
        bal     roll_is_point       @ all else is point (r8), skip
        
    point_compare:
        @ Check outcome of subsequent rolls.
        @   Losing roll: 7
        @   Winning roll: Point (r8)
        @   Anything else: keep rolling.
        cmp     r6, #7              @ Seven Out = Loser
        beq     roll_is_loser
        cmp     r6, r8              @ made Point
        beq     roll_is_winner
        bal     open_roll           @ else, roll again
        

    @ Branches for handling winning and losing rolls.
        
    roll_is_winner:
        ldr     r0, =roll_winner    @ point to winning roll message
        bl      printf
        cmp     r10, #NO_PASS       @ did you bet No Pass?
        beq     no_payout
        mov     r9, #2              @ winning hands pays "even", ie 2x bet
        bal     handle_payout
        
    roll_is_loser:
        ldr     r0, =roll_loser     @ point to winning roll message
        bl      printf
        cmp     r10, #PASS          @ did you bet Pass?
        beq     no_payout           @ if so, go to no payout
        mov     r9, #2              @ No_PASS losing hand pays
        bal     handle_payout
    
    roll_is_tie:
        @ If bet was Pass, then this is a loss
        @ otherwise, it is a tie        
        cmp     r10, #PASS          @ did player bet Pass?
        beq     roll_is_loser       @ if PASS, go to loser, else...
        ldr     r0, =roll_tie       @ point to winning roll message
        bl      printf
        mov     r9, #1              @ if a tie, get back only 1x bet
        bal     handle_payout
        
    roll_is_point:
        ldr     r0, =point_message
        mov     r1, r8
        bl      printf              @ print Point message
        bal     open_roll           @ and roll again
        
    
    handle_payout:
        ldr     r6, =cur_bet        @ put current bet into r6  
        ldr     r6, [r6]   
        mov     r1, r6              @ put it in r1 to printf
        ldr     r0, =win_message
        cmp     r9, #1              @ if it was a tie (r9=1x) then 
        ldreq   r0, =newline        @ replace message with a blank line
        bl      greenText
        bl      printf
        bl      resetText
        mov     r0, r6              @ put bet in r0 to pass to wallet
        mul     r0, r9              @ (bet * payout rate)
        bl      addWallet           @ add total payout to Wallet
        bal     game_start          @ start over with new bet
        
    no_payout:
        ldr     r1, =cur_bet        @ put current bet into r1 for printf
        ldr     r1, [r1]
        ldr     r0, =lose_message   @ point to lose bet message
        bl      redText             @ make following text red
        bl      printf
        bl      resetText           @ reset text to default
        bal     game_start          @ then start over
        
    @ Everything below here is a game exit.
        
    safety_net:
        bal     exit 
    
    end_zero_loser:
        @ player lost all money.
        bl      redText
        ldr     r0, =bankrupt_msg   @ point to loser message 
        bl      printf
        bl      resetText
        bal     exit 
    
    end_quitter:
        @ user bet $0 to quit.
        ldr     r1, =wallet
        ldr     r1, [r1]            @ put bank amount in r1 for printf
        cmp     r1, #100            @ compare to starting value
        ldrge   r2, =congrats_msg   @ if greater, load congrats_msg
        ldrlt   r2, =too_bad_msg    @ if less, load consolation msg
        ldr     r0, =quit_message   @ point to quit message 
        bl      printf
        
        bal     exit 
        
    exit:
        pop     {ip, pc}

@ -----------------------------------
@   Code Section -- Subroutines
@ -----------------------------------

@------------------------------------
@   print_bank -- function to print bank balance
@   
@   inputs:
@       none
@   returns:
@       r0 - the value of the bank balance

print_bank:
        push    {r1-r4, lr}
        
        ldr     r4, =wallet         @ point to wallet to print
        ldr     r1, [r4]            @ load r1 with cont of wallet for printf
        ldr     r0, =bankBal_str    @ point to string for printing
        bl      printf
        ldr     r0, [r4]            @ load r0 with cont of wallet to return
        
        pop     {r1-r4, pc}
        

@------------------------------------
@   get_bet -- function to get bet from user input
@   
@   inputs:
@       none
@   returns:
@       r0 - the value of the bet
@       r1 - the flag for cur_pass_bet
@   sets:
@       global variables cur_bet and cur_pass_bet

get_bet:
        push    {r2-r8, lr}
        
        ldr     r4, =wallet         @ get value of bankBal 
        ldr     r4, [r4]            @ into r4 for comparisons
        
    get_bet_start:
        ldr     r0, =bet_message    @ print prompt for bet
        bl      printf
        ldr     r1, =cur_bet        @ ptr for current bet variable
        ldr     r0, =int_format     
        bl      scanf               @ puts value of bet into [r1]
        ldr     r0, =cur_bet        @ load it back into r0
        ldr     r0, [r0] 
        cmp     r0, #0              @ is bet 0 or negative?
        beq     get_bet_exit        @ if 0, just quit 
        blt     get_bet_invalid     @ if neg, go to error message 
        cmp     r0, r4              @ compare current bet to wallet
        ble     get_bet_pass        @ if bet is < wallet, OK
    get_bet_invalid:
        ldr     r0, =bet_invalid
        bl      printf              @ print error message
        bal     get_bet_start       @ go back and try again
        
    get_bet_pass:
        @ get whether the bet is Pass or No Pass
        @ Ultimately, flag should be 0 (Pass) or 1 (No Pass)
        ldr     r0, =pass_message   @ print prompt for pass / no pass bet
        bl      printf
        ldr     r1, =cur_pass_bet   @ ptr for current bet variable
        ldr     r0, =int_format     
        bl      scanf               @ user response in [r1], but as 1 or 2
        ldr     r2, =cur_pass_bet   @ reload user response in r1
        ldr     r1, [r2]            
        cmp     r1, #2              @ if user responded 2
        moveq   r0, #NO_PASS        @ if yes, set to 1, 
        movne   r0, #PASS           @ else, set to 0.
        str     r0, [r2]            @ and put answer in variable
        
    get_bet_exit:    
        ldr     r0, =cur_bet        @ put value of bet in r0 for return
        ldr     r0, [r0] 
        ldr     r1, =cur_pass_bet   @ put value of flag in r1 for return
        ldr     r1, [r1]
        pop     {r2-r8, pc}


@ -----------------------------------
@ addWallet() - adds value in r0 to bank 
@
@   inputs:
@       r0 - amount to be added to wallet
@   returns:
@       r0 - amount in wallet

addWallet:
        push    {r1-r2, lr}
        
        ldr     r2, =wallet
        ldr     r1, [r2]            @ put amount in wallet into r2
        adds    r1, r1, r0          @ add r0
        movmi   r1, #0              @ if result is negative, make 0 (should not happen)
        str     r1, [r2]            @ store result in variable
        
        ldr     r0, [r2]            @ put amount in r0 for return 
        pop     {r1-r2, pc}


@ -----------------------------------
@ subWallet() - subtracts value in r0 from bank 
@
@   inputs:
@       r0 - amount to be added to wallet
@   returns:
@       r0 - amount in wallet

subWallet:
        push    {r1-r2, lr}
        
        ldr     r2, =wallet
        ldr     r1, [r2]            @ put amount in wallet into r2
        subs    r1, r1, r0          @ add r0
        movmi   r1, #0              @ if result is negative, make 0 (should not happen)
        str     r1, [r2]            @ store result in variable
        
        ldr     r0, [r2]            @ put amount in r0 for return 
        pop     {r1-r2, pc}

        
@ -----------------------------------
@   waitEnter(): prompts user to hit Enter, then waits

waitEnter:
        @ param:  nothing
        @ returns nothing, and does not use anything the user inputs
        @ relies on dummy string address to hold user input.
        
        push    {r0-r6, lr}           @ protect some of the registers from printf, scanf 
        
        ldr     r0, =cont_string
        bl      printf

        bl      getchar
        
        ldr     r0, =erase_string         @ erase the prompt 
        bl      printf
    
        pop     {r0-r6, pc}
        
