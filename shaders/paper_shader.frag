#include <flutter/runtime_effect.glsl>

// Uniforms passed from Flutter
uniform vec2 u_resolution;
uniform vec2 u_lightPos; // Passed as raw pixel coordinates from top-left
uniform float u_time;

out vec4 fragColor;

// --- NOISE FUNCTIONS ---
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

// Random hash for dust
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// --- HEIGHT MAP GENERATION ---
float getHeight(vec2 uv) {
    float macro = snoise(uv * 2.0) * 1.0;
    float micro = snoise(vec2(uv.x * 350.0, uv.y * 250.0)) * 0.12;
    float height = macro + micro;

    float perfX = 0.06;
    float distToPerf = abs(uv.x - perfX);
    if(uv.x < 0.1) {
        height += (1.0 - smoothstep(0.0, 0.015, distToPerf)) * 0.15;
    }

    return height * 0.03;
}

void main() {
    // 1. Calculate UVs and project to 3D Space
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / u_resolution;
    
    // Invert Y so math matches standard 3D coordinates (Y goes up)
    vec2 st = vec2(uv.x, 1.0 - uv.y);
    vec2 aspectUv = st * vec2(u_resolution.x / u_resolution.y, 1.0);

    // Reconstruct 3D positions purely from 2D coordinates
    vec3 cameraPosition = vec3(0.0, 0.0, 3.5);
    vec3 vPosition = vec3(
        (st.x - 0.5) * 2.0 * (u_resolution.x / u_resolution.y),
        (st.y - 0.5) * 2.0,
        0.0
    );

    // Convert Flutter light pixel coordinates to the same 3D space
    vec2 lightNorm = u_lightPos / u_resolution;
    vec2 lightSt = vec2(lightNorm.x, 1.0 - lightNorm.y);
    vec3 lightPos3D = vec3(
        (lightSt.x - 0.5) * 2.0 * (u_resolution.x / u_resolution.y),
        (lightSt.y - 0.5) * 2.0,
        0.6 // Light hovers slightly above the paper
    );

    // --- PERFORATION MASK ---
    float perfX = 0.06 * (u_resolution.x / u_resolution.y); 
    float holeSpacing = 50.0;
    float holeY = fract(aspectUv.y * holeSpacing) - 0.5;
    float holeDist = length(vec2((aspectUv.x - perfX) * 1.5, holeY));
    
    // Transparent holes instead of 'discard' for better Flutter compatibility
    if (aspectUv.x < perfX + 0.02 && holeDist < 0.12) {
        fragColor = vec4(0.0);
        return;
    }

    // --- NORMALS ---
    float h = getHeight(aspectUv);
    float eps = 0.001;
    float hx = getHeight(aspectUv + vec2(eps, 0.0));
    float hy = getHeight(aspectUv + vec2(0.0, eps));
    
    vec3 tx = vec3(eps, 0.0, hx - h);
    vec3 ty = vec3(0.0, eps, hy - h);
    vec3 normal = normalize(cross(tx, ty));

    // --- MATERIAL PROPERTIES ---
    vec3 albedo = vec3(0.04, 0.04, 0.04);
    
    float distToPerf = abs(aspectUv.x - perfX);
    albedo += (1.0 - smoothstep(0.0, 0.01, distToPerf)) * vec3(0.02);
    
    float dustHash = random(aspectUv * 15.0);
    if (dustHash > 0.9996) {
        albedo = vec3(0.4); 
    }

    float smudgeNoise = snoise(aspectUv * 8.0);
    float roughness = 0.95 - (max(0.0, smudgeNoise) * 0.25);
    roughness = mix(roughness, 1.0, (1.0 - smoothstep(0.0, 0.01, distToPerf)));

    // --- LIGHTING ---
    vec3 viewDir = normalize(cameraPosition - vPosition);
    vec3 lightDir = normalize(lightPos3D - vPosition);
    vec3 halfVector = normalize(lightDir + viewDir);

    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float NdotH = max(dot(normal, halfVector), 0.0);

    float dist = length(lightPos3D - vPosition);
    float attenuation = 1.0 / (1.0 + 0.5 * dist + 0.1 * dist * dist);
    float lightIntensity = 4.5; 

    vec3 diffuse = albedo * NdotL;

    float shininess = 2.0 / (pow(roughness, 4.0) + 0.001) - 2.0;
    float spec = pow(NdotH, max(shininess, 0.0001));
    
    float F0 = 0.015; 
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);
    
    float anisotropyMask = pow(max(dot(normal, normalize(halfVector + vec3(0.0, 0.5, 0.0))), 0.0), shininess * 0.5);
    vec3 specular = vec3(spec * fresnel + (anisotropyMask * 0.01)) * NdotL * 0.5;

    float sheenFresnel = pow(1.0 - NdotV, 3.0);
    vec3 sheen = vec3(0.04) * sheenFresnel * NdotL * (1.0 - roughness); 

    vec3 ambient = albedo * 0.05;

    // --- COMBINE & OUTPUT ---
    vec3 finalColor = ambient + (diffuse + specular + sheen) * attenuation * lightIntensity;
    
    // Tone mapping
    finalColor = finalColor / (finalColor + vec3(1.0));
    finalColor = pow(finalColor, vec3(1.0/2.2));

    fragColor = vec4(finalColor, 1.0);
}