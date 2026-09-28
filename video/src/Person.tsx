import React from "react";

const skin = "#e3b48f";
const hair = "#3a302a";
const hoodie = "#3d444d";
const pod = "#ffffff";

type PersonProps = {
  /** Head yaw in degrees, seen from behind: negative turns left, positive right. */
  yaw: number;
  x: number;
  y: number;
  scale?: number;
  /** 0–1 glow around the AirPods. */
  podsHighlight?: number;
};

/**
 * The user seen from behind, over the shoulder. The head is modelled as a circle from
 * above: turning moves each ear around it (toward the viewer when turning to that side)
 * and lets the cheek peek out past the hair on the side being faced.
 */
export function Person({ yaw, x, y, scale = 1, podsHighlight = 0 }: PersonProps) {
  const r = 78;
  const t = (yaw * Math.PI) / 180;
  // Azimuth φ measured from "facing away from the viewer"; x = r·sin φ, toward viewer when cos φ < 0.
  const ear = (side: 1 | -1) => {
    const phi = t + (side * Math.PI) / 2;
    return { x: r * Math.sin(phi), front: Math.cos(phi) < 0 };
  };
  const right = ear(1);
  const left = ear(-1);
  // The cheek sits just inside the rim and only peeks out once the head turns.
  const cheekX = Math.sign(t) * Math.min(Math.abs(Math.sin(t)) * r * 1.7, r * 0.72);

  const drawEar = (e: { x: number; front: boolean }, key: string) => (
    <g key={key} transform={`translate(${e.x} 6)`}>
      <ellipse rx="13" ry="21" fill={skin} />
      {/* AirPod: bud in the ear, stem pointing down */}
      <circle r={9 + 9 * podsHighlight} fill="#0969da" opacity={0.2 * podsHighlight} />
      <ellipse cy="-2" rx="7.5" ry="8" fill={pod} stroke="#d0d7de" strokeWidth="1" />
      <rect x="-3.2" y="3" width="6.4" height="24" rx="3.2" fill={pod} stroke="#d0d7de" strokeWidth="1" />
    </g>
  );

  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%, -50%) scale(${scale})` }}>
      <svg width="520" height="420" viewBox="-260 -150 520 420" style={{ overflow: "visible" }}>
        {/* shoulders */}
        <path d="M-230 270 C-230 150 -170 118 -80 108 L80 108 C170 118 230 150 230 270 Z" fill={hoodie} />
        <path d="M-34 70 L34 70 L40 116 L-40 116 Z" fill="#c99a78" />
        <path d="M-70 110 C-40 128 40 128 70 110" fill="none" stroke="#2d333b" strokeWidth="6" strokeLinecap="round" />

        {/* ears and cheek behind the hair */}
        {!right.front && drawEar(right, "r")}
        {!left.front && drawEar(left, "l")}
        <ellipse cx={cheekX} cy="16" rx="34" ry="46" fill={skin} />

        {/* back of the head */}
        <ellipse cx={Math.sin(t) * 6} cy="0" rx={r} ry={r * 1.12} fill={hair} />
        <path
          d={`M${-r * 0.55 + Math.sin(t) * 6} -60 C${-20 + Math.sin(t) * 6} -78 ${20 + Math.sin(t) * 6} -78 ${r * 0.55 + Math.sin(t) * 6} -60`}
          fill="none" stroke="#4a3f37" strokeWidth="5" strokeLinecap="round" opacity="0.6"
        />

        {/* ears turned toward the viewer sit in front of the hair */}
        {right.front && drawEar(right, "r")}
        {left.front && drawEar(left, "l")}
      </svg>
    </div>
  );
}
