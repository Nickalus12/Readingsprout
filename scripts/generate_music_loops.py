#!/usr/bin/env python3
"""Generate ambient music loops for Reading Sprout zones.

Uses only Python standard library (wave, struct, math) to create simple
WAV files with sine-wave-based ambient pads, melodies, and stingers.

Usage:
    python scripts/generate_music_loops.py

Output:
    assets/audio/music/*.wav
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 22050  # Lower quality is fine for ambient loops
CHANNELS = 1


def sine_wave(freq, duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate a sine wave with fade-in/fade-out envelope."""
    samples = []
    num_samples = int(sample_rate * duration)
    for i in range(num_samples):
        t = i / sample_rate
        # Smooth fade in/out to prevent clicks (50ms ramp)
        fade_in = min(t * 20, 1.0)
        fade_out = min((duration - t) * 20, 1.0)
        env = fade_in * fade_out
        samples.append(volume * env * math.sin(2 * math.pi * freq * t))
    return samples


def triangle_wave(freq, duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate a softer triangle wave."""
    samples = []
    num_samples = int(sample_rate * duration)
    period = sample_rate / freq
    for i in range(num_samples):
        t = i / sample_rate
        fade_in = min(t * 20, 1.0)
        fade_out = min((duration - t) * 20, 1.0)
        env = fade_in * fade_out
        # Triangle wave from sawtooth
        phase = (i % period) / period
        val = abs(4 * phase - 2) - 1
        samples.append(volume * env * val)
    return samples


def mix(tracks):
    """Mix multiple tracks together, normalizing to prevent clipping."""
    if not tracks:
        return [0.0]
    length = max(len(t) for t in tracks)
    mixed = [0.0] * length
    for track in tracks:
        for i, s in enumerate(track):
            mixed[i] += s
    peak = max(abs(s) for s in mixed) or 1.0
    return [s / peak * 0.7 for s in mixed]


def save_wav(filename, samples, sample_rate=SAMPLE_RATE):
    """Save samples as a 16-bit mono WAV file."""
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as f:
        f.setnchannels(CHANNELS)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            f.writeframes(struct.pack('<h', int(clamped * 32767)))
    size_kb = os.path.getsize(filename) / 1024
    print(f'  -> {filename} ({size_kb:.1f} KB)')


# ── Zone definitions ──────────────────────────────────────────────────
# Each zone has chord progressions, a pentatonic melody scale, and a tempo.
# Chords are tuples of frequencies (Hz) forming triads.

ZONES = {
    'woods': {  # Whispering Woods — gentle, nature-y, calming
        'chords': [
            (261.6, 329.6, 392.0),   # C major
            (220.0, 277.2, 329.6),   # A minor
            (246.9, 311.1, 370.0),   # B diminished (gentle)
            (261.6, 329.6, 392.0),   # C major (resolve)
        ],
        'scale': [261.6, 293.7, 329.6, 392.0, 440.0],  # C pentatonic
        'tempo': 0.6,
        'pad_volume': 0.18,
        'melody_volume': 0.22,
    },
    'shore': {  # Shimmer Shore — flowing, watery, bright
        'chords': [
            (349.2, 440.0, 523.3),   # F major
            (392.0, 493.9, 587.3),   # G major
            (329.6, 415.3, 493.9),   # E minor
            (349.2, 440.0, 523.3),   # F major (resolve)
        ],
        'scale': [349.2, 392.0, 440.0, 523.3, 587.3],  # F pentatonic
        'tempo': 0.55,
        'pad_volume': 0.17,
        'melody_volume': 0.20,
    },
    'peaks': {  # Crystal Peaks — sparkly, bright, crystalline
        'chords': [
            (523.3, 659.3, 784.0),   # C5 major
            (440.0, 554.4, 659.3),   # A major
            (493.9, 622.3, 740.0),   # B major
            (523.3, 659.3, 784.0),   # C5 major (resolve)
        ],
        'scale': [523.3, 587.3, 659.3, 784.0, 880.0],  # C5 pentatonic
        'tempo': 0.45,
        'pad_volume': 0.15,
        'melody_volume': 0.20,
    },
    'sky': {  # Skyward Kingdom — majestic, uplifting, soaring
        'chords': [
            (392.0, 493.9, 587.3),   # G major
            (440.0, 554.4, 659.3),   # A major
            (349.2, 440.0, 523.3),   # F major
            (392.0, 493.9, 587.3),   # G major (resolve)
        ],
        'scale': [392.0, 440.0, 493.9, 587.3, 659.3],  # G pentatonic
        'tempo': 0.5,
        'pad_volume': 0.16,
        'melody_volume': 0.22,
    },
    'crown': {  # Celestial Crown — ethereal, magical, shimmery
        'chords': [
            (523.3, 659.3, 784.0),   # C5 major
            (587.3, 740.0, 880.0),   # D5 major
            (493.9, 622.3, 740.0),   # B major
            (523.3, 659.3, 784.0),   # C5 major (resolve)
        ],
        'scale': [523.3, 622.3, 740.0, 784.0, 932.3],  # Ethereal scale
        'tempo': 0.4,
        'pad_volume': 0.14,
        'melody_volume': 0.18,
    },
}


def generate_pad(zone_name, zone, duration=8.0):
    """Generate a lush ambient pad loop with detuned sine waves."""
    tracks = []
    num_chords = len(zone['chords'])
    chord_dur = duration / num_chords

    for ci, chord in enumerate(zone['chords']):
        for freq in chord:
            vol = zone.get('pad_volume', 0.18)
            # Main tone
            t1 = sine_wave(freq, chord_dur, volume=vol)
            # Slightly detuned copy for richness (chorus effect)
            t2 = sine_wave(freq * 1.004, chord_dur, volume=vol * 0.7)
            # Sub-octave for warmth (quieter)
            t3 = sine_wave(freq * 0.5, chord_dur, volume=vol * 0.3)

            offset = [0.0] * int(ci * chord_dur * SAMPLE_RATE)
            tracks.append(offset + t1)
            tracks.append(offset + t2)
            tracks.append(offset + t3)

    return mix(tracks)


def generate_melody(zone_name, zone, duration=4.0):
    """Generate a simple pentatonic melody loop."""
    import random
    random.seed(hash(zone_name) % (2**31))  # deterministic per zone

    tracks = []
    note_dur = zone['tempo']
    vol = zone.get('melody_volume', 0.22)
    time_pos = 0.0

    # Create a gentle melodic pattern (not random — use a simple contour)
    scale = zone['scale']
    # Build a melodic contour: up, up, down, rest, up, down, down, rest
    pattern_indices = [0, 1, 2, 4, 3, 2, 1, 0]
    random.shuffle(pattern_indices)  # deterministic shuffle per zone

    i = 0
    while time_pos < duration - 0.1:
        idx = pattern_indices[i % len(pattern_indices)]
        freq = scale[idx % len(scale)]

        # Alternate between sine and triangle for variety
        if i % 3 == 0:
            note = triangle_wave(freq, note_dur * 0.75, volume=vol)
        else:
            note = sine_wave(freq, note_dur * 0.75, volume=vol)

        offset = [0.0] * int(time_pos * SAMPLE_RATE)
        tracks.append(offset + note)
        time_pos += note_dur
        i += 1

    return mix(tracks) if tracks else [0.0] * int(duration * SAMPLE_RATE)


def generate_stinger(name, freqs, duration=0.5):
    """Generate a short stinger (chime) sound effect."""
    tracks = []
    num_notes = len(freqs)
    for i, freq in enumerate(freqs):
        delay = i * 0.07  # slight arpeggio
        note_dur = duration - delay
        if note_dur <= 0:
            continue
        note = sine_wave(freq, note_dur, volume=0.3)
        # Add a quieter octave-up shimmer
        shimmer = sine_wave(freq * 2, note_dur * 0.5, volume=0.1)
        offset = [0.0] * int(delay * SAMPLE_RATE)
        tracks.append(offset + note)
        tracks.append(offset + shimmer)
    return mix(tracks)


def generate_percussion(style, duration=4.0):
    """Generate a gentle rhythmic pattern using short noise-like tones."""
    tracks = []

    if style == 'gentle':
        # Soft taps — very high frequency short bursts (like rain)
        beat_interval = 0.5
        time_pos = 0.0
        while time_pos < duration:
            tap = sine_wave(800, 0.03, volume=0.15)
            offset = [0.0] * int(time_pos * SAMPLE_RATE)
            tracks.append(offset + tap)
            time_pos += beat_interval
    elif style == 'medium':
        # Light pulse
        beat_interval = 0.25
        time_pos = 0.0
        beat = 0
        while time_pos < duration:
            vol = 0.18 if beat % 4 == 0 else 0.10
            tap = sine_wave(600, 0.04, volume=vol)
            offset = [0.0] * int(time_pos * SAMPLE_RATE)
            tracks.append(offset + tap)
            time_pos += beat_interval
            beat += 1
    else:  # energetic
        beat_interval = 0.2
        time_pos = 0.0
        beat = 0
        while time_pos < duration:
            vol = 0.20 if beat % 4 == 0 else 0.12
            freq = 700 if beat % 2 == 0 else 900
            tap = sine_wave(freq, 0.05, volume=vol)
            offset = [0.0] * int(time_pos * SAMPLE_RATE)
            tracks.append(offset + tap)
            time_pos += beat_interval
            beat += 1

    return mix(tracks) if tracks else [0.0] * int(duration * SAMPLE_RATE)


def main():
    out_dir = 'assets/audio/music'
    os.makedirs(out_dir, exist_ok=True)

    # ── Zone pad and melody loops ──────────────────────────────────
    for name, zone in ZONES.items():
        print(f'Generating {name} pad (8s loop)...')
        save_wav(f'{out_dir}/{name}_pad.wav', generate_pad(name, zone, duration=8.0))

        print(f'Generating {name} melody (4s loop)...')
        save_wav(f'{out_dir}/{name}_melody.wav', generate_melody(name, zone, duration=4.0))

    # ── Percussion patterns ────────────────────────────────────────
    for style in ['gentle', 'medium', 'energetic']:
        print(f'Generating {style} percussion (4s loop)...')
        save_wav(f'{out_dir}/perc_{style}.wav', generate_percussion(style, duration=4.0))

    # ── Stingers ───────────────────────────────────────────────────
    print('Generating correct answer chime...')
    save_wav(f'{out_dir}/correct_chime.wav',
             generate_stinger('correct', [523.3, 659.3, 784.0], duration=0.5))

    print('Generating streak chime...')
    save_wav(f'{out_dir}/streak_chime.wav',
             generate_stinger('streak', [523.3, 659.3, 784.0, 1046.5], duration=0.8))

    print('Generating combo chime...')
    save_wav(f'{out_dir}/combo_chime.wav',
             generate_stinger('combo', [440.0, 554.4, 659.3, 880.0], duration=0.6))

    print('\nDone! Generated all music loops and stingers.')


if __name__ == '__main__':
    main()
