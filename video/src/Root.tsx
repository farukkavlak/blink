import React from "react";
import { Composition } from "remotion";
import { Blink, DURATION } from "./Blink";
import { FPS } from "./theme";

export function Root() {
  return <Composition id="Blink" component={Blink} durationInFrames={DURATION} fps={FPS} width={1920} height={1080} />;
}
