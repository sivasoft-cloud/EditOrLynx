#!/usr/bin/env python3
"""Synthesize the notch sound cues into Sources/Pounce/Resources as 16-bit CAF files.

Every cue is built from soft sine partials with short envelopes, so they read as subtle
interface ticks and chimes rather than alerts. Run from the repository root:

    python3 scripts/make-sounds.py
"""

import math
import os
import struct
import subprocess
import tempfile
import wave

RATE = 44_100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "Sources", "Pounce", "Resources")


def envelope(t, length, attack=0.004, decay=0.18, power=2.4):
    if t < attack:
        return t / attack
    rel = (t - attack) / max(1e-6, length - attack)
    if rel >= 1:
        return 0.0
    return math.exp(-power * 3.2 * rel) * (1 - rel) ** 1.6


def partial(t, freq, amp, length, decay, harmonic=1.0):
    return amp * math.sin(2 * math.pi * freq * harmonic * t) * envelope(t, length, decay=decay)


def bell(t, start, freq, length, amp, decay=0.18):
    """A struck-tone partial set: fundamental plus quiet upper harmonics."""
    if t < start:
        return 0.0
    local = t - start
    if local > length:
        return 0.0
    env = envelope(local, length, decay=decay)
    return amp * env * (
        math.sin(2 * math.pi * freq * local)
        + 0.32 * math.sin(2 * math.pi * freq * 2.0 * local)
        + 0.12 * math.sin(2 * math.pi * freq * 3.01 * local)
    )


def shake(t, start, freq, length, amp):
    """A short wooden click."""
    if t < start:
        return 0.0
    local = t - start
    if local > length:
        return 0.0
    env = envelope(local, length, attack=0.001, decay=0.05, power=5.0)
    return amp * env * math.sin(2 * math.pi * freq * local)


def thud(t, start, freq, length, amp):
    if t < start:
        return 0.0
    local = t - start
    if local > length:
        return 0.0
    env = envelope(local, length, attack=0.002, decay=0.06, power=3.0)
    return amp * env * math.sin(2 * math.pi * freq * local)


def render(duration, voices):
    frames = int(RATE * duration)
    samples = []
    for i in range(frames):
        t = i / RATE
        value = sum(voice(t) for voice in voices)
        samples.append(value)
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.55 / peak
    pcm = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * gain)) * 32_000)
        pcm += struct.pack("<h", v)
    return pcm


CUES = {
    # Link recognised in the clipboard.
    "link": (0.48, [
        lambda t: bell(t, 0.00, 1046.5, 0.30, 0.80, decay=0.14),
        lambda t: bell(t, 0.10, 1567.98, 0.34, 0.62, decay=0.16),
    ]),
    # Something copied out of the notch.
    "copy": (0.48, [
        lambda t: shake(t, 0.00, 2093.0, 0.09, 0.7),
        lambda t: shake(t, 0.055, 2637.0, 0.09, 0.55),
        lambda t: bell(t, 0.00, 1046.5, 0.22, 0.22, decay=0.12),
    ]),
    # A download finished.
    "complete": (0.88, [
        lambda t: bell(t, 0.00, 523.25, 0.60, 0.70, decay=0.16),
        lambda t: bell(t, 0.11, 659.25, 0.62, 0.62, decay=0.16),
        lambda t: bell(t, 0.22, 783.99, 0.64, 0.55, decay=0.16),
        lambda t: bell(t, 0.33, 1046.5, 0.55, 0.42, decay=0.20),
    ]),
    # A clip was cut.
    "clip": (0.60, [
        lambda t: shake(t, 0.00, 1174.7, 0.11, 0.75),
        lambda t: shake(t, 0.10, 783.99, 0.13, 0.65),
        lambda t: bell(t, 0.10, 392.0, 0.26, 0.22, decay=0.10),
    ]),
    # Files dropped on the shelf.
    "drop": (0.48, [
        lambda t: thud(t, 0.00, 132.0, 0.34, 0.85),
        lambda t: shake(t, 0.005, 2200.0, 0.07, 0.30),
    ]),
    # Something could not be used.
    "failed": (0.80, [
        lambda t: bell(t, 0.00, 392.0, 0.46, 0.70, decay=0.12),
        lambda t: bell(t, 0.16, 261.63, 0.62, 0.62, decay=0.14),
        lambda t: thud(t, 0.16, 130.81, 0.40, 0.22),
    ]),
}


def write_cue(name, duration, voices):
    pcm = render(duration, voices)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as handle:
        wav_path = handle.name
    with wave.open(wav_path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(bytes(pcm))
    caf_path = os.path.join(OUT_DIR, f"{name}.caf")
    subprocess.run(
        ["afconvert", "-f", "caff", "-d", "LEI16", wav_path, caf_path],
        check=True,
    )
    os.unlink(wav_path)
    return caf_path, duration


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, (duration, voices) in CUES.items():
        path, seconds = write_cue(name, duration, voices)
        print(f"{os.path.basename(path)}  {seconds:.2f}s  {os.path.getsize(path)} bytes")


if __name__ == "__main__":
    main()
