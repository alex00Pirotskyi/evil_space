#include <flutter/runtime_effect.glsl>

// Evil Space / Ultra-Premium Minimalist — heavyweight graphite art paper.
// An intentionally empty, full-bleed canvas: no cuts, holes or dust overlays.
// The mouse/touch steers a soft virtual light; no ongoing animation is needed.
uniform vec2 u_resolution;
uniform vec2 u_lightPos;
uniform float u_time; // Reserved for future design studies; currently static.

out vec4 fragColor;

// Simplex 2D noise
vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }
float snoise(vec2 v){
    const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod(i, 289.0);
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 )) + i.x + vec3(0.0, i1.x, 1.0 ));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// Two-scale paper height: extremely subtle, rigid-stock warp plus fine tooth.
// The different fiber frequencies add a faint Y-directed paper grain.
float paperHeight(vec2 p) {
    float rigidWarp = snoise(p * 1.45) * 0.00030;
    float fiberTooth = snoise(vec2(p.x * 320.0, p.y * 250.0)) * 0.00045;
    return rigidWarp + fiberTooth;
}

void main() {
    // Match Flutter's top-left pixel coordinates, even on narrow mobile screens.
    vec2 resolution = max(u_resolution, vec2(1.0));
    vec2 uv = FlutterFragCoord().xy / resolution;
    float aspect = resolution.x / resolution.y;
    vec2 paperUv = vec2(uv.x * aspect, 1.0 - uv.y);

    // Reconstruct a shallow virtual 3D surface and cursor-controlled light.
    vec3 surfacePos = vec3(
        (uv.x - 0.5) * 2.0 * aspect,
        (0.5 - uv.y) * 2.0,
        0.0
    );
    vec2 pointer = clamp(u_lightPos / resolution, vec2(0.0), vec2(1.0));
    vec3 lightPos = vec3(
        (pointer.x - 0.5) * 2.0 * aspect,
        (0.5 - pointer.y) * 2.0,
        0.80
    );
    vec3 cameraPos = vec3(0.0, 0.0, 3.5);

    // Height derivatives generate normals directly, no normal texture needed.
    float eps = 0.001;
    float height = paperHeight(paperUv);
    float heightX = paperHeight(paperUv + vec2(eps, 0.0));
    float heightY = paperHeight(paperUv + vec2(0.0, eps));
    vec3 normal = normalize(vec3(
        -(heightX - height) / eps,
        -(heightY - height) / eps,
        1.0
    ));

    // Graphite/charcoal stock: enough reflectance to reveal the micro-tooth.
    // Albedo is physical reflectance, not the final displayed RGB value.
    float pigment = snoise(paperUv * 6.0);
    vec3 albedo = vec3(0.035) * (1.0 + 0.045 * pigment);

    // Mostly untouched matte paper. Tiny oil/smudge patches gently lower
    // roughness without creating the slick highlights of a plastic surface.
    float oil = clamp(max(0.0, snoise(paperUv * 5.0)) * 2.0, 0.0, 1.0);
    float roughness = 0.95 - 0.01 * oil; // Subtle smudges, never below 0.94.

    vec3 viewDir = normalize(cameraPos - surfacePos);
    vec3 lightDir = normalize(lightPos - surfacePos);
    vec3 halfDir = normalize(lightDir + viewDir);
    float ndl = max(dot(normal, lightDir), 0.0);
    float ndv = max(dot(normal, viewDir), 0.0);
    float ndh = max(dot(normal, halfDir), 0.0);

    float distanceToLight = length(lightPos - surfacePos);
    float attenuation = 1.0 / (
        1.0 + 0.55 * distanceToLight + 0.18 * distanceToLight * distanceToLight
    );

    // A broad, low-F0 Blinn/Schlick response suitable for nonmetallic fibers.
    float f0 = 0.016;
    float fresnel = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
    float broadHighlight = pow(ndh, 2.5) * fresnel *
        (1.0 - roughness) * 0.28;

    // Tiny vertical anisotropy and soft grazing-angle fiber sheen.
    vec3 fiberHalf = normalize(halfDir + vec3(0.0, 0.28, 0.0));
    float directionalSheen =
        pow(max(dot(normal, fiberHalf), 0.0), 2.0) *
        (1.0 - roughness) * 0.005;
    float grazingSheen =
        pow(1.0 - ndv, 3.0) * ndl *
        (1.0 - roughness) * 0.010;

    vec3 ambient = albedo * 0.085;
    vec3 diffuse = albedo * ndl * attenuation * 2.3;
    vec3 specular = vec3(
        (broadHighlight * ndl + directionalSheen + grazingSheen) *
        attenuation
    );

    vec3 finalColor = ambient + diffuse + specular;
    finalColor = finalColor / (finalColor + vec3(1.0));
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    fragColor = vec4(finalColor, 1.0);
}
