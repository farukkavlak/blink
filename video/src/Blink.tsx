import React from "react";
import { AbsoluteFill, Audio, Easing, Sequence, spring, staticFile, useCurrentFrame } from "remotion";
import { Backdrop, Finish } from "./Backdrop";
import { Desk } from "./Desk";
import { Person } from "./Person";
import { color, font, FPS, keyframes } from "./theme";

// Scene boundaries, in frames at 30 fps. The video opens on the product itself.
const TURN = [0, 300];
const AIRPODS = [300, 420];
const LEARN = [420, 540];
const WALK = [540, 740];
const END = [740, 830];
export const DURATION = END[1];

const LAPTOP = -28; // head yaw (seen from behind) when facing each screen
const MONITOR = 28;
const PERSON = { x: 960, y: 900 };
const EAR = { x: PERSON.x + 70, y: PERSON.y - 40 }; // right ear, where the camera zooms in

/** Quick turns, then complete stillness: contrast reads better than constant motion. */
function headYaw(frame: number) {
  return keyframes(frame, [
    [14, LAPTOP],
    [28, MONITOR],
    [112, MONITOR],
    [126, LAPTOP],
    [196, LAPTOP],
    [210, MONITOR],
    [AIRPODS[0] + 30, MONITOR],
    [AIRPODS[0] + 50, LAPTOP],
    [AIRPODS[0] + 76, MONITOR],
    [WALK[0] + 5, MONITOR],
    [WALK[0] + 22, 70], // turns to walk off to the right
  ]);
}

// The app waits `dwell` after the head passes the midpoint by the hysteresis,
// then fades the blur over 0.3 s. Reproduce that from the head yaw.
const DWELL = Math.round(0.25 * FPS);
const FADE = Math.round(0.3 * FPS);
const HYSTERESIS = 4;

/** Frames at which the blur starts moving, and to which screen (1 = monitor sharp). */
const blurChanges: { frame: number; to: number }[] = (() => {
  const changes: { frame: number; to: number }[] = [];
  let state = 0;
  for (let f = 0; f <= WALK[0]; f++) {
    const yaw = headYaw(f - DWELL);
    const faced = yaw > HYSTERESIS ? 1 : yaw < -HYSTERESIS ? 0 : state;
    if (faced !== state) {
      state = faced;
      changes.push({ frame: f, to: faced });
    }
  }
  return changes;
})();

/** 0 = laptop sharp, 1 = monitor sharp. */
function sharpScreen(frame: number) {
  const last = [...blurChanges].reverse().find((c) => c.frame <= frame);
  if (!last) return 0;
  const progress = Easing.inOut(Easing.cubic)(Math.min(1, (frame - last.frame) / FADE));
  return last.to === 1 ? progress : 1 - progress;
}

function rise(frame: number, start: number, damping = 18) {
  return spring({ frame: frame - start, fps: FPS, config: { damping, mass: 0.8 } });
}

/** A line that comes in word by word (fade, rise, unblur) and leaves faster as a whole. */
function Words({ text, start, end, size, weight = 600, tone = color.ink }: {
  text: string; start: number; end: number; size: number; weight?: number; tone?: string;
}) {
  const frame = useCurrentFrame();
  if (frame < start || frame > end) return null;
  const exit = keyframes(frame, [[end - 7, 1], [end, 0]], Easing.in(Easing.cubic));
  return (
    <div
      style={{
        width: "100%",
        textAlign: "center",
        fontFamily: font,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size > 80 ? -4 : -0.6,
        color: tone,
        opacity: exit,
        transform: `translateY(${(1 - exit) * -10}px)`,
      }}
    >
      {text.split(" ").map((word, i) => {
        const p = rise(frame, start + i * 3);
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              marginRight: "0.26em",
              opacity: p,
              transform: `translateY(${(1 - p) * 22}px)`,
              filter: `blur(${(1 - p) * 6}px)`,
            }}
          >
            {word}
          </span>
        );
      })}
    </div>
  );
}

function Chip({ text, opacity }: { text: string; opacity: number }) {
  return (
    <div
      style={{
        position: "absolute",
        left: PERSON.x + 150,
        top: PERSON.y - 70,
        padding: "8px 16px",
        borderRadius: 999,
        background: color.surface,
        border: `1px solid ${color.line}`,
        boxShadow: "0 6px 16px rgba(31, 35, 40, 0.06)",
        fontFamily: font,
        fontSize: 24,
        color: color.muted,
        fontVariantNumeric: "tabular-nums",
        whiteSpace: "nowrap",
        opacity,
      }}
    >
      {text}
    </div>
  );
}

function Sfx({ at, name, volume = 1 }: { at: number; name: string; volume?: number }) {
  return (
    <Sequence from={Math.max(0, at)} durationInFrames={FPS}>
      <Audio src={staticFile(`sfx/${name}.wav`)} volume={volume} />
    </Sequence>
  );
}

const TYPED = "Blur follows where you look.";
const typingStart = LEARN[0] + 15;
const typingEnd = LEARN[1] - 20;
const typedAt = (frame: number) =>
  Math.round(keyframes(frame, [[typingStart, 0], [typingEnd, TYPED.length]], Easing.linear));
const countdownStart = WALK[0] + 45;
const lockAt = countdownStart + 3 * FPS;
const minus = (n: number) => (n < 0 ? `−${-n}` : `${n}`);

