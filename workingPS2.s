/*  Elevator control program
	global registers:
	r5 
	r15 
	r17 safety flag, set via gpio, unset via successful safety unset
	r18 previous push button value is copied here if we arrive from the LEGO triggered safety interrupt
	r20 direction of motors - inferred from current/wanted floor logic -> lego init call takes r20 as the parameter
	r21 push button value
	r22 floor now = "previous" push button value, stored in binary
	r23 timer snapshot remaining value -> timer call takes r4 as the parameter
	*/


#define constants for interrupts
.equ ADDR_JP1, 0xFF200060   # Address GPIO JP1 -> LEGO address
#.equ stackP, 0x80000000     #the stack address
.equ TIMER_0_BASE, 0xFF202000  #all the timer addresses
#.equ  TIMER0_STATUS,    0
#.equ  TIMER0_CONTROL,   4
#.equ  TIMER0_PERIODL,   8
#.equ  TIMER0_PERIODH,   12
#.equ  TIMER0_SNAPL,     16
#.equ  TIMER0_SNAPH,     20
#.equ  TICKSPERSEC,      100000
.equ PUSH_BUTTONS_BASE, 0xFF200050

#vga addresses
.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000

#ps/2
.equ PS2_ADDR, 0xFF200100
.equ PS2_CTRL, 0x10000104

#.equ CYCLE, 1000
.equ SECOND, 50000000#50000000
.equ TWO_SECONDS, 100000000#100000000
.equ NULL, 00000000

#.equ ADDR_JP1_IRQ, 0x800


#interrupt routine
	.section .exceptions, "ax"
myISR:
	addi	sp, sp, -132
	stw		ea, 0(sp)
	stw		et, 4(sp)
	stw		r2, 12(sp)
	stw		r3, 16(sp)
	stw		r4, 20(sp)
	stw		r6, 28(sp)
	stw		r7, 32(sp)
	stw		r8, 36(sp)
	stw		r9, 40(sp)
	stw		r10, 44(sp)
	stw		r11, 48(sp)
	stw		r12, 52(sp)
	stw		r13, 56(sp)
	stw		r14, 60(sp)
	stw		ra, 68(sp)
	stw		r16, 72(sp)
	stw		r19, 84(sp)
	
	#check which interrupt
	rdctl	r16, ctl4
	andi	r16, r16, 0x1	#check for IRQ0, paramount priority, timer
	bne		r16, r0, TIMER_0_ISR
	
	rdctl	r16, ctl4
	andi	r16, r16, 0x2	#check for IRQ1, PUSH_BUTTONS
	bne		r16, r0, PUSH_BUTTONS_ISR
	
	rdctl	r16, ctl4
	andi	r16, r16, 0x80	#check for IRQ1, PUSH_BUTTONS
	bne		r16, r0, PS2_ISR
	
	rdctl	r16, ctl4
	andi	r16, r16, 0x800	#check for IRQ 11, GPIO 1
	bne		r16, r0, GPIO_1_ISR

GPIO_1_ISR: #LEGO
#if here means safety sensor got triggered
	#ack interrupt
	movia	r16, ADDR_JP1
	movia	r13, 0xFFFFFFFF 
	stwio	r13, 12(r16)#writing to the edge capture register, suppose to 1 it all to ack
	
	#halt
	movia r13, 0xFFDFFFFF
	movia	r16, ADDR_JP1
	stwio r13, 0(r16)
	
	
	#stop timer, will we still read snapshot correctly? yes it will
	movia	r8, TIMER_0_BASE
	movi	r9, 0b1000
	stwio	r9, 4(r8)
	stwio	r0, 0(r8)
	
	#set flag to triggered
	movi r17, 1
	
	#store the previous push button value for which floor logic for later on
	movi r16, 0b1000 #dont update if r21 (Current pb value) holds the safety button keycode
	beq r21, r16, skip
	mov r18, r21#save previous push button value (Desired floor) to the global r18
	
skip:
	#poll timer to know snapshot value -> safety triggered  
	#store remaining time
	stw ra, 116(sp)
	
	call CHECK_TIMER_SNAPSHOT
	
    ldw ra, 116(sp)
	
	br END_ISR
	
	
