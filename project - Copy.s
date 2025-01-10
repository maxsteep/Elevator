/*  Elevator control program
	global registers:
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

.equ SECOND, 50000000#50000000
.equ TWO_SECONDS, 100000000#100000000
.equ NULL, 00000000

#.equ ADDR_JP1_IRQ, 0x800


#interrupt routine
	.section .exceptions, "ax"
myISR:
	addi	sp, sp, -128
	stw		ea, 0(sp)
	stw		et, 4(sp)
	#rdctl	et, ctl1
	#stw		et, 8(sp)
	
	stw		r2, 12(sp)
	stw		r3, 16(sp)
	stw		r4, 20(sp)
	stw		r5, 24(sp)
	stw		r6, 28(sp)
	stw		r7, 32(sp)
	stw		r8, 36(sp)
	stw		r9, 40(sp)
	stw		r10, 44(sp)
	stw		r11, 48(sp)
	stw		r12, 52(sp)
	stw		r13, 56(sp)
	stw		r14, 60(sp)
	stw		r15, 64(sp)
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
	andi	r16, r16, 0x800	#check for IRQ 11, GPIO 1
	bne		r16, r0, GPIO_1_ISR
	
	#br		PUSH_BUTTONS_ISR_END	#will never happen

GPIO_1_ISR: #LEGO
#if here means safety sensor got triggered

	#ack interrupt
	movia	r16, ADDR_JP1
	movia	r13, 0xFFFFFFFF 
	stwio	r13, 12(r16)#writing to the edge capture register, suppose to 1 it all to ack
	
	movi r17, 0x1
	#stw ra, 124(sp)
	
	#updates the current floor
	#call HALT
	
    #ldw ra, 124(sp)
	
	#stop timer, will we still read snapshot correctly?
	movia	r8, TIMER_0_BASE
	movi	r9, 0b1000
	stwio	r9, 4(r8)
	stwio	r0, 0(r8)
	
	#store the previous push button value for which floor logic for later on
	#movi r16, 0b1000 #dont update if r21 (Current pb value) holds the safety button keycode
	#beq r21, r16, skip
	#mov r18, r21#save previous push button value (Desired floor) to the global r18
	
skip:
	#poll timer to know snapshot value -> safety triggered  
	#store remaining time
	#addi sp, sp, -4
	#stw ra, 116(sp)
	
	#call CHECK_TIMER_SNAPSHOT
	
    #ldw ra, 116(sp)	
	#addi sp, sp, 4
	#br END_ISR
	br GPIO_1_ISR_END #-> done above
	
	
TIMER_0_ISR:
   #Reading the current value of the timer into R23
	#addi sp, sp, -4
	stw ra, 100(sp)
	
	call CHECK_TIMER_SNAPSHOT
	
    ldw ra, 100(sp)	
	#addi sp, sp, 4
	
	#should literally branch to timer clean, rewrite timer ISR to compact it
	#trim the code, safety wont get triggered through timer
	movia r2, 0x02FAF080#sec
	beq r23, r2, TIMER_0_ISR_CLEAN
	movia r2, 0x05F5E100#2 sec
	beq r23, r2, TIMER_0_ISR_CLEAN
    beq r23, r0, TIMER_0_ISR_CLEAN#first time, 0 sec
	#TIMER_0_ISR_CLEAN in turn update the floor value
	#br TIMER_0_ISR_SAFETY_TRIG	#unused
    br TIMER_0_ISR_END	#we never arrive on unclean through timer interrupt
	
PUSH_BUTTONS_ISR:
	#store push button value
	movia r2, PUSH_BUTTONS_BASE
    ldwio r21, 12(r2)   # Read in buttons - active high from edge capture register

	stwio	r21, 12(r2) # Clear edge capture register to prevent unexpected interrupt



    #Reading the current value of the timer into R23
	#if PB0-2 are pressed after an unclean exit everything breaks
	#addi sp, sp, -4
	stw ra, 104(sp)
	
	call CHECK_TIMER_SNAPSHOT
	
    ldw ra, 104(sp)	
	#addi sp, sp, 4
	
	#if snapshot has value -> go to safety
	movia r2, 0x02FAF080#sec
	beq r23, r2, continue
	movia r2, 0x05F5E100#2 sec
	beq r23, r2, continue
	beq r23, r0, continue
	br safety
	#if 0, clean exit, do below

	
	#br PUSH_BUTTONS_ISR_END - should never get triggered if math is right
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
	
	br PUSH_BUTTONS_ISR_END
		
PB_ONE:#KEY0
	sub r19, r22, r21
	beq r19, r0, PUSH_BUTTONS_ISR_END	#=0
	
	movi r13, 1
	beq r19, r13, BW1
	
	movi r13, 3
	beq r19, r13, BW2
	
	#br continue_PB_ISR - should never get triggered if math is right
	
PB_TWO:#KEY1
	sub r19, r22, r21
	beq r19, r0, PUSH_BUTTONS_ISR_END
	
	movi r13, -1
	beq r19, r13, FF1
	
	movi r13, 2
	beq r19, r13, BW1
	
	#br continue_PB_ISR - should never get triggered if math is right
	
PB_THREE:#KEY2
	sub r19, r22, r21
	beq r19, r0, PUSH_BUTTONS_ISR_END
	
	movi r13, -3
	beq r19, r13, FF2
	
	movi r13, -2
	beq r19, r13, FF1
	
	#br continue_PB_ISR - should never get triggered if math is right

PB_FOUR:#safety#KEY3
	movia r2, 0x02FAF080#sec
	beq r23, r2, PUSH_BUTTONS_ISR_END
	movia r2, 0x05F5E100#2 sec
	beq r23, r2, PUSH_BUTTONS_ISR_END
	beq r23, r0, PUSH_BUTTONS_ISR_END #-> exited cleanly, do nothing
	
	#if not clean, do this
	mov r4, r23	#-> load timer with remaining
	
	br continue_PB_ISR

FF1:
	#set up r20 for motor direction and movement
	#set up r4 for timer , ie how long
	movia r20, 0xFFDEABF0       # motor0 enabled (bit0=0), direction set to forward (bit1=0)
	movia r4, SECOND
	
	br continue_PB_ISR
	
FF2:
	movia r20, 0xFFDEABF0       # motor0 enabled (bit0=0), direction set to forward (bit1=0)
	movia r4, TWO_SECONDS
	
	br continue_PB_ISR
	
BW1:
	movia r20, 0xFFDEABFA
	movia r4, SECOND
	
	br continue_PB_ISR
	
BW2:
	movia r20, 0xFFDEABFA
	movia r4, TWO_SECONDS

	
continue_PB_ISR:
	#start moving and enable safety features
	#addi sp, sp, -4
	stw ra, 108(sp)
	
	call LEGO_INIT_ISR
	
    ldw ra, 108(sp)	
	#addi sp, sp, 4

	#need to load r4 with apporpriate countdown value inferred from the current/needed floor logic
	# sp, sp, -4
	stw ra, 112(sp)
	call	TIMER_INIT_ISR#also loads the value, enables the timer, enables timer ISR
	ldw ra, 112(sp)	
	#addi sp, sp, 4
	
	br PUSH_BUTTONS_ISR_END
	
TIMER_0_ISR_CLEAN:
	#update to PB value
	#addi sp, sp, -4
	stw ra, 120(sp)
	
	#updates the current floor
	call CHECK_PB
	
    ldw ra, 120(sp)	
	#addi sp, sp, 4
	
	
	br TIMER_0_ISR_END
	
TIMER_0_ISR_SAFETY_TRIG:
	
	br TIMER_0_ISR_END
	
TIMER_0_ISR_END:
	# ack interrupt
	movia	r16, TIMER_0_BASE
	stwio	r0, 0(r16)
	
	#disable LEGO
	movia  r8, ADDR_JP1     	        # init pointer to JP1
	movia  r9,  0xFFDFFFFF      # disable everything + switch to state mode. interrupts have not been enabled yet
    stwio  r9,  0(r8)
	
	br	END_ISR
	
PUSH_BUTTONS_ISR_END:
	# ack interrupt
	#We DONT NEED THIS
	movia	r16, PUSH_BUTTONS_BASE
	movi	r13, 0x1111
	stwio	r13, 12(r16)
	br	END_ISR
	
GPIO_1_ISR_END:	#lego interrupt
	# ack interrupt
	#movia	r16, ADDR_JP1
	#movia	r13, 0xFFFFFFFF 
	#stwio	r13, 12(r16)
	
END_ISR:
	ldw		ea, 0(sp)
	#ldw		et, 8(sp)	#which
	#wrctl	ctl1, et	#which
	ldw		et, 4(sp)	#which
	ldw		r2, 12(sp)
	ldw		r3, 16(sp)
	ldw		r4, 20(sp)
	ldw		r5, 24(sp)
	ldw		r6, 28(sp)
	ldw		r7, 32(sp)
	ldw		r8, 36(sp)
	ldw		r9, 40(sp)
	ldw		r10, 44(sp)
	ldw		r11, 48(sp)
	ldw		r12, 52(sp)
	ldw		r13, 56(sp)
	ldw		r14, 60(sp)
	ldw		r15, 64(sp)
	ldw		ra, 68(sp)
	ldw		r16, 72(sp)
	ldw		r19, 84(sp)
	addi	sp, sp, 128
	addi	ea, ea, -4
	eret
	
#start program
.text
	.global _start

_start:
	#set up initial 
	movia r20, 0xFFFFFFFF
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
 
   movia  r9,  0xFF3EFFFF       # set motors off enable threshold load sensor 3
   stwio  r9,  0(r8)            # store value into threshold register
   
   movia  r9,  0xFF5FFFFF       # set motors off, sensors off, enable threshold load sensor off
   stwio  r9,  0(r8)            # store value into threshold register

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
	
#set-up interrupts globally
	#movi r19, 0x803	#to enable IRQ interrupts 0,1,11 for timer 0 and pushbuttons and gpio 1 , respectively -> bits 1,2,12
	#movi r19, 0x3	#to enable IRQ interrupts 0,1,11 for timer 0 and pushbuttons and gpio 1 , respectively -> bits 1,2,12
	movi r19, 0x803	#to enable IRQ interrupts 0,1,11 for timer 0 and pushbuttons and gpio 1 , respectively -> bits 1,2,12
	wrctl ctl3, r19
	movi r19, 1
	wrctl ctl0, r19 #set PIE bit
	
#start:
	#main loop
loop:
	movi r19, 0x1
	beq r17, r19, HALT
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
	
LEGO_INIT_ISR: #start moving too
	# prologue
	addi	sp, sp, -8
	stw		r8, 0(sp)
	stw		r12, 4(sp)
	
	movia  r8, ADDR_JP1     	 # init pointer to JP1 -> LEGO
	#start moving
	stwio	 r20, 0(r8)
	
	# enable interrupts
    movia  r12, 0x60000000       # enable interrupts on sensor 3,2
    stwio  r12, 8(r8)
	
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
	#mov r17, r0
	
	#epilogue:
	ldw		r8, 0(sp)
	ldw		r9, 4(sp)
	addi	sp, sp, 8
	ret
