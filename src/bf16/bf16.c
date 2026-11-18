#include "bf16.h"

#define BF16_SIGN 0x8000u
#define BF16_INF 0x7f80u
#define BF16_NAN 0x7fc0u
#define BF16_FRACTION 0x7fu
#define BF16_HIDDEN 0x80u

/* Dummies: every function returns 0. Replace with the real routines. */
uint16_t bf16_from_f32(uint32_t f32bits)
{
    if ((f32bits & 0x7f800000u) != 0x7f800000u) {
        uint32_t last_kept_bit = (f32bits >> 16) & 1u;
        f32bits += 0x7fffu + last_kept_bit;
    }

    return (uint16_t) (f32bits >> 16);
}

static unsigned normalized_significand(unsigned magnitude, int *exponent)
{
    unsigned fraction = magnitude & BF16_FRACTION;
    *exponent = (int) (magnitude >> 7);

    if (*exponent != 0)
        return fraction | BF16_HIDDEN;

    *exponent = 1;
    do {
        fraction <<= 1;
        --*exponent;
    } while (fraction < BF16_HIDDEN);

    return fraction;
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    unsigned sign = (a ^ b) & BF16_SIGN;
    unsigned x = a & (BF16_SIGN - 1u);
    unsigned y = b & (BF16_SIGN - 1u);

    if (x >= BF16_INF) {
        if (x > BF16_INF)
            return a;
        return y ? (uint16_t) (sign | BF16_INF) : BF16_NAN;
    }
    if (y >= BF16_INF) {
        if (y > BF16_INF)
            return b;
        return x ? (uint16_t) (sign | BF16_INF) : BF16_NAN;
    }
    if (x == 0u || y == 0u)
        return (uint16_t) sign;

    int exp_x, exp_y;
    unsigned sig_x = normalized_significand(x, &exp_x);
    unsigned sig_y = normalized_significand(y, &exp_y);
    unsigned product = sig_x * sig_y;
    int exponent = exp_x + exp_y - 127;

    if (product & 0x8000u) {
        product >>= 1;
        ++exponent;
    }

    unsigned fraction = (product >> 7) & BF16_FRACTION;

    if (exponent >= 255)
        return (uint16_t) (sign | BF16_INF);
    if (exponent > 0)
        return (uint16_t) (sign | ((unsigned) exponent << 7) | fraction);
    if (exponent < -6)
        return (uint16_t) sign;

    return (uint16_t) (sign | (fraction >> (1 - exponent)));
}

uint16_t bf16_sqrt(uint16_t a)
{
    (void) a;
    return 0;
}
