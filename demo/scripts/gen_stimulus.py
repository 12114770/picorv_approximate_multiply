import os
import numpy as np
import argparse

def gen_stimulus(seed: int, n : int) -> tuple[list[int], list[int]]:
    a = []
    b = []
    rng = np.random.default_rng(seed)
    for i in range(n):
        a.append(rng.integers(0, 2**16))
    for i in range(n):
        b.append(rng.integers(0, 2**16))
    return (a,b)

def write_sim_stimulus_file(a: list[int], b: list[int], dir_path: str):
        file_path = os.path.join(dir_path, "sim_input_a.hex")
        if(os.path.exists(file_path) == False):
            with open(file_path, "w") as f:
                for i in range(len(a)):
                    f.write(f"{a[i]:04x}\n")
        file_path = os.path.join(dir_path, "sim_input_b.hex")
        if(os.path.exists(file_path) == False):
            with open(file_path, "w") as f:
                for i in range(len(b)):
                    f.write(f"{b[i]:04x}\n")

def main():
    parser = argparse.ArgumentParser("Approximate multiplier stimulus generator")
    parser.add_argument(
        "out_dir",
        help="Relative path to directory where the stimulus hex file is written to",
        type=str
    )
    parser.add_argument(
        "num_values",
        help="Number of input pairs generated",
        type=int
    )
    parser.add_argument(
        "seed",
        help="Seed for the randomizer",
        type=int
    )
    args = parser.parse_args()
    a,b = gen_stimulus(args.seed, args.num_values)
    write_sim_stimulus_file(a,b, os.path.abspath(args.out_dir))

if __name__ == "__main__":
    main()