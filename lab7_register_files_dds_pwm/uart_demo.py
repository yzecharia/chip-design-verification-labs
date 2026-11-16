#!/usr/bin/env python3
"""Lab 7 board demo over UART (Nexys A7-100T, 57600 8-N-1).

Sends a fixed sequence of messages to the FPGA: static colours on each LED, CIE on / off,
power on / off, BREATH and RAINBOW. After every step it reads the register back, prints
what was sent and what came back, and then waits so you can take a picture of the board.

    python3 -m venv .venv && .venv/bin/pip install pyserial      # once
    .venv/bin/python uart_demo.py                 # 10 s between steps
    .venv/bin/python uart_demo.py --delay 20      # 20 s between steps
    .venv/bin/python uart_demo.py --enter         # wait for Enter between steps
    .venv/bin/python uart_demo.py --port /dev/cu.usbserial-XXXX1
    .venv/bin/python uart_demo.py --dry-run       # no board: only print the bytes

Everything printed is also saved to uart_demo_log.txt next to this file.
Close CoolTerm first: only one program can use the serial port at a time.
"""
import argparse
import glob
import os
import sys
import time

BAUD = 57600
CLK_FREQ = 100_000_000
SWEEP_TIME = 1024
REPLY_BYTES = 16

LED_RGF, PWM_RGF, CNT_RGF, SYS_RGF = 0, 1, 2, 3

LED_CTRL, LED_PATTERN, LED16_VALUE, LED17_VALUE, LED_STATUS = 0, 4, 8, 12, 16
PWM_CFG, RED_PWM_CTRL, GREEN_PWM_CTRL, BLUE_PWM_CTRL, PWM_STATUS = 0, 4, 8, 12, 16
CNT_RX_PACKET, CNT_TX_PACKET, CNT_COLOR_MSG, CNT_CONFIG_MSG, CNT_STATUS = 0, 4, 8, 12, 16
SYS_CTRL, SYS_STATUS = 0, 4

STATIC, BREATH, RAINBOW = 0, 1, 2
SEL_LED16, SEL_LED17 = 0b01, 0b10

NAMES = {
    (LED_RGF, LED_CTRL): "LED_CTRL", (LED_RGF, LED_PATTERN): "LED_PATTERN",
    (LED_RGF, LED16_VALUE): "LED16_VALUE", (LED_RGF, LED17_VALUE): "LED17_VALUE",
    (LED_RGF, LED_STATUS): "LED_STATUS",
    (PWM_RGF, PWM_CFG): "PWM_CFG", (PWM_RGF, RED_PWM_CTRL): "RED_PWM_CTRL",
    (PWM_RGF, GREEN_PWM_CTRL): "GREEN_PWM_CTRL", (PWM_RGF, BLUE_PWM_CTRL): "BLUE_PWM_CTRL",
    (PWM_RGF, PWM_STATUS): "PWM_STATUS",
    (CNT_RGF, CNT_RX_PACKET): "CNT_RX_PACKET", (CNT_RGF, CNT_TX_PACKET): "CNT_TX_PACKET",
    (CNT_RGF, CNT_COLOR_MSG): "CNT_COLOR_MSG", (CNT_RGF, CNT_CONFIG_MSG): "CNT_CONFIG_MSG",
    (CNT_RGF, CNT_STATUS): "CNT_STATUS",
    (SYS_RGF, SYS_CTRL): "SYS_CTRL", (SYS_RGF, SYS_STATUS): "SYS_STATUS",
}


# ---------------------------------------------------------------- messages
def addr_bytes(rgf, offset):
    return bytes([rgf, (offset >> 8) & 0xFF, offset & 0xFF])


def msg_write(rgf, offset, data):
    """{W a2 a1 a0 , V 00 d3 d2 , V 00 d1 d0}  - address and data are raw bytes"""
    d = data.to_bytes(4, "big")
    return b"{W" + addr_bytes(rgf, offset) + b",V\x00" + d[0:2] + b",V\x00" + d[2:4] + b"}"


def msg_read(rgf, offset):
    """{R a2 a1 a0}  - address is raw bytes"""
    return b"{R" + addr_bytes(rgf, offset) + b"}"


def msg_rgb(r, g, b):
    """{Rddd,Gddd,Bddd}  - ASCII digits, 000..255"""
    return f"{{R{r:03d},G{g:03d},B{b:03d}}}".encode()


def msg_led(n):
    """{L016} or {L017}  - ASCII digits"""
    return f"{{L{n:03d}}}".encode()


def led_ctrl(sel, power16=1, power17=1, cie16=0, cie17=0):
    return (cie17 << 5) | (cie16 << 4) | (power17 << 3) | (power16 << 2) | sel


def pwm_ctrl(freq, mag=0, phase=0):
    return (freq << 11) | (mag << 9) | phase


