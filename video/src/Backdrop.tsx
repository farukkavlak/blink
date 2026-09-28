import React from "react";
import { AbsoluteFill, getInputProps, useCurrentFrame } from "remotion";
import { color } from "./theme";

/**
 * Rendering for the README GIF (`--props='{"forGif":true}'`): GIF compression collapses
 * when every pixel changes each frame, so the drift and grain are turned off there.
 */
const forGif = Boolean(getInputProps().forGif);

/** Background: base color with two very soft, slowly drifting light pools. */
export function Backdrop() {
  const frame = forGif ? 0 : useCurrentFrame();
  const drift1 = Math.sin(frame / 60) * 40;
  const drift2 = Math.cos(frame / 75) * 35;
  return (
    <AbsoluteFill style={{ background: color.background }}>
      <div
        style={{
          position: "absolute", width: 1300, height: 1300, borderRadius: "50%",
          top: -620, left: -260 + drift1, filter: "blur(60px)",
          background: "radial-gradient(circle, rgba(9, 105, 218, 0.07), transparent 62%)",
        }}
      />
      <div
        style={{
          position: "absolute", width: 1100, height: 1100, borderRadius: "50%",
          bottom: -560, right: -220 - drift2, filter: "blur(70px)",
          background: "radial-gradient(circle, rgba(191, 135, 0, 0.05), transparent 65%)",
        }}
      />
    </AbsoluteFill>
  );
}

/** Topmost finishing layer: a faint vignette and moving film grain. */
export function Finish() {
  const frame = useCurrentFrame();
  const noise = `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='220' height='220'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3C/filter%3E%3Crect width='220' height='220' filter='url(%23n)' opacity='0.5'/%3E%3C/svg%3E")`;
  return (
    <>
      <AbsoluteFill
        style={{
          pointerEvents: "none",
          background: "radial-gradient(ellipse at center, transparent 60%, rgba(31, 35, 40, 0.07) 100%)",
        }}
      />
      {!forGif && <AbsoluteFill
        style={{
          pointerEvents: "none",
          backgroundImage: noise,
          backgroundSize: "220px",
          backgroundPosition: `${(frame * 7) % 220}px ${(frame * 13) % 220}px`,
          opacity: 0.035,
          mixBlendMode: "multiply",
        }}
      />}
    </>
  );
}