export function Blink() {
  const frame = useCurrentFrame();

  const yaw = headYaw(frame);
  const sharp = sharpScreen(frame);
  const appYaw = Math.round(((Math.max(LAPTOP, Math.min(MONITOR, yaw)) - LAPTOP) / (MONITOR - LAPTOP)) * -40);

  // Camera: settles in at the start, pushes in slowly, drifts toward the faced screen,
  // and zooms onto the ear for the AirPods scene.
  const settle = rise(frame, 0, 26);
  const zoomIn = rise(frame, AIRPODS[0], 26) - rise(frame, AIRPODS[1] - 22, 26);
  const pushIn = keyframes(frame, [[0, 1], [WALK[1], 1.06]], Easing.inOut(Easing.sin));
  const scale = (1.05 - 0.05 * settle) * pushIn * (1 + 1.5 * zoomIn);
  const drift = -(sharp * 2 - 1) * 22 * (1 - zoomIn);
  const originX = 960 + (EAR.x - 960) * zoomIn;
  const originY = 540 + (EAR.y - 540) * zoomIn;
  const stageOpacity = Math.min(settle * 1.5, keyframes(frame, [[WALK[1] - 12, 1], [WALK[1], 0]]));

  // The person walks off to the right with a step bob.
  const walk = keyframes(frame, [[WALK[0] + 22, 0], [WALK[0] + 110, 1]], Easing.in(Easing.quad));
  const bob = walk > 0 && walk < 1 ? Math.abs(Math.sin((frame - WALK[0]) / 3)) * -10 : 0;

  const learned = Math.round(keyframes(frame, [[LEARN[0] + 20, -35], [LEARN[1] - 20, -40]]));
  const secondsLeft = 3 - Math.floor((frame - countdownStart) / FPS);
  const hud = frame >= countdownStart && secondsLeft > 0 ? `Walked away, locking in ${secondsLeft} s\nMove the mouse to cancel` : undefined;
  const locked = keyframes(frame, [[lockAt, 0], [lockAt + 10, 1]]);

  const chip = frame >= LEARN[0] && frame < LEARN[1] ? `monitor learned at ${minus(learned)}°` : `yaw ${minus(appYaw)}°`;
  const chipOpacity =
    keyframes(frame, [[40, 0], [52, 1], [WALK[0], 1], [WALK[0] + 8, 0]]) * (1 - zoomIn);

  const keyFrames: number[] = [];
  for (let f = typingStart; f <= typingEnd; f++) if (typedAt(f) > typedAt(f - 1)) keyFrames.push(f);

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      <Backdrop />

      <AbsoluteFill
        style={{
          opacity: stageOpacity,
          transform: `translateX(${drift}px) scale(${scale})`,
          transformOrigin: `${originX}px ${originY}px`,
        }}
      >
        {/* The desk steps back while the camera is on the AirPods, so the caption stays readable. */}
        <div style={{ opacity: 1 - 0.88 * zoomIn }}>
          <Desk laptopBlur={16 * sharp} monitorBlur={16 * (1 - sharp)} locked={locked} typed={TYPED.slice(0, typedAt(frame))} hud={hud} />
        </div>
        <Person yaw={yaw} x={PERSON.x + walk * 1250} y={PERSON.y + bob} podsHighlight={zoomIn} />
        <Chip text={chip} opacity={chipOpacity} />
      </AbsoluteFill>

      {/* Live yaw readout while the camera is on the AirPods */}
      <div
        style={{
          position: "absolute", right: 170, top: 470, fontFamily: font, fontSize: 76, fontWeight: 600,
          color: color.ink, fontVariantNumeric: "tabular-nums",
          opacity: keyframes(frame, [[AIRPODS[0] + 20, 0], [AIRPODS[0] + 32, 1], [AIRPODS[1] - 24, 1], [AIRPODS[1] - 16, 0]]),
        }}
      >
        <div style={{ fontSize: 26, fontWeight: 500, color: color.muted, marginBottom: 4 }}>head yaw</div>
        {minus(appYaw)}°
      </div>

      <div style={{ position: "absolute", top: 100, width: "100%" }}>
        <Words text="Blur the screen you're not looking at." start={6} end={150} size={56} />
        <Words text="Just turn your head." start={156} end={AIRPODS[0]} size={56} />
        <Words text="No camera. Just the AirPods you're wearing." start={AIRPODS[0] + 8} end={AIRPODS[1]} size={56} />
        <Words text="It learns your desk from what you type." start={LEARN[0] + 4} end={LEARN[1]} size={56} />
        <Words text="Walk away, and it locks." start={WALK[0] + 4} end={WALK[1] - 4} size={56} />
      </div>

      <AbsoluteFill style={{ justifyContent: "center", gap: 10 }}>
        <Words text="Blink" start={END[0] + 4} end={END[1] + 30} size={150} weight={700} />
        <Words text="github.com/farukkavlak/blink" start={END[0] + 12} end={END[1] + 30} size={42} weight={500} tone={color.accent} />
        <Words text="macOS 14+ · AirPods head tracking · MIT" start={END[0] + 20} end={END[1] + 30} size={26} weight={400} tone={color.faint} />
      </AbsoluteFill>

      <Finish />

      {/* Sound: each cue starts ~2 frames before its visual, which reads as in sync. */}
      {blurChanges.map((c) => <Sfx key={c.frame} at={c.frame - 2} name="tick" />)}
      <Sfx at={AIRPODS[0] - 4} name="whoosh" />
      <Sfx at={AIRPODS[1] - 26} name="whoosh" volume={0.7} />
      {keyFrames.map((f, i) => <Sfx key={f} at={f - 1} name={`key${i % 3}`} volume={0.8 + 0.2 * ((i * 7) % 3) / 2} />)}
      <Sfx at={countdownStart - 2} name="tick" volume={0.7} />
      <Sfx at={lockAt - 2} name="lock" />
      <Sfx at={END[0] + 2} name="tick" volume={0.8} />
    </AbsoluteFill>
  );
}
