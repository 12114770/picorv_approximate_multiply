/*
original work: Copyright (C) 2015 - 2021  Claire Xenia Wolf <claire@yosyshq.com>
original license: ISC-style permissive license see in third party license in the parent directory

Modifications: Copyright (C) 2025 Edonis Berisha, Jonas Moosbrugger, Nikola Szucsich

Licensed under the EUPL, Version 1.2 or – as soon they will be approved by
the European Commission - subsequent versions of the EUPL (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software
distributed under the Licence is distributed on an "AS IS" basis,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the Licence for the specific language governing permissions and
limitations under the Licence.
*/

#include <stdint.h>
#include <stdbool.h>

#ifdef USE_MYSTDLIB
    extern int printf(const char *format, ...);
#else
    #include <stdlib.h>
    #include <string.h>
#endif

extern uint32_t sram;

#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)
#define reg_leds (*(volatile uint32_t*)0x03000000)

// --------------------------------------------------------

uint32_t custom_mul(uint32_t a, uint32_t b) {
	uint32_t result;
	__asm__ (".insn r 0x33, 0x0, 0x2A, %0, %1, %2":  "=r" (result) : "r" (a), "r" (b));
	return result;
}

// --------------------------------------------------------

void putchar(char c) {
    if(c == '\n')
        putchar('\r');
    reg_uart_data = c;
}

void print(const char *p) {
    while(*p)
        putchar(*(p++));
}

char getchar_prompt(char *prompt) {
    int32_t c = -1;

    uint32_t cycles_begin, cycles_now, cycles;
    __asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));

    reg_leds = ~0;

    if (prompt)
        print(prompt);

    while (c == -1) {
        __asm__ volatile ("rdcycle %0" : "=r"(cycles_now));
        cycles = cycles_now - cycles_begin;
        if (cycles > 12000000) {
            if (prompt)
                print(prompt);
            cycles_begin = cycles_now;
            reg_leds = ~reg_leds;
        }
        c = reg_uart_data;
    }

    reg_leds = 0;
    return c;
}

char getchar() {
    return getchar_prompt(0);
}

