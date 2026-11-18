# rubik_solve_asm: optimal 2x2x2 cube solver, hand-written RV32I.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
#                                   a0 = state, a1 = out, a2 = cap; result in a0
#
# The prefix search uses a bounded stack of frames. The tail table stores
# one optimal step per state and the projected distances prune the prefix.

    .include "src/rubik/rubik_tables.inc"
    .text

    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
    # Local path at 0(sp), rendered text at 16(sp).
    addi    sp, sp, -96
    sw      ra, 92(sp)
    sw      s0, 88(sp)
    sw      s1, 84(sp)
    sw      s2, 80(sp)
    sw      s3, 76(sp)
    sw      s4, 72(sp)
    sw      s5, 68(sp)
    sw      s7, 60(sp)
    sw      s8, 56(sp)
    mv      s0, a1                     # Output pointer.
    mv      s1, a2                     # Output capacity.

    # Rank the permutation using the count of still-available smaller digits.
    li      t1, 127                    # Available digits.
    li      s2, 0                      # Permutation rank.
    la      t3, .Lrank_weights
    li      t4, 7
    li      a5, 1
.Lparse_perm:
    lbu     t5, 0(a0)
    addi    a0, a0, 1
    addi    t5, t5, -49
    li      a3, 7
    bgeu    t5, a3, .Linvalid
    sll     t6, a5, t5
    and     a3, t6, t1
    beqz    a3, .Linvalid
    xor     t1, t1, t6
    addi    t6, t6, -1
    and     t6, t6, t1                # Available digits below this one.
    mv      a3, t3
    beqz    t6, .Ladd_rank
.Lcount_smaller:
    addi    a4, t6, -1
    and     t6, t6, a4
    addi    a3, a3, 2
    bnez    t6, .Lcount_smaller
.Ladd_rank:
    lhu     a3, 0(a3)
    add     s2, s2, a3
    addi    t3, t3, 16
    addi    t4, t4, -1
    bnez    t4, .Lparse_perm

    li      t0, 6
    li      s3, 0                      # Orientation rank.
    li      t1, 0                      # Orientation sum.
    li      t2, 3
.Lparse_orient:
    lbu     t3, 0(a0)
    addi    a0, a0, 1
    addi    t3, t3, -49
    bgeu    t3, t2, .Linvalid
    slli    t4, s3, 1
    add     s3, s3, t4
    add     s3, s3, t3
    add     t1, t1, t3
    addi    t0, t0, -1
    bnez    t0, .Lparse_orient
    lbu     t3, 0(a0)
    addi    t3, t3, -49
    bgeu    t3, t2, .Linvalid
    lbu     t4, 1(a0)
    bnez    t4, .Linvalid
    add     t1, t1, t3
    li      t3, 0x1249                 # Bits 0, 3, 6, 9 and 12.
    srl     t3, t3, t1
    andi    t3, t3, 1
    beqz    t3, .Linvalid
    beqz    s1, .Lshort_output

    la      s7, .Lnext_p
    la      s8, .Lnext_o
    li      s4, 0                      # Number of moves in the path.
    mv      a1, s2
    mv      a2, s3
    jal     ra, .Llookup_near
    bnez    a0, .Lfollow_tail
    la      a5, .Ldiameter
    li      a6, .Ldiameter_count
    jal     ra, .Llookup
    li      s5, 1                      # Smallest prefix for a state beyond the table.
    beqz    a0, .Ltry_prefix

    # For a state at diameter 11 the stored first move leaves distance 10.
    andi    a0, a0, 15
    sb      a0, 0(sp)
    li      s4, 1
    jal     ra, .Lturn
    mv      s2, a1
    mv      s3, a2
    li      s5, 5
.Ltry_prefix:
    mv      a0, s2
    mv      a1, s3
    mv      a2, s5
    add     a3, sp, s4
    jal     ra, .Lsearch_prefix
    bnez    a0, .Ljoin_prefix
    addi    s5, s5, 1
    li      t0, 5
    bgeu    t0, s5, .Ltry_prefix
    j       .Linvalid
.Ljoin_prefix:
    add     s4, s4, s5
.Lfollow_tail:
    andi    t0, a0, 0x70               # Zero distance marks the solved cube.
    beqz    t0, .Lrender
    andi    a0, a0, 15
    add     t0, sp, s4
    sb      a0, 0(t0)
    addi    s4, s4, 1
    jal     ra, .Lturn
    jal     ra, .Llookup_near
    j       .Lfollow_tail

