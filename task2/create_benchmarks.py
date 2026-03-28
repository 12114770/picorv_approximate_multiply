#!/usr/bin/env python3

import argparse
import csv
import glob
import itertools
import os
import re
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
        if (candidate / "picosoc").is_dir() and (candidate / "dhrystone").is_dir():
            return candidate
    raise SystemExit(
        "Could not locate the PicoRV32 task root. Expected to find 'picosoc/' and 'dhrystone/' "
        f"under one of: {', '.join(str(path) for path in candidates)}"
    )


REPO_ROOT = resolve_picorv32_root()
PICOSOC_ROOT = REPO_ROOT / "picosoc"
DHRYSTONE_ROOT = REPO_ROOT / "dhrystone"
PARAMETER_KEYS = ["BARREL_SHIFTER", "TWO_CYCLE_ALU"]
RISCV_ISA_CHOICES = ["i", "im", "ic", "imc"]
DMIPS_RE = re.compile(r"(?:DMIPS/MHz|DMIPS_Per_MHz):\s*([0-9]+\.[0-9]+)")
PROMPT_RE = re.compile(r"ENTER to continue\.\.")


def run_capture(cmd, cwd):
    print("+", " ".join(str(part) for part in cmd), flush=True)
    proc = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = proc.stdout
    returncode = proc.returncode
    if returncode != 0:
        raise subprocess.CalledProcessError(returncode, cmd, output=output)
    return output


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


def parse_utilization(text):
    result = {}
    for name, used, total in re.findall(r"Info:\s+([A-Z0-9_]+):\s+(\d+)\s*/\s*(\d+)", text):
        result[name] = f"{used}/{total}"
    match = re.search(r"Max frequency for clock '.*?':\s+([0-9.]+) MHz", text)
    if match:
        result["fmax_mhz"] = match.group(1)
    return result


def parse_dmips(text):
    match = DMIPS_RE.search(text)
    return match.group(1) if match else ""


def parse_code_size(text):
    for line in text.splitlines():
        fields = line.split()
        if len(fields) >= 6 and all(field.isdigit() for field in fields[:4]):
            return fields[0]
    return ""


def get_hw_elf_path(target):
    if target == "prog_flash":
        return Path("build/firmware/icebreaker_fw_flash.elf")
    return Path("build/firmware/icebreaker_fw_bram.elf")


def get_sw_code_size(riscv_isa, config):
    size_out = run_capture(
        [
            "make",
            f"RISCV_ISA={riscv_isa}",
            f"BARREL_SHIFTER={config['BARREL_SHIFTER']}",
            f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
            "size",
        ],
        DHRYSTONE_ROOT,
    )
    return parse_code_size(size_out)


def get_sw_dmips(riscv_isa, config):
    test_out = run_capture(
        [
            "make",
            f"RISCV_ISA={riscv_isa}",
            f"BARREL_SHIFTER={config['BARREL_SHIFTER']}",
            f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
            "test",
        ],
        DHRYSTONE_ROOT,
    )
    return parse_dmips(test_out)


def get_hw_code_size(riscv_isa, config, elf_path):
    size_cmd = [
        "make",
        f"RISCV_ISA={riscv_isa}",
        f"BARREL_SHIFTER={config['BARREL_SHIFTER']}",
        f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
        "size",
    ]
    size_out = run_capture(size_cmd, PICOSOC_ROOT)
    return parse_code_size(size_out)


def decode_sim_serial(text):
    chars = []
    for line in text.splitlines():
        printable = re.fullmatch(r"Serial data: '(.+)'", line)
        if printable:
            chars.append(printable.group(1))
            continue
        numeric = re.fullmatch(r"Serial data:\s+(\d+)", line)
        if numeric:
            chars.append(chr(int(numeric.group(1))))
    return "".join(chars)


