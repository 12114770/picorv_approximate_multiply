#!/usr/bin/env python3

import argparse
import csv
import glob
import itertools
import os
import re
import shutil
import subprocess
import termios
import time
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent


def resolve_picorv32_root():
    candidates = [
        PROJECT_ROOT / "picorv32",
        PROJECT_ROOT.parent,
        PROJECT_ROOT.parent / "task1" / "picorv32",
        PROJECT_ROOT.parent / "task1",
        PROJECT_ROOT.parent / "picorv32",
        PROJECT_ROOT.parent / "test" / "picorv32",
    ]
    for candidate in candidates:
        if (candidate / "picosoc").is_dir() and (candidate / "dhrystone").is_dir() and (candidate / "firmware").is_dir():
            return candidate
    raise SystemExit(
        "Could not locate the PicoRV32 task root. Expected to find 'picosoc/', 'dhrystone/', and "
        f"'firmware/' under one of: {', '.join(str(path) for path in candidates)}"
    )


REPO_ROOT = resolve_picorv32_root()
PICOSOC_ROOT = REPO_ROOT / "picosoc"
WORKSPACE_ROOT = PROJECT_ROOT / "hw_workspaces"
DMIPS_RE = re.compile(r"DMIPS/MHz:\s*([0-9]+\.[0-9]+)")
PROMPT_RE = re.compile(r"ENTER to continue\.\.")
ISA_CHOICES = ["i", "im", "ic", "imc"]


def prepare_workspace(name):
    job_root = WORKSPACE_ROOT / name
    workspace = job_root / "picosoc"
    if workspace.exists():
        shutil.rmtree(workspace)
    shutil.copytree(PICOSOC_ROOT, workspace, symlinks=True)

    picorv32_link = job_root / "picorv32.v"
    if picorv32_link.exists() or picorv32_link.is_symlink():
        picorv32_link.unlink()
    picorv32_link.symlink_to(REPO_ROOT / "picorv32.v")

    firmware_link = job_root / "firmware"
    if firmware_link.exists() or firmware_link.is_symlink():
        if firmware_link.is_dir() and not firmware_link.is_symlink():
            shutil.rmtree(firmware_link)
        else:
            firmware_link.unlink()
    firmware_link.symlink_to(REPO_ROOT / "firmware", target_is_directory=True)

    dhrystone_link = job_root / "dhrystone"
    if dhrystone_link.exists() or dhrystone_link.is_symlink():
        if dhrystone_link.is_dir() and not dhrystone_link.is_symlink():
            shutil.rmtree(dhrystone_link)
        else:
            dhrystone_link.unlink()
    dhrystone_link.symlink_to(REPO_ROOT / "dhrystone", target_is_directory=True)

    return workspace


def detect_port():
    ports = sorted(glob.glob("/dev/ttyUSB*") + glob.glob("/dev/ttyACM*"))
    if not ports:
        raise SystemExit("No /dev/ttyUSB* or /dev/ttyACM* port found.")
    return ports[-1]


def configure_serial(fd):
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attrs[3] = 0
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 1
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIOFLUSH)


def open_serial(port):
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    configure_serial(fd)
    return fd


def capture_dmips(fd, timeout_seconds):
    deadline = time.time() + timeout_seconds
    chunks = []
    prompt_count = 0
    while time.time() < deadline:
        try:
            data = os.read(fd, 4096)
        except BlockingIOError:
            data = b""
        if data:
            text = data.decode("utf-8", errors="replace")
            chunks.append(text)
            buffer = "".join(chunks)
            seen_prompts = len(PROMPT_RE.findall(buffer))
            while prompt_count < seen_prompts:
                os.write(fd, b"\r")
                prompt_count += 1
            match = DMIPS_RE.search(buffer)
            if match:
                return match.group(1), buffer
        time.sleep(0.05)
    return "", "".join(chunks)


def update_csv(csv_path, updates, match_fields):
    if not csv_path.exists():
        return
    with csv_path.open(newline="") as f:
        rows = list(csv.DictReader(f))
        fieldnames = rows[0].keys() if rows else []
    changed = False
    for row in rows:
        if all(row.get(key, "") == str(value) for key, value in match_fields.items()):
            row.update(updates)
            changed = True
    if changed:
        with csv_path.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)


