import math
import wave
import struct
import numpy as np

SAMPLE_RATE = 44100
BPM = 120.0
BEAT_DUR = 60.0 / BPM  # 0.500 s
TOTAL_BEATS = 28
TOTAL_DURATION = TOTAL_BEATS * BEAT_DUR  # 14.0 s
TOTAL_SAMPLES = int(SAMPLE_RATE * TOTAL_DURATION)

t_axis = np.linspace(0, TOTAL_DURATION, TOTAL_SAMPLES, endpoint=False)
audio_left = np.zeros(TOTAL_SAMPLES, dtype=np.float64)
audio_right = np.zeros(TOTAL_SAMPLES, dtype=np.float64)

def add_tone(start_t, dur, freq, amp=0.5, decay=8.0, pan=0.0):
    start_idx = int(start_t * SAMPLE_RATE)
    num_samples = int(dur * SAMPLE_RATE)
    if start_idx >= TOTAL_SAMPLES:
        return
    end_idx = min(TOTAL_SAMPLES, start_idx + num_samples)
    actual_samples = end_idx - start_idx
    local_t = np.linspace(0, actual_samples / SAMPLE_RATE, actual_samples, endpoint=False)
    
    # Sine with exponential envelope
    env = np.exp(-decay * local_t)
    wave = np.sin(2 * np.pi * freq * local_t) * env * amp
    
    left_gain = math.sqrt(0.5 * (1.0 - pan))
    right_gain = math.sqrt(0.5 * (1.0 + pan))
    
    audio_left[start_idx:end_idx] += wave * left_gain
    audio_right[start_idx:end_idx] += wave * right_gain

def add_kick(start_t, amp=0.75):
    start_idx = int(start_t * SAMPLE_RATE)
    dur = 0.28
    num_samples = int(dur * SAMPLE_RATE)
    if start_idx >= TOTAL_SAMPLES:
        return
    end_idx = min(TOTAL_SAMPLES, start_idx + num_samples)
    actual_samples = end_idx - start_idx
    local_t = np.linspace(0, actual_samples / SAMPLE_RATE, actual_samples, endpoint=False)
    
    # Pitch drop 150 Hz -> 45 Hz
    freq = 45.0 + 105.0 * np.exp(-32.0 * local_t)
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    env = np.exp(-9.0 * local_t)
    wave = np.sin(phase) * env * amp
    # Sub bass presence
    wave += 0.3 * np.sin(2 * np.pi * 50.0 * local_t) * np.exp(-6.0 * local_t)
    
    audio_left[start_idx:end_idx] += wave * 0.707
    audio_right[start_idx:end_idx] += wave * 0.707

def add_hihat(start_t, amp=0.18):
    start_idx = int(start_t * SAMPLE_RATE)
    dur = 0.05
    num_samples = int(dur * SAMPLE_RATE)
    if start_idx >= TOTAL_SAMPLES:
        return
    end_idx = min(TOTAL_SAMPLES, start_idx + num_samples)
    actual_samples = end_idx - start_idx
    local_t = np.linspace(0, actual_samples / SAMPLE_RATE, actual_samples, endpoint=False)
    
    noise = np.random.uniform(-1.0, 1.0, actual_samples)
    env = np.exp(-55.0 * local_t)
    wave = noise * env * amp
    
    audio_left[start_idx:end_idx] += wave * 0.65
    audio_right[start_idx:end_idx] += wave * 0.75

def add_ui_click(start_t, pitch=2200.0, amp=0.45):
    start_idx = int(start_t * SAMPLE_RATE)
    dur = 0.02
    num_samples = int(dur * SAMPLE_RATE)
    if start_idx >= TOTAL_SAMPLES:
        return
    end_idx = min(TOTAL_SAMPLES, start_idx + num_samples)
    actual_samples = end_idx - start_idx
    local_t = np.linspace(0, actual_samples / SAMPLE_RATE, actual_samples, endpoint=False)
    
    env = np.exp(-140.0 * local_t)
    # High frequency transient burst
    click = (np.sin(2 * np.pi * pitch * local_t) + 0.4 * np.sin(2 * np.pi * (pitch * 1.6) * local_t)) * env * amp
    
    audio_left[start_idx:end_idx] += click * 0.707
    audio_right[start_idx:end_idx] += click * 0.707

