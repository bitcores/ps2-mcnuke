.ps2_ee

.entry_point main
.export start
.export GIF_send_data
.export Memorycard_getspecs
.export Memorycard_comm
.export Memorycard_set_addr
.export Memorycard_set_cmd
.export Memorycard_erase
.export Memorycard_findpage
.export Memorycard_cacheblock

.define SETREG_DISPFB(fpb,fbw,psm,dbx,dby) \
	(((dby) << 43) | \
		((dbx) << 32) | \
		((psm) << 15) | \
		((fbw) << 9) | \
		(fpb))
.define SETREG_DISPLAY_HI(dw,dh) \
	(((dh) << 12)   | \
		(dw))
.define SETREG_DISPLAY_LO(dx,dy,magh,magv) \
	(((magv) << 27) | \
		((magh) << 23) | \
		(((dy) << 12)   | \
		(dx))
.define SETREG_TRXPOS(ssax,ssay,dsax,dsay,dir) \
	(((dir)  << 59) | \
		((dsay) << 48) | \
		((dsax) << 32) | \
		((ssay) << 16) | \
		(ssax))
.define SETREG_TRXREG(rrw,rrh) (((rrh) << 32) | (rrw))
.define SETREG_TRXDIR(dir) (dir)
.define SETREG_BITBLTBUF(src_base,src_width,src_format,dst_base,dst_width,dst_format) \
	(((dst_format) << 56) | \
		((dst_width)  << 48) | \
		((dst_base)   << 32) | \
		((src_format) << 24) | \
		((src_width)  << 16) | \
		(src_base))
.define GIF_TAG(nloop,eop,pre,prim,flg,nreg) \
	(((nreg) << 60) | \
		((flg)  << 58) | \
		((prim) << 47) | \
		((pre)  << 46) | \
		((eop)  << 15) | \
		(nloop))
.define SETREG_XYOFFSET(ofx,ofy) (((ofy) << 32) | (ofx))
.define SETREG_SCISSOR(scax0,scax1,scay0,scay1) \
	(((scay1) << 48) | \
		((scay0) << 32) | \
		((scax1) << 16) | \
		(scax0))
.define SETREG_XYZ2(x,y,z) (z<<32)|(y<<16)|x

GS_CSR			equ 0x1200_1000
GS_PMODE		equ 0x1200_0000
GS_DISPFB1		equ 0x1200_0070
GS_DISPLAY1		equ 0x1200_0080
_SetGsCrt		equ 2
_GsPutIMR		equ 113	
FMT_PSMCT16		equ 0x02
DIR_UL_LR		equ 0
XDIR_HOST_TO_LOCAL equ 0
FLG_PACKED		equ 0
FLG_IMAGE		equ 2
PRIM_SPRITE		equ 6

REG_PRIM		equ 0x00
REG_RGBAQ		equ 0x01
REG_XYZ2		equ 0x05
REG_A_D			equ 0x0E
REG_TEX2_2		equ 0x17
REG_XYOFFSET_1	equ 0x18
REG_PRMODECONT	equ 0x1A
REG_SCISSOR_1	equ 0x40
REG_DTHE		equ 0x45
REG_COLCLAMP	equ 0x46
REG_TEST_1		equ 0x47
REG_FRAME_1		equ 0x4C
REG_ZBUF_1		equ 0x4E
REG_BITBLTBUF	equ 0x50
REG_TRXPOS		equ 0x51
REG_TRXREG		equ 0x52
REG_TRXDIR		equ 0x53

D2_CHCR			equ 0x1000_A000
D_CTRL			equ 0x1000_E000
D_ENABLEW		equ 0x1000_F590

CDVD_SCMD		equ 0x1F40_2016		; starts the command when written, params first
CDVD_STATP		equ 0x1F40_2017		; read - status, write - params
CDVD_RESULT		equ 0x1F40_2018		; FIFO

SIO2_CTRL		equ 0x1F80_8268
SIO2_SEND3		equ 0x1F80_8200
SIO2_SEND12		equ 0x1F80_8240
SIO2_FIFOIN		equ 0x1F80_8260
SIO2_FIFOOUT	equ 0x1F80_8264
SIO2_RECV1		equ 0x1F80_826C
SIO2_RECV2		equ 0x1F80_8270
SIO2_RECV3		equ 0x1F80_8274
SIO2_ISTAT		equ 0x1F80_8280
SIO2_RESET		equ 0x03F0
SIO2_IDLE		equ 0x03BC
SIO2_SEND		equ 0x03B3 ; <- not this more like 0x3B3 (or CTRL with 3)

mccmd			equ 0x001E_0000		; place to prepare mc commands
mcspecs			equ 0x001E_00E0
mcscratch		equ 0x001E_0100		; used during commands to store response
mcsuper			equ 0x001E_0800		; superblock
mcbuffer		equ 0x001E_8000
mcblkcachep		equ 0x001F_0000		; list of cached blocks
mcblkcache		equ 0x0020_0000		; i'll cache blocks that will be edited and written back here

;; if successful, will return to ps2 menu. if error occurs, will show fail message

; code entry point
.org 0x10_0000
start:
main:
    ; set up stack pointer	
    ; this is at the very top of the 32MB of system ram
    li $sp, 0x0200_0000

    jal DMA_reset
    nop

    ;; Reset GS
    li $v1, GS_CSR
    li $v0, 0x200
    sd $v0, ($v1)

    ;; Interrupt mask register
    li $v1, _GsPutIMR
    li $a0, 0xff00
    syscall
    nop

    ;; interlace      { PS2_NONINTERLACED = 0, PS2_INTERLACED = 1 };
    ;; videotype      { PS2_NTSC = 2, PS2_PAL = 3 };
    ;; frame          { PS2_FRAME = 1, PS2_FIELD = 0 }; only relevant if interlaced
    li $v1, _SetGsCrt
    li $a0, 0
    li $a1, 2
    li $a2, 0
    syscall
    nop

    ;; Use framebuffer read circuit (1 or 2?)
	;; 1 0xFF25 2 0xFF66 1+2 0xFF67 (or other)
    li $v1, GS_PMODE
    li $v0, 0xFF25
    sd $v0, ($v1)

    li $v1, GS_DISPFB1
    li $v0, SETREG_DISPFB(0, 5, FMT_PSMCT16, 0, 0)
    sd $v0, ($v1)

    li $v1, GS_DISPLAY1
	;; dw, dh
	li $v0, SETREG_DISPLAY_HI(2559,223)
	dsll32 $v0, $v0, 0
	;; dx, dy, magh, magv
	li $at, SETREG_DISPLAY_LO(656,36,7,0)
    or $v0, $v0, $at
    sd $v0, ($v1)

	jal clear_screen
    nop
	jal vsync_wait
	nop

;; gotta make sure cache pointer list is zero
	li $s0, mcblkcachep
	sw $zero, ($s0)
;; start with get specs
;; get specs	
	jal Memorycard_getspecs
	nop

;; load size of memory card from specs
	li $s0, mcspecs
	lbu $s4, 8($s0)
	sll $s4, $s4, 8
	lbu $s2, 7($s0)
	or $s4, $s4, $s2
	slt $s2, $zero, $s4
	beq $s2, $zero, Failed
	and $s3, $s3, $zero
	
Wipe_MC_loop:
	li $s0, memorycard_starterase
	jal Memorycard_set_addr
	nop
	jal Memorycard_erase
	nop
	jal vsync_wait
	addi $s3, $s3, 0x10
	slt $s2, $s3, $s4
	bne $s2, $zero, Wipe_MC_loop
	nop
	

	jal vsync_wait
	nop
	jal vsync_wait
	nop
	jal vsync_wait
	nop
	jal vsync_wait
	nop
	;; return to OSDSYS
	li $v1, 0x04
	li $a0, 0
	syscall
	nop
	
Failed:
	jal Show_fail_msg
	nop
	
while_1:
	jal vsync_wait
	nop
	j while_1
	nop


;;  $s0 = source, $s1 = length
;;  will clob $t2, $t3
SIO_fifoin_write:
	addi $sp, $sp, -8
	sd $s0, 0($sp)
	li $s2, SIO2_FIFOIN
loop_fifoin_write:	
	lbu $s3, 1($s0)
	sb $s3, ($s2)
	;sync.p
	addi $s1, $s1, -1
	bnez $s1, loop_fifoin_write
	addi $s0, $s0, 1
	ld $s0, 0($sp)
	jr $ra
	addi $sp, $sp, 8
;;  $s0 = destination, $s1 = length
;;  will clob $t2, $t3
SIO_fifoout_read:
	addi $sp, $sp, -8
	sd $s0, 0($sp)
	li $s2, SIO2_FIFOOUT
loop_fifoout_read:
	lbu $s3, ($s2)
	;sync.p
	sb $s3, ($s0)
	addi $s1, $s1, -1
	bnez $s1, loop_fifoout_read
	addi $s0, $s0, 1
	ld $s0, 0($sp)
	jr $ra
	addi $sp, $sp, 8

;;  will clob $t0, $t1
SIO_interrupt_reset:
	; prepare SIO interrupt
	li $s0, 0x1F801070
	li $s1, 0xFFFD_FFFF
	sw $s1, ($s0)
	jr $ra
	nop
;;  will clob $t0 - $t3
SIO_interrupt_wait:
	ori $s2, $zero, 0x4000
	li $s3, 0x2_0000
	li $s0, 0x1F801070
SIO_iwait_loop:
	lwu $s1, ($s0)
	and $s1, $s1, $s3
	beqz $s2, SIO_iwait_escape	; interrupt should never take this long, exit
	addi $s2, $s2, -1
	bne $s1, $s3, SIO_iwait_loop
	nop
SIO_iwait_escape:
	jr $ra
	sw $s1, ($s0)
	
.align 32
Memorycard_getspecs:
	ori $t0, $zero, 5
	addi $sp, $sp, -48
	sd $s0, 8($sp)
	sd $s1, 16($sp)
	sd $s2, 24($sp)
	sd $s3, 32($sp)
	sd $ra, 40($sp)
	; reset sio2
Memorycard_getspecs_loop:
	li $s0, SIO2_CTRL
	li $s1, SIO2_IDLE
	sw $s1, ($s0)
	; prepare send buf
	li $s2, SIO2_SEND12
	li $s3, 0xFF02_0405
	sw $s3, 16($s2)
	sw $s3, 24($s2)		; setting positions for port 3?
	li $s3, 0x5_FFFF
	sw $s3, 20($s2)
	sw $s3, 28($s2)		; setting positions for port 3?
	; prep up send3 based on length of command
	li $s0, memorycard_getspecs
	lbu $s1, 0($s0)
	li $s2, SIO2_SEND3
	or $s3, $s1, $zero
	sll $s3, $s3, 10
	or $s3, $s3, $s1
	sll $s3, $s3, 8
	ori $s3, $s3, 0x40	; this as well?
	addi $s3, $s3, 3	; port 3 = MC 2? (0 controller 1, 1 controller 2, 2 mc 1, 3 mc 2)
	sw $s3, 0($s2)
	jal SIO_fifoin_write
	sb $s1, 0($sp)
	; start transfer
	jal SIO_interrupt_reset
	addi $t0, $t0, -1
	li $s0, SIO2_CTRL
	lwu $s1, ($s0)
	ori $s1, $s1, 3 ; aaaaaaaa lmao
	sw $s1, 0($s0)
	jal SIO_interrupt_wait
	nop
	li $s0, mcspecs
	; read out
	jal SIO_fifoout_read
	lbu $s1, 0($sp)			; length to read
	li $s0, mcspecs
	li $s2, SIO2_RECV1
	lw $s1, ($s2)
	sw $s1, 16($s0)
	li $s0, 0x1100
	beq $s1, $s0, Memorycard_getspecs_end
	nop
	bne $t0, $zero, Memorycard_getspecs_loop
	nop
Memorycard_getspecs_end:
	ld $s0, 8($sp)
	ld $s1, 16($sp)
	ld $s2, 24($sp)
	ld $s3, 32($sp)
	ld $ra, 40($sp)
	jr $ra
	addi $sp, $sp, 48


;;	$s0 comes with command location
;;  return $s1 with size of data read
Memorycard_comm:
	ori $t0, $zero, 5
	addi $sp, $sp, -40
	sd $s0, 8($sp)
	sd $s2, 16($sp)
	sd $s3, 24($sp)
	sd $ra, 32($sp)
Memorycard_comm_retry:
	; reset sio2
	li $s0, SIO2_CTRL
	li $s1, SIO2_IDLE
	sw $s1, ($s0)
	; prepare send buf
	li $s2, SIO2_SEND12
	li $s3, 0xFF02_0405
	sw $s3, 16($s2)
	sw $s3, 24($s2)		; setting positions for port 3?
	li $s3, 0x5_FFFF
	sw $s3, 20($s2)
	sw $s3, 28($s2)		; setting positions for port 3?
	; prep up send3 based on length of command
	ld $s0, 8($sp)
	lbu $s1, 0($s0)
	li $s2, SIO2_SEND3
	or $s3, $s1, $zero
	sll $s3, $s3, 10
	or $s3, $s3, $s1
	sll $s3, $s3, 8
	ori $s3, $s3, 0x40	; this as well?
	addi $s3, $s3, 3	; port 3 = MC 2? (0 controller 1, 1 controller 2, 2 mc 1, 3 mc 2)
	sw $s3, 0($s2)
	jal SIO_fifoin_write
	sb $s1, 0($sp)
	; start transfer
	jal SIO_interrupt_reset
	addi $t0, $t0, -1
	li $s0, SIO2_CTRL
	lwu $s1, ($s0)
	ori $s1, $s1, 3 ; aaaaaaaa lmao
	sw $s1, 0($s0)
	jal SIO_interrupt_wait
	nop
	li $s0, mcscratch
	; read out
	jal SIO_fifoout_read
	lbu $s1, 0($sp)			; length to read
	;li $s0, mcbuffer
	li $s2, SIO2_RECV1
	lw $s1, ($s2)
	;sw $s1, 16($s0)
	li $s0, 0x1100
	beq $s1, $s0, Memorycard_comm_end
	nop
	bne $t0, $zero, Memorycard_comm_retry
	nop
Memorycard_comm_end:
	lbu $s1, 0($sp)
	ld $s0, 8($sp)
	ld $s2, 16($sp)
	ld $s3, 24($sp)
	ld $ra, 32($sp)
	jr $ra
	addi $sp, $sp, 40

;; input address type (read, write, erase)
;; use $s0 to bring pointer to command
;; use $s3 to bring page addr
Memorycard_set_addr:
	addi $sp, $sp, -32
	sd $ra, 0($sp)
	sd $s1, 8($sp)
	sd $s2, 16($sp)
	jal Memorycard_set_cmd
	sd $s3, 24($sp)
	li $s0, mccmd
	sb $s3, 3($s0)
	srl $s3, $s3, 8
	sb $s3, 4($s0)
	jal Memorycard_comm
	lbu $s1, 0($s0)
	ld $ra, 0($sp)
	ld $s1, 8($sp)
	ld $s2, 16($sp)
	ld $s3, 24($sp)
	jr $ra
	addi $sp, $sp, 32

;; takes $s0 as pointer to command
Memorycard_set_cmd:
	addi $sp, $sp, -32
	sd $s1, 0($sp)
	sd $s2, 8($sp)
	sd $t0, 16($sp)
	sd $t1, 24($sp)
	lbu $s1, 0($s0)
	and $t0, $t0, $zero
	li $s2, mccmd
Memorycard_set_cmd_loop:
	lbu $t1, ($s0)
	sb $t1, ($s2)
	addi $s0, $s0, 1
	addi $t0, $t0, 1
	bne $t0, $s1, Memorycard_set_cmd_loop
	addi $s2, $s2, 1
	ld $s1, 0($sp)
	ld $s2, 8($sp)
	ld $t0, 16($sp)
	ld $t1, 24($sp)
	jr $ra
	addi $sp, $sp, 32

;; address must be erase block aligned
Memorycard_erase:
	addi $sp, $sp, -24
	sd $ra, 0($sp)
	sd $s0, 8($sp)
	sd $s1, 16($sp)
	li $s0, memorycard_eraseblock
	jal Memorycard_set_cmd
	nop
	li $s0, mccmd
	jal Memorycard_comm
	lbu $s1, 0($s0)
	;; after erase is done, run the flush(?)
	;jal vsync_wait
	;nop
	li $s0, memorycard_erase_flush
	jal Memorycard_set_cmd
	nop
	li $s0, mccmd
	jal Memorycard_comm
	lbu $s1, 0($s0)
	ld $ra, 0($sp)
	ld $s0, 8($sp)
	ld $s1, 16($sp)
	jr $ra
	addi $sp, $sp, 24

;; destination is $s7
;; addresses must be erase block aligned
Memorycard_read_block:
	addi $sp, $sp, -48
	sd $ra, 0($sp)
	sd $s0, 8($sp)
	sd $s1, 16($sp)
	sd $s2, 24($sp)
	sd $s3, 32($sp)
	sd $s4, 40($sp)
	li $s0, memorycard_readwrite
	jal Memorycard_set_cmd
	ori $s1, $zero, 0x43
	li $s0, mccmd
	sb $s1, 2($s0)
	ori $s4, $zero, 0x41
Memorycard_read_block_loop:	
	jal Memorycard_comm
	lbu $s1, 0($s0)
	li $s1, mcscratch
	ori $s3, $zero, 0x80
Memorycard_read_block_copy:
	lw $t0, 4($s1)
	sw $t0, ($s7)
	addi $s1, $s1, 4
	addi $s3, $s3, -4
	bne $s3, $zero, Memorycard_read_block_copy
	addi $s7, $s7, 4
	bne $s4, $zero, Memorycard_read_block_loop
	addi $s4, $s4, -1
	;; after reading a block i HAVE to readdress, so end readwrite
	li $s0, memorycard_readwrite_end
	jal Memorycard_set_cmd
	nop
	li $s0, mccmd
	jal Memorycard_comm
	lbu $s1, 0($s0)
	ld $ra, 0($sp)
	ld $s0, 8($sp)
	ld $s1, 16($sp)
	ld $s2, 24($sp)
	ld $s3, 32($sp)
	ld $s4, 40($sp)
	jr $ra
	addi $sp, $sp, 48

;; input pointer to storage ($s7?)
Memorycard_read_page:
	addi $sp, $sp, -40
	sd $ra, 0($sp)
	sd $s0, 8($sp)
	sd $s1, 16($sp)
	sd $s2, 24($sp)
	sd $s3, 32($sp)
	li $s0, memorycard_readwrite
	jal Memorycard_set_cmd
	ori $s1, $zero, 0x43
	li $s0, mccmd
	sb $s1, 2($s0)
	li $s1, memorycard_rw_page
	ld $s3, ($s1)
Memorycard_read_page_loop:
	jal Memorycard_comm
	lbu $s1, 0($s0)
	li $s1, mcscratch
	andi $s2, $s3, 0xFF
Memorycard_read_page_copy:
	lw $t0, 4($s1)
	sw $t0, ($s7)
	addi $s1, $s1, 4
	addi $s2, $s2, -4
	bne $s2, $zero, Memorycard_read_page_copy
	addi $s7, $s7, 4
	dsrl $s3, $s3, 8
	bne $s3, $zero, Memorycard_read_page_loop
	nop
	li $s0, memorycard_readwrite_end
	jal Memorycard_set_cmd
	nop
	li $s0, mccmd
	jal Memorycard_comm
	lbu $s1, 0($s0)
	ld $ra, 0($sp)
	ld $s0, 8($sp)
	ld $s1, 16($sp)
	ld $s2, 24($sp)
	ld $s3, 32($sp)
	jr $ra
	addi $sp, $sp, 40

;; load a block from the memory card and append it to the cache
;; $s3 will have the target block in it, $s1 return index
Memorycard_cacheblock:
	addi $sp, $sp, -48
	sd $ra, 0($sp)
	sd $s0, 8($sp)
	sd $s2, 16($sp)
	sd $s3, 24($sp)
	sd $s4, 32($sp)
	sd $s7, 40($sp)
	li $s0, memorycard_startwrite
	jal Memorycard_set_addr	
	nop
	li $s7, mcbuffer
	jal Memorycard_read_block
	nop
	li $s0, mcblkcachep
	lwu $s1, ($s0)			; load offset for caching block
	li $s0, mcblkcache
	dsll $s2, $s1, 13		; multiply index by 8192 (length of block - CRCs)
	dadd $s0, $s0, $s2		
	li $s7, mcbuffer
	ori $s2, $zero, 0x10
Memorycard_cacheblock_toloop:
	ori $s3, $zero, 0x80
Memorycard_cacheblock_tiloop:
	lw $s4, ($s7)
	sw $s4, ($s0)
	addi $s7, $s7, 4
	addi $s3, $s3, -1
	bne $s3, $zero, Memorycard_cacheblock_tiloop
	addi $s0, $s0, 4
	addi $s2, $s2, -1
	bne $s2, $zero, Memorycard_cacheblock_toloop
	addi $s7, $s7, 16
	li $s0, mcblkcachep		; now the block has been cached, update the pointer
	addi $s2, $s1, 1		; increment it
	sw $s2, ($s0)			; store back
	sll $s2, $s2, 2			; multi 4
	add $s0, $s0, $s2		; add memory address
	ld $s3, 24($sp)
	sw $s3, ($s0)			; store block page number in list
	ld $ra, 0($sp)
	ld $s0, 8($sp)
	ld $s2, 16($sp)
	ld $s4, 32($sp)
	ld $s7, 40($sp)
	jr $ra
	addi $sp, $sp, 48

	;; give a page number and return memory address of that page in memory
;; if the page had not been cached, load it from the memory card
;; $a0 - page index, $v0 - memory address
Memorycard_findpage:
	addi $sp, $sp, -48
	sd $ra, 0($sp)
	sd $s0, 8($sp)
	sd $s1, 16($sp)
	sd $s2, 24($sp)
	sd $s3, 32($sp)
	sd $s4, 40($sp)
	andi $s3, $a0, 0xFFF0	; gives block number from page number
	andi $s4, $a0, 0xF		; gives offset in block
	li $s0, mcblkcachep
	lwu $s1, ($s0)
	sll $s2, $s1, 2		; multiply by 4
	beq $s1, $zero, Memorycard_findpage_cache
	add $s0, $s0, $s2
Memorycard_findpage_loop:
	lwu $s2, ($s0)
	beq $s2, $s3, Memorycard_findpage_end
	addi $s1, $s1, -1
	bne $s1, $zero, Memorycard_findpage_loop
	addi $s0, $s0, -4
Memorycard_findpage_cache:
	jal Memorycard_cacheblock
	nop
Memorycard_findpage_end:
	dsll $s1, $s1, 13		; multiply by large to get block offset in buffer
	sll $s4, $s4, 9			; multiply by 512 to get page offset in block
	dadd $s1, $s1, $s4
	li $v0, mcblkcache
	dadd $v0, $v0, $s1		; return the memory address of the start of the page in cache
	ld $ra, 0($sp)
	ld $s0, 8($sp)
	ld $s1, 16($sp)
	ld $s2, 24($sp)
	ld $s3, 32($sp)
	ld $s4, 40($sp)
	jr $ra
	addi $sp, $sp, 48
	

Show_fail_msg:
	addi $sp, $sp, -8
	sd $ra, 0($sp)
	li $a0, failtitle_packet
	li $a1, failtitle_packet_end
	jal GIF_send_data
	nop
	jal vsync_wait
	nop
	ld $ra, 0($sp)
	jr $ra
	addi $sp, $sp, 8

clear_screen:
    ;; Save return address register
	addi $sp, $sp, -24
	sd $ra, 0($sp)
	sd $a0,	8($sp)
	sd $a1,	16($sp)
    ;; send gif pointers
    li $a0, black_screen
	li $a1, black_screen_end
    jal GIF_send_data
	nop
    ;; Restore return address register
    ld $ra, 0($sp)
	ld $a0, 8($sp)
	ld $a1, 16($sp)
    jr $ra
    addi $sp, $sp, 24

;; enter with $a0 = address, $a1 = end
GIF_send_data:
	addi $sp, $sp, -40
	sd $ra, 0($sp)
	sd $v0, 8($sp)
	sd $v1, 16($sp)
	sd $a0, 24($sp)
	sd $a1, 32($sp)
	li $v0, D2_CHCR
    jal DMA_wait
	sub $v1, $a1, $a0
	srl $v1, $v1, 4
    sw $a0, 0x10($v0)         ; DMA02 ADDRESS
    sw $v1, 0x20($v0)         ; DMA02 SIZE
    li $v1, 0x101
    sw $v1, ($v0)             ; start
	jal DMA_wait
	nop
	ld $ra, 0($sp)
	ld $v0, 8($sp)
	ld $v1, 16($sp)
	ld $a0, 24($sp)
	ld $a1, 32($sp)
	jr $ra
	addi $sp, $sp, 40

;;  waits until vsync then return
;;  clobs $v0 and $v1
vsync_wait:
	addi $sp, $sp, -16
	sd $v0, 0($sp)
	sd $v1, 8($sp)
	li $v1, GS_CSR
    li $v0, 8
    sw $v0, ($v1)
vsync_wait_loop:
    lw $v0, ($v1)
    andi $v0, $v0, 8
    beqz $v0, vsync_wait_loop
    nop
	ld $v0, 0($sp)
	ld $v1, 8($sp)
	jr $ra
	addi $sp, $sp, 16

;; $t0 and $t1 will be destroyed
DMA_reset:
	li $t0, D2_CHCR
    sw $zero, 0x00($t0)    ; D2_CHCR
    sw $zero, 0x30($t0)    ; D2_TADR
    sw $zero, 0x10($t0)    ; D2_MADR
    sw $zero, 0x50($t0)    ; D2_ASR1
    sw $zero, 0x40($t0)    ; D2_ASR0
    li $t0, D_CTRL
    li $t1, 0xff1f
    sw $t1, 0x10($t0)      ; DMA_STAT
    sw $zero, 0x00($t0)    ; DMA_CTRL
    sw $zero, 0x20($t0)    ; DMA_PCR
    sw $zero, 0x30($t0)    ; DMA_SQWC
    sw $zero, 0x50($t0)    ; DMA_RBOR
    sw $zero, 0x40($t0)    ; DMA_RBSR
    lw $t1, 0x00($t0)      ; DMA_CTRL
    ori $t1, $t1, 1
    sw $t1, 0x00($t0)      ; DMA_CTRL
	li $t0, D_ENABLEW
	li $t1, 0x1201
	sw $t1, ($t0)

	jr $ra
    nop

	; call with the DMA channel in $v0
DMA_wait:
	;; back up $s1
    addi $sp, $sp, -8
	sd $s1, 0($sp)
DMA_waitloop:
    lw $s1, ($v0)
    andi $s1, $s1, 0x100
    bnez $s1, DMA_waitloop
    nop
	;; restore $s1
	ld $s1, 0($sp)
	jr $ra
    addi $sp, $sp, 8


.align 128
memorycard_getspecs:
	dc8 13, 0x81, 0x26, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
memorycard_probe:
	dc8 4, 0x81, 0x11, 0x00, 0x00
memorycard_erase_flush:
	dc8 4, 0x81, 0x12, 0x00, 0x00
memorycard_starterase:
	dc8 9, 0x81, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
memorycard_startwrite:
	dc8 9, 0x81, 0x22, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
memorycard_startread:
	dc8 9, 0x81, 0x23, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
memorycard_setterminator:
	dc8 5, 0x81, 0x27, 0x00, 0x00, 0x00
memorycard_getterminator:
	dc8 5, 0x81, 0x28, 0x00, 0x00, 0x00
memorycard_readwrite:
	dc8 134, 0x81, 0xFF, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
memorycard_readwrite_end:
	dc8 4, 0x81, 0x81, 0x00, 0x00
memorycard_eraseblock:
	dc8 4, 0x81, 0x82, 0x00, 0x00
.align 64
	;; read four 128byte blocks (512 bytes) and then crc (16 bytes)
memorycard_rw_page:
	dc64 0x10_8080_8080
.align 32	; this table is used to generating the page CRCs on memory card
memorycard_xor_table:
	dc8 0x00, 0x87, 0x96, 0x11, 0xa5, 0x22, 0x33, 0xb4, 0xb4, 0x33, 0x22, 0xa5, 0x11, 0x96, 0x87, 0x00
	dc8 0xc3, 0x44, 0x55, 0xd2, 0x66, 0xe1, 0xf0, 0x77, 0x77, 0xf0, 0xe1, 0x66, 0xd2, 0x55, 0x44, 0xc3
	dc8 0xd2, 0x55, 0x44, 0xc3, 0x77, 0xf0, 0xe1, 0x66, 0x66, 0xe1, 0xf0, 0x77, 0xc3, 0x44, 0x55, 0xd2
	dc8 0x11, 0x96, 0x87, 0x00, 0xb4, 0x33, 0x22, 0xa5, 0xa5, 0x22, 0x33, 0xb4, 0x00, 0x87, 0x96, 0x11
	dc8 0xe1, 0x66, 0x77, 0xf0, 0x44, 0xc3, 0xd2, 0x55, 0x55, 0xd2, 0xc3, 0x44, 0xf0, 0x77, 0x66, 0xe1
	dc8 0x22, 0xa5, 0xb4, 0x33, 0x87, 0x00, 0x11, 0x96, 0x96, 0x11, 0x00, 0x87, 0x33, 0xb4, 0xa5, 0x22
	dc8 0x33, 0xb4, 0xa5, 0x22, 0x96, 0x11, 0x00, 0x87, 0x87, 0x00, 0x11, 0x96, 0x22, 0xa5, 0xb4, 0x33
	dc8 0xf0, 0x77, 0x66, 0xe1, 0x55, 0xd2, 0xc3, 0x44, 0x44, 0xc3, 0xd2, 0x55, 0xe1, 0x66, 0x77, 0xf0
	dc8 0xf0, 0x77, 0x66, 0xe1, 0x55, 0xd2, 0xc3, 0x44, 0x44, 0xc3, 0xd2, 0x55, 0xe1, 0x66, 0x77, 0xf0
	dc8 0x33, 0xb4, 0xa5, 0x22, 0x96, 0x11, 0x00, 0x87, 0x87, 0x00, 0x11, 0x96, 0x22, 0xa5, 0xb4, 0x33
	dc8 0x22, 0xa5, 0xb4, 0x33, 0x87, 0x00, 0x11, 0x96, 0x96, 0x11, 0x00, 0x87, 0x33, 0xb4, 0xa5, 0x22
	dc8 0xe1, 0x66, 0x77, 0xf0, 0x44, 0xc3, 0xd2, 0x55, 0x55, 0xd2, 0xc3, 0x44, 0xf0, 0x77, 0x66, 0xe1
	dc8 0x11, 0x96, 0x87, 0x00, 0xb4, 0x33, 0x22, 0xa5, 0xa5, 0x22, 0x33, 0xb4, 0x00, 0x87, 0x96, 0x11
	dc8 0xd2, 0x55, 0x44, 0xc3, 0x77, 0xf0, 0xe1, 0x66, 0x66, 0xe1, 0xf0, 0x77, 0xc3, 0x44, 0x55, 0xd2
	dc8 0xc3, 0x44, 0x55, 0xd2, 0x66, 0xe1, 0xf0, 0x77, 0x77, 0xf0, 0xe1, 0x66, 0xd2, 0x55, 0x44, 0xc3
	dc8 0x00, 0x87, 0x96, 0x11, 0xa5, 0x22, 0x33, 0xb4, 0xb4, 0x33, 0x22, 0xa5, 0x11, 0x96, 0x87, 0x00
.align 128
black_screen:
    dc64 GIF_TAG(14, 1, 0, 0, FLG_PACKED, 1), REG_A_D
    dc64 (FMT_PSMCT16 << 24) | ((320/64) << 16), REG_FRAME_1  ; framebuffer config
    dc64 (FMT_PSMCT16 << 24) | 0x70, REG_ZBUF_1		; zbuf config (size of FB in bytes/2048)
	dc64 SETREG_XYOFFSET(1728 << 4, 1936 << 4), REG_XYOFFSET_1
    dc64 SETREG_SCISSOR(0,319,0,223), REG_SCISSOR_1
    dc64 1, REG_PRMODECONT                 ; refer to prim attributes
    dc64 1, REG_COLCLAMP
    dc64 0, REG_DTHE                       ; Dither off
    dc64 0x30000, REG_TEST_1
    dc64 0x30000, REG_TEST_1
    dc64 PRIM_SPRITE, REG_PRIM
    dc64 0x3f80_0000_0000_0000, REG_RGBAQ  ; Background RGBA (A, blue, green, red)
    dc64 SETREG_XYZ2(1728 << 4, 1936 << 4, 0), REG_XYZ2
    dc64 SETREG_XYZ2(2368 << 4, 2384 << 4, 0), REG_XYZ2
    dc64 0x30000, REG_TEST_1
black_screen_end:
.align 128
failtitle_packet:
	dc64 GIF_TAG(4, 1, 0, 0, FLG_PACKED, 1), REG_A_D
	dc64 SETREG_BITBLTBUF(0, 0, 0, 0 / 64, 320 / 64, FMT_PSMCT16), REG_BITBLTBUF
	dc64 SETREG_TRXPOS(0, 0, 224, 176, DIR_UL_LR), REG_TRXPOS
	dc64 SETREG_TRXREG(64, 16), REG_TRXREG
	dc64 SETREG_TRXDIR(XDIR_HOST_TO_LOCAL), REG_TRXDIR
	dc64 GIF_TAG(((failtitle_bin_end - failtitle_bin) / 16), 1, 0, 0, FLG_IMAGE, 1), REG_A_D
failtitle_bin:
	.binfile "FAILstr.img"
failtitle_bin_end:
failtitle_packet_end:
.align 128
	dc64 1

