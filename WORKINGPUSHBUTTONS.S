/*  Elevator control program
	global registers:
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

.equ SECOND, 50000000
.equ TWO_SECONDS, 100000000

#.equ ADDR_JP1_IRQ, 0x800


#interrupt routine
	.section .exceptions, "ax"
myISR:
	addi	sp, sp, -104
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
	stw		r17, 76(sp)
	stw		r18, 80(sp)
	stw		r19, 84(sp)
	#stw		r20, 88(sp)
	#stw		r21, 92(sp)
	#stw		r22, 96(sp)
	#stw		r23, 100(sp)
	
	#check which interrupt
	#rdctl	r16, ctl4
	#andi	r16, r16, 0x1	#check for IRQ0, paramount priority, timer
	#bne		r16, r0, TIMER_0_ISR
	
	rdctl	r16, ctl4
	andi	r16, r16, 0x2	#check for IRQ1, PUSH_BUTTONS
	bne		r16, r0, PUSH_BUTTONS_ISR
	
	#rdctl	r16, ctl4
	#andi	r16, r16, 0x400	#check for IRQ 11, GPIO 1
	#bne		r16, r0, GPIO_1_ISR
	
	#br		PUSH_BUTTONS_ISR_END	#will never happen
	
#TIMER_0_ISR:
   #Reading the current value of the timer into R23
#	addi sp, sp, -4
#	stw ra, 104(sp)
	
#	call CHECK_TIMER_SNAPSHOT
	
#    ldw ra, 104(sp)	
#	addi sp, sp, 4
	
#    beq r23, r0, TIMER_0_ISR_CLEAN #updates floor
	#br TIMER_0_ISR_SAFETY_TRIG	#unused
#    br TIMER_0_ISR_END
	
PUSH_BUTTONS_ISR:
    #Reading the current value of the timer into R23
	#addi sp, sp, -4
	#stw ra, 100(sp)
	
	#call CHECK_TIMER_SNAPSHOT
	
    #ldw ra, 100(sp)	
	#addi sp, sp, 4
	
	#if snapshot has value -> go to safety
	#movi r21, 0x11	DEFINITELY REACHES HERE
	#bne r23, r0, safety
	
	#if 0, clean exit, do below
	#store push button value
	movia r2, PUSH_BUTTONS_BASE
	#movi r21, 0x11
    ldwio r21, 12(r2)   # Read in buttons - active high from edge capture register
	
	#WORKS
	#movia r2,PUSH_BUTTONS_BASE
    #movi r3,0xF	# Load interrrupt mask = 1111
	#stwio	r3, 12(r2) # Clear edge capture register to prevent unexpected interrupt
	#WORKS END
	
	stwio	r21, 12(r2) # Clear edge capture register to prevent unexpected interrupt
	
	#movia	r16, PUSH_BUTTONS_BASE
	#movi	r13, 0x1111
	#stwio	r13, 12(r2)
	
	br PUSH_BUTTONS_ISR_END
	
	#WHICH push button
	#r3 is just temp, holding the masked value
	#r13 is temp, holding the pre-defined value for pre-defined floors
	#andi r3, r21, 0x1	#mask out the bit
	movi r13,0b0001	#we need to something to compare against
	beq r21,r13, PB_ONE	#comparison and jump
	#andi r3, r21, 0x2
	movi r13,0b0010
	beq r21,r13, PB_TWO
	#andi r3, r21, 0x4
	movi r13,0b0100
	beq r21,r13, PB_THREE
	
safety:
	#andi r3, r21, 0x8
	movi r13,0b1000
	beq r21,r13, PB_FOUR
	
	br continue_PB_ISR	#never arrive here if code is right
		
PB_ONE:
	sub r19, r22, r21
	beq r19, r0, PUSH_BUTTONS_ISR_END	#=0
	
	movi r13, 1
	#beq r19, r13, BW1
	
	movi r13, 3
	#beq r19, r13, BW2
	
	br continue_PB_ISR
	
PB_TWO:
	#srli   r3,  r3, 1
	sub r19, r22, r21
	beq r19, r0, PUSH_BUTTONS_ISR_END
	br PUSH_BUTTONS_ISR_END
	
	movi r13, -1
	#beq r19, r13, FF1	#=1
	
	movi r13, 2
	#beq r19, r13, BW1
	
	br continue_PB_ISR
	
PB_THREE:
	#srli   r3,  r3, 2
	sub r19, r22, r21
	#beq r19, r0, PUSH_BUTTONS_ISR_END
	br PUSH_BUTTONS_ISR_END
	
	movi r13, -3
	#beq r19, r13, FF1
	
	movi r13, -2
	#beq r19, r13, FF2
	
	br continue_PB_ISR

PB_FOUR:#safety
	beq r23, r0, PUSH_BUTTONS_ISR_END #-> exited cleanly, do nothing
	br PUSH_BUTTONS_ISR_END
	
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
	#stw ra, 104(sp)
	
	#call LEGO_INIT_ISR
	
    #ldw ra, 104(sp)	
	#addi sp, sp, 4

	#need to load r4 with apporpriate countdown value inferred from the current/needed floor logic
	# sp, sp, -4
	#stw ra, 100(sp)
	#call	TIMER_INIT_ISR
	#ldw ra, 100(sp)	
	#addi sp, sp, 4
	
	br PUSH_BUTTONS_ISR_END
	
GPIO_1_ISR: #LEGO
#if here means safety sensor got triggered
#halt
	movia  r8, ADDR_JP1     	 # init pointer to JP1
	movia  r9, 0xffffffff        #turning everything off and storing in data register
	stwio  r9, 0(r8)			 #halt

	#update floor, poll timer to know snapshot value -> safety triggered  
	#store remaining time
	#addi sp, sp, -4
	stw ra, 100(sp)
	
	call CHECK_TIMER_SNAPSHOT
	
    ldw ra, 100(sp)	
	#addi sp, sp, 4
	
	br GPIO_1_ISR_END
	
TIMER_0_ISR_CLEAN:
	#update to PB value
	#addi sp, sp, -4
	stw ra, 100(sp)
	
	#updates the current floor
	call CHECK_PB
	
    ldw ra, 100(sp)	
	#addi sp, sp, 4
	
	
	br TIMER_0_ISR_END
	
TIMER_0_ISR_SAFETY_TRIG:
	
	br TIMER_0_ISR_END
	
TIMER_0_ISR_END:
	# ack interrupt
	movia	r16, TIMER_0_BASE
	stwio	r0, 0(r16)
	br	END_ISR
	
PUSH_BUTTONS_ISR_END:
	# ack interrupt
	movia	r16, PUSH_BUTTONS_BASE
	movi	r13, 0x1111
	stwio	r13, 12(r16)
	br	END_ISR
	
GPIO_1_ISR_END:	#lego interrupt
	# ack interrupt
	movia	r16, ADDR_JP1
	movi	r13, 1
	stwio	r13, 12(r16)
	
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
	ldw		r17, 76(sp)
	ldw		r18, 80(sp)
	ldw		r19, 84(sp)
	#ldw		r20, 88(sp)
	#ldw		r21, 92(sp)
	#ldw		r22, 96(sp)
	#ldw		r23, 100(sp)
	addi	sp, sp, 104
	addi	ea, ea, -4
	eret
	
#start program
.text
	.global _start

_start:
	#init stack - auto?
	#orhi sp, zero, 0x400
	#addi sp, sp, 0x0
	#nor sp, sp, sp
	#ori sp, sp, 0x7
	#nor sp, sp, sp
		
	#set up initial 
	movia r20, 0xFFFFFFFF
	movi r21, 0x0000
	movi r22, 0x0001	#start at floor 0(1)
	movia r23, 0x00000000

#START SETUP LEGO ---------------------------------------------------------------------------------------------------	 GPIO_1_ISR
	#init the LEGO controller
	movia  r8, ADDR_JP1     	        # init pointer to JP1
	
	#load threshold values -> 00000111111101010101011111111111)2 = (7F557FF)16 = 7F557FFh
	movia  r9, 0x07f557ff       # set motor,threshold and sensors bits to output, set state and sensor valid bits to inputs
    stwio  r9, 4(r8)	#init DIR

# load sensor0 threshold value 1 and enable sensor0 - light sensor
 
   movia  r9,  0xF8BFDFFF       # set motors off enable threshold load sensor 0
   stwio  r9,  0(r8)            # store value into threshold register
   
   movia  r9,  0xF8FFFFFF       # set motors off, sensors off, enable threshold load sensor off
   stwio  r9,  0(r8)            # store value into threshold register

# load sensor1 threshold value 1 and enable sensor1 - light sensor
 
   movia  r9,  0xF8BFBFFF       # set motors off enable threshold load sensor 1
   stwio  r9,  0(r8)            # store value into threshold register
   
   movia  r9,  0xF8FFFFFF       # set motors off, sensors off, enable threshold load sensor off
   stwio  r9,  0(r8)            # store value into threshold register

# load sensor2 threshold value F and enable sensor2 - touch sensor
 
   movia  r9,  0xFFBF7FFF       # set motors off enable threshold load sensor 2
   stwio  r9,  0(r8)            # store value into threshold register   
   
   movia  r9,  0xFFFFFFFF       # set motors off, sensors off, enable threshold load sensor off
   stwio  r9,  0(r8)            # store value into threshold register
	
# load sensor3 threshold value F and enable sensor3 - touch sensor
 
   movia  r9,  0xFFBEFFFF       # set motors off enable threshold load sensor 3
   stwio  r9,  0(r8)            # store value into threshold register
   
   movia  r9,  0xFFFFFFFF       # set motors off, sensors off, enable threshold load sensor off
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
	
#set-up interrupts globally
	#movi r18, 0x803	#to enable IRQ interrupts 0,1,11 for timer 0 and pushbuttons and gpio 1 , respectively -> bits 1,2,12
	#movi r18, 0x3	#to enable IRQ interrupts 0,1,11 for timer 0 and pushbuttons and gpio 1 , respectively -> bits 1,2,12
	movi r18, 0x2	#to enable IRQ interrupts 0,1,11 for timer 0 and pushbuttons and gpio 1 , respectively -> bits 1,2,12
	wrctl ctl3, r18
	movi r18, 1
	wrctl ctl0, r18 #set PIE bit

	
	movia r2,PUSH_BUTTONS_BASE
    movi r3,0xF	# Load interrrupt mask = 1111
	stwio	r3, 12(r2) # Clear edge capture register to prevent unexpected interrupt
	
#start:
	#main loop
loop:
	#movia	r16, PUSH_BUTTONS_BASE
	#movi	r13, 0x1111
	#stwio	r13, 12(r16)
	br loop
	br loop
	br loop
	br loop
	
#FUNCTION calls below
TIMER_INIT_ISR:	# setup timer and enable interrupt and continuing
					# r4 = # of clock cycles
	# prologue
	addi	sp, sp, -8
	stw		r8, 0(sp)
	stw		r9, 4(sp)
	
	# reset timer
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
	
	#start moving
	stwio	 r20, 0(r8)
	
	# enable interrupts
	movia  r8, ADDR_JP1     	 # init pointer to JP1
    movia  r12, 0x78000000       # enable interrupts on sensor 3,2,1,0
    stwio  r12, 8(r8)
	
	# epilogue
	ldw		r8, 0(sp)
	ldw		r12, 4(sp)
	addi	sp, sp, 8
	ret
	
CHECK_TIMER_SNAPSHOT:
#this block of code takes snapshot of the remaining time
	# prologue
	addi	sp, sp, -8
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
	addi	sp, sp, 8
	ret
	
CHECK_PB: #updates the current floor
# prologue
	addi	sp, sp, -12
	stw		r2, 0(sp)
	stw		r3, 4(sp)
	stw		r13, 8(sp)
	
#WHICH push button
	andi r3, r21, 0x1
	movi r13,1
	beq r3,r13, one
	andi r3, r21, 0x2
	movi r13,1
	beq r3,r13, two
	andi r3, r21, 0x4
	movi r13,1
	beq r3,r13, three
	#think what happens when last button pressed was safety
one:
	movi r22, 0x1

	br epilogue

two:
	movi r22, 0x2

	br epilogue

three:
	movi r22, 0x4
	
# epilogue
epilogue:
	ldw		r2, 0(sp)
	ldw		r3, 4(sp)
	ldw		r13, 8(sp)
	addi	sp, sp, 12
	ret