.Lrender:
    # Render to the local buffer first so an undersized output stays empty.
    addi    a3, sp, 16
    mv      t0, sp
    add     t1, sp, s4
    la      t2, .Lmove_names
    beqz    s4, .Lrender_end
.Lrender_move:
    lbu     t3, 0(t0)
    slli    t3, t3, 1
    add     t3, t2, t3
    lbu     t4, 0(t3)
    lbu     t5, 1(t3)
    sb      t4, 0(a3)
    addi    a3, a3, 1
    beqz    t5, .Lrender_separator
    sb      t5, 0(a3)
    addi    a3, a3, 1
.Lrender_separator:
    addi    t0, t0, 1
    beq     t0, t1, .Lrender_end
    li      t4, 32
    sb      t4, 0(a3)
    addi    a3, a3, 1
    j       .Lrender_move
.Lrender_end:
    sb      zero, 0(a3)
    addi    t0, sp, 16
    sub     t1, a3, t0
    addi    t1, t1, 1
    bltu    s1, t1, .Lshort_output
.Lcopy_text:
    lbu     t2, 0(t0)
    sb      t2, 0(s0)
    addi    t0, t0, 1
    addi    s0, s0, 1
    bnez    t2, .Lcopy_text
    mv      a0, s4
    j       .Ldone
.Lshort_output:
    beqz    s1, .Lshort_return
    sb      zero, 0(s0)
.Lshort_return:
    li      a0, -2
    j       .Ldone
.Linvalid:
    li      a0, -1
.Ldone:
    lw      s8, 56(sp)
    lw      s7, 60(sp)
    lw      s5, 68(sp)
    lw      s4, 72(sp)
    lw      s3, 76(sp)
    lw      s2, 80(sp)
    lw      s1, 84(sp)
    lw      s0, 88(sp)
    lw      ra, 92(sp)
    addi    sp, sp, 96
    ret
    .size   rubik_solve_asm, .-rubik_solve_asm

# Apply move a0 to a1:a2 (permutation and orientation), preserving table bases
# s7 and s8 supplied by the outer solver.
.Lturn:
    li      t0, 0
    li      t1, 3
.Lturn_face:
    bltu    a0, t1, .Lturn_once
    addi    a0, a0, -3
    addi    t0, t0, 1
    j       .Lturn_face
.Lturn_once:
    slli    t1, a1, 1
    slli    t2, a2, 1
    add     t1, t1, a1
    add     t2, t2, a2
    add     t1, t1, t0
    add     t2, t2, t0
    slli    t1, t1, 1
    slli    t2, t2, 1
    add     t1, s7, t1
    add     t2, s8, t2
    lhu     a1, 0(t1)
    lhu     a2, 0(t2)
    addi    a0, a0, -1
    bgez    a0, .Lturn_once
    ret

.Llookup_near:
    la      a5, .Lnear
    la      a6, .Lnear_offsets
# A directory maps the permutation to the inclusive/exclusive table offsets.
.Llookup_near_slice:
    slli    t0, a1, 1
    add     t0, a6, t0
    lhu     t1, 0(t0)
    lhu     t2, 2(t0)
    sub     a6, t2, t1
    slli    t1, t1, 2
    add     a5, a5, t1
# Lower bound on the shifted key. Distance and move occupy the low seven
# bits. These lookup helpers preserve a1:a2 for the search.
.Llookup:
    slli    t0, a1, 17
    slli    t1, a2, 7
    or      t0, t0, t1
    mv      t1, a5                     # Base of the current slice.
    mv      t2, a6                     # Length of the slice, in words.
.Llookup_loop:
    beqz    t2, .Llookup_end
    srli    t3, t2, 1
    slli    t4, t3, 2
    add     t4, t1, t4
    lw      t5, 0(t4)
    bltu    t5, t0, .Llookup_right
    mv      t2, t3
    j       .Llookup_loop
.Llookup_right:
    addi    t1, t4, 4
    sub     t2, t2, t3
    addi    t2, t2, -1
    j       .Llookup_loop
.Llookup_end:
    slli    t2, a6, 2
    add     t2, a5, t2
    beq     t1, t2, .Llookup_miss
    lw      a0, 0(t1)
    xor     t0, t0, a0
    srli    t0, t0, 7
    beqz    t0, .Llookup_done
.Llookup_miss:
    li      a0, 0
.Llookup_done:
    ret

