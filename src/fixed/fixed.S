# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li      t0, 0
    beqz    a1, .Lop1_done

.Lop1_loop:
    and     t1, a0, a1
    xor     a0, a0, a1
    slli    a1, t1, 1
    addi    t0, t0, 1
    bnez    a1, .Lop1_loop

.Lop1_done:
    sw      t0, 0(a2)
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and     t0, a0, a1
    xor     t1, a0, a1
    srli    t1, t1, 1
    add     a0, t0, t1
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    # a2:a0 holds the signed multiplicand.
    # t1 is the sign mask of b, and a1 becomes its magnitude.
    srai    a2, a0, 31
    srai    t1, a1, 31
    xor     a1, a1, t1
    sub     a1, a1, t1

    # a4:a3 holds the 64-bit product.
    li      a3, 0
    li      a4, 0
    beqz    a1, .Lq_round

.Lq_product:
    andi    t0, a1, 1
    beqz    t0, .Lq_shift
    add     a3, a3, a0
    add     a4, a4, a2
    sltu    t0, a3, a0
    add     a4, a4, t0

.Lq_shift:
    srli    t0, a0, 31
    slli    a2, a2, 1
    slli    a0, a0, 1
    or      a2, a2, t0
    srli    a1, a1, 1
    bnez    a1, .Lq_product

    # Restore the sign of b in the full product.
    beqz    t1, .Lq_round
    neg     a3, a3
    seqz    t0, a3
    not     a4, a4
    add     a4, a4, t0

.Lq_round:
    li      t0, 0x80000
    add     a3, a3, t0
    sltu    t1, a3, t0
    add     a4, a4, t1
    srli    a3, a3, 20
    slli    a4, a4, 12
    or      a0, a3, a4
    ret
    .size   q_mul_asm, .-q_mul_asm
