struct VertexInput {
    @location(0) vertexPosition: vec3<f32>,
    @location(1) vertexTexCoord: vec2<f32>
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texCoord: vec2<f32>
}

@group(0) @binding(0) var<uniform> worldViewProjection: mat4x4<f32>;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.texCoord = in.vertexTexCoord;
    out.position = worldViewProjection * vec4(in.vertexPosition, 1.0);

    return out;
}

const NUM_CASCADES: u32 = 3;
const PI: f32 = radians(180.0);

@group(1) @binding(0) var<uniform> lightDirection: vec3<f32>;
@group(1) @binding(1) var<uniform> lightColor: vec4<f32>;
@group(1) @binding(2) var<uniform> invViewProj: mat4x4<f32>;
@group(1) @binding(3) var<uniform> cameraPosition: vec3<f32>;
@group(1) @binding(4) var<uniform> lightIntensity: f32;
@group(1) @binding(5) var<uniform> viewMatrix: mat4x4<f32>;
@group(1) @binding(6) var<uniform> cascadeDistances: array<vec4<f32>, NUM_CASCADES>;
@group(1) @binding(7) var<uniform> lightViewProjMatrices: array<mat4x4<f32>, NUM_CASCADES>;
@group(1) @binding(8) var<uniform> shadowsEnabled: u32;
@group(1) @binding(9) var<uniform> shadowBias: f32;
@group(1) @binding(10) var<uniform> softShadows: u32;
@group(1) @binding(11) var<uniform> shadowMapInvSize: f32;

@group(2) @binding(0) var depthTexture: texture_2d<f32>;
@group(2) @binding(1) var colorTexture: texture_2d<f32>;
@group(2) @binding(2) var normalTexture: texture_2d<f32>;
@group(2) @binding(3) var materialTexture: texture_2d<f32>;
@group(2) @binding(4) var shadowCascade0: texture_2d<f32>;
@group(2) @binding(5) var shadowCascade1: texture_2d<f32>;
@group(2) @binding(6) var shadowCascade2: texture_2d<f32>;
@group(2) @binding(7) var sampler_2d: sampler;

@fragment
fn fs_main_directional(in: VertexOutput) -> @location(0) vec4<f32> {
    let material: vec3<f32> = textureSample(materialTexture, sampler_2d, in.texCoord).rgb;

    let fragmentPosition: vec3<f32> = S_UnProject(vec3(in.texCoord, textureSample(depthTexture, sampler_2d, in.texCoord).r), invViewProj);
    let diffuseColor: vec4<f32> = textureSample(colorTexture, sampler_2d, in.texCoord);

    var ctx: TPBRContext;
    ctx.albedo = S_SRGBToLinear(diffuseColor).rgb;
    ctx.fragmentToLight = lightDirection;
    ctx.fragmentNormal = normalize(textureSample(normalTexture, sampler_2d, in.texCoord).xyz * 2.0 - 1.0);
    ctx.lightColor = lightColor.rgb;
    ctx.metallic = material.x;
    ctx.roughness = material.y;
    ctx.viewVector = normalize(cameraPosition - fragmentPosition);

    let lighting: vec3<f32> = S_PBR_CalculateLight(ctx);

    let fragmentZViewSpace: f32 = abs((viewMatrix * vec4(fragmentPosition, 1.0)).z);

    var shadow: f32 = 1.0;

    if (fragmentZViewSpace <= cascadeDistances[0].x && fragmentZViewSpace <= cascadeDistances[0].y && fragmentZViewSpace <= cascadeDistances[0].z) {
        shadow = CsmGetShadow(shadowCascade0, fragmentPosition, lightViewProjMatrices[0]);
    } else if (fragmentZViewSpace <= cascadeDistances[1].x && fragmentZViewSpace <= cascadeDistances[1].y && fragmentZViewSpace <= cascadeDistances[1].z) {
        shadow = CsmGetShadow(shadowCascade1, fragmentPosition, lightViewProjMatrices[1]);
    } else if (fragmentZViewSpace <= cascadeDistances[2].x && fragmentZViewSpace <= cascadeDistances[2].y && fragmentZViewSpace <= cascadeDistances[2].z) {
        shadow = CsmGetShadow(shadowCascade2, fragmentPosition, lightViewProjMatrices[2]);
    }

    return shadow * vec4(lightIntensity * lighting, diffuseColor.a);
}

@fragment
fn fs_main_spot() -> @location(0) vec4<f32> {
    return vec4(0.0);
}

@fragment
fn fs_main_point() -> @location(0) vec4<f32> {
    return vec4(0.0);
}

fn CsmGetShadow(texture: texture_2d<f32>, fragmentPosition: vec3<f32>, lightViewProjMatrix: mat4x4<f32>) -> f32 {
    return S_SpotShadowFactor(shadowsEnabled, softShadows, shadowBias, fragmentPosition, lightViewProjMatrix, shadowMapInvSize, texture);
}

