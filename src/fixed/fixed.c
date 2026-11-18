#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;

    while (b != 0u) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        ++passes;
    }

    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t x = a < 0 ? 0u - (uint32_t) a : (uint32_t) a;
    uint32_t y = b < 0 ? 0u - (uint32_t) b : (uint32_t) b;
    uint32_t low = 0;
    uint32_t high = 0;
    uint32_t term_high = 0;

    /* Multiply the magnitudes using shifts and additions. */
    while (y != 0u) {
        if (y & 1u) {
            uint32_t next = low + x;
            high += term_high + (next < low);
            low = next;
        }

        term_high = (term_high << 1) | (x >> 31);
        x <<= 1;
        y >>= 1;
    }

    /* Negate the 64-bit product when the input signs differ. */
    if ((a < 0) != (b < 0)) {
        high = ~high + (low == 0u);
        low = 0u - low;
    }

    /* Add half a unit, then keep 32 bits of the scaled result. */
    uint32_t half = 1u << (Q - 1);
    high += low > UINT32_MAX - half;
    uint32_t rounded = low + half;
    uint32_t bits = (high << (32 - Q)) | (rounded >> Q);

    return bits <= INT32_MAX ? (int32_t) bits : -1 - (int32_t) ~bits;
}