void main() {
    reg_leds = 31;
    reg_uart_clkdiv = 104;

    extern long time(long *ignored);
    extern long insn(long *ignored);

    // Cycles and instructions
    long cycles_start, cycles_end, cycles_run_approx, cycles_run_exact;
    long insn_start, insn_end, insn_run_approx, insn_run_exact;

    print("Booting\n");

    while(getchar_prompt("Press ENTER\n") != '\r') { /* wait */ }

    const uint16_t len = 400;
    // Test inputs:
    uint16_t a[] = {
                        // Some (more or less) directed test cases
                        0,     1,     1,     2,     1, 2<<14, 2<<14,     7,     9,   100,     1,  2798,  5102,
                        9<<7, 65535,     1, 65535, 65535, 65535,    50, 9<<15, 65<<2, 41236, 1<<10,     2,  5<<7,
                        1<<15,  8191, 16383,  1000,     0,  1000,    15,   127,  6129,     0,  1234,   256,  8192,
                        // random tests
                        17419, 27505, 63903, 16017, 1098, 27341, 6392, 22597, 11358, 26930, 43738, 9151, 61184, 44016,
                        22696, 22950, 54753, 29683, 39470, 18411, 15933, 44105, 19802, 20702, 43265, 12994, 10454, 16891,
                        36142, 61064, 43688, 31381, 23898, 8237, 49594, 50467, 8597, 22000, 60605, 5258, 14833, 518, 14619,
                        32643, 22150, 20303, 61986, 9211, 40654, 12486, 37948, 24059, 4478, 29323, 33768, 24559, 42078, 26793,
                        47384, 8957, 29610, 30580, 10699, 38061, 39950, 59231, 25531, 52525, 4543, 42616, 28453, 14153, 32164,
                        34382, 61811, 649, 1060, 64707, 39777, 8956, 65244, 17715, 39000, 53897, 48443, 40095, 63906, 41872,
                        65174, 52669, 125, 25273, 61537, 63141, 36627, 59525, 56297, 9041, 24884, 63748, 5972, 47930, 58642,
                        21872, 40948, 42545, 61666, 1903, 38089, 41114, 5002, 41344, 3206, 64503, 8677, 44317, 63612, 31195,
                        29274, 14576, 40083, 22291, 1482, 60709, 13688, 35093, 35251, 3860, 32469, 34094, 36103, 23520, 31024,
                        21359, 42719, 39468, 24699, 28996, 38508, 28060, 12971, 21705, 36910, 7380, 62029, 65439, 28679, 20479,
                        28594, 2462, 55560, 3267, 8486, 39203, 19035, 37513, 13713, 63478, 33503, 26598, 30240, 44945, 44157,
                        13343, 27956, 58937, 7385, 39827, 1790, 37413, 3721, 56669, 1964, 51780, 38059, 38745, 12272, 28546,
                        31161, 35835, 53753, 14369, 56607, 41988, 19675, 3656, 46908, 6015, 24722, 4201, 58882, 52268, 23719,
                        51627, 38802, 57918, 15703, 62339, 16812, 9787, 9482, 19875, 40167, 45362, 12975, 20162, 16196, 880,
                        5709, 45379, 43817, 16102, 62340, 65454, 47121, 35816, 39703, 21965, 44348, 16523, 52525, 53879, 48826,
                        27064, 29351, 65484, 25944, 1430, 30315, 26171, 34091, 9107, 5281, 9556, 56481, 17937, 18565, 33822,
                        24630, 8593, 62974, 50785, 56052, 35531, 44243, 58658, 63313, 3823, 64427, 19323, 58582, 40273, 37414,
                        28281, 58282, 917, 27178, 8012, 20416, 51178, 45797, 24949, 21743, 36462, 1244, 57510, 63368, 11674,
                        64248, 56633, 54992, 29010, 6635, 15231, 39586, 50249, 27993, 44428, 53890, 27137, 3400, 34361, 17825,
                        31218, 22149, 3083, 49666, 38417, 42916, 14107, 49918, 39313, 33902, 25191, 5161, 20273, 13114, 24978,
                        6797, 14267, 2470, 54272, 25828, 27219, 34971, 64546, 52063, 44257, 57464, 35382, 64340, 6904, 14300,
                        46864, 14978, 38175, 18249, 30311, 63410, 28913, 45601, 23996, 62071, 9773, 37551, 18094, 50901, 47420,
                        8119, 6781, 64808, 1458, 38688, 63800, 973, 2647, 37063, 39058, 35274, 40023, 51096, 4704, 60122, 15672,
                        3465, 52128, 60550, 45159, 50357, 37873, 25021, 25792, 3, 36499, 27229, 11495, 31533, 5306, 24090, 62144, 47583
                    };
    uint16_t b[] = {
                        // Some (more or less) directed test cases
                        1,     0,     1,     1,     2,     0,     1,     9,     7,     1,   100,    23,  5178,
                        25<<3,     0, 65535,     1, 65535,   569,    50, 5<<11,     3,   999,     7, 1<<15, 1<<15,
                        841, 16383, 65535,     0,  1000,  1000,   127, 20000,  4096,  1234,  1234,   256,   255,
                        // random tests
                        60174, 557, 56918, 6073, 46518, 31783, 39945, 61434, 46854, 7857, 58174, 2442, 16434, 33847,
                        2683, 50464, 8079, 5993, 5705, 660, 45916, 42834, 43296, 43920, 3960, 28783, 9807, 43300, 59172,
                        30741, 56917, 1256, 12371, 9991, 20585, 61583, 3419, 64947, 60456, 14079, 11995, 12091, 39968, 16920,
                        3211, 34127, 40534, 48402, 5890, 34432, 40279, 52745, 46331, 43892, 12292, 40095, 12787, 39998, 56230,
                        18675, 6029, 9240, 5920, 3875, 2150, 14497, 57069, 765, 21522, 14481, 36221, 37259, 19915, 28314, 25486,
                        17156, 62342, 46990, 63575, 50248, 8557, 26348, 35323, 64020, 46187, 56487, 39882, 53344, 13649, 48454,
                        44975, 7897, 57318, 23023, 45717, 2684, 39718, 31626, 11699, 62651, 54703, 23961, 46288, 24761, 30971,
                        60038, 35740, 42420, 10953, 50336, 18335, 36808, 51197, 16593, 51360, 44288, 15610, 29989, 13375, 7284,
                        49375, 18665, 38120, 1161, 8399, 26547, 44306, 33039, 17316, 11963, 23156, 1012, 58103, 57111, 26969, 27284,
                        64169, 28194, 49101, 17983, 43205, 37484, 38976, 56317, 48436, 9058, 60066, 25689, 62829, 49344, 10136,
                        17490, 60154, 25481, 44726, 14715, 33354, 38966, 40262, 19342, 1508, 33183, 4626, 42400, 14329, 29060, 60826,
                        36472, 40343, 25940, 43008, 21959, 62343, 48336, 12482, 21978, 50439, 7034, 56135, 59832, 46046, 3183, 55796,
                        37242, 29226, 42215, 3025, 61848, 31641, 62973, 27172, 2760, 53816, 3289, 55043, 57159, 61954, 24495, 7466, 51531,
                        40783, 22767, 55561, 54614, 1075, 59482, 40716, 40925, 28676, 65034, 58453, 11508, 29172, 42811, 4595, 63570, 47578,
                        22241, 19751, 2282, 19472, 10230, 12657, 11529, 33074, 37189, 18226, 9064, 20046, 27151, 37329, 61598, 51446, 62069,
                        476, 22732, 42373, 38951, 37654, 13146, 34152, 2616, 45661, 63587, 46830, 17827, 14801, 59709, 41151, 3341, 27308,
                        62893, 45003, 45002, 7615, 42927, 30676, 12707, 31184, 34357, 56066, 45369, 34847, 11368, 12010, 4578, 11857, 44918,
                        5809, 54203, 3008, 18132, 33497, 16960, 63937, 17517, 17361, 40648, 54845, 41434, 10158, 25660, 44941, 4396, 20698,
                        39178, 44514, 60785, 48753, 36161, 42478, 47474, 12496, 22157, 26693, 34907, 9280, 7691, 22616, 61926, 52378, 8937,
                        9524, 7742, 37488, 58067, 16413, 48607, 18469, 44099, 59147, 37679, 24198, 18369, 9594, 16474, 60029, 26715, 22040,
                        15769, 45063, 63304, 26233, 37685, 6147, 24048, 24194, 21431, 28072, 44333, 60955, 60632, 46391, 23698, 45655, 34640,
                        59161, 19195, 39971, 2971, 46150, 52320, 15010, 2080, 27262, 3311, 27469, 63141, 18760, 51750, 13212, 33046, 56811,
                        52237, 2457, 38648, 31290, 14897, 47951, 25571, 65121
                    };
    // Results
    uint32_t res_approx[len];
    uint32_t res_exact[len];
    uint32_t err_abs = 0;

    print("Starting Benchmark\n");
    print("Use approximate multiplier:\n");

    insn_start = insn ((long *) 0);
    cycles_start = time ((long *) 0);

    // Benchmark: approximate multiplications
    for(int i = 0; i < len; ++i) {
        res_approx[i] = custom_mul(a[i], b[i]);
    }
    cycles_end = time((long *) 0);
    insn_end   = insn((long *) 0);
    // correcting duration of insn() and time() calls
    cycles_run_approx = cycles_end - cycles_start - 23;
    insn_run_approx   = insn_end - insn_start - 15;

    // Reference calculation (correct multiplication)
	int hits = 0;

    print("Use exact multiplier:\n");
    insn_start = insn ((long *) 0);
    cycles_start = time ((long *) 0);
    // Benchmark: exact multiplications
    for(int i = 0; i < len; ++i) {
        res_exact[i] = a[i]*b[i];
    }

    cycles_end = time((long *) 0);
    insn_end   = insn((long *) 0);
    // correcting duration of insn() and time() calls
    cycles_run_exact = cycles_end - cycles_start - 23;
    insn_run_exact   = insn_end - insn_start - 15;

    print("Compare results:\n");
	for(int i = 0; i < len; i++) {
        printf("Test case %u|Inputs: a=%u, b =%u|p_a=%u|p_e=%u", i, a[i], b[i], res_approx[i], res_exact[i]);
		if(res_approx[i] == res_exact[i]) {
            hits += 1;
		}

        if(res_approx[i] > res_exact[i]) {
            printf("|Absolute error: %u\n", res_approx[i]-res_exact[i]);
        }
        else {
            printf("|Absolute error: %u\n", res_exact[i]-res_approx[i]);
        }

	}

    printf("Finished Benchmark\n");
    printf("Checked %u values, got %u correct results\n", len, hits);
    printf("Approximate multiplications finished after: %u cycles, %u insn\n", cycles_run_approx, insn_run_approx);
    printf("Exact multiplications finished after: %u cycles, %u insn\n", cycles_run_exact, insn_run_exact);
    printf("Cycle difference: %d cycles\n", (cycles_run_exact-cycles_run_approx));
    return;
}
// --------------------------------------------------------