def pwm_cfg(sweep_time, time_slots):
    return (sweep_time << 16) | time_slots


def hexs(b):
    return " ".join(f"{x:02X}" for x in b)


def show(b):
    """bytes as text: printable ASCII as is, anything else as \\xNN"""
    return "".join(chr(x) if 0x20 <= x < 0x7F else f"\\x{x:02X}" for x in b)


def parse_reply(b):
    """{R a2 a1 a0 , V 00 d3 d2 , V 00 d1 d0}  ->  (rgf, offset, data) or None"""
    if len(b) != REPLY_BYTES or b[0:2] != b"{R" or b[5:7] != b",V" or b[10:12] != b",V" or b[15:16] != b"}":
        return None
    return b[2], (b[3] << 8) | b[4], (b[8] << 24) | (b[9] << 16) | (b[13] << 8) | b[14]


# ---------------------------------------------------------------- board
class Board:
    def __init__(self, port, dry_run, log):
        self.dry_run, self.log, self.ser = dry_run, log, None
        self.errors = 0
        if not dry_run:
            import serial
            self.ser = serial.Serial(port, BAUD, bytesize=8, parity="N", stopbits=1, timeout=1.0)
            time.sleep(0.2)
            self.ser.reset_input_buffer()

    def out(self, text=""):
        print(text, flush=True)
        self.log.write(text + "\n")
        self.log.flush()

    def send(self, msg):
        self.out(f"    TX  {hexs(msg):<48}  {show(msg)}")
        if self.ser:
            self.ser.write(msg)
            self.ser.flush()
            time.sleep(0.05)

    def write(self, rgf, offset, data):
        self.send(msg_write(rgf, offset, data))

    def read(self, rgf, offset, expect=None, mask=0xFFFFFFFF):
        name = NAMES.get((rgf, offset), f"rgf {rgf} offset {offset}")
        self.send(msg_read(rgf, offset))
        if not self.ser:
            self.out(f"    RX  (dry run)   {name}")
            return None
        reply = self.ser.read(REPLY_BYTES)
        parsed = parse_reply(reply)
        if parsed is None:
            self.errors += 1
            got = hexs(reply) if reply else "nothing (timeout)"
            self.out(f"    RX  {got}")
            self.out(f"        ** bad or missing reply for {name} **")
            return None
        data = parsed[2]
        verdict = ""
        if expect is not None:
            ok = (data & mask) == (expect & mask)
            verdict = "OK" if ok else f"** MISMATCH, expected 0x{expect & mask:08X} **"
            self.errors += 0 if ok else 1
        self.out(f"    RX  {hexs(reply):<48}  {name} = 0x{data:08X}  {verdict}")
        return data

    def close(self):
        if self.ser:
            self.ser.close()


def cycle_seconds(freq, sweep_time, time_slots):
    """time of one full BREATH / RAINBOW cycle: 512 table entries, 256 fraction steps each, one step of freq per PWM period"""
    return (512 * 256 / freq) * sweep_time * time_slots / CLK_FREQ


def time_slots_for(seconds, freq, sweep_time):
    """PWM_CFG.time_slots that makes one full cycle last about this many seconds"""
    return max(1, min(0xFFFF, round(seconds * CLK_FREQ * freq / (512 * 256 * sweep_time))))


def wait(board, args, text="take the picture", seconds=None):
    if args.dry_run:
        return
    if args.enter:
        input(f"    >> {text}, then press Enter ")
        return
    for left in range(seconds or args.delay, 0, -1):
        print(f"\r    >> {text}: {left:3d} s ", end="", flush=True)
        time.sleep(1)
    print("\r" + " " * 60 + "\r", end="", flush=True)


