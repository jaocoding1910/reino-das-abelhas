"""
Gera os sons do Reino das Abelhas (WAV 44,1 kHz mono), 100% sintetizados aqui:
nenhum áudio de terceiros. Uso:  python sons.py ..
Saída: Asas, Coleta, Entrega, Nivel, Dano, Clique, AmbienteDia, AmbienteNoite (.wav)
"""
import math
import os
import sys
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(2026)


def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack, release, curve=4.0):
    """Envelope: subida linear e queda exponencial."""
    e = np.ones(n)
    a = max(1, int(attack * SR))
    e[:a] = np.linspace(0, 1, a)
    r = min(n - a, max(1, int(release * SR)))
    e[n - r:] *= np.exp(-curve * np.linspace(0, 1, r))
    return e


def lowpass(x, cutoff):
    alpha = 1 - math.exp(-2 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def reverb(x, mix=0.25, decay=0.5):
    """Reverb simples (Schroeder): pentes em paralelo + passa-tudo."""
    out = np.zeros(len(x) + SR)
    padded = np.concatenate([x, np.zeros(SR)])
    for delay_ms, g in [(29.7, decay), (37.1, decay * 0.95), (41.1, decay * 0.9), (43.7, decay * 0.85)]:
        d = int(delay_ms * SR / 1000)
        y = padded.copy()
        for i in range(d, len(y)):
            y[i] += g * y[i - d]
        out += y * 0.25
    for delay_ms in (5.0, 1.7):
        d = int(delay_ms * SR / 1000)
        y = np.zeros_like(out)
        for i in range(len(out)):
            xd = out[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -0.7 * out[i] + xd + 0.7 * yd
        out = y
    dry = np.concatenate([x, np.zeros(SR)])
    return dry * (1 - mix) + out * mix


def note(freq):
    return freq


def bell(freq, seconds, partials=((1, 1.0), (2.76, 0.4), (5.4, 0.2), (8.93, 0.08))):
    t = t_axis(seconds)
    y = np.zeros_like(t)
    for ratio, amp in partials:
        y += amp * np.sin(2 * math.pi * freq * ratio * t) * np.exp(-t * (3 + ratio * 1.5))
    return y * env(len(t), 0.004, seconds * 0.3, 2)


def marimba(freq, seconds):
    t = t_axis(seconds)
    y = np.sin(2 * math.pi * freq * t) * np.exp(-t * 6)
    y += 0.35 * np.sin(2 * math.pi * freq * 4 * t) * np.exp(-t * 22)
    y += 0.15 * np.sin(2 * math.pi * freq * 9.2 * t) * np.exp(-t * 40)
    return y * env(len(t), 0.002, 0.05)


def place(buffer, sound, at_seconds, gain=1.0):
    i = int(at_seconds * SR)
    end = min(len(buffer), i + len(sound))
    buffer[i:end] += sound[: end - i] * gain


def normalize(x, peak_db=-1.0):
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * (10 ** (peak_db / 20))


def loopable(full, loop_seconds):
    """Dobra a cauda sobre o começo: o som repete sem emenda."""
    n = int(loop_seconds * SR)
    out = full[:n].copy()
    tail = full[n:]
    out[: len(tail)] += tail[:n]
    return out


def write(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ sons

def asas():
    # Zumbido em loop de 2 s: fundamental 180 Hz (360 ciclos = emenda perfeita),
    # vibrato de 6 Hz (12 ciclos) e harmônicos de "serra" suavizados.
    seconds = 2.0
    t = t_axis(seconds * 3)
    vib = 3.0 * np.sin(2 * math.pi * 6 * t)
    phase = 2 * math.pi * np.cumsum(180 + vib) / SR
    y = np.zeros_like(t)
    for n in range(1, 18):
        y += np.sin(n * phase) / (n ** 1.15)
    y *= 0.85 + 0.15 * np.sin(2 * math.pi * 3 * t)  # leve "batida" de asa
    y = lowpass(y, 1900)
    n = int(seconds * SR)
    return normalize(y[n: 2 * n], -6)  # pega o ciclo do meio (filtro já estável)


def coleta():
    t = t_axis(0.18)
    freq = 520 + 520 * (t / t[-1]) ** 0.6
    blip = np.sin(2 * math.pi * np.cumsum(freq) / SR) * env(len(t), 0.003, 0.12, 5)
    out = np.zeros(int(0.5 * SR))
    place(out, blip, 0)
    place(out, bell(1568, 0.35) * 0.5, 0.07)
    return normalize(reverb(out, 0.18)[: int(0.7 * SR)], -2)


def entrega():
    out = np.zeros(int(1.2 * SR))
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        place(out, marimba(f, 0.9), i * 0.085, 1.0 - i * 0.1)
    return normalize(reverb(out, 0.25)[: int(1.5 * SR)], -2)


def nivel():
    out = np.zeros(int(2.2 * SR))
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5, 1318.5)):
        place(out, bell(f, 1.6), i * 0.11, 0.9)
    # acorde final com brilho
    for f in (523.25, 659.25, 783.99, 1046.5):
        place(out, bell(f, 1.6) * 0.5, 0.62)
    t = t_axis(1.2)
    shimmer = RNG.normal(0, 1, len(t)) * np.exp(-t * 3) * 0.05
    place(out, lowpass(shimmer, 6000), 0.6)
    return normalize(reverb(out, 0.3)[: int(2.6 * SR)], -1.5)


def dano():
    t = t_axis(0.4)
    freq = 140 * np.exp(-t * 4) + 55
    thump = np.sin(2 * math.pi * np.cumsum(freq) / SR) * env(len(t), 0.002, 0.3, 4)
    noise = lowpass(RNG.normal(0, 1, len(t)), 900) * env(len(t), 0.001, 0.25, 7) * 0.8
    return normalize(thump + noise, -2)


def clique():
    t = t_axis(0.07)
    y = np.sin(2 * math.pi * 1800 * t) * np.exp(-t * 90)
    y += 0.4 * np.sin(2 * math.pi * 3200 * t) * np.exp(-t * 140)
    return normalize(y, -4)


def pad(freqs, seconds):
    t = t_axis(seconds)
    y = np.zeros_like(t)
    for f in freqs:
        for detune in (-0.6, 0.6):
            ph = 2 * math.pi * (f + detune) * t
            y += np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
    y /= len(freqs) * 2
    return lowpass(y, 1400) * env(len(t), 1.2, 2.0, 3)


def chirp_bird(seconds=0.25):
    t = t_axis(seconds)
    f = 2600 + 1400 * np.sin(2 * math.pi * 9 * t) + 900 * (t / seconds)
    y = np.sin(2 * math.pi * np.cumsum(f) / SR)
    return y * env(len(t), 0.01, seconds * 0.6, 3) * np.sin(np.pi * t / seconds)


def ambiente_dia():
    # Música leve em loop de 24 s: 4 acordes de 6 s + marimba pentatônica + passarinhos.
    loop = 24.0
    out = np.zeros(int((loop + 4) * SR))
    chords = [
        (261.63, 329.63, 392.0, 493.88),  # Cmaj7
        (220.0, 261.63, 329.63, 392.0),  # Am7
        (174.61, 220.0, 261.63, 329.63),  # Fmaj7
        (196.0, 246.94, 293.66, 329.63),  # G6
    ]
    for i, chord in enumerate(chords):
        place(out, pad(chord, 7.5), i * 6.0, 0.55)
    scale = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
    beat = 60 / 96
    step = 0
    time = 0.0
    while time < loop - 0.1:
        if RNG.random() < 0.62:
            f = scale[(step * 2 + RNG.integers(0, 3)) % len(scale)]
            place(out, marimba(f, 0.8), time, 0.32 if step % 2 == 0 else 0.22)
        time += beat / 2
        step += 1
    for _ in range(9):
        place(out, chirp_bird(RNG.uniform(0.15, 0.3)), RNG.uniform(0, loop - 1), 0.07)
    out = reverb(out, 0.3, 0.55)
    return normalize(loopable(out, loop), -4)


def ambiente_noite():
    # Grilos + um acorde grave bem baixinho, loop de 16 s.
    loop = 16.0
    out = np.zeros(int((loop + 3) * SR))
    place(out, pad((110.0, 164.81, 220.0, 261.63), 18.0), 0, 0.35)
    for cricket in range(4):
        carrier = RNG.uniform(4200, 5200)
        period = RNG.uniform(0.55, 0.9)
        offset = RNG.uniform(0, period)
        gain = RNG.uniform(0.05, 0.12)
        time = offset
        while time < loop:
            for k in range(3):
                t = t_axis(0.025)
                pulse = np.sin(2 * math.pi * carrier * t) * np.sin(np.pi * t / t[-1])
                place(out, pulse, time + k * 0.045, gain)
            time += period
    return normalize(loopable(reverb(out, 0.2, 0.4), loop), -6)


SOUNDS = {
    "Asas": asas,
    "Coleta": coleta,
    "Entrega": entrega,
    "Nivel": nivel,
    "Dano": dano,
    "Clique": clique,
    "AmbienteDia": ambiente_dia,
    "AmbienteNoite": ambiente_noite,
}

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in SOUNDS.items():
        audio = fn()
        path = os.path.join(out_dir, f"{name}.wav")
        write(path, audio)
        print(f"{name:14s} {len(audio) / SR:5.2f} s  {os.path.getsize(path) / 1024:7.0f} KB")
