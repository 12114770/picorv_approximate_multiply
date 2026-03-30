#!/usr/bin/env python3
import argparse
import csv
import re
import subprocess
import time
from pathlib import Path

import serial
from serial import SerialException


CONFIGS = [
    (1, "22_66_66_66", "a"),
    (2, "22_55_55_55", "a"),
    (3, "22_44_44_44", "a"),
    (4, "22_22_22_22", "a"),
    (5, "22_66_66_66", "b"),
    (6, "22_55_55_55", "b"),
    (7, "22_44_44_44", "b"),
    (8, "22_22_22_22", "b"),
    (9, "E_66_66_66", "a"),
    (10, "E_55_55_55", "a"),
    (11, "E_44_44_44", "a"),
    (12, "E_22_22_22", "a"),
    (13, "E_66_66_66", "b"),
    (14, "E_55_55_55", "b"),
    (15, "E_44_44_44", "b"),
    (16, "E_22_22_22", "b"),
    (17, "E_E_66_66", "a"),
    (18, "E_E_55_55", "a"),
    (19, "E_E_44_44", "a"),
    (20, "E_E_22_22", "a"),
    (21, "E_E_66_66", "b"),
    (22, "E_E_55_55", "b"),
    (23, "E_E_44_44", "b"),
    (24, "E_E_22_22", "b"),
    (25, "E_E_E_66", "a"),
    (26, "E_E_E_55", "a"),
    (27, "E_E_E_44", "a"),
    (28, "E_E_E_22", "a"),
    (29, "E_E_E_66", "b"),
    (30, "E_E_E_55", "b"),
    (31, "E_E_E_44", "b"),
    (32, "E_E_E_22", "b"),
]


def decode(token: str) -> int:
    if token == "E":
        return 0
    return {"22": 2, "44": 4, "55": 5, "66": 6}[token]


def run_capture(cmd: list[str], workdir: Path) -> str:
    print("+", " ".join(cmd), flush=True)
    proc = subprocess.run(cmd, cwd=workdir, check=True, text=True, capture_output=True)
    return proc.stdout + proc.stderr


def parse_metrics(output: str) -> dict[str, str]:
    return {
        "nmed": _match(output, r"NMED=([0-9.]+)"),
        "mred": _match(output, r"MRED=([0-9.]+)"),
    }


def parse_resources(log_text: str) -> dict[str, str]:
    hier_section = re.search(r"=== design hierarchy ===(.*?)(?:\n\d+\.|\Z)", log_text, re.S)
    text = hier_section.group(1) if hier_section else ""
    return {
        "hier_cells": _match(text, r"\n\s*(\d+) approx_mul16_loa"),
        "total_cells": _match(text, r"\n\s*(\d+) cells\n"),
        "and_cells": _match(text, r"\n\s*(\d+)\s+\$_AND_"),
        "mux_cells": _match(text, r"\n\s*(\d+)\s+\$_MUX_"),
        "or_cells": _match(text, r"\n\s*(\d+)\s+\$_OR_"),
        "xor_cells": _match(text, r"\n\s*(\d+)\s+\$_XOR_"),
    }


def parse_pnr(output: str) -> dict[str, str]:
    return {
        "max_freq_mhz": _match(output, r"Max frequency.*?:\s*([0-9.]+) MHz"),
        "ice_lc_used": _match(output, r"ICESTORM_LC:\s*(\d+)/"),
        "ice_lc_total": _match(output, r"ICESTORM_LC:\s*\d+/\s*(\d+)"),
        "ice_ram_used": _match(output, r"ICESTORM_RAM:\s*(\d+)/"),
        "ice_ram_total": _match(output, r"ICESTORM_RAM:\s*\d+/\s*(\d+)"),
    }


def parse_bench_lines(text: str) -> dict[str, str]:
    dps = _match(text, r"Dhrystones/Second_MHz:\s*([0-9]+)")
    dmips = _match(text, r"DMIPS/MHz:\s*([0-9.]+)")
    if not dmips:
        dmips = _match(text, r"dmips_per_mhz=([0-9.]+)")
    return {
        "dhrystones_per_second_mhz": dps,
        "dmips_per_mhz": dmips,
        "mul16_iters": _match(text, r"mul16 iters:\s*([0-9]+)"),
        "mul16_cycles": _match(text, r"mul16 cycles:\s*([0-9]+)") or _match(text, r"mul16_cycles=([0-9]+)"),
        "mul16_checksum": _match(text, r"mul16 checksum:\s*(0x[0-9a-fA-F]+)") or _match(text, r"checksum=(0x[0-9a-fA-F]+)"),
        "bench_done": "1" if "BENCH_DONE" in text else "0",
    }


def _match(text: str, pattern: str) -> str:
    m = re.search(pattern, text, re.S)
    return m.group(1) if m else ""


