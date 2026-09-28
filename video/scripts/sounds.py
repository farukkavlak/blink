"""Synthesises the video's sound effects into public/sfx/ (no downloaded assets).

Run: python3 scripts/sounds.py
"""

import wave
from pathlib import Path

import numpy as np

RATE = 48_000
OUT = Path(__file__).resolve().parent.parent / "public" / "sfx"
rng = np.random.default_rng(7)


def seconds(duration: float) -> np.ndarray:
    return np.arange(int(RATE * duration)) / RATE


def lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    """One-pole low-pass filter."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, x in enumerate(signal):
        acc += alpha * (x - acc)
        out[i] = acc
    return out


def highpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    return signal - lowpass(signal, cutoff)


def save(name: str, signal: np.ndarray, peak: float) -> None:
    fade = min(len(signal), int(RATE * 0.004))
    signal = signal.copy()
    signal[:fade] *= np.linspace(0, 1, fade)
    signal[-fade:] *= np.linspace(1, 0, fade)
    signal = signal / (np.max(np.abs(signal)) or 1) * peak
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((signal * 32767).astype(np.int16).tobytes())


def tick() -> np.ndarray:
    """Soft, glassy tick for the blur moving between screens."""
    t = seconds(0.09)
    tone = np.sin(2 * np.pi * 2300 * t) * np.exp(-t * 70) + 0.5 * np.sin(2 * np.pi * 3450 * t) * np.exp(-t * 95)
    click = highpass(rng.standard_normal(len(t)), 3000) * np.exp(-t * 400) * 0.3
    return tone + click


def key(variant: int) -> np.ndarray:
    """A laptop key: short band-limited noise plus a small body thump."""
    t = seconds(0.06)
    noise = lowpass(highpass(rng.standard_normal(len(t)), 1200 + 250 * variant), 6000)
    body = np.sin(2 * np.pi * (160 + 25 * variant) * t) * np.exp(-t * 90) * 0.6
    return noise * np.exp(-t * 160) + body


def whoosh() -> np.ndarray:
    """Airy swell for the camera pushing in."""
    t = seconds(0.55)
    envelope = np.sin(np.pi * np.clip(t / 0.55, 0, 1)) ** 2
    noise = rng.standard_normal(len(t))
    # Sweep the filter upward by blending two low-passed copies.
    low, high = lowpass(noise, 500), lowpass(noise, 2400)
    mix = np.clip(t / 0.55, 0, 1)
    return (low * (1 - mix) + high * mix) * envelope


def lock() -> np.ndarray:
    """Muted two-part thunk, like a lid settling."""
    t = seconds(0.35)
    thump = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 18) + 0.4 * np.sin(2 * np.pi * 220 * t) * np.exp(-t * 30)
    click = lowpass(rng.standard_normal(len(t)), 2500) * np.exp(-t * 250) * 0.5
    second = np.zeros_like(t)
    offset = int(RATE * 0.07)
    second[offset:] = 0.5 * np.sin(2 * np.pi * 150 * t[: len(t) - offset]) * np.exp(-t[: len(t) - offset] * 26)
    return thump + click + second


if __name__ == "__main__":
    save("tick", tick(), 0.35)
    for v in range(3):
        save(f"key{v}", key(v), 0.22)
    save("whoosh", whoosh(), 0.25)
    save("lock", lock(), 0.6)
    print("wrote", sorted(p.name for p in OUT.iterdir()))
