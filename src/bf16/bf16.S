# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    slli    t0, a0, 1
    li      t1, 0xff000000
    srli    t2, a0, 16
    bgeu    t0, t1, .Lf32_high

    slli    t0, a0, 16
    li      t1, 0x80000000
    bltu    t0, t1, .Lf32_high
    bne     t0, t1, .Lf32_round_up

    andi    t1, t2, 1
    add     a0, t2, t1
    ret

.Lf32_round_up:
    addi    a0, t2, 1
    ret

.Lf32_high:
    mv      a0, t2
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    # Keep the output sign and extract the two magnitudes.
    xor     t0, a0, a1
    srli    t0, t0, 15
    slli    t0, t0, 15
    slli    a2, a0, 17
    slli    a3, a1, 17
    srli    a2, a2, 17
    srli    a3, a3, 17
    li      t1, 0x7f80
    bgeu    a2, t1, .Lmul_special_a
    bgeu    a3, t1, .Lmul_special_b
    beqz    a2, .Lmul_zero
    beqz    a3, .Lmul_zero

    # a2/a3 hold significands, and a4/a5 hold biased exponents.
    srli    a4, a2, 7
    srli    a5, a3, 7
    andi    a2, a2, 127
    andi    a3, a3, 127
    beqz    a4, .Lmul_subnormal_a
    ori     a2, a2, 128
.Lmul_normal_a:
    beqz    a5, .Lmul_subnormal_b
    ori     a3, a3, 128

.Lmul_normal_b:
    # Bit 7 of the multiplier is set after normalization.
    slli    a6, a2, 7
    .set    bit, 0
    .rept   7
    andi    t2, a3, (1 << bit)
    beqz    t2, 1f
    slli    t2, a2, bit
    add     a6, a6, t2
1:
    .set    bit, bit + 1
    .endr

    # Normalize the product and truncate the fraction.
    add     a4, a4, a5
    srli    t2, a6, 15
    addi    a4, a4, -127
    add     a4, a4, t2
    srli    a6, a6, 7
    srl     a6, a6, t2
    li      t2, 255
    bge     a4, t2, .Lmul_inf
    blez    a4, .Lmul_underflow
    andi    a6, a6, 127
    slli    a4, a4, 7
    or      t0, t0, a4
    or      a0, t0, a6
    ret

.Lmul_underflow:
    li      t2, -6
    blt     a4, t2, .Lmul_zero
    li      t2, 1
    sub     t2, t2, a4
    andi    a6, a6, 127
    srl     a6, a6, t2
    or      a0, t0, a6
    ret

.Lmul_subnormal_a:
    li      a4, 1
2:
    slli    a2, a2, 1
    addi    a4, a4, -1
    srli    t2, a2, 7
    beqz    t2, 2b
    j       .Lmul_normal_a

.Lmul_subnormal_b:
    li      a5, 1
3:
    slli    a3, a3, 1
    addi    a5, a5, -1
    srli    t2, a3, 7
    beqz    t2, 3b
    j       .Lmul_normal_b

.Lmul_special_a:
    bne     a2, t1, .Lmul_return
    bnez    a3, .Lmul_inf
    j       .Lmul_nan

.Lmul_special_b:
    mv      a0, a1
    bne     a3, t1, .Lmul_return
    beqz    a2, .Lmul_nan

.Lmul_inf:
    or      t0, t0, t1
.Lmul_zero:
    mv      a0, t0
.Lmul_return:
    ret

.Lmul_nan:
    li      a0, 0x7fc0
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    slli    t0, a0, 17
    srli    t0, t0, 17
    li      t1, 0x7f80
    bltu    t1, t0, .Lsqrt_return
    srli    t2, a0, 15
    bnez    t2, .Lsqrt_negative
    beq     t0, t1, .Lsqrt_return
    srli    t0, a0, 7
    beqz    t0, .Lsqrt_zero

    # Index the table by unbiased exponent parity and fraction.
    addi    t0, t0, -127
    andi    t1, t0, 1
    slli    t1, t1, 7
    andi    t2, a0, 127
    or      t1, t1, t2
    la      t2, .Lsqrt_fraction
    add     t2, t2, t1
    lbu     t2, 0(t2)

    # Halve the exponent and pack the BFloat16 result.
    srai    t0, t0, 1
    addi    t0, t0, 127
    slli    t0, t0, 7
    or      a0, t0, t2
.Lsqrt_return:
    ret

.Lsqrt_negative:
    beqz    t0, .Lsqrt_zero
    li      a0, 0x7fc0
    ret

.Lsqrt_zero:
    li      a0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm

    .section .rodata
.Lsqrt_fraction:
    # Two rows indexed by exponent parity and input fraction.
    .set parity, 0
    .rept 2
    .set fraction, 0
    .set root, 127 + 53 * parity
    .rept 128
    .set radicand, (((128 + fraction) << parity) << 7) + 127
    .rept 2
    .if (root + 1) * (root + 1) <= radicand
    .set root, root + 1
    .endif
    .endr
    .byte root & 127
    .set fraction, fraction + 1
    .endr
    .set parity, parity + 1
    .endr
