import time

import numpy as np
import serial
from numpy.typing import NDArray
from serial import Serial

DEVICE_PATH = "/dev/tty.usbserial-20250303171"
BAUD_RATE = 2_000_000
NUM_LEDS = 6


def transmit_slow(data: NDArray, ser: Serial, delay_s: float = 0.25):
    print(f"Transmit 1 byte every {delay_s}s")

    for i in data:
        ser.write(bytes([i]))

        received = int.from_bytes(ser.read(1))
        assert i == received

        time.sleep(delay_s)


# Need to chunk data since we don't have HW flow control
# Tang Nano 20K MCU buffer size is 32
def transmit_fast(data: NDArray, ser: Serial, chunk_size: int = 32):
    print("Transmit fast")

    num_chunks = len(data) // chunk_size
    results_raw = bytearray()
    for chunk in np.array_split(data, num_chunks):
        ser.write(chunk)
        results_raw += ser.read(len(chunk))

    results = np.frombuffer(results_raw, dtype=np.uint8)
    assert np.allclose(data, results)


def main():
    # Ascend from 0 to 2^NUM_LEDS then descend to 0
    led_range = np.arange(0, 2**NUM_LEDS, dtype=np.uint8)
    data = np.concat((led_range, np.flip(led_range[:-1])))

    with serial.Serial(DEVICE_PATH, BAUD_RATE, timeout=1) as ser:
        print(f"Connected to {ser.name}")
        transmit_slow(data, ser, 0.05)
        transmit_fast(data, ser, 32)


if __name__ == "__main__":
    main()
