#!/usr/bin/env python3
"""
Pareto front analysis for approximate 16x16 multiplier configurations.
Objectives: minimise NMED, minimise ice_lc_used, maximise icetime_fmax_mhz

Produces:
  results/pareto_front.png   — 3 scatter plots (2D projections of 3D front)
  results/pareto_front.csv   — table of Pareto-optimal configs
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

ROOT    = Path(__file__).resolve().parents[2]
CSV_IN  = ROOT / "build" / "combined_analysis" / "combined32.csv"
OUT_DIR = ROOT / "results"
OUT_DIR.mkdir(exist_ok=True)


def pareto_mask(df: pd.DataFrame, minimize: list[str], maximize: list[str]) -> pd.Series:
    """Return boolean Series: True where the row is Pareto-optimal."""
    costs = np.column_stack(
        [df[c].values for c in minimize] +
        [-df[c].values for c in maximize]
    )
    n = len(costs)
    dominated = np.zeros(n, dtype=bool)
    for i in range(n):
        if dominated[i]:
            continue
        for j in range(n):
            if i == j:
                continue
            if np.all(costs[j] <= costs[i]) and np.any(costs[j] < costs[i]):
                dominated[i] = True
                break
    return pd.Series(~dominated, index=df.index)


def scatter_2d(ax, df, pareto_df, xcol, ycol, xlabel, ylabel, title):
    """2D scatter: gray background points, coloured Pareto points by k."""
    non_p = df[~df["pareto"]]
    ax.scatter(
        non_p[xcol], non_p[ycol],
        color="lightgray", edgecolors="silver", s=50, zorder=2,
        label="Other configs",
    )

    palette = {4: ("tab:blue", "^"), 6: ("tab:orange", "D")}
    for k_val, (color, marker) in palette.items():
        sub = pareto_df[pareto_df["k"] == k_val]
        if sub.empty:
            continue
        ax.scatter(
            sub[xcol], sub[ycol],
            marker=marker, color=color, edgecolors="black",
            s=110, zorder=4, label=f"Pareto k={k_val}",
        )
        for _, row in sub.iterrows():
            ax.annotate(
                f"{row['config_label']}\nk={int(row['k'])}",
                (row[xcol], row[ycol]),
                textcoords="offset points",
                xytext=(6, 4),
                fontsize=7,
                color=color,
            )

    ax.set_xlabel(xlabel, fontsize=10)
    ax.set_ylabel(ylabel, fontsize=10)
    ax.set_title(title, fontsize=11, fontweight="bold")
    ax.grid(True, alpha=0.35, linestyle="--")
    ax.legend(fontsize=8)


def main() -> None:
    if not CSV_IN.exists():
        sys.exit(f"CSV not found: {CSV_IN}\nRun 'make combined' first.")

    df = pd.read_csv(CSV_IN)

    # Force numeric types (some columns may be empty strings / NaN)
    for col in ("nmed", "mred", "icetime_fmax_mhz", "nextpnr_fmax_mhz",
                "ice_lc_used", "bench_done"):
        df[col] = pd.to_numeric(df[col], errors="coerce")

    # Keep only successful runs
    df = df[(df["pnr_status"] == "pass") & (df["bench_done"] == 1)].copy()
    if df.empty:
        sys.exit("No successful configurations found in CSV.")

    # Compute 3D Pareto front
    df["pareto"] = pareto_mask(
        df,
        minimize=["nmed", "ice_lc_used"],
        maximize=["icetime_fmax_mhz"],
    )

    pareto_df = df[df["pareto"]].sort_values("ice_lc_used")

    # --- Console summary ---
    print(f"\nPareto-optimal: {len(pareto_df)} / {len(df)} configurations\n")
    print(
        pareto_df[[
            "id", "config_label", "k",
            "nmed", "mred",
            "ice_lc_used",
            "icetime_fmax_mhz",
            "nextpnr_fmax_mhz",
        ]].to_string(index=False)
    )

    # --- Save Pareto table ---
    pareto_csv = OUT_DIR / "pareto_front.csv"
    pareto_df.to_csv(pareto_csv, index=False)
    print(f"\nWrote {pareto_csv}")

    # --- 3 scatter plots ---
    fig, axes = plt.subplots(1, 3, figsize=(17, 5))
    """fig.suptitle(
        "Pareto Front — Approximate 16×16 Multiplier  "
        "(▼ NMED · ▼ LC used · ▲ Fmax)",
        fontsize=12, y=1.02,
    )"""

    scatter_2d(
        axes[0], df, pareto_df,
        xcol="ice_lc_used",      ycol="nmed",
        xlabel="iCE40 Logic Cells Used",
        ylabel="NMED (lower = more accurate)",
        title="Accuracy vs Area",
    )

    scatter_2d(
        axes[1], df, pareto_df,
        xcol="icetime_fmax_mhz", ycol="nmed",
        xlabel="icetime Fmax (MHz)",
        ylabel="NMED (lower = more accurate)",
        title="Accuracy vs Speed",
    )

    scatter_2d(
        axes[2], df, pareto_df,
        xcol="ice_lc_used",      ycol="icetime_fmax_mhz",
        xlabel="iCE40 Logic Cells Used",
        ylabel="icetime Fmax (MHz)",
        title="Area vs Speed",
    )

    plt.tight_layout()
    out_png = OUT_DIR / "pareto_front.png"
    plt.savefig(out_png, dpi=200, bbox_inches="tight")
    print(f"Wrote {out_png}")
    plt.show()


if __name__ == "__main__":
    main()
