#version 460 core
#include <flutter/runtime_effect.glsl>

// 2x Catmull-Rom (bicubic) upscale of a decoded page image.
//
// The reader only ever has the 1280px-wide image that E-Hentai serves, while
// the zoom can display it up to ~1.4x above its native size on a 1080p screen.
// Magnifying with plain bilinear sampling is what makes zoomed text look soft,
// so this pass builds a 2x texture instead: the final on-screen magnification
// then stays below 1.0x (the GPU minifies it with mipmaps).
//
// Catmull-Rom is used instead of a wider Lanczos kernel because it is cheap
// (4x4 taps) and keeps text edges sharp; the CAS pass that runs afterwards
// takes care of the extra crispness without adding halos.

uniform vec2 uOutputSize;
uniform vec2 uSourceSize;
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 cubicWeights(float t) {
  float t2 = t * t;
  float t3 = t2 * t;

  return vec4(
    -0.5 * t3 + t2 - 0.5 * t,
     1.5 * t3 - 2.5 * t2 + 1.0,
    -1.5 * t3 + 2.0 * t2 + 0.5 * t,
     0.5 * t3 - 0.5 * t2
  );
}

vec2 sourceUv(vec2 pixel) {
  return (clamp(pixel, vec2(0.0), uSourceSize - vec2(1.0)) + 0.5) / uSourceSize;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uOutputSize;
  vec2 position = uv * uSourceSize - vec2(0.5);

  vec2 base = floor(position);
  vec4 wx = cubicWeights(position.x - base.x);
  vec4 wy = cubicWeights(position.y - base.y);

  /// Horizontal 4-tap interpolation of the four source rows around [base].
  vec4 row0 = texture(uTexture, sourceUv(base + vec2(-1.0, -1.0))) * wx.x
            + texture(uTexture, sourceUv(base + vec2( 0.0, -1.0))) * wx.y
            + texture(uTexture, sourceUv(base + vec2( 1.0, -1.0))) * wx.z
            + texture(uTexture, sourceUv(base + vec2( 2.0, -1.0))) * wx.w;
  vec4 row1 = texture(uTexture, sourceUv(base + vec2(-1.0,  0.0))) * wx.x
            + texture(uTexture, sourceUv(base + vec2( 0.0,  0.0))) * wx.y
            + texture(uTexture, sourceUv(base + vec2( 1.0,  0.0))) * wx.z
            + texture(uTexture, sourceUv(base + vec2( 2.0,  0.0))) * wx.w;
  vec4 row2 = texture(uTexture, sourceUv(base + vec2(-1.0,  1.0))) * wx.x
            + texture(uTexture, sourceUv(base + vec2( 0.0,  1.0))) * wx.y
            + texture(uTexture, sourceUv(base + vec2( 1.0,  1.0))) * wx.z
            + texture(uTexture, sourceUv(base + vec2( 2.0,  1.0))) * wx.w;
  vec4 row3 = texture(uTexture, sourceUv(base + vec2(-1.0,  2.0))) * wx.x
            + texture(uTexture, sourceUv(base + vec2( 0.0,  2.0))) * wx.y
            + texture(uTexture, sourceUv(base + vec2( 1.0,  2.0))) * wx.z
            + texture(uTexture, sourceUv(base + vec2( 2.0,  2.0))) * wx.w;

  fragColor = clamp(row0 * wy.x + row1 * wy.y + row2 * wy.z + row3 * wy.w, 0.0, 1.0);
}