# ---------------------------------------------------------------- the demo
def demo(board, args):
    n = 0

    def dim(r, g, b):
        return tuple(round(c * args.brightness / 100) for c in (r, g, b))

    def val(r, g, b):
        r, g, b = dim(r, g, b)
        return (r << 16) | (g << 8) | b

    def step(title):
        nonlocal n
        n += 1
        board.out()
        board.out(f"[{n:02d}] {title}")

    step("State after reset (no picture needed)")
    board.read(SYS_RGF, SYS_CTRL)
    board.read(LED_RGF, LED_CTRL)
    board.read(LED_RGF, LED_PATTERN)
    board.read(PWM_RGF, PWM_CFG)

    step("Both LEDs on, no CIE, STATIC pattern, both black")
    board.write(LED_RGF, LED_PATTERN, STATIC)
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED16))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED16), 0x3F)
    board.send(msg_rgb(*dim(0, 0, 0)))
    board.send(msg_led(17))
    board.send(msg_rgb(*dim(0, 0, 0)))
    board.send(msg_led(16))

    step("LED16 = red (LED17 stays black)")
    board.send(msg_rgb(*dim(255, 0, 0)))
    board.read(LED_RGF, LED16_VALUE, val(255, 0, 0), 0xFFFFFF)
    wait(board, args)

    step("LED17 = blue (LED16 stays red)")
    board.send(msg_led(17))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17), 0x3F)
    board.send(msg_rgb(*dim(0, 0, 255)))
    board.read(LED_RGF, LED17_VALUE, val(0, 0, 255), 0xFFFFFF)
    wait(board, args)

    step("LED16 = green (LED17 stays blue)")
    board.send(msg_led(16))
    board.send(msg_rgb(*dim(0, 255, 0)))
    board.read(LED_RGF, LED16_VALUE, val(0, 255, 0), 0xFFFFFF)
    wait(board, args)

    step("Both LEDs = white 255/255/255, no CIE")
    board.send(msg_rgb(*dim(255, 255, 255)))
    board.send(msg_led(17))
    board.send(msg_rgb(*dim(255, 255, 255)))
    board.read(LED_RGF, LED16_VALUE, val(255, 255, 255), 0xFFFFFF)
    board.read(LED_RGF, LED17_VALUE, val(255, 255, 255), 0xFFFFFF)
    wait(board, args)

    step("Same white, CIE on LED16 only (compare the two LEDs)")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, cie16=1))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, cie16=1), 0x3F)
    wait(board, args)

    step("Same white, CIE on both LEDs")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, cie16=1, cie17=1))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, cie16=1, cie17=1), 0x3F)
    wait(board, args)

    step("Both LEDs = 128/128/128, no CIE (gamma: much dimmer than half)")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17))
    board.send(msg_rgb(*dim(128, 128, 128)))
    board.send(msg_led(16))
    board.send(msg_rgb(*dim(128, 128, 128)))
    board.read(LED_RGF, LED16_VALUE, val(128, 128, 128), 0xFFFFFF)
    board.read(LED_RGF, LED17_VALUE, val(128, 128, 128), 0xFFFFFF)
    wait(board, args)

    step("LED16 = orange 255/128/0, LED17 = purple 128/0/255, no CIE")
    board.send(msg_rgb(*dim(255, 128, 0)))
    board.send(msg_led(17))
    board.send(msg_rgb(*dim(128, 0, 255)))
    board.read(LED_RGF, LED16_VALUE, val(255, 128, 0), 0xFFFFFF)
    board.read(LED_RGF, LED17_VALUE, val(128, 0, 255), 0xFFFFFF)
    wait(board, args)

    step("Same colours, CIE on both")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, cie16=1, cie17=1))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, cie16=1, cie17=1), 0x3F)
    wait(board, args)

    step("LED17 power off (LED16 stays orange)")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, power17=0))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, power17=0), 0x3F)
    wait(board, args)

    step("LED16 power off, LED17 on (purple)")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, power16=0))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, power16=0), 0x3F)
    wait(board, args)

    step(f"Both on again, DDS registers: red / green / blue freq {args.freq}, mag 0, phase 0")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17))
    board.write(PWM_RGF, RED_PWM_CTRL, pwm_ctrl(args.freq))
    board.write(PWM_RGF, GREEN_PWM_CTRL, pwm_ctrl(args.freq))
    board.write(PWM_RGF, BLUE_PWM_CTRL, pwm_ctrl(args.freq))
    board.read(PWM_RGF, RED_PWM_CTRL, pwm_ctrl(args.freq), 0xFFFFFF)

    ts = time_slots_for(args.breath, args.freq, SWEEP_TIME)
    cycle = cycle_seconds(args.freq, SWEEP_TIME, ts)
    step(f"Pattern = BREATH (both LEDs, white): time_slots {ts} -> one breath = {cycle:.2f} s, PWM = {CLK_FREQ / (SWEEP_TIME * ts):.0f} Hz")
    board.write(PWM_RGF, PWM_CFG, pwm_cfg(SWEEP_TIME, ts))
    board.read(PWM_RGF, PWM_CFG, pwm_cfg(SWEEP_TIME, ts))
    board.write(LED_RGF, LED_PATTERN, BREATH)
    board.read(LED_RGF, LED_PATTERN, BREATH, 0x3)
    wait(board, args, "take pictures / a video", max(args.delay, int(3 * cycle) + 1))

    ts = time_slots_for(3 * args.rainbow, args.freq, SWEEP_TIME)
    cycle = cycle_seconds(args.freq, SWEEP_TIME, ts)
    step(f"Pattern = RAINBOW (both LEDs): time_slots {ts} -> each colour = {cycle / 3:.2f} s, full cycle = {cycle:.2f} s, PWM = {CLK_FREQ / (SWEEP_TIME * ts):.0f} Hz")
    board.write(PWM_RGF, PWM_CFG, pwm_cfg(SWEEP_TIME, ts))
    board.read(PWM_RGF, PWM_CFG, pwm_cfg(SWEEP_TIME, ts))
    board.write(LED_RGF, LED_PATTERN, RAINBOW)
    board.read(LED_RGF, LED_PATTERN, RAINBOW, 0x3)
    wait(board, args, "take pictures / a video", max(args.delay, int(2 * cycle) + 1))

    step("RAINBOW with LED16 power off (power beats the pattern)")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, power16=0))
    board.read(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17, power16=0), 0x3F)
    wait(board, args)

    step("Back to STATIC, both on (orange and purple return), PWM_CFG back to its reset value")
    board.write(LED_RGF, LED_CTRL, led_ctrl(SEL_LED17))
    board.write(LED_RGF, LED_PATTERN, STATIC)
    board.read(LED_RGF, LED_PATTERN, STATIC, 0x3)
    board.write(PWM_RGF, PWM_CFG, pwm_cfg(SWEEP_TIME, 1))
    board.read(PWM_RGF, PWM_CFG, pwm_cfg(SWEEP_TIME, 1))
    wait(board, args)

    step("Counters and status registers (no picture needed)")
    board.read(CNT_RGF, CNT_RX_PACKET)
    board.read(CNT_RGF, CNT_TX_PACKET)
    board.read(CNT_RGF, CNT_COLOR_MSG)
    board.read(CNT_RGF, CNT_CONFIG_MSG)
    board.read(LED_RGF, LED_STATUS)
    board.read(PWM_RGF, PWM_STATUS)
    board.read(SYS_RGF, SYS_STATUS)