def capture_board_uart(root: Path, port: str, baud: int, timeout_s: float, make_args: list[str]) -> str:
    captured = []
    print("+", " ".join(["make", "board_bench_test", *make_args]), flush=True)
    subprocess.run(["make", "board_bench_test", *make_args], cwd=root, check=True, text=True)
    time.sleep(1.0)

    ser = None
    deadline = time.time() + timeout_s

    while time.time() < deadline:
        if ser is None:
            try:
                ser = serial.Serial(port, baudrate=baud, timeout=0.1)
                ser.reset_input_buffer()
            except SerialException:
                time.sleep(0.2)
                continue

        try:
            data = ser.read(4096)
            if data:
                captured.append(data.decode(errors="ignore"))
                if "BENCH_DONE" in "".join(captured):
                    break
        except SerialException:
            try:
                ser.close()
            except Exception:
                pass
            ser = None
            time.sleep(0.2)
            continue

    if ser is not None:
        ser.close()
    return "".join(captured)


def simulate_bench(root: Path, make_args: list[str]) -> str:
    sim_out = run_capture(["make", "board_bench_sim", *make_args], root)
    chars = []
    for token in re.findall(r"Serial data:\s+(.*)", sim_out):
        token = token.strip()
        if token.startswith("'") and token.endswith("'"):
            chars.append(token[1:-1])
        elif token == "13":
            chars.append("\r")
        elif token == "10":
            chars.append("\n")
    return "".join(chars)


def analyze_one(root: Path, k: int, m0: int, m1: int, m2: int, m3: int, samples: int, board: bool, serial_port: str, baud: int, timeout_s: float) -> dict[str, str]:
    make_args = [
        f"LOA_K={k}",
        f"M0_APPROX={m0}",
        f"M1_APPROX={m1}",
        f"M2_APPROX={m2}",
        f"M3_APPROX={m3}",
    ]

    run_capture(["make", "clean"], root)
    run_capture(["make", "-C", "picorv32/picosoc", "clean"], root)
    (root / "build" / "combined_analysis").mkdir(parents=True, exist_ok=True)

    metrics_out = run_capture([
        "python3", "group8/scripts/evaluate_mul16.py",
        "--k", str(k),
        "--m0", str(m0),
        "--m1", str(m1),
        "--m2", str(m2),
        "--m3", str(m3),
        "--samples", str(samples),
    ], root)

    run_capture(["make", "synth", *make_args], root)
    log_path = root / "build" / "synth" / f"approx_mul16_loa_k{k}_{m0}_{m1}_{m2}_{m3}.log"
    resource_data = parse_resources(log_path.read_text())
    pnr_out = run_capture(["make", "-C", "picorv32/scripts/icestorm", "all", "BOARD_APP=mul16_dhry", *make_args], root)

    bench_mode = "board" if board else "simulation"
    if board:
        bench_text = capture_board_uart(root, serial_port, baud, timeout_s, make_args)
    else:
        bench_text = simulate_bench(root, make_args)

    row = {
        "config": f"{m0}_{m1}_{m2}_{m3}",
        "k": k,
        "m0": m0,
        "m1": m1,
        "m2": m2,
        "m3": m3,
        "bench_mode": bench_mode,
    }
    row.update(parse_metrics(metrics_out))
    row.update(resource_data)
    row.update(parse_pnr(pnr_out))
    row.update(parse_bench_lines(bench_text))

    print(
        "  values:"
        f" NMED={row.get('nmed', '')}"
        f" MRED={row.get('mred', '')}"
        f" cells={row.get('total_cells', '')}"
        f" fmax={row.get('max_freq_mhz', '')}MHz"
        f" dmips/mhz={row.get('dmips_per_mhz', '')}"
        f" mul16_cycles={row.get('mul16_cycles', '')}"
        f" checksum={row.get('mul16_checksum', '')}"
        f" bench_done={row.get('bench_done', '')}",
        flush=True,
    )
    return row


def main() -> None:
    parser = argparse.ArgumentParser(description="Combined analyzer for metrics, resources, timing, and benchmark output.")
    parser.add_argument("--k", type=int, choices=(4, 6))
    parser.add_argument("--m0", type=int)
    parser.add_argument("--m1", type=int)
    parser.add_argument("--m2", type=int)
    parser.add_argument("--m3", type=int)
    parser.add_argument("--samples", type=int, default=10000)
    parser.add_argument("--board", action="store_true", help="run real board benchmark over UART")
    parser.add_argument("--serial-port", default="/dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--output", default="build/combined_analysis/combined.csv")
    parser.add_argument("--all", action="store_true", help="run the combined analysis for all 32 configurations")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    out_path = root / args.output
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if not args.all and None in (args.k, args.m0, args.m1, args.m2, args.m3):
        parser.error("--k, --m0, --m1, --m2, and --m3 are required unless --all is used")

    rows = []
    if args.all:
        for idx, cfg_text, version in CONFIGS:
            parts = cfg_text.split("_")
            k = 4 if version == "a" else 6
            m0, m1, m2, m3 = [decode(p) for p in parts]
            print(f"[{idx:02d}/32] {cfg_text} {version} -> k={k}", flush=True)
            row = {
                "id": idx,
                "config_label": cfg_text,
                "version": version,
            }
            row.update(analyze_one(root, k, m0, m1, m2, m3, args.samples, args.board, args.serial_port, args.baud, args.timeout))
            rows.append(row)
    else:
        rows.append(analyze_one(root, args.k, args.m0, args.m1, args.m2, args.m3, args.samples, args.board, args.serial_port, args.baud, args.timeout))

    with out_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