TIMER_0_ISR:
	#disable LEGO
	movia  r8, ADDR_JP1     	        # init pointer to JP1
	movia  r9,  0xFFDFFFFF      # disable everything + switch to state mode. interrupts have not been enabled yet
    stwio  r9,  0(r8)
    
	#Reading the current value of the timer into R23
	stw ra, 100(sp)
	
	call CHECK_TIMER_SNAPSHOT
	
    ldw ra, 100(sp)	
	
	
	stw ra, 120(sp)
	
	#updates the current floor
	call CHECK_PB
	
    ldw ra, 120(sp)
	
	# ack interrupt
	movia	r16, TIMER_0_BASE
	stwio	r0, 0(r16)
		
	br	END_ISR
	
PUSH_BUTTONS_ISR:
	#store push button value
	movia r2, PUSH_BUTTONS_BASE
    ldwio r21, 12(r2)   # Read in buttons - active high from edge capture register

	stwio	r21, 12(r2) # Clear edge capture register to prevent unexpected interrupt

    #Reading the current value of the timer into R23
	#if PB0-2 are pressed after an unclean exit everything breaks
	
	#unnecessary, but lets leave for now, is it really? check later<24>
	stw ra, 104(sp)
	
	call CHECK_TIMER_SNAPSHOT
	
    ldw ra, 104(sp)	
	#addi sp, sp, 4
	
	#if snapshot has value -> go to safety
	movia r2, 0x02FAF080#sec
	beq r23, r2, continue
	movia r2, 0x05F5E100#2 sec
	beq r23, r2, continue
	
	#beq r23, r17, continue#safety value check
	beq r23, r0, continue#checking remaining timer value, probably unneeded, check - <
	beq r17, r0, continue#if flag = 0 continue
	#there will be a case where timer has an unclean value but jump should happen via r17 = 0
	br safety
	#if 0, clean exit, do below
	
continue:	
	#WHICH push button
	#r13 is temp, holding the pre-defined value for pre-defined floors
	movi r13,0b0001	#we need to something to compare against
	beq r21,r13, PB_ONE	#comparison and jump
	#andi r3, r21, 0x2
	movi r13,0b0010
	beq r21,r13, PB_TWO
	#andi r3, r21, 0x4
	movi r13,0b0100
	beq r21,r13, PB_THREE
	
safety:#remaining timer snapshot value triggered
	movi r13,0b1000
	beq r21,r13, PB_FOUR
	
	br END_ISR
		
PB_ONE:#KEY0
	sub r19, r22, r21
	beq r19, r0, END_ISR	#=0
	
	movi r13, 1
	beq r19, r13, BW1
	
	movi r13, 3
	beq r19, r13, BW2
	
	#br continue_PB_ISR - should never get triggered if math is right
	
PB_TWO:#KEY1
	sub r19, r22, r21
	beq r19, r0, END_ISR
	
	
	#stw ra, 120(sp)
	
	#updates the current floor
	#call CLEAR_SCREEN
	
    #ldw ra, 120(sp)
	
	
	movi r13, -1
	beq r19, r13, FF1
	
	movi r13, 2
	beq r19, r13, BW1
	
	#br continue_PB_ISR - should never get triggered if math is right
	
PB_THREE:#KEY2
	sub r19, r22, r21
	beq r19, r0, END_ISR
	
	movi r13, -3
	beq r19, r13, FF2
	
	movi r13, -2
	beq r19, r13, FF1
	
	#br continue_PB_ISR - should never get triggered if math is right

PB_FOUR:#safety#KEY3
	movia r2, 0x02FAF080#sec
	beq r23, r2, END_ISR
	movia r2, 0x05F5E100#2 sec
	beq r23, r2, END_ISR
	beq r23, r0, END_ISR #-> exited cleanly, do nothing
	
	#if clean, skip
	beq r17, r0, skipSafety

	mov r4, r23	#-> load timer with remaining
	movi r17, 0
skipSafety:	
	br continue_PB_ISR

FF1:
	#set up r20 for motor direction and movement
	#set up r4 for timer , ie how long
	movia r20, 0xFFDFFFF0       # motor0 enabled (bit0=0), direction set to forward (bit1=0)
	movia r4, SECOND
	
	br continue_PB_ISR
	
FF2:
	movia r20, 0xFFDFFFF0       # motor0 enabled (bit0=0), direction set to forward (bit1=0)
	movia r4, TWO_SECONDS
	
	br continue_PB_ISR
	
BW1:
	movia r20, 0xFFDFFFFA
	movia r4, SECOND
	
	br continue_PB_ISR
	
BW2:
	movia r20, 0xFFDFFFFA
	movia r4, TWO_SECONDS

	
