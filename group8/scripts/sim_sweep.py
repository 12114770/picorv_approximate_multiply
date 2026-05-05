#!/usr/bin/env python3
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

def decode(x):
    return 0 if x == "E" else {"22": 2, "44": 4, "55": 5, "66": 6}[x]

def parse_value(text, name):
    m = re.search(rf"{name}=([0-9.]+)", text)
    return m.group(1) if m else ""

rows = []

for idx, cfg, version in CONFIGS:
    k = 4 if version == "a" else 6
    m0, m1, m2, m3 = [decode(x) for x in cfg.split("_")]

    cmd = [
        "make", "sim",
        f"LOA_K={k}",
        f"M0_APPROX={m0}",
        f"M1_APPROX={m1}",
        f"M2_APPROX={m2}",
        f"M3_APPROX={m3}",
    ]

    print(f"[{idx:02d}/32] {cfg} {version}")
    out = subprocess.run(cmd, text=True, capture_output=True, check=True).stdout

    rows.append({
        "id": idx,
        "config": cfg,
        "version": version,
        "k": k,
        "m0": m0,
        "m1": m1,
        "m2": m2,
        "m3": m3,
        "nmed": parse_value(out, "NMED"),
        "mred": parse_value(out, "MRED"),
    })

Path("build/config_sweep").mkdir(parents=True, exist_ok=True)

with open("build/config_sweep/error_metrics.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

print("wrote build/config_sweep/error_metrics.csv")