# a0:a1 = start coordinates, a2 = exact prefix length (1..5), a3 = path.
# Returns the tail-table word in a0 and the joined coordinates in a1:a2.
# A 32-byte frame holds the starting coordinates (0,4), next face and turn
# (8,12), the last same-face sibling (16,20), and the preceding face (24).
.Lsearch_prefix:
    addi    sp, sp, -208
    sw      ra, 204(sp)
    sw      s0, 200(sp)
    sw      s1, 196(sp)
    sw      s2, 192(sp)
    sw      s3, 188(sp)
    sw      s4, 184(sp)
    sw      s5, 180(sp)
    sw      s6, 176(sp)
    sw      s7, 172(sp)
    sw      s8, 168(sp)
    mv      s0, sp
    mv      s1, a3
    mv      s2, a2
    mv      s3, s7
    mv      s4, s8
    la      s5, .Ldistance_p
    la      s6, .Ldistance_o
    la      s7, .Lnear
    la      s8, .Lnear_offsets
    li      t0, 3
    mv      a2, a1
    mv      a1, a0
.Lstart_frame:
    sw      a1, 0(s0)
    sw      a2, 4(s0)
    sw      zero, 8(s0)
    sw      zero, 12(s0)
    sw      a1, 16(s0)
    sw      a2, 20(s0)
    sw      t0, 24(s0)
.Lnext_candidate:
    lw      t0, 8(s0)
    li      t6, 3
    beq     t0, t6, .Lpop_frame
    lw      t1, 24(s0)
    beq     t0, t1, .Lnext_face
    lw      t2, 12(s0)
    beq     t2, t6, .Lnext_face

    lw      a1, 16(s0)
    lw      a2, 20(s0)
    slli    t3, a1, 1
    slli    t4, a2, 1
    add     t3, t3, a1
    add     t4, t4, a2
    add     t3, t3, t0
    add     t4, t4, t0
    slli    t3, t3, 1
    slli    t4, t4, 1
    add     t3, s3, t3
    add     t4, s4, t4
    lhu     a1, 0(t3)
    lhu     a2, 0(t4)
    sw      a1, 16(s0)
    sw      a2, 20(s0)
    addi    t3, t2, 1
    sw      t3, 12(s0)

    add     t3, s5, a1
    lbu     t3, 0(t3)
    addi    t5, s2, 4
    bltu    t5, t3, .Lnext_candidate
    add     t4, s6, a2
    lbu     t4, 0(t4)
    bltu    t5, t4, .Lnext_candidate
    slli    t3, t0, 1
    add     t3, t3, t0
    add     t3, t3, t2
    sb      t3, 0(s1)

    addi    s2, s2, -1
    beqz    s2, .Lleaf
    addi    s0, s0, 32
    addi    s1, s1, 1
    j       .Lstart_frame
.Lleaf:
    mv      a5, s7
    mv      a6, s8
    jal     ra, .Llookup_near_slice
    bnez    a0, .Lsearch_done
    addi    s2, s2, 1
    j       .Lnext_candidate
.Lnext_face:
    addi    t0, t0, 1
    sw      t0, 8(s0)
    sw      zero, 12(s0)
    lw      t1, 0(s0)
    lw      t2, 4(s0)
    sw      t1, 16(s0)
    sw      t2, 20(s0)
    j       .Lnext_candidate
.Lpop_frame:
    beq     s0, sp, .Lsearch_miss
    addi    s0, s0, -32
    addi    s1, s1, -1
    addi    s2, s2, 1
    j       .Lnext_candidate
.Lsearch_miss:
    li      a0, 0
.Lsearch_done:
    lw      s8, 168(sp)
    lw      s7, 172(sp)
    lw      s6, 176(sp)
    lw      s5, 180(sp)
    lw      s4, 184(sp)
    lw      s3, 188(sp)
    lw      s2, 192(sp)
    lw      s1, 196(sp)
    lw      s0, 200(sp)
    lw      ra, 204(sp)
    addi    sp, sp, 208
    ret

    .section .rodata
.Lmove_names:
    .byte 82, 0, 82, 50, 82, 39         # R, R2, R'
    .byte 66, 0, 66, 50, 66, 39         # B, B2, B'
    .byte 68, 0, 68, 50, 68, 39         # D, D2, D'
    .balign 2
.Lrank_weights:
    .macro rank_row weight
    .set smaller, 0
    .rept 8
    .half smaller * \weight
    .set smaller, smaller + 1
    .endr
    .endm
    rank_row 720
    rank_row 120
    rank_row 24
    rank_row 6
    rank_row 2
    rank_row 1
    rank_row 1