def build_soc_config(config, riscv_isa, port, timeout, target, measure_hw_dmips):
    row = {
        "RISCV_ISA": f"rv32{riscv_isa}",
        "BARREL_SHIFTER": config["BARREL_SHIFTER"],
        "TWO_CYCLE_ALU": config["TWO_CYCLE_ALU"],
        "icestorm_lc": "",
        "icestorm_ram": "",
        "sb_io": "",
        "sb_gb": "",
        "icestorm_dsp": "",
        "fmax_mhz": "",
        "sw_code_size": "",
        "hw_code_size": "",
        "sw_dmips_per_mhz": "",
        "hw_dmips_per_mhz": "",
    }
    hw_elf_path = get_hw_elf_path(target)
    try:
        run_capture(["make", "clean"], PICOSOC_ROOT)
        run_capture(["make", "clean"], DHRYSTONE_ROOT)
        pnr_out = run_capture(
            [
                "make",
                f"RISCV_ISA={riscv_isa}",
                f"BARREL_SHIFTER={config['BARREL_SHIFTER']}",
                f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
                "pnr",
            ],
            PICOSOC_ROOT,
        )
        sw_dmips = get_sw_dmips(riscv_isa, config)
        sw_code_size = get_sw_code_size(riscv_isa, config)
        hw_code_size = get_hw_code_size(riscv_isa, config, hw_elf_path)
    except subprocess.CalledProcessError as exc:
        print(
            f"Build failed for RISCV_ISA={riscv_isa} BARREL_SHIFTER={config['BARREL_SHIFTER']} "
            f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}: exit {exc.returncode}",
            flush=True,
        )
        return row

    if not sw_dmips:
        print(
            f"No software DMIPS line captured for RISCV_ISA={riscv_isa} BARREL_SHIFTER={config['BARREL_SHIFTER']} "
            f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
            flush=True,
        )
        raise SystemExit("Aborting after missing software DMIPS output.")

    parsed = parse_utilization(pnr_out)
    row.update(
        {
            "icestorm_lc": parsed.get("ICESTORM_LC", ""),
            "icestorm_ram": parsed.get("ICESTORM_RAM", ""),
            "sb_io": parsed.get("SB_IO", ""),
            "sb_gb": parsed.get("SB_GB", ""),
            "icestorm_dsp": parsed.get("ICESTORM_DSP", ""),
            "fmax_mhz": parsed.get("fmax_mhz", ""),
            "sw_code_size": sw_code_size,
            "hw_code_size": hw_code_size,
            "sw_dmips_per_mhz": sw_dmips,
        }
    )

    if measure_hw_dmips:
        fd = open_serial(port)
        try:
            cmd = [
                "make",
                f"RISCV_ISA={riscv_isa}",
                f"BARREL_SHIFTER={config['BARREL_SHIFTER']}",
                f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
                target,
            ]
            print("+", " ".join(cmd), flush=True)
            program = subprocess.Popen(cmd, cwd=PICOSOC_ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            dmips, capture = capture_dmips(fd, timeout)
            returncode = program.wait()
        finally:
            os.close(fd)

        if returncode != 0:
            print(
                f"Build/program failed for RISCV_ISA={riscv_isa} BARREL_SHIFTER={config['BARREL_SHIFTER']} "
                f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
                flush=True,
            )
            return row

        if not dmips:
            print(
                f"No DMIPS line captured for RISCV_ISA={riscv_isa} BARREL_SHIFTER={config['BARREL_SHIFTER']} "
                f"TWO_CYCLE_ALU={config['TWO_CYCLE_ALU']}",
                flush=True,
            )
            print(f"DEBUG: Captured UART output before timeout: {capture!r}", flush=True)
            raise SystemExit("Aborting after missing DMIPS output. Check the UART log above.")

        row["hw_dmips_per_mhz"] = dmips

    print(f"Stored row: {row}", flush=True)
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--riscv-isa", choices=RISCV_ISA_CHOICES)
    parser.add_argument("--measure-hw-dmips", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--port", default=None)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--target", choices=["prog_bram", "prog_flash"], default="prog_bram")
    parser.add_argument("--out", default="soc_results.csv")
    args = parser.parse_args()

    isa_values = [args.riscv_isa] if args.riscv_isa else RISCV_ISA_CHOICES
    configs = [dict(zip(PARAMETER_KEYS, values)) for values in itertools.product([0, 1], repeat=2)]
    port = (args.port or detect_port()) if args.measure_hw_dmips else None
    rows = [
        build_soc_config(config, isa, port, args.timeout, args.target, args.measure_hw_dmips)
        for isa, config in itertools.product(isa_values, configs)
    ]

    out_path = PROJECT_ROOT / args.out
    with out_path.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "RISCV_ISA",
                "BARREL_SHIFTER",
                "TWO_CYCLE_ALU",
                "icestorm_lc",
                "icestorm_ram",
                "sb_io",
                "sb_gb",
                "icestorm_dsp",
                "fmax_mhz",
                "sw_code_size",
                "hw_code_size",
                "sw_dmips_per_mhz",
                "hw_dmips_per_mhz",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