# 1. Generate 120 BPM minimal groove
for beat in range(TOTAL_BEATS):
    t = beat * BEAT_DUR
    bar_beat = beat % 4
    
    # Kick on beat 0 and 2
    if bar_beat == 0:
        add_kick(t, amp=0.82)
    elif bar_beat == 2:
        add_kick(t, amp=0.68)
        
    # Rim/Snare on beat 1 and 3
    if bar_beat == 1 or bar_beat == 3:
        add_tone(t, 0.08, 380.0, amp=0.25, decay=35.0, pan=-0.1)
        add_tone(t, 0.06, 850.0, amp=0.18, decay=50.0, pan=0.1)
        
    # Hi-hat on every 8th note (t and t + 0.25)
    add_hihat(t + 0.25, amp=0.15)
    if bar_beat != 0:
        add_hihat(t, amp=0.10)

    # Ambient deep chords (pentatonic groove: F# min / A maj)
    chord_root = 138.59 if (beat // 4) % 2 == 0 else 110.0
    if bar_beat == 0:
        add_tone(t, 1.8, chord_root, amp=0.20, decay=2.2, pan=-0.3)
        add_tone(t, 1.8, chord_root * 1.5, amp=0.15, decay=2.0, pan=0.3)
        add_tone(t, 1.8, chord_root * 2.0, amp=0.12, decay=2.5, pan=0.0)

# 2. Synchronized UI Transients exactly on the motion choreography
ui_events = [
    (0.00, 2400, 0.50),  # Beat 1: Button press down
    (0.50, 1800, 0.35),  # Beat 2: Morph to loader
    (1.00, 3200, 0.60),  # Beat 3: Check snap
    (1.50, 1200, 0.40),  # Beat 4: Dynamic Island expand
    (2.00, 1400, 0.40),  # Beat 5: Music player unfold
    (2.50, 2600, 0.55),  # Beat 6: Play -> Pause toggle
    (3.00, 1900, 0.45),  # Beat 7: Scrubber grab
    (3.40, 2100, 0.45),  # Beat 8: Scrubber release
    (4.00, 1500, 0.40),  # Beat 9: Volume slider appear
    (4.50, 2800, 0.50),  # Beat 10: Rubber-band max stretch
    (4.90, 1600, 0.40),  # Beat 11: Release & spring recoil
    (5.50, 1300, 0.35),  # Beat 12: Morph to toggle
    (6.00, 2200, 0.60),  # Beat 13: Toggle flip snap
    (6.50, 1500, 0.40),  # Beat 14: Tabs unfold
    (7.00, 2000, 0.50),  # Beat 15: Tab 2 click glide
    (7.50, 2400, 0.50),  # Beat 16: Tab 3 click glide
    (8.00, 1100, 0.40),  # Beat 17: Chart card open
    (8.50, 1700, 0.35),  # Beat 18: Chart spline draw
    (9.00, 3400, 0.55),  # Beat 19: Tooltip hover pop
    (9.50, 1600, 0.30),  # Beat 20: Tooltip exit
    (10.00, 1400, 0.45), # Beat 21: Command palette collapse
    (10.50, 2800, 0.30), # Beat 22: Type 'e'
    (10.60, 2900, 0.30), # Type 'x'
    (10.70, 2850, 0.30), # Type 'p'
    (10.80, 2950, 0.30), # Type 'o'
    (11.00, 2200, 0.40), # Beat 23: Row highlight
    (11.50, 3600, 0.65), # Beat 24: Enter key mechanical click
    (12.00, 4200, 0.70), # Beat 25: Toast alert chime
    (13.00, 1600, 0.35), # Beat 27: Morph back to button
    (13.80, 2000, 0.25), # Beat 28: Settle to rest
]

for event in ui_events:
    t_ev, pitch, amp = event
    add_ui_click(t_ev, pitch=pitch, amp=amp)

# Normalize audio to prevent any digital clipping
max_peak = max(np.max(np.abs(audio_left)), np.max(np.abs(audio_right)))
if max_peak > 0.001:
    gain = 0.88 / max_peak
    audio_left *= gain
    audio_right *= gain

# Interleave stereo 16-bit PCM
pcm_left = (audio_left * 32767.0).clip(-32767, 32767).astype(np.int16)
pcm_right = (audio_right * 32767.0).clip(-32767, 32767).astype(np.int16)
stereo_pcm = np.empty((TOTAL_SAMPLES * 2,), dtype=np.int16)
stereo_pcm[0::2] = pcm_left
stereo_pcm[1::2] = pcm_right

out_wav_path = "/Users/sivasoft/Downloads/temp/lynk/motion/track_120bpm.wav"
with wave.open(out_wav_path, "wb") as wf:
    wf.setnchannels(2)
    wf.setsampwidth(2)
    wf.setframerate(SAMPLE_RATE)
    wf.writeframes(stereo_pcm.tobytes())

print(f"Generated 120 BPM audio track: {out_wav_path} ({TOTAL_DURATION}s, {TOTAL_SAMPLES} samples)")