continue_PB_ISR:
	#start moving and enable safety features
	stw ra, 108(sp)
	
	call LEGO_UPDATE
	
    ldw ra, 108(sp)	

	
	#need to load r4 with apporpriate countdown value inferred from the current/needed floor logic
	stw ra, 112(sp)
	
	call	TIMER_INIT_ISR#also loads the value, enables the timer, enables timer ISR
	
	ldw ra, 112(sp)	
	
	br END_ISR
	
PS2_ISR:
	ldwio r12, 0(r8)			# loading the data
	movi r13, 0xff					
	and r12, r12, r13			# bits [7:0] from data register
	
	movi r5, 1

ONE:
	cmpeqi r16, r12, 0x16
	beq r16, r0, TWO
	
	#this
	movi r15, 0b0001
	
	br END_ISR

TWO:
	cmpeqi r16, r12, 0x1E
	beq r16, r0, THREE
	
	movi r15, 0b0010
	
	br END_ISR

THREE:
	cmpeqi r16, r12, 0x26
	beq r16, r0, SAFETY
	
	movi r15, 0b0100
	
	br END_ISR
	
SAFETY:
	cmpeqi r16, r12, 0x1B
	beq r16, r0, END_ISR
	
	movi r15, 0b1000
	
	br END_ISR
	
END_ISR:
	ldw		ea, 0(sp)
	#ldw		et, 8(sp)	#which
	#wrctl	ctl1, et	#which
	ldw		et, 4(sp)	#which
	ldw		r2, 12(sp)
	ldw		r3, 16(sp)
	ldw		r4, 20(sp)
	ldw		r6, 28(sp)
	ldw		r7, 32(sp)
	ldw		r8, 36(sp)
	ldw		r9, 40(sp)
	ldw		r10, 44(sp)
	ldw		r11, 48(sp)
	ldw		r12, 52(sp)
	ldw		r13, 56(sp)
	ldw		r14, 60(sp)
	ldw		ra, 68(sp)
	ldw		r16, 72(sp)
	ldw		r19, 84(sp)
	addi	sp, sp, 132
	addi	ea, ea, -4
	eret
	
#start program
.text
	.global _start

_start:
	#set up initial 
	movia r20, 0xFFDFFFFF 
	movi r21, 0b0000
	movi r22, 0b0001	#start at floor 0(1)
	movia r23, 0x00000000

#START SETUP LEGO ---------------------------------------------------------------------------------------------------	 GPIO_1_ISR
	#init the LEGO controller
	movia  r8, ADDR_JP1     	        # init pointer to JP1
	
	#load threshold values -> 00000111111101010101011111111111)2 = (7F557FF)16 = 7F557FFh
	movia  r9, 0x07f557ff       # set motor,threshold and sensors bits to output, set state and sensor valid bits to inputs
    stwio  r9, 4(r8)	#init DIR

# load sensor0 threshold value 1 and enable sensor0 - light sensor - unreliable threshholds, disable for now
 
#   movia  r9,  0xF8BFDFFF       # set motors off enable threshold load sensor 0
#   stwio  r9,  0(r8)            # store value into threshold register
   
#   movia  r9,  0xF8FFFFFF       # set motors off, sensors off, enable threshold load sensor off
#   stwio  r9,  0(r8)            # store value into threshold register

# load sensor1 threshold value 1 and enable sensor1 - light sensor - unreliable threshholds, disable for now
 
#   movia  r9,  0xF8BFBFFF       # set motors off enable threshold load sensor 1
#   stwio  r9,  0(r8)            # store value into threshold register
   
#   movia  r9,  0xF8FFFFFF       # set motors off, sensors off, enable threshold load sensor off
#   stwio  r9,  0(r8)            # store value into threshold register

# load sensor2 threshold value E and enable sensor2 - touch sensor
 
   movia  r9,  0xFF3FBFFF       # set motors off enable threshold load sensor 2
   stwio  r9,  0(r8)            # store value into threshold register   
   
   movia  r9,  0xFF5FFFFF       # set motors off, sensors off, enable threshold load sensor off
   stwio  r9,  0(r8)            # store value into threshold register
	
# load sensor3 threshold value E and enable sensor3 - touch sensor
 
#   movia  r9,  0xFF3EFFFF       # set motors off enable threshold load sensor 3
#   stwio  r9,  0(r8)            # store value into threshold register
   
#   movia  r9,  0xFF5FFFFF       # set motors off, sensors off, enable threshold load sensor off
#   stwio  r9,  0(r8)            # store value into threshold register

# disable threshold register and enable state mode
  
    movia  r9,  0xFFDFFFFF      # disable everything + switch to state mode. interrupts have not been enabled yet
    stwio  r9,  0(r8)
				
