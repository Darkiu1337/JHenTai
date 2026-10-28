#version 460 core
#include <flutter/runtime_effect.glsl>

// AMD FidelityFX CAS (Contrast Adaptive Sharpening), single pass.
//
// Ported from ffx-cas (https://github.com/GPUOpen-Effects/FidelityFX-CAS,
// MIT) through Magpie's CAS effect. It runs on the 2x texture produced by
// bicubic_x2.frag and only sharpens where the local contrast allows it, so flat
// areas and JPEG noise are left alone.

uniform vec2 uSize;
uniform float uSharpness;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 texel = 1.0 / uSize;

  vec4 center = texture(uTexture, uv);
  vec3 e = center.rgb;
  vec3 b = texture(uTexture, uv + vec2(0.0, -texel.y)).rgb;
  vec3 d = texture(uTexture, uv + vec2(-texel.x, 0.0)).rgb;
  vec3 f = texture(uTexture, uv + vec2(texel.x, 0.0)).rgb;
  vec3 h = texture(uTexture, uv + vec2(0.0, texel.y)).rgb;

  vec3 mn = min(min(min(d, e), f), min(b, h));
  vec3 mx = max(max(max(d, e), f), max(b, h));

  /// Smooth minimum distance to the signal limit, divided by the smooth max.
  vec3 amplitude = clamp(min(mn, vec3(1.0) - mx) / max(mx, vec3(1e-4)), 0.0, 1.0);
  amplitude = sqrt(amplitude);

  float peak = -1.0 / (8.0 - 3.0 * clamp(uSharpness, 0.0, 1.0));

  /// The reference filter uses the green weight for the three channels.
  float weight = amplitude.g * peak;

  vec3 sharpened = clamp(((b + d + f + h) * weight + e) / (1.0 + 4.0 * weight), 0.0, 1.0);

  fragColor = vec4(sharpened, center.a);
}