def measure_config(port, isa, barrel_shifter, two_cycle_alu, timeout, target, build_name=None):
    build_name = build_name or f"hw_b{barrel_shifter}_a{two_cycle_alu}_rv32{isa}"
    workspace = prepare_workspace(build_name)

    fd = open_serial(port)
    try:
        print("+ make clean", flush=True)
        subprocess.run(
            ["make", "clean"],
            cwd=workspace,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print(
            "+ make "
            f"RISCV_ISA={isa} BARREL_SHIFTER={barrel_shifter} TWO_CYCLE_ALU={two_cycle_alu} {target}",
            flush=True,
        )
        program = subprocess.Popen(
            [
                "make",
                f"RISCV_ISA={isa}",
                f"BARREL_SHIFTER={barrel_shifter}",
                f"TWO_CYCLE_ALU={two_cycle_alu}",
                target,
            ],
            cwd=workspace,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        dmips, capture = capture_dmips(fd, timeout)
        returncode = program.wait()
    except subprocess.CalledProcessError as exc:
        print(f"Build cleanup failed for isa={isa} b={barrel_shifter} a={two_cycle_alu}: {exc}", flush=True)
        return {"status": "CLEAN_FAILED", "dmips": ""}
    finally:
        os.close(fd)

    if returncode != 0:
        print(f"Build/program failed for isa={isa} b={barrel_shifter} a={two_cycle_alu}", flush=True)
        return {"status": "BUILD_FAILED", "dmips": ""}

    if not dmips:
        print(f"No DMIPS line captured for isa={isa} b={barrel_shifter} a={two_cycle_alu}", flush=True)
        print(f"DEBUG: Captured UART output before timeout: {capture!r}", flush=True)
        raise SystemExit("Aborting after missing DMIPS output. Check the UART log above.")

    print(
        f"RISCV_ISA={isa} BARREL_SHIFTER={barrel_shifter} TWO_CYCLE_ALU={two_cycle_alu} DMIPS/MHz={dmips}",
        flush=True,
    )

    update_csv(
        PROJECT_ROOT / "soc_results.csv",
        {"hw_dmips_per_mhz": dmips},
        {
            "RISCV_ISA": f"rv32{isa}",
            "BARREL_SHIFTER": barrel_shifter,
            "TWO_CYCLE_ALU": two_cycle_alu,
        },
    )
    update_csv(
        PROJECT_ROOT / "benchmark_results.csv",
        {"hw_dmips_per_mhz": dmips},
        {
            "BARREL_SHIFTER": barrel_shifter,
            "TWO_CYCLE_ALU": two_cycle_alu,
            "isa": f"rv32{isa}",
        },
    )
    print(
        "Stored result: "
        f"{{'RISCV_ISA': 'rv32{isa}', 'BARREL_SHIFTER': {barrel_shifter}, "
        f"'TWO_CYCLE_ALU': {two_cycle_alu}, 'hw_dmips_per_mhz': '{dmips}'}}",
        flush=True,
    )
    return {"status": "OK", "dmips": dmips}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--barrel-shifter", type=int, choices=[0, 1])
    parser.add_argument("--two-cycle-alu", type=int, choices=[0, 1])
    parser.add_argument("--isa", choices=ISA_CHOICES)
    parser.add_argument("--port", default=None)
    parser.add_argument("--build-name", default=None)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--target", choices=["prog_bram", "prog_flash"], default="prog_bram")
    parser.add_argument("--all-configs", action="store_true")
    parser.add_argument("--all-isas", action="store_true")
    args = parser.parse_args()

    if args.barrel_shifter is None and args.two_cycle_alu is None:
        args.all_configs = True
    elif args.barrel_shifter is None or args.two_cycle_alu is None:
        parser.error("provide both --barrel-shifter and --two-cycle-alu, or neither")

    if args.isa is None:
        args.all_isas = True

    isa_values = ISA_CHOICES if args.all_isas else [args.isa]

    port = args.port or detect_port()
    WORKSPACE_ROOT.mkdir(parents=True, exist_ok=True)
    if args.all_configs:
        for isa, (barrel_shifter, two_cycle_alu) in itertools.product(isa_values, itertools.product([0, 1], repeat=2)):
            name = f"hw_b{barrel_shifter}_a{two_cycle_alu}_rv32{isa}"
            measure_config(port, isa, barrel_shifter, two_cycle_alu, args.timeout, args.target, name)
        return

    result = measure_config(
        port,
        isa_values[0],
        args.barrel_shifter,
        args.two_cycle_alu,
        args.timeout,
        args.target,
        args.build_name,
    )
    if not result["dmips"]:
        raise SystemExit("Did not capture a DMIPS/MHz line. Check the UART port and rerun.")


if __name__ == "__main__":
    main()
