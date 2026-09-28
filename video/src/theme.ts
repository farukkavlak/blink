import { Easing, interpolate } from "remotion";

// Same palette as docs/how-it-works.svg.
export const color = {
  background: "#f6f8fa",
  surface: "#ffffff",
  ink: "#1f2328",
  muted: "#57606a",
  faint: "#8c959f",
  line: "#d0d7de",
  accent: "#0969da",
};

export const font = `-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", Arial, sans-serif`;

export const FPS = 30;

/** Piecewise interpolation through [frame, value] keyframes, eased between each pair. */
export function keyframes(frame: number, points: [number, number][], easing = Easing.inOut(Easing.cubic)) {
  return interpolate(
    frame,
    points.map(([f]) => f),
    points.map(([, v]) => v),
    { easing, extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
}

/** 0 → 1 → 0 opacity for something visible from `start` to `end`. */
export function fadeInOut(frame: number, start: number, end: number, fade = 10) {
  return keyframes(frame, [
    [start, 0],
    [start + fade, 1],
    [end - fade, 1],
    [end, 0],
  ]);
}