fn S_SpotShadowFactor(
    shadowsEnabled: u32,
    softShadows: u32,
    shadowBias: f32,
    fragmentPosition: vec3<f32>,
    lightViewProjMatrix: mat4x4<f32>,
    shadowMapInvSize: f32,
    spotShadowTexture: texture_2d<f32>
) -> f32 {
    let shadowsEnabledBool: bool = bool(shadowsEnabled & 0x1);
    let softShadowsBool: bool = bool(softShadows & 0x1);

    if (shadowsEnabledBool) {
        let lightSpacePosition: vec3<f32> = S_Project(fragmentPosition, lightViewProjMatrix);

        let biasedLightSpaceFragmentDepth: f32 = lightSpacePosition.z - shadowBias;

        if (softShadowsBool) {
            var accumulator: f32 = 0.0;

            for (var y = -0.5; y <= 0.5; y += 0.5) {
                for (var x = -0.5; x <= 0.5; x += 0.5) {
                    let fetchTexCoord: vec2<f32> = lightSpacePosition.xy + vec2(x, y) * shadowMapInvSize;
                    if (biasedLightSpaceFragmentDepth > textureSample(spotShadowTexture, sampler_2d, fetchTexCoord).r) {
                        accumulator += 1.0;
                    }
                }
            }

            return clamp(1.0 - accumulator / 9.0, 0.0, 1.0);
        } else {
            return select(1.0, 0.0, biasedLightSpaceFragmentDepth > textureSample(spotShadowTexture, sampler_2d, lightSpacePosition.xy).r);
        }
    } else {
        return 1.0; // No shadow
    }
}

fn S_Project(worldPosition: vec3<f32>, inputMatrix: mat4x4<f32>) -> vec3<f32> {
    var screenPos = inputMatrix * vec4(worldPosition, 1);

    screenPos.x /= screenPos.w;
    screenPos.y /= screenPos.w;
    screenPos.z /= screenPos.w;

    return screenPos.xyz * 0.5 * 0.5;
}

fn S_UnProject(screenPos: vec3<f32>, inputMatrix: mat4x4<f32>) -> vec3<f32> {
    let clipSpacePos: vec4<f32> = vec4(screenPos * 2.0 - 1.0, 1.0);
    let position: vec4<f32> = inputMatrix * clipSpacePos;

    return position.xyz / position.w;
}

fn S_SRGBToLinear(color: vec4<f32>) -> vec4<f32> {
    var a: vec3<f32> = color.rgb / 12.92;
    var b: vec3<f32> = pow((color.rgb + 0.055) / 1.055, vec3(2.4));
    var c: vec3<f32> = step(vec3(0.04045), color.rgb);
    var rgb: vec3<f32> = mix(a, b, c);

    return vec4(rgb, color.a);
}

fn S_PBR_CalculateLight(ctx: TPBRContext) -> vec3<f32> {
    let F0: vec3<f32> = mix(vec3(0.04), ctx.albedo, ctx.metallic);

    let L: vec3<f32> = ctx.fragmentToLight;
    let H: vec3<f32> = normalize(ctx.viewVector + L);

    let NDF: f32 = S_DistributionGGX(ctx.fragmentNormal, H, ctx.roughness);
    let G: f32 = S_GeometrySmith(ctx.fragmentNormal, ctx.viewVector, L, ctx.roughness);
    let F: vec3<f32> = S_FresnelSchlick(max(dot(H, ctx.viewVector), 0.0), F0);

    let numerator: vec3<f32> = NDF * G * F;
    let denominator: f32 = 4.0 * max(dot(ctx.fragmentNormal, ctx.viewVector), 0.0) * max(dot(ctx.fragmentNormal, L), 0.0) + 0.001;
    let specular: vec3<f32> = numerator / denominator;

    let kS: vec3<f32> = F;
    var kD: vec3<f32> = vec3(1.0) - kS;
    kD *= 1.0 - ctx.metallic;

    let NdotL: f32 = max(dot(ctx.fragmentNormal, L), 0.0);

    return (kD * ctx.albedo / PI + specular) * ctx.lightColor * NdotL;
}

fn S_DistributionGGX(N: vec3<f32>, H: vec3<f32>, roughness: f32) -> f32 {
    let a: f32 = roughness * roughness;
    let a2: f32 = a * a;
    let NdotH: f32 = max(dot(N, H), 0.0);
    let NdotH2: f32 = NdotH * NdotH;

    let nom: f32 = a2;
    var denom: f32 = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}

fn S_GeometrySmith(N: vec3<f32>, V: vec3<f32>, L: vec3<f32>, roughness: f32) -> f32 {
    let NdotV: f32 = max(dot(N, V), 0.0);
    let NdotL: f32 = max(dot(N, L), 0.0);
    let ggx2: f32 = S_GeometrySchlickGGX(NdotV, roughness);
    let ggx1: f32 = S_GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

fn S_GeometrySchlickGGX(NdotV: f32, roughness: f32) -> f32 {
    let r: f32 = (roughness + 1.0);
    let k: f32 = (r * r) / 8.0;

    let nom: f32 = NdotV;
    let denom: f32 = NdotV * (1.0 - k) + k;

    return nom / denom;
}

fn S_FresnelSchlick(cosTheta: f32, F0: vec3<f32>) -> vec3<f32> {
    return F0 + (1.0 - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}

struct TPBRContext {
    lightColor: vec3<f32>,
    viewVector: vec3<f32>,
    fragmentToLight: vec3<f32>,
    fragmentNormal: vec3<f32>,
    metallic: f32,
    roughness: f32,
    albedo: vec3<f32>
}
