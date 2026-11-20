// Mac DFU Studio — SwiftUI shader effects.
// Compiled into Effects.metallib by build-app.sh and loaded with ShaderLibrary(url:).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// The ambient background: soft pools of the state's colour drifting over the window colour.
// Everything is computed from the pixel's position — there is no layer underneath to rasterize — and two
// overlapping flow fields bend the coordinates so the pools appear to breathe. `blend` cross-fades from
// the previous state's colour to the current one.
[[ stitchable ]] half4 aurora(float2 position, half4 color, float2 size, float time,
                              half4 base, half4 tintFrom, half4 tintTo, float blend,
                              half4 accent, float energy) {
    float2 uv = position / max(size, float2(1.0));
    float t = time * 0.11;

    float2 p = uv * 2.6;
    float2 flow = float2(
        sin(p.y * 1.7 + t * 2.1) + 0.6 * cos(p.x * 2.3 - t * 1.3),
        cos(p.x * 1.9 + t * 1.7) + 0.6 * sin(p.y * 2.1 + t * 2.4)
    );
    // A second, finer octave driven by the first keeps the motion from looking periodic.
    float2 q = uv * 5.1 + flow * 0.35;
    flow += 0.35 * float2(sin(q.y + t * 3.0), cos(q.x - t * 2.6));

    float2 w = uv + flow * (0.035 + 0.03 * energy);

    half3 tint = mix(tintFrom.rgb, tintTo.rgb, half(smoothstep(0.0, 1.0, blend)));
    float main = smoothstep(0.78, 0.0, distance(w, float2(0.56, 0.42)));
    float side = smoothstep(0.62, 0.0, distance(w, float2(0.02, 0.55)));
    float low  = smoothstep(0.55, 0.0, distance(w, float2(0.62, 1.05)));

    half3 rgb = base.rgb;
    rgb = mix(rgb, tint, half(main * 0.40));
    rgb = mix(rgb, accent.rgb, half(side * 0.12));
    rgb = mix(rgb, tint, half(low * 0.14));

    float sheen = 0.5 + 0.5 * sin((uv.x * 1.3 + uv.y) * 5.0 + t * 3.2 + flow.x * 0.8);
    rgb += half3(half(sheen * sheen * 0.03));
    return half4(rgb, 1.0) * color.a;
}

// A ring of displacement that travels outward from a point and fades — played once when a Mac arrives
// or an action succeeds.
[[ stitchable ]] half4 ripple(float2 position, SwiftUI::Layer layer, float2 origin, float time,
                              float amplitude, float frequency, float decay, float speed) {
    float2 offset = position - origin;
    float distance = length(offset);
    float local = max(0.0, time - distance / speed);

    float wave = amplitude * sin(frequency * local) * exp(-decay * local);
    float2 direction = distance > 0.001 ? offset / distance : float2(0.0);

    half4 color = layer.sample(position + wave * direction);
    // Lighten the crests a little, in proportion to the pixel's own coverage.
    color.rgb += half3(half(0.14 * (wave / max(amplitude, 0.001)))) * color.a;
    return color;
}

// A soft band of light that sweeps across whatever it is applied to — used while work is in progress.
[[ stitchable ]] half4 shimmer(float2 position, half4 color, float2 size, float time) {
    float2 uv = position / max(size, float2(1.0));
    float sweep = fract(time * 0.55) * 1.8 - 0.4;
    float band = smoothstep(0.22, 0.0, abs(uv.x + uv.y * 0.25 - sweep));
    return color + half4(half3(half(band * 0.4)) * color.a, 0.0);
}
