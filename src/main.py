#!/usr/bin/env python3

import argparse
import time

import numpy as np
import serial
from numpy.typing import NDArray
from serial import Serial

NUM_LEDS = 6


def transmit_slow(data: NDArray, ser: Serial, delay_s: float):
    print(f"Transmit 1 byte every {delay_s}s")

    for i in data:
        ser.write(bytes([i]))

        received = int.from_bytes(ser.read(1))
        assert i == received

        time.sleep(delay_s)


# Need to chunk data since we don't have HW flow control
# Tang Nano 20K MCU buffer size is 32
def transmit_fast(data: NDArray, ser: Serial, chunk_size: int):
    print("Transmit fast")

    num_chunks = len(data) // chunk_size
    results_raw = bytearray()
    for chunk in np.array_split(data, num_chunks):
        ser.write(chunk)
        results_raw += ser.read(len(chunk))

    results = np.frombuffer(results_raw, dtype=np.uint8)
    assert np.allclose(data, results)


def main():
    parser = argparse.ArgumentParser(description="UART LED Loopback Runner")
    parser.add_argument(
        "-d",
        "--device",
        type=str,
        default="/dev/tty.usbserial-20250303171",
        help="USB-serial port device",
    )
    parser.add_argument(
        "-b",
        "--baud_rate",
        type=int,
        default=2_000_000,
        help="Baud rate",
    )

    # Parse CLI args
    args = parser.parse_args()

    # Ascend from 0 to 2^NUM_LEDS then descend to 0
    led_range = np.arange(0, 2**NUM_LEDS, dtype=np.uint8)
    data = np.concat((led_range, np.flip(led_range[:-1])))

    with serial.Serial(args.device, args.baud_rate, timeout=1) as ser:
        print(f"Connected to {ser.name}")
        transmit_slow(data, ser, 0.05)
        transmit_fast(data, ser, 32)


if __name__ == "__main__":
    main()
