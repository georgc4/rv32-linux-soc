/* Integer-only 8x8 grayscale nearest-prototype baseline. No custom ISA. */
#include <stdint.h>
#include <stdio.h>

/* Rows are binary stroke prototypes, expanded to 0/255 at inference time. */
static const char *const glyph[10][8] = {
    {"..####..", ".##..##.", "##....##", "##....##", "##....##", "##....##", ".##..##.", "..####.."},
    {"...##...", "..###...", ".####...", "...##...", "...##...", "...##...", "...##...", ".######."},
    {"..####..", ".##..##.", ".....##.", "....##..", "..##....", ".##.....", "##......", "########"},
    {".######.", ".....##.", "....##..", "..####..", ".....##.", ".....##.", ".##..##.", "..####.."},
    {"....##..", "...###..", "..####..", ".##.##..", "##..##..", "########", "....##..", "....##.."},
    {"########", "##......", "##......", "######..", ".....##.", ".....##.", ".##..##.", "..####.."},
    {"..####..", ".##..##.", "##......", "######..", "##...##.", "##...##.", ".##..##.", "..####.."},
    {"########", ".....##.", "....##..", "...##...", "..##....", "..##....", "..##....", "..##...."},
    {"..####..", ".##..##.", ".##..##.", "..####..", ".##..##.", ".##..##.", ".##..##.", "..####.."},
    {"..####..", ".##..##.", ".##..##.", "..#####.", ".....##.", ".....##.", ".##..##.", "..####.."}
};

static unsigned classify(const uint8_t pixels[64], uint32_t *best_score) {
    unsigned best = 0;
    *best_score = UINT32_MAX;
    for (unsigned digit = 0; digit < 10; digit++) {
        uint32_t score = 0;
        for (unsigned row = 0; row < 8; row++) {
            for (unsigned col = 0; col < 8; col++) {
                int prototype = glyph[digit][row][col] == '#' ? 255 : 0;
                int delta = (int)pixels[row * 8 + col] - prototype;
                score += (uint32_t)(delta < 0 ? -delta : delta);
            }
        }
        if (score < *best_score) {
            best = digit;
            *best_score = score;
        }
    }
    return best;
}

int main(void) {
    uint8_t pixels[64];
    for (unsigned i = 0; i < 64; i++) {
        unsigned value;
        if (scanf("%u", &value) != 1 || value > 255) {
            fputs("expected 64 grayscale values from 0 to 255\n", stderr);
            return 2;
        }
        pixels[i] = (uint8_t)value;
    }
    uint32_t score;
    unsigned result = classify(pixels, &score);
    printf("digit=%u score=%u\n", result, (unsigned)score);
    return 0;
}
