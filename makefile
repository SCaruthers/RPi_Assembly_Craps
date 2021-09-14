craps: craps.s dice_functions.s debug.s
	gcc -o craps craps.s dice_functions.s

test: test_prt.s 
	gcc -g -o test_prt test_prt.s

pig: pig_dice.s dice_functions.s debug.s
	gcc -g -o pig pig_dice.s dice_functions.s


