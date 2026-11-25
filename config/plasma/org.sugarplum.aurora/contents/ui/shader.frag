#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    vec2 pointer;
    vec2 resolution;
    int style;
    float intensity;
    float stars;
};

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec3 glow(vec2 uv, vec2 center, float radius, vec3 color, float alpha) {
    vec2 d = (uv - center) * vec2(resolution.x / max(resolution.y, 1.0), 1.0);
    float dist2 = dot(d, d);
    return color * alpha * exp(-dist2 / (radius * radius));
}

vec3 silkBand(vec2 uv, float base, float amp, float speed, float offset, vec3 ca, vec3 cb) {
    float wave = sin(uv.x * 6.2 + phase * speed + offset) * amp
               + sin(uv.x * 13.0 - phase * speed * 0.7 + offset) * amp * 0.24;

    // Local pointer influence: bend this band toward the pointer and compress
    // the wave around the pointer's x position. No global up/down shift.
    float dx = uv.x - pointer.x;
    float influence = exp(-(dx * dx) / 0.020);
    float y = base + wave
            + (pointer.y - base) * 0.22 * influence
            + sin(dx * 34.0 + phase * 1.2) * 0.006 * influence;

    float d = abs(uv.y - y);
    vec3 color = mix(ca, cb, smoothstep(0.15, 0.85, uv.x));
    float core = smoothstep(0.060, 0.0, d);
    float halo = exp(-(d * d) / 0.0028);
    return color * (core * 0.24 + halo * 0.10);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);

    vec3 col = mix(vec3(0.105, 0.090, 0.140), vec3(0.035, 0.030, 0.055), uv.y);

    if (style == 1) {
        col += silkBand(uv, 0.30, 0.075, 0.24, 0.0, vec3(1.0, 0.70, 0.85), vec3(0.68, 0.77, 1.0)) * intensity;
        col += silkBand(uv, 0.44, 0.055, 0.18, 1.4, vec3(0.78, 0.71, 0.89), vec3(0.72, 0.90, 0.90)) * intensity;
        col += silkBand(uv, 0.56, 0.065, 0.21, 2.9, vec3(0.68, 0.77, 1.0), vec3(0.96, 0.76, 0.91)) * intensity;
        col += silkBand(uv, 0.68, 0.045, 0.15, 4.1, vec3(0.97, 0.88, 0.71), vec3(1.0, 0.70, 0.85)) * intensity;
        col += glow(uv, pointer, 0.22, vec3(1.0, 0.70, 0.85), 0.10 * intensity);
    } else {
        vec2 d = (pointer - 0.5) * 0.06;
        col += glow(uv, vec2(0.16, 0.78) + d, 0.58, vec3(1.0, 0.70, 0.85), 0.34 * intensity);
        col += glow(uv, vec2(0.84, 0.22) + d, 0.54, vec3(0.68, 0.77, 1.0), 0.30 * intensity);
        col += glow(uv, vec2(0.72, 0.84) + d * 0.5, 0.30, vec3(0.72, 0.90, 0.90), 0.14 * intensity);
        col += glow(uv, pointer, 0.16, vec3(1.0, 0.70, 0.85), 0.06 * intensity);
    }

    if (stars > 0.5) {
        vec2 guv = uv * vec2(160.0 * aspect, 160.0);
        vec2 cell = floor(guv);
        float h = hash21(cell);
        if (h > 0.982) {
            vec2 f = fract(guv) - 0.5;
            float d = length(f);
            float twinkle = 0.5 + 0.5 * sin(phase * (1.0 + h * 2.0) + h * 20.0);
            float a = smoothstep(0.16, 0.0, d) * (0.18 + 0.45 * twinkle) * h;
            col += vec3(0.97, 0.88, 0.70) * a;
        }
    }

    float vignette = smoothstep(0.36, 0.92, length((uv - 0.5) * vec2(aspect, 1.0)));
    col *= 1.0 - 0.34 * vignette;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
