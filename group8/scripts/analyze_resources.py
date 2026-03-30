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
    return {"22": 2, "44": 4, "55": 5, "66": 6}[token]


def run(cmd: list[str], workdir: Path) -> None:
    subprocess.run(cmd, cwd=workdir, check=True, text=True)


def parse_log(log_path: Path) -> dict[str, str]:
    text = log_path.read_text()
    top_section = re.search(r"=== approx_mul16_loa ===(.*?)===", text, re.S)
    hier_section = re.search(r"=== design hierarchy ===(.*?)(?:\n\d+\.|\Z)", text, re.S)

    top_text = top_section.group(1) if top_section else ""
    hier_text = hier_section.group(1) if hier_section else ""

    hier_cells = re.search(r"\n\s*(\d+) approx_mul16_loa", hier_text)
    total_cells = re.search(r"\n\s*(\d+) cells\n", hier_text)
    and_cells = re.search(r"\n\s*(\d+)\s+\$_AND_", hier_text)
    mux_cells = re.search(r"\n\s*(\d+)\s+\$_MUX_", hier_text)
    or_cells = re.search(r"\n\s*(\d+)\s+\$_OR_", hier_text)
    xor_cells = re.search(r"\n\s*(\d+)\s+\$_XOR_", hier_text)
    wires = re.search(r"\n\s*(\d+) wires\n", hier_text)
    wire_bits = re.search(r"\n\s*(\d+) wire bits\n", hier_text)
    public_wires = re.search(r"\n\s*(\d+) public wires\n", hier_text)
    public_wire_bits = re.search(r"\n\s*(\d+) public wire bits\n", hier_text)
    ports = re.search(r"\n\s*(\d+) ports\n", hier_text)
    port_bits = re.search(r"\n\s*(\d+) port bits\n", hier_text)
    top_local_cells = re.search(r"\n\s*(\d+) submodules", top_text)

    return {
        "hier_cells": hier_cells.group(1) if hier_cells else "",
        "total_cells": total_cells.group(1) if total_cells else "",
        "and_cells": and_cells.group(1) if and_cells else "",
        "mux_cells": mux_cells.group(1) if mux_cells else "",
        "or_cells": or_cells.group(1) if or_cells else "",
        "xor_cells": xor_cells.group(1) if xor_cells else "",
        "wires": wires.group(1) if wires else "",
        "wire_bits": wire_bits.group(1) if wire_bits else "",
        "public_wires": public_wires.group(1) if public_wires else "",
        "public_wire_bits": public_wire_bits.group(1) if public_wire_bits else "",
        "ports": ports.group(1) if ports else "",
        "port_bits": port_bits.group(1) if port_bits else "",
        "top_local_submodules": top_local_cells.group(1) if top_local_cells else "",
    }


def row_for_config(idx: int, cfg_text: str, version: str) -> dict[str, str]:
    parts = cfg_text.split("_")
    k = 4 if version == "a" else 6
    m0, m1, m2, m3 = [decode(p) for p in parts]
    return {
        "id": idx,
        "config": cfg_text,
        "version": version,
        "k": k,
        "m0": m0,
        "m1": m1,
        "m2": m2,
        "m3": m3,
    }


def synthesize_and_collect(root: Path, row: dict[str, str]) -> dict[str, str]:
    make_args = [
        f"LOA_K={row['k']}",
        f"M0_APPROX={row['m0']}",
        f"M1_APPROX={row['m1']}",
        f"M2_APPROX={row['m2']}",
        f"M3_APPROX={row['m3']}",
    ]
    run(["make", "synth", *make_args], root)
    log_path = root / "build" / "synth" / f"approx_mul16_loa_k{row['k']}_{row['m0']}_{row['m1']}_{row['m2']}_{row['m3']}.log"
    parsed = parse_log(log_path)
    return row | parsed


def main() -> None:
    parser = argparse.ArgumentParser(description="Analyze synthesis resource consumption and write CSV.")
    parser.add_argument("--all", action="store_true", help="analyze all 32 assigned configurations")
    parser.add_argument("--k", type=int, choices=(4, 6), default=4)
    parser.add_argument("--m0", type=int, default=2)
    parser.add_argument("--m1", type=int, default=2)
    parser.add_argument("--m2", type=int, default=2)
    parser.add_argument("--m3", type=int, default=2)
    parser.add_argument("--output", default="build/resource_analysis/resources.csv")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    out_path = root / args.output
    out_path.parent.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    if args.all:
        for idx, cfg_text, version in CONFIGS:
            rows.append(synthesize_and_collect(root, row_for_config(idx, cfg_text, version)))
    else:
        row = {
            "id": 0,
            "config": f"{args.m0}_{args.m1}_{args.m2}_{args.m3}",
            "version": "manual",
            "k": args.k,
            "m0": args.m0,
            "m1": args.m1,
            "m2": args.m2,
            "m3": args.m3,
        }
        rows.append(synthesize_and_collect(root, row))

    with out_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
