#!/usr/bin/env python3
import argparse
import random
from pathlib import Path

from evaluate_mul16 import approx_mul16


FIXED_CASES = [
    (0x0000, 0x0000),
    (0x0001, 0x0001),
    (0x000F, 0x0003),
    (0x00FF, 0x0002),
    (0x00FF, 0x00FF),
    (0x1234, 0x5678),
    (0xA5A5, 0x5A5A),
    (0xFFFF, 0x0001),
    (0xFFFF, 0xFFFF),
    (0x8000, 0x0002),
]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Python-reference vectors for approx_mul16_loa_tb.")
    parser.add_argument("--k", type=int, choices=(4, 6), required=True)
    parser.add_argument("--m0", type=int, required=True)
    parser.add_argument("--m1", type=int, required=True)
    parser.add_argument("--m2", type=int, required=True)
    parser.add_argument("--m3", type=int, required=True)
    parser.add_argument("--random-samples", type=int, default=50)
    parser.add_argument("--seed", type=int, default=0x1BADC0DE)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    configs = (args.m0, args.m1, args.m2, args.m3)
    cases = list(FIXED_CASES)
    cases.extend((rng.randrange(0, 1 << 16), rng.randrange(0, 1 << 16)) for _ in range(args.random_samples))

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w") as f:
        for a, b in cases:
            expected = approx_mul16(a, b, args.k, configs)
            exact = (a * b) & 0xFFFFFFFF
            f.write(f"{a:04x} {b:04x} {expected:08x} {exact:08x}\n")


if __name__ == "__main__":
    main()
