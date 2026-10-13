#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform vec4 uRect;
uniform float uOpacity;
uniform float uPressLight;
uniform sampler2D uBackdrop;
uniform sampler2D uMask;
out vec4 fragColor;

vec3 toneAt(vec2 uv) {
    vec4 sampleColor = texture(uBackdrop, uv);
    return sampleColor.rgb / max(sampleColor.a, 0.001);
}

void main() {
    vec2 position = FlutterFragCoord().xy;
    vec2 maskUV = (position - uRect.xy) / uRect.zw;
    vec4 backdrop = texture(uBackdrop, position / uSize);
    vec2 center = (uRect.xy + uRect.zw * 0.5) / uSize;
    vec2 span = uRect.zw * 0.3 / uSize;
    vec3 tone = (toneAt(center)
        + toneAt(center + span)
        + toneAt(center - span)
        + toneAt(center + vec2(span.x, -span.y))
        + toneAt(center + vec2(-span.x, span.y))) * 0.2;
    float luma = dot(tone, vec3(0.2126, 0.7152, 0.0722));
    // Undo the contact veil for polarity selection, so pressing alone cannot
    // flip the icon. A single polarity covers the entire glyph. A hard switch
    // keeps intermediate, stationary backgrounds from producing grey-on-grey.
    float restLuma = clamp((luma - uPressLight) / (1.0 - uPressLight), 0.0, 1.0);
    float ink = mix(0.96, 0.08, step(0.52, restLuma));
    // UIKit's dark template dims more strongly than its light template.
    float contactDimming = mix(1.05, 0.75, step(0.5, ink));
    ink = mix(ink, luma, uPressLight * contactDimming);
    float coverage = texture(uMask, maskUV).a * uOpacity;
    fragColor = vec4(mix(backdrop.rgb, vec3(ink), coverage),
                     mix(backdrop.a, 1.0, coverage));
}
