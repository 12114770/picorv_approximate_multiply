#!/usr/bin/env python3
import argparse
import csv
import re
import subprocess
from pathlib import Path


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
    return {
        "22": 2,
        "44": 4,
        "55": 5,
        "66": 6,
    }[token]


def run(cmd: list[str], workdir: Path) -> str:
    proc = subprocess.run(cmd, cwd=workdir, check=True, text=True, capture_output=True)
    return proc.stdout + proc.stderr


def parse_metrics(output: str) -> tuple[str, str]:
    nmed = re.search(r"NMED=([0-9.]+)", output)
    mred = re.search(r"MRED=([0-9.]+)", output)
    return (nmed.group(1) if nmed else "", mred.group(1) if mred else "")


def parse_cells(log_path: Path) -> str:
    text = log_path.read_text()
    match = re.search(r"=== design hierarchy ===.*?\n\s*(\d+) approx_mul16_loa", text, re.S)
    return match.group(1) if match else ""


def main() -> None:
    parser = argparse.ArgumentParser(description="Run all 32 assigned multiplier configurations.")
    parser.add_argument("--samples", type=int, default=10000)
    parser.add_argument("--output", default="build/config_sweep/results.csv")
    parser.add_argument("--skip-sim", action="store_true")
    parser.add_argument("--skip-synth", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    out_path = root / args.output
    out_path.parent.mkdir(parents=True, exist_ok=True)

    rows = []
    for idx, cfg_text, version in CONFIGS:
        parts = cfg_text.split("_")
        k = 4 if version == "a" else 6
        m0, m1, m2, m3 = [decode(p) for p in parts]
        make_args = [
            f"LOA_K={k}",
            f"M0_APPROX={m0}",
            f"M1_APPROX={m1}",
            f"M2_APPROX={m2}",
            f"M3_APPROX={m3}",
        ]

        if not args.skip_sim:
            run(["make", "sim", *make_args], root)

        metrics_out = run([
            "python3",
            "group8/scripts/evaluate_mul16.py",
            "--k", str(k),
            "--m0", str(m0),
            "--m1", str(m1),
            "--m2", str(m2),
            "--m3", str(m3),
            "--samples", str(args.samples),
        ], root)
        nmed, mred = parse_metrics(metrics_out)

        cells = ""
        if not args.skip_synth:
            run(["make", "synth", *make_args], root)
            log_name = f"approx_mul16_loa_k{k}_{m0}_{m1}_{m2}_{m3}.log"
            cells = parse_cells(root / "build" / "synth" / log_name)

        rows.append({
            "id": idx,
            "config": cfg_text,
            "version": version,
            "k": k,
            "m0": m0,
            "m1": m1,
            "m2": m2,
            "m3": m3,
            "nmed": nmed,
            "mred": mred,
            "cells": cells,
        })

    with out_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
