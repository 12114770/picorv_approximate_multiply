#!/usr/bin/env python3
import argparse
import random


def apply_group_approx(value: int, approx_bits: int) -> int:
    if approx_bits <= 0:
        return value & 0xFFF
    if approx_bits >= 12:
        return 0
    mask = ((1 << 12) - 1) & ~((1 << approx_bits) - 1)
    return value & mask


def v2_mul8(a: int, b: int, approx_group_a: int, approx_group_b: int) -> int:
    group_a = apply_group_approx((a & 0xFF) * (b & 0x0F), approx_group_a)
    group_b = apply_group_approx((a & 0xFF) * ((b >> 4) & 0x0F), approx_group_b)
    return (((group_b << 4) + group_a) & 0xFFFF)


def loa_add(x: int, y: int, k: int, width: int = 32) -> int:
    lower_mask = (1 << k) - 1
    lower = (x | y) & lower_mask
    carry = ((x >> (k - 1)) & 1) & ((y >> (k - 1)) & 1)
    upper = (x >> k) + (y >> k) + carry
    return ((upper << k) | lower) & ((1 << width) - 1)


def approx_mul16(a: int, b: int, k: int, configs: tuple[int, int, int, int]) -> int:
    m0 = v2_mul8(a & 0xFF, b & 0xFF, configs[0], configs[0])
    m1 = v2_mul8(a & 0xFF, (b >> 8) & 0xFF, configs[1], configs[1])
    m2 = v2_mul8((a >> 8) & 0xFF, b & 0xFF, configs[2], configs[2])
    m3 = v2_mul8((a >> 8) & 0xFF, (b >> 8) & 0xFF, configs[3], configs[3])

    upper0 = (m0 >> 8) & 0xFF
    upper1 = m1 & 0xFFFF
    upper2 = m2 & 0xFFFF
    upper3 = (m3 << 8) & 0xFFFFFF

    s0 = loa_add(upper0, upper1, k, width=24)
    s1 = loa_add(upper2, upper3, k, width=24)
    upper = loa_add(s0, s1, k, width=24)
    return ((upper << 8) | (m0 & 0xFF)) & 0xFFFFFFFF


def main() -> None:
    parser = argparse.ArgumentParser(description="Estimate Group 8 multiplier error metrics.")
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
    print("note=metrics use the current best-effort block model")


if __name__ == "__main__":
    main()
