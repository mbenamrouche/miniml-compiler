.text
	beqz $a0, init_end
	lw $a0, 0($a1)
	jal atoi
init_end:
	subi $sp, $sp, 4
	sw $v0, 0($sp)
	jal main
	li $v0, 10
	syscall
main:
	subi $sp, $sp, 4
	sw $fp, 0($sp)
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	addi $fp, $sp, 4
	addi $sp, $sp, 0
	subi $sp, $sp, 4
	sw $s0, 0($sp)
	subi $sp, $sp, 4
	sw $s1, 0($sp)
	subi $sp, $sp, 4
	sw $s2, 0($sp)
	li $t0, 0
	move $s1, $t0
	li $t0, 10
	move $s2, $t0
	li $t0, 32
	la $t1, espace
	sw $t0, 0($t1)
	b __main_0
__main_1:
	move $t0, $s0
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	move $t0, $s1
	subi $sp, $sp, 4
	sw $t0, 0($sp)
	jal affiche_ligne
	addi $sp, $sp, 8
	move $t0, $s2
	move $a0, $t0
	li $v0, 11
	syscall
	move $t0, $s1
	li $t1, 1
	add $t0, $t0, $t1
	move $s1, $t0
__main_0:
	move $t0, $s1
	move $t1, $s0
	li $t2, 1
	add $t1, $t1, $t2
	slt $t0, $t0, $t1
	bnez $t0, __main_1
	lw $s2, 0($sp)
	addi $sp, $sp, 4
	lw $s1, 0($sp)
	addi $sp, $sp, 4
	lw $s0, 0($sp)
	addi $sp, $sp, 4
	addi $sp, $sp, 0
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	lw $fp, 0($sp)
	addi $sp, $sp, 4
	li $t0, 0
	jr $ra
affiche_ligne:
	subi $sp, $sp, 4
	sw $fp, 0($sp)
	subi $sp, $sp, 4
	sw $ra, 0($sp)
	addi $fp, $sp, 4
	addi $sp, $sp, 0
	subi $sp, $sp, 4
	sw $s0, 0($sp)
	subi $sp, $sp, 4
	sw $s1, 0($sp)
	subi $sp, $sp, 4
	sw $s2, 0($sp)
	subi $sp, $sp, 4
	sw $s3, 0($sp)
	li $t0, 0
	move $s3, $t0
	b __affiche_ligne_0
__affiche_ligne_1:
	move $t0, $s0
	move $t1, $s0
	mul $t0, $t0, $t1
	move $t1, $s3
	move $t2, $s3
	mul $t1, $t1, $t2
	add $t0, $t0, $t1
	move $t1, $s2
	move $t2, $s2
	mul $t1, $t1, $t2
	slt $t0, $t0, $t1
	bnez $t0, __affiche_ligne_2
	li $t0, 35
	move $a0, $t0
	li $v0, 11
	syscall
	b __affiche_ligne_3
__affiche_ligne_2:
	li $t0, 46
	move $a0, $t0
	li $v0, 11
	syscall
__affiche_ligne_3:
	move $t0, $s1
	move $a0, $t0
	li $v0, 11
	syscall
	move $t0, $s3
	li $t1, 1
	add $t0, $t0, $t1
	move $s3, $t0
__affiche_ligne_0:
	move $t0, $s3
	move $t1, $s2
	li $t2, 1
	add $t1, $t1, $t2
	slt $t0, $t0, $t1
	bnez $t0, __affiche_ligne_1
	lw $s3, 0($sp)
	addi $sp, $sp, 4
	lw $s2, 0($sp)
	addi $sp, $sp, 4
	lw $s1, 0($sp)
	addi $sp, $sp, 4
	lw $s0, 0($sp)
	addi $sp, $sp, 4
	addi $sp, $sp, 0
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	lw $fp, 0($sp)
	addi $sp, $sp, 4
	li $t0, 0
	jr $ra
#built-in atoi
atoi:
	li $v0, 0
atoi_loop:
	lbu $t0, 0($a0)
	beqz $t0, atoi_end
	addi $t0, $t0, -48
	bltz $t0, atoi_error
	bge $t0, 10, atoi_error
	mul $v0, $v0, 10
	add $v0, $v0, $t0
	addi $a0, $a0, 1
	b atoi_loop
atoi_error:
	li $v0, 10
	syscall
atoi_end:
	jr $ra
.data
retour:
	.word 0
espace:
	.word 0
