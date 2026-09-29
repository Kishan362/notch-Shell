#!/usr/bin/python3
"""
make_notification_sound.py: generate the notification chime.

The shell points SoundEffect at ~/.config/quickshell/notification.wav but ships
no such file, so every install logs a decode warning and plays nothing. Rather
than commit a binary blob, generate the tone: 44.1 kHz 16-bit mono, two notes
with a soft envelope so there is no click at either edge.

    ./make_notification_sound.py [output.wav]

Defaults to ~/.config/quickshell/notification.wav.
"""
import math
import os
import struct
import sys
import wave

RATE = 44100

# (frequency Hz, duration s) - a rising sixth reads as a positive "ding"
NOTES = [(880.00, 0.085), (1318.51, 0.150)]
GAP = 0.012
FADE_IN = 0.004
DECAY = 5.0  # exponential fall-off rate; higher = shorter tail


def render() -> bytes:
    frames = bytearray()
    for freq, dur in NOTES:
        n = int(RATE * dur)
        for i in range(n):
            t = i / RATE
            # sine fundamental plus a quiet octave for a bit of brightness
            s = math.sin(2 * math.pi * freq * t)
            s += 0.18 * math.sin(2 * math.pi * freq * 2 * t)
            env = math.exp(-DECAY * t)
            if t < FADE_IN:
                env *= t / FADE_IN
            if i > n * 0.85:  # gentle tail fade, never end on a discontinuity
                env *= max(0.0, (n - i) / (n * 0.15))
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s * env)) * 26000))
        frames += b"\x00\x00" * int(RATE * GAP)
    return bytes(frames)


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
        "~/.config/quickshell/notification.wav"
    )
    os.makedirs(os.path.dirname(out), exist_ok=True)
    data = render()
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(f"wrote {out} ({len(data) / 2 / RATE:.3f}s, {RATE} Hz mono)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