def find_port():
    ports = sorted(glob.glob("/dev/cu.usbserial-*"))
    if not ports:
        sys.exit("No /dev/cu.usbserial-* port found. Is the board connected and on? Or pass --port.")
    return ports[-1]


def use_venv():
    """if this Python has no pyserial but lab_7/.venv does, run the script again with the .venv Python"""
    try:
        import serial  # noqa: F401
        return
    except ImportError:
        pass
    venv_python = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".venv", "bin", "python")
    if os.path.exists(venv_python) and os.path.abspath(sys.executable) != os.path.abspath(venv_python) and not os.environ.get("UART_DEMO_VENV"):
        os.environ["UART_DEMO_VENV"] = "1"
        os.execv(venv_python, [venv_python, os.path.abspath(__file__)] + sys.argv[1:])


def main():
    p = argparse.ArgumentParser(description="Lab 7 UART board demo")
    p.add_argument("--port", help="serial port (default: the last /dev/cu.usbserial-*)")
    p.add_argument("--delay", type=int, default=10, help="seconds to wait at each picture step (default 10)")
    p.add_argument("--enter", action="store_true", help="wait for Enter instead of a fixed delay")
    p.add_argument("--freq", type=int, default=10, help="DDS freq field for BREATH / RAINBOW: the step per PWM period, smaller = slower (default 10, the minimum in the lab PDF)")
    p.add_argument("--breath", type=float, default=2.0, help="seconds for one full breath, dark -> bright -> dark (default 2.0)")
    p.add_argument("--rainbow", type=float, default=1.5, help="seconds per colour in RAINBOW; the full cycle is 3 times this (default 1.5)")
    p.add_argument("--brightness", type=int, default=100, help="scale every static colour value to this percent, 1..100 (default 100). Does not affect BREATH / RAINBOW")
    p.add_argument("--dry-run", action="store_true", help="do not open the port, only print the bytes")
    args = p.parse_args()
    if not args.dry_run:
        use_venv()

    port = None if args.dry_run else (args.port or find_port())
    log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uart_demo_log.txt")
    with open(log_path, "w") as log:
        try:
            board = Board(port, args.dry_run, log)
        except ImportError:
            sys.exit("pyserial is missing in this Python.\nOnce:  python3 -m venv .venv && .venv/bin/pip install pyserial\nThen:  .venv/bin/python uart_demo.py")
        except Exception as e:
            sys.exit(f"Could not open {port}: {e}\nIf CoolTerm is connected, disconnect it first.")
        board.out(f"Lab 7 UART demo   port: {port or 'dry run'}   {BAUD} 8-N-1   {time.strftime('%Y-%m-%d %H:%M:%S')}")
        if args.brightness != 100:
            board.out(f"static colours scaled to {args.brightness}%: the values in the step titles are the full-brightness ones")
        try:
            demo(board, args)
        except KeyboardInterrupt:
            board.out("\nstopped")
        finally:
            board.close()
        board.out()
        board.out(f"done, {board.errors} problem(s). Log: {log_path}")


if __name__ == "__main__":
    main()
