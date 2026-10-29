#!/usr/bin/env python3
"""Generate three short original ambient loops for the Pounce demo library."""
import math
import os
import struct
import subprocess
import tempfile
import wave

SAMPLE_RATE = 44_100
DURATION = 40.0
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Sources", "Pounce", "Resources")


def render(path, chord, sparkle_notes, tempo, warmth=0.0):
    total = int(SAMPLE_RATE * DURATION)
    frames = bytearray()
    random_state = 1337

    for i in range(total):
        t = i / SAMPLE_RATE
        fade_in = min(1.0, t / 3.0)
        fade_out = min(1.0, (DURATION - t) / 4.0)
        env = max(0.0, min(fade_in, fade_out))
        lfo = 0.82 + 0.12 * math.sin(2 * math.pi * 0.06 * t) + 0.06 * math.sin(2 * math.pi * 0.11 * t + 1.2)

        left = 0.0
        right = 0.0
        for index, freq in enumerate(chord):
            detune = 0.09 if index % 2 == 0 else -0.07
            phase_left = 2 * math.pi * (freq + detune) * t
            phase_right = 2 * math.pi * (freq - detune) * t
            tone_l = math.sin(phase_left) + 0.34 * math.sin(2 * phase_left) + 0.12 * math.sin(3 * phase_left)
            tone_r = math.sin(phase_right) + 0.34 * math.sin(2 * phase_right) + 0.12 * math.sin(3 * phase_right)
            weight = 1.0 - index * 0.12
            left += tone_l * weight
            right += tone_r * weight

        # Soft, slow bell arpeggio.
        step = int(t / (tempo / 4.0))
        note_freq = sparkle_notes[step % len(sparkle_notes)]
        local = (t % (tempo / 4.0)) / (tempo / 4.0)
        bell_env = math.exp(-3.2 * local) * 0.22
        bell = math.sin(2 * math.pi * note_freq * t) * bell_env
        left += bell * 0.9
        right += bell * 1.1

        # Airy noise floor.
        random_state = (1103515245 * random_state + 12345) & 0x7FFFFFFF
        noise = ((random_state / 0x7FFFFFFF) - 0.5) * (0.006 + warmth)

        left = (left * 0.13 + noise) * env * lfo
        right = (right * 0.13 + noise) * env * lfo

        frames += struct.pack("<hh", int(max(-1, min(1, left)) * 32767), int(max(-1, min(1, right)) * 32767))

    with wave.open(path, "wb") as fh:
        fh.setnchannels(2)
        fh.setsampwidth(2)
        fh.setframerate(SAMPLE_RATE)
        fh.writeframes(bytes(frames))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    tracks = [
        ("notchlight", [110.00, 164.81, 207.65, 277.18], [329.63, 415.30, 493.88, 554.37], 4.8, 0.0),
        ("shelf-life", [87.31, 130.81, 174.61, 220.00], [261.63, 349.23, 392.00, 523.25], 3.8, 0.008),
        ("blue-hour", [73.42, 146.83, 174.61, 220.00], [293.66, 349.23, 440.00, 587.33], 6.0, 0.003),
    ]
    for name, chord, sparkle, tempo, warmth in tracks:
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, f"{name}.wav")
            print(f"rendering {name}…")
            render(wav, chord, sparkle, tempo, warmth)
            out = os.path.join(OUT_DIR, f"{name}.m4a")
            subprocess.run(
                ["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "aac", "-b:a", "112k", out],
                check=True,
            )
            print(f"  wrote {out} ({os.path.getsize(out) // 1024} KB)")


if __name__ == "__main__":
    main()
