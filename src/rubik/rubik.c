#include "rubik.h"

#include "rubik_tables.h"

enum { CUBIES = 7, TAIL_DEPTH = 5, DIAMETER = 11 };

struct coordinate {
    unsigned perm;
    unsigned orient;
};

static int parse(const char *state, struct coordinate *start)
{
    unsigned char cubies[CUBIES];
    unsigned seen = 0;
    for (unsigned i = 0; i < CUBIES; ++i) {
        unsigned digit = (unsigned char) state[i] - (unsigned) '1';
        if (digit >= CUBIES || (seen & (1u << digit)))
            return 0;
        cubies[i] = (unsigned char) digit;
        seen |= 1u << digit;
    }
    unsigned sum = 0, orient = 0;
    for (unsigned i = 0; i < CUBIES; ++i) {
        unsigned digit = (unsigned char) state[CUBIES + i] - (unsigned) '1';
        if (digit >= 3)
            return 0;
        sum += digit;
        if (i < CUBIES - 1)
            orient = 3 * orient + digit;
    }
    /* With seven digits in [0, 2], the only multiples are 0, 3, 6, 9, 12. */
    if (state[RUBIK_STATE_LEN] || !(0x1249u & (1u << sum)))
        return 0;

    unsigned perm = 0;
    for (unsigned i = 0; i < CUBIES; ++i) {
        unsigned smaller = 0;
        for (unsigned j = i + 1; j < CUBIES; ++j)
            smaller += cubies[j] < cubies[i];
        perm = perm * (CUBIES - i) + smaller;
    }
    *start = (struct coordinate) {perm, orient};
    return 1;
}

static uint32_t lookup(struct coordinate state,
                       const uint32_t *table,
                       unsigned count)
{
    uint32_t key = (state.perm << 10) | state.orient;
    unsigned low = 0, high = count;
    while (low < high) {
        unsigned mid = low + ((high - low) >> 1);
        if ((table[mid] >> 7) < key)
            low = mid + 1;
        else
            high = mid;
    }
    return low < count && (table[low] >> 7) == key ? table[low] : 0;
}

static struct coordinate quarter_turn(struct coordinate state, unsigned face)
{
    return (struct coordinate) {next_p[3 * state.perm + face],
                                next_o[3 * state.orient + face]};
}

static struct coordinate turn(struct coordinate state, unsigned move)
{
    unsigned face = move < 3 ? 0 : move < 6 ? 1 : 2;
    unsigned turns = move - 3 * face + 1;
    do {
        state = quarter_turn(state, face);
    } while (--turns);
    return state;
}

/* Search an exact prefix because a shortest solution of length >= 5 has a
 * suffix of exactly five moves. One coordinate's shortest path is a lower
 * bound on the full state's remaining distance. */
static uint32_t search(struct coordinate state,
                       unsigned left,
                       unsigned previous_face,
                       unsigned char *path,
                       struct coordinate *joint)
{
    if (!left) {
        uint32_t entry = lookup(state, near, sizeof near / sizeof *near);
        if (entry)
            *joint = state;
        return entry;
    }
    unsigned bound = left + TAIL_DEPTH - 1;
    for (unsigned face = 0; face < 3; ++face) {
        if (face == previous_face)
            continue;
        struct coordinate child = state;
        for (unsigned step = 0; step < 3; ++step) {
            child = quarter_turn(child, face);
            if (distance_p[child.perm] > bound ||
                distance_o[child.orient] > bound)
                continue;
            uint32_t entry = search(child, left - 1, face, path + 1, joint);
            if (entry) {
                *path = (unsigned char) (3 * face + step);
                return entry;
            }
        }
    }
    return 0;
}

static int write_solution(const unsigned char *path,
                          unsigned length,
                          char *out,
                          size_t cap)
{
    static const char tokens[9][2] = {{'R', 0}, {'R', '2'}, {'R', '\''},
                                      {'B', 0}, {'B', '2'}, {'B', '\''},
                                      {'D', 0}, {'D', '2'}, {'D', '\''}};
    size_t needed = length ? 2 * length : 1;
    for (unsigned i = 0; i < length; ++i)
        needed += tokens[path[i]][1] != 0;
    if (cap < needed) {
        if (cap)
            out[0] = '\0';
        return -2;
    }
    for (unsigned i = 0; i < length; ++i) {
        unsigned move = path[i];
        if (i)
            *out++ = ' ';
        *out++ = tokens[move][0];
        if (tokens[move][1])
            *out++ = tokens[move][1];
    }
    *out = '\0';
    return (int) length;
}

int rubik_solve(const char *state, char *out, size_t cap)
{
    struct coordinate start;
    if (!parse(state, &start))
        return -1;
    if (!cap)
        return -2;

    unsigned char path[DIAMETER];
    unsigned length = 0;
    struct coordinate joint = start;
    uint32_t entry = lookup(start, near, sizeof near / sizeof *near);
    if (!entry) {
        uint32_t far =
            lookup(start, diameter, sizeof diameter / sizeof *diameter);
        unsigned first = 1;
        if (far) {
            unsigned move = far & 15u;
            path[length++] = (unsigned char) move;
            start = turn(start, move);
            first = TAIL_DEPTH;
        }
        for (unsigned prefix = first; prefix <= TAIL_DEPTH; ++prefix) {
            entry = search(start, prefix, 3, path + length, &joint);
            if (entry) {
                length += prefix;
                break;
            }
        }
    }
    if (!entry)
        return -1;

    while ((entry >> 4) & 7u) {
        unsigned move = entry & 15u;
        path[length++] = (unsigned char) move;
        joint = turn(joint, move);
        entry = lookup(joint, near, sizeof near / sizeof *near);
    }
    return write_solution(path, length, out, cap);
}
