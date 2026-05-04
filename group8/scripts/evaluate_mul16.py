#!/usr/bin/env python3
import argparse
import random


def bit(value: int, index: int) -> int:
    return (value >> index) & 1


def ppu1(a: int, b: int, s_in: int, c_in: int) -> tuple[int, int]:
    pp = a & b
    s_out = pp ^ c_in ^ s_in
    c_out = (pp & s_in) | (pp & c_in) | (s_in & c_in)
    return s_out, c_out


def ppu2(
    a_i: int,
    a_j: int,
    b_i: int,
    b_j: int,
    s_in: int,
    c_in_i: int,
    c_in_j: int,
) -> tuple[int, int, int]:
    s_int, c_out_i = ppu1(a_i, b_i, s_in, c_in_i)
    s_out, c_out_j = ppu1(a_j, b_j, s_int, c_in_j)
    return s_out, c_out_i, c_out_j


def v2_cell(
    a_i: int,
    a_j: int,
    b_i: int,
    b_j: int,
    c_in_i: int,
    c_in_j: int,
) -> tuple[int, int, int]:
    del a_i, b_i, c_in_i
    s_out_j = (a_j & c_in_j) | (a_j & b_j)
    c_out_i = 0
    c_out_j = (a_j & b_j) | (a_j & c_in_j) | (b_j & c_in_j)
    return s_out_j, c_out_i, c_out_j


def exact_8x4(a: int, b: int) -> int:
    a &= 0xFF
    b &= 0xF
    c = [[0] * 9 for _ in range(4)]
    s = [[0] * 8 for _ in range(4)]

    for i in range(8):
        s[0][i] = bit(a, i) & bit(b, 0)

    for r in range(1, 4):
        for i in range(7):
            s[r][i], c[r][i + 1] = ppu1(bit(a, i), bit(b, 1), s[r - 1][i + 1], c[r][i])
        s[r][7], c[r][8] = ppu1(bit(a, 7), bit(b, 1), c[r - 1][8], c[r][7])

    return ((c[3][8] << 11) | (bits_to_int(s[3]) << 3) | (s[2][0] << 2) | (s[1][0] << 1) | s[0][0]) & 0xFFF


def v2_8x4(a: int, b: int, approx: int) -> int:
    a &= 0xFF
    b &= 0xF
    if approx < 0 or approx > 6:
        raise ValueError(f"approx must be in 0..6, got {approx}")

    c_1 = [0] * 9
    c_2 = [0] * 9
    c_3 = [0] * 9
    s_0 = [0] * 8
    s_1 = [0] * 8
    s_2 = [0] * 8
    s_3 = [0] * 8

    s_0[0] = bit(a, 0) & bit(b, 0)

    for i in range(7):
        s_1[i], _c_out_i, c_1[i + 1] = v2_cell(bit(a, i + 1), bit(a, i), bit(b, 0), bit(b, 1), 0, c_1[i])

    s_1[7], c_1[8] = ppu1(bit(a, 7), bit(b, 1), 0, c_1[7])
    s_2[0], c_2[1] = ppu1(bit(a, 0), bit(b, 2), s_1[1], c_2[0])

    for i in range(approx):
        s_3[i], c_2[i + 2], c_3[i + 1] = v2_cell(bit(a, i + 1), bit(a, i), bit(b, 2), bit(b, 3), c_2[i + 1], c_3[i])

    for i in range(approx, 6):
        s_3[i], c_2[i + 2], c_3[i + 1] = ppu2(bit(a, i + 1), bit(a, i), bit(b, 2), bit(b, 3), s_1[i], c_2[i + 1], c_3[i])

    s_3[6], c_2[8], c_3[7] = ppu2(bit(a, 7), bit(a, 6), bit(b, 2), bit(b, 3), c_1[8], c_2[7], c_3[6])
    s_3[7], c_3[8] = ppu1(bit(a, 7), bit(b, 3), c_2[8], c_3[7])

    return ((c_3[8] << 11) | (bits_to_int(s_3) << 3) | (s_2[0] << 2) | (s_1[0] << 1) | s_0[0]) & 0xFFF


