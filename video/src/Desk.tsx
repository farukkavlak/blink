import React from "react";
import { color, font } from "./theme";

type ScreenProps = {
  width: number;
  height: number;
  /** Gaussian blur radius in px, as the app applies to screens you don't face. */
  blur: number;
  /** 0 = unlocked, 1 = lock screen. */
  locked: number;
  children: React.ReactNode;
  overlay?: React.ReactNode;
};

function Screen({ width, height, blur, locked, children, overlay }: ScreenProps) {
  return (
    <div
      style={{
        width,
        height,
        borderRadius: 14,
        background: color.ink,
        padding: 12,
        boxShadow: "0 18px 40px rgba(31, 35, 40, 0.12)",
      }}
    >
      <div
        style={{
          position: "relative",
          width: "100%",
          height: "100%",
          borderRadius: 6,
          overflow: "hidden",
          background: color.surface,
        }}
      >
        <div style={{ position: "absolute", inset: 0, filter: `blur(${blur}px)`, transform: "scale(1.02)" }}>
          {children}
        </div>
        {overlay}
        <LockScreen opacity={locked} />
      </div>
    </div>
  );
}

function LockScreen({ opacity }: { opacity: number }) {
  if (opacity <= 0) return null;
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: "#24292f",
        opacity,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <svg width="54" height="66" viewBox="0 0 54 66">
        <path d="M13 28 V19 a14 14 0 0 1 28 0 V28" fill="none" stroke="#f6f8fa" strokeWidth="6" />
        <rect x="3" y="28" width="48" height="36" rx="7" fill="#f6f8fa" />
      </svg>
    </div>
  );
}

/** Deterministic pseudo-random widths so the fake content looks written, not generated each frame. */
const widths = [72, 48, 86, 60, 34, 78, 55, 90, 42, 66, 80, 38, 58, 74];
const syntax = ["#cf222e", "#8250df", "#0550ae", "#1f2328", "#116329"];

function Editor() {
  return (
    <div style={{ padding: "26px 30px", display: "flex", flexDirection: "column", gap: 13 }}>
      {widths.map((w, i) => (
        <div key={i} style={{ display: "flex", gap: 10, paddingLeft: (i % 4) * 22 }}>
          <div style={{ width: 22, height: 9, borderRadius: 3, background: color.line }} />
          <div style={{ width: w * 2.1, height: 9, borderRadius: 3, background: syntax[i % syntax.length], opacity: 0.75 }} />
          {i % 3 === 0 && <div style={{ width: w, height: 9, borderRadius: 3, background: syntax[(i + 2) % syntax.length], opacity: 0.6 }} />}
        </div>
      ))}
    </div>
  );
}

function Document({ typed }: { typed: string }) {
  return (
    <div style={{ padding: "34px 44px", fontFamily: font }}>
      <div style={{ width: 300, height: 20, borderRadius: 5, background: color.ink, marginBottom: 26 }} />
      {[92, 88, 95, 60].map((w, i) => (
        <div key={i} style={{ width: `${w}%`, height: 10, borderRadius: 3, background: color.line, marginBottom: 14 }} />
      ))}
      <div style={{ display: "flex", gap: 22, margin: "26px 0" }}>
        <div style={{ width: 230, height: 130, borderRadius: 8, background: "#ddf4ff" }} />
        <div style={{ flex: 1 }}>
          {[100, 94, 97, 70].map((w, i) => (
            <div key={i} style={{ width: `${w}%`, height: 10, borderRadius: 3, background: color.line, marginBottom: 14 }} />
          ))}
        </div>
      </div>
      <div style={{ fontSize: 24, color: color.ink, height: 30, whiteSpace: "nowrap" }}>
        {typed}
        {typed.length > 0 && <span style={{ borderLeft: `2px solid ${color.accent}`, marginLeft: 2 }} />}
      </div>
    </div>
  );
}

export type DeskProps = {
  laptopBlur: number;
  monitorBlur: number;
  locked: number;
  typed: string;
  hud?: string;
};

/** A laptop on the left and an external monitor on the right, seen from the chair. */
export function Desk({ laptopBlur, monitorBlur, locked, typed, hud }: DeskProps) {
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 250, display: "flex", justifyContent: "center", alignItems: "flex-end", gap: 90 }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Screen
          width={560}
          height={360}
          blur={laptopBlur}
          locked={locked}
          overlay={hud ? <Hud text={hud} /> : null}
        >
          <Editor />
        </Screen>
        {/* keyboard deck */}
        <div style={{ width: 660, height: 16, borderRadius: "0 0 12px 12px", background: "#afb8c1" }} />
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <Screen width={800} height={470} blur={monitorBlur} locked={locked}>
          <Document typed={typed} />
        </Screen>
        <div style={{ width: 70, height: 60, background: "#afb8c1" }} />
        <div style={{ width: 240, height: 12, borderRadius: 6, background: "#afb8c1" }} />
      </div>
    </div>
  );
}

/** The app's lock countdown panel. */
function Hud({ text }: { text: string }) {
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div
        style={{
          background: "rgba(0, 0, 0, 0.8)",
          color: "#ffffff",
          fontFamily: font,
          fontWeight: 600,
          fontSize: 26,
          lineHeight: 1.4,
          textAlign: "center",
          padding: "22px 32px",
          whiteSpace: "pre-line",
        }}
      >
        {text}
      </div>
    </div>
  );
}
