#!/usr/bin/env python3

import argparse
import re
import subprocess
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
PICOSOC_ROOT = PROJECT_ROOT / "picorv32" / "picosoc"
ISA_CHOICES = ["i", "ic"]
SERIAL_CHAR_RE = re.compile(r"Serial data: '(.+)'$")
SERIAL_NUM_RE = re.compile(r"Serial data:\s+(\d+)$")


def run_capture(cmd, cwd):
    print("+", " ".join(str(part) for part in cmd), flush=True)
    proc = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, cmd, output=proc.stdout)
    return proc.stdout


def decode_sim_serial(text):
    chars = []
    for line in text.splitlines():
        printable = SERIAL_CHAR_RE.fullmatch(line)
        if printable:
            chars.append(printable.group(1))
            continue
        numeric = SERIAL_NUM_RE.fullmatch(line)
        if numeric:
            chars.append(chr(int(numeric.group(1))))
    return "".join(chars)


def test_isa(isa, target):
    run_capture(["make", "clean"], PICOSOC_ROOT)
    output = run_capture(["make", f"RISCV_ISA={isa}", target], PICOSOC_ROOT)

    row = {
        "isa": f"rv32{isa}",
        "target": target,
        "status": "OK",
    }

    if target == "sim":
        serial_text = decode_sim_serial(output)
        row["serial"] = serial_text.strip()
        print(f"rv32{isa} serial: {serial_text.strip()}", flush=True)
    else:
        row["serial"] = ""
        verify_ok = "VERIFY OK" in output
        row["verify_ok"] = "yes" if verify_ok else "no"
        print(f"rv32{isa} prog_bram verify_ok={row['verify_ok']}", flush=True)

    return row


def main():
    parser = argparse.ArgumentParser(description="Task2-style automation for task3 PicoSoC ISA checks.")
    parser.add_argument("--isa", choices=ISA_CHOICES)
    parser.add_argument("--all-isas", action="store_true")
    parser.add_argument("--target", choices=["sim", "prog_bram"], default="sim")
    args = parser.parse_args()

    if args.isa is None:
        args.all_isas = True

    isa_values = ISA_CHOICES if args.all_isas else [args.isa]
    rows = [test_isa(isa, args.target) for isa in isa_values]

    print("RESULTS", flush=True)
    for row in rows:
        print(row, flush=True)


if __name__ == "__main__":
    main()