def bits_to_int(bits: list[int]) -> int:
    value = 0
    for index, item in enumerate(bits):
        value |= (item & 1) << index
    return value


def mul8x4(a: int, b: int, approx: int) -> int:
    if approx == 0:
        return exact_8x4(a, b)
    return v2_8x4(a, b, approx)


def loa_add(x: int, y: int, k: int, width: int) -> int:
    lower_mask = (1 << k) - 1
    lower = (x | y) & lower_mask
    carry = ((x >> (k - 1)) & 1) & ((y >> (k - 1)) & 1)
    upper = (x >> k) + (y >> k) + carry
    return ((upper << k) | lower) & ((1 << width) - 1)


def v2_mul8(a: int, b: int, approx_group_a: int, approx_group_b: int, loa_k: int) -> int:
    group_a = mul8x4(a & 0xFF, b & 0x0F, approx_group_a)
    group_b = mul8x4(a & 0xFF, (b >> 4) & 0x0F, approx_group_b)
    loa_input_a = (group_a >> 4) & 0xFF
    loa_input_b = group_b & 0xFFF
    upper = loa_add(loa_input_a, loa_input_b, loa_k, width=12)
    return ((upper << 4) | (group_a & 0xF)) & 0xFFFF


def approx_mul16(a: int, b: int, k: int, configs: tuple[int, int, int, int]) -> int:
    a &= 0xFFFF
    b &= 0xFFFF
    m0 = v2_mul8(a & 0xFF, b & 0xFF, configs[0], configs[0], k)
    m1 = v2_mul8(a & 0xFF, (b >> 8) & 0xFF, configs[1], configs[1], k)
    m2 = v2_mul8((a >> 8) & 0xFF, b & 0xFF, configs[2], configs[2], k)
    m3 = v2_mul8((a >> 8) & 0xFF, (b >> 8) & 0xFF, configs[3], configs[3], k)

    part_sum0 = ((m0 >> 8) + (m1 & 0xFF)) & 0xFF
    part_sum1 = (part_sum0 + (m2 & 0xFF)) & 0xFF
    part_sum2 = ((m2 >> 8) + (m1 >> 8)) & 0xFF
    part_sum3 = (part_sum2 + (m3 & 0xFF)) & 0xFF

    return (((m3 >> 8) << 24) | (part_sum3 << 16) | (part_sum1 << 8) | (m0 & 0xFF)) & 0xFFFFFFFF


def main() -> None:
    parser = argparse.ArgumentParser(description="Estimate Group 8 structural multiplier error metrics.")
    parser.add_argument("--k", type=int, choices=(4, 6), required=True, help="LOA approximation width")
    parser.add_argument("--m0", type=int, default=2, help="M0 approximation setting: 0,2,4,5,6")
    parser.add_argument("--m1", type=int, default=2, help="M1 approximation setting: 0,2,4,5,6")
    parser.add_argument("--m2", type=int, default=2, help="M2 approximation setting: 0,2,4,5,6")
    parser.add_argument("--m3", type=int, default=2, help="M3 approximation setting: 0,2,4,5,6")
    parser.add_argument("--samples", type=int, default=100000, help="number of random input pairs")
    parser.add_argument("--seed", type=int, default=8, help="random seed")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    max_exact = 0xFFFF * 0xFFFF
    nmed_acc = 0.0
    mred_acc = 0.0
    mred_count = 0

    configs = (args.m0, args.m1, args.m2, args.m3)

    for _ in range(args.samples):
        a = rng.randrange(0, 1 << 16)
        b = rng.randrange(0, 1 << 16)
        exact = a * b
        approx = approx_mul16(a, b, args.k, configs)
        error = abs(exact - approx)
        nmed_acc += error / max_exact
        if exact != 0:
            mred_acc += error / exact
            mred_count += 1

    print(f"LOA k={args.k}")
    print(f"config={args.m0}_{args.m1}_{args.m2}_{args.m3}")
    print(f"samples={args.samples}")
    print(f"NMED={nmed_acc / args.samples:.10f}")
    print(f"MRED={mred_acc / max(mred_count, 1):.10f}")
    print("note=metrics use the structural v2/8x4 RTL model")


if __name__ == "__main__":
    main()