#END SETUP LEGO ---------------------------------------------------------------------------------------------------	GPIO_1_ISR


# set up PB_ISR
	movia r2,PUSH_BUTTONS_BASE
    movi r3,0xF	# Load interrrupt mask = 1111
    stwio r3,8(r2)  # Enable interrupts on pushbuttons 1,2,3 and 4
    stwio r3,12(r2) # Clear edge capture register to prevent unexpected interrupt
	
# null timer
	movia	r8, TIMER_0_BASE
	movi	r9, 0b1000
	stwio	r9, 4(r8)
	stwio	r0, 0(r8)
	
	#movia r9, 0x00000000
	#andi	r9, r4, 0xFFFF
	#stwio	r9, 8(r8)
	#srli	r9, r4, 16
	#stwio	r9, 12(r8)
	
	addi  r9, r0, %lo (NULL)
    stwio r9, 8(r8)
    addi  r9, r0, %hi (NULL)
    stwio r9, 12(r8)
	
#start set up lego isr
	movia  r8, ADDR_JP1     	 # init pointer to JP1 -> LEGO
	
	#ack interrupt
	movia	r12, 0xFFFFFFFF 
	stwio	r12, 12(r8)#writing to the edge capture register, suppose to 1 it all to ack
	
	# enable interrupts
    movia  r12, 0x40000000       # enable interrupts on sensor 3,2 (3 for now)
    stwio  r12, 8(r8)
	
	#ack interrupt
	movia	r12, 0xFFFFFFFF 
	stwio	r12, 12(r8)#writing to the edge capture register, suppose to 1 it all to ack
#end set up lego isr

#start ps2
#Enable interrupts on PS/2
	movia r8, PS2_ADDR
	movi r9, 0b1
	stwio r9, 4(r8)	
	
	#movia r8, PS2_ADDR
	#movia r9, PS2_CTRL

	#ldwio r10, 0(r9)		# reading from 4(keyboard) control bits
	#movi r11, 0x1
	#or r10, r11, r10
	#stwio r10, 0(r9)		# configure device
#end ps2	
	
#set-up interrupts globally
	movi r19, 0x883	#to enable IRQ interrupts 0,1,11 for timer 0 and pushbuttons and gpio 1 , respectively -> bits 1,2,12
	wrctl ctl3, r19
	movi r19, 1
	wrctl ctl0, r19 #set PIE bit
	
	addi sp, sp, -4
	stw ra, 0(sp)
	call DRAWPIX
	ldw ra, 0(sp)
	addi sp, sp, 4
	

	addi sp, sp, -4
	stw ra, 0(sp)
	call DRAWCHAR
	ldw ra, 0(sp)
	addi sp, sp, 4
  
  
	
	
	
#start:
	#main loop
loop:

	br loop#dont need this
	
#FUNCTION calls below
TIMER_INIT_ISR:	# setup timer and enable interrupt and continuing
					# r4 = # of clock cycles
	# prologue
	addi	sp, sp, -8
	stw		r8, 0(sp)
	stw		r9, 4(sp)
	
	# reset timer - SHOULD WE?
	movia	r8, TIMER_0_BASE
	movi	r9, 0b1000
	stwio	r9, 4(r8)
	stwio	r0, 0(r8)
	# set period and start - another way exists
	andi	r9, r4, 0xFFFF
	stwio	r9, 8(r8)
	srli	r9, r4, 16
	stwio	r9, 12(r8)
	movi	r9, 0b0101#start, not cont, en inter
	stwio	r9, 4(r8)
	
	# epilogue
	ldw		r8, 0(sp)
	ldw		r9, 4(sp)
	addi	sp, sp, 8
	ret
	
LEGO_UPDATE: #start moving too, takes r20
	# prologue
	addi	sp, sp, -8
	stw		r8, 0(sp)
	stw		r12, 4(sp)
	
	movia  r8, ADDR_JP1     	 # init pointer to JP1 -> LEGO
	
	#start/stop? moving
	stwio	 r20, 0(r8)
	
	# epilogue
	ldw		r8, 0(sp)
	ldw		r12, 4(sp)
	addi	sp, sp, 8
	ret
	
