    .text
    .globl gcd_u32_asm
    .type  gcd_u32_asm, @function
    .align 2

gcd_u32_asm:
    beqz    a0, .Lreturn_b
    beqz    a1, .Ldone
    li      t0, 0

.Lcommon_twos:
    or      t1, a0, a1
    andi    t1, t1, 1
    bnez    t1, .Lstrip_a
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    t0, t0, 1
    j       .Lcommon_twos

.Lstrip_a:
    andi    t1, a0, 1
    bnez    t1, .Lstrip_b
    srli    a0, a0, 1
    j       .Lstrip_a

.Lhalve_b:
    srli    a1, a1, 1

.Lstrip_b:
    andi    t1, a1, 1
    beqz    t1, .Lhalve_b

.Lorder:
    bgeu    a1, a0, .Lsubtract
    mv      t1, a0
    mv      a0, a1
    mv      a1, t1

.Lsubtract:
    sub     a1, a1, a0
    bnez    a1, .Lhalve_b
    sll     a0, a0, t0

.Ldone:
    ret

.Lreturn_b:
    mv      a0, a1
    ret

    .size gcd_u32_asm, .-gcd_u32_asm