CHECK_TIMER_SNAPSHOT:
#this block of code takes snapshot of the remaining time
	# prologue
	addi	sp, sp, -12
	stw		r3, 0(sp)
	stw		r7, 4(sp)
	stw		r8, 8(sp)

    movia r7, TIMER_0_BASE       # r7 contains the base address for the timer 
    stwio r0,16(r7)              # Tell Timer to take a snapshot of the timer 
    ldwio r3,16(r7)              # Read snapshot bits 0..15 
    ldwio r8,20(r7)             # Read snapshot bits 16...31 
    slli  r8,r8,16		     # Shift left logically
    or    r23,r8,r3             # Combine bits 0..15 and 16...31 into one register
    #r23 holds the value
	
	# epilogue
	ldw		r3, 0(sp)
	ldw		r7, 4(sp)
	ldw		r8, 8(sp)
	addi	sp, sp, 12
	ret
	
CHECK_PB: #updates the current floor
# prologue
	addi	sp, sp, -12
	stw		r2, 0(sp)
	stw		r3, 4(sp)
	stw		r13, 8(sp)
	
#WHICH push button
	#andi r3, r21, 0x1
	movi r13,0b0001
	beq r21,r13, one
	#andi r3, r21, 0x2
	movi r13,0b0010
	beq r21,r13, two
	#andi r3, r21, 0x4
	movi r13,0b0100
	beq r21,r13, three
	#if not 3 above, definitely safety triggered
	movi r13, 0b1000
	beq r21, r13, fourSafety
	#think what happens when last button pressed was the safety button?!
	#br epilogue#shouldnt happen unless safety button
one:
	movi r22, 0b0001

	br epilogue

two:
	movi r22, 0b0010

	br epilogue

three:
	movi r22, 0b0100
	
	br epilogue
	
fourSafety:
	mov r22, r18#r18 holds the previous push button value, aka the desired floor we were moving to when safety got triggered
	
# epilogue
epilogue:
	ldw		r2, 0(sp)
	ldw		r3, 4(sp)
	ldw		r13, 8(sp)
	addi	sp, sp, 12
	ret
	
HALT: #self explanatory
# prologue
	addi	sp, sp, -8
	stw		r8, 0(sp)
	stw		r9, 4(sp)
	
	#halt motors (LEGO)
	movia  r8, ADDR_JP1     	 # init pointer to JP1
	movia  r9, 0xFFDFFFFF        #turning everything off and storing in data register
	stwio  r9, 0(r8)			 #halt
	
	#epilogue:
	ldw		r8, 0(sp)
	ldw		r9, 4(sp)
	addi	sp, sp, 8
	ret
	
DRAWPIX:
	movia r2,ADDR_VGA
	movui r4,0xffff  /* White pixel */
	sthio r4,1032(r2) /* pixel (4,1) is x*2 + y*1024 so (8 + 1024 = 1032) */

	ret

DRAWCHAR:
	movia r3, ADDR_CHAR
	movi  r4, 0x41   /* ASCII for 'A' */
	stbio r4,132(r3) /* character (4,1) is x + y*128 so (4 + 128 = 132) */
	
	ret
	

CLEAR_SCREEN:

	addi sp, sp, -40
	stw ra, 0(sp)
	stw r6, 4(sp)
	stw r7, 8(sp)
	stw r8, 12(sp)
	stw r9, 16(sp)
	stw r10, 20(sp)
	stw r11, 24(sp)
	stw r12, 28(sp)
	stw r13, 32(sp)
	stw r14, 36(sp)


	movui r13,0x0000  /* black pixel */
	mov r6, r0
	movi r8, 320
	movi r9, 240

	OUTER_LOOP:

	bge r6, r8, EXIT

	# start inner loop
	mov r7, r0

	INNER_LOOP:

	bge r7, r9, EXIT_INNER

	# plot the pixel
	movia r14,ADDR_VGA			# getting the initial device (VGA) address
	muli r10, r6, 2 			# effective x-coordinate
	muli r11, r7, 1024			# effective y-coordinate
	add r12, r10, r11			# memory offset corresponding (x,y)
	add r14, r14, r12			# adding the memory offset initial VGA address
	sthio r13,(r14) 			/* pixel (4,1) is x*2 + y*1024 so (8 + 1024 = 1032) formula */

	addi r7, r7, 1
	br INNER_LOOP

	EXIT_INNER:

	addi r6, r6, 1
	br OUTER_LOOP

	EXIT:
	
	ldw r14, 36(sp)
	ldw r13, 32(sp)
	ldw r12, 28(sp)
	ldw r11, 24(sp)
	ldw r10, 20(sp)
	ldw r9, 16(sp)
	ldw r8, 12(sp)
	ldw r7, 8(sp)
	ldw r6, 4(sp)
	ldw ra, 0(sp)

	addi sp, sp, 40
	ret
