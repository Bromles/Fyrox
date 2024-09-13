struct VertexInput {
    @location(0) vertexPosition: vec3<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
}

@group(0) @binding(0) var<uniform> worldViewProjection: mat4x4<f32>;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.position = worldViewProjection * vec4(in.vertexPosition, 1.0);

    return out;
}

@group(1) @binding(0) var sceneDepth: texture_2d<f32>;
@group(1) @binding(1) var diffuseTexture: texture_2d<f32>;
@group(1) @binding(2) var normalTexture: texture_2d<f32>;
@group(1) @binding(3) var decalMask: texture_2d<f32>;
@group(1) @binding(4) var sampler_2d: sampler;

@group(2) @binding(0) var<uniform> invViewProj: mat4x4<f32>;
@group(2) @binding(1) var<uniform> invWorldDecal: mat4x4<f32>;
@group(2) @binding(2) var<uniform> resolution: vec2<f32>;
@group(2) @binding(3) var<uniform> color: vec4<f32>;
@group(2) @binding(4) var<uniform> layerIndex: u32;

struct FragmentOutput {
    @location(0) outDiffuseMap: vec4<f32>,
    @location(1) outNormalMap: vec4<f32>
}

@fragment
fn fs_main(in: VertexOutput) -> FragmentOutput {
    var out: FragmentOutput;
    let screenPos: vec2<f32> = in.position.xy / in.position.w;
    let texCoord: vec2<f32> = vec2(
        (1.0 + screenPos.x) / 2.0 + (0.5 / resolution.x),
        (1.0 + screenPos.y) / 2.0 + (0.5 / resolution.y),
    );

    let maskIndex: u32 = u32(round(textureSample(decalMask, sampler_2d, texCoord).r));

    if (maskIndex != layerIndex) {
        discard;
    }

    let screenDepthR: f32 = textureSample(sceneDepth, sampler_2d, texCoord).r;

    let sceneWorldPosition: vec3<f32> = S_UnProject(vec3(texCoord, screenDepthR), invViewProj);

    let decalSpacePosition: vec3<f32> = (invWorldDecal * vec4(sceneWorldPosition, 1.0)).xyz;

    let dpos: vec3<f32> = vec3(0.5) - abs(decalSpacePosition.xyz);
    if (dpos.x < 0.0 || dpos.y < 0.0 || dpos.z < 0.0) {
        discard;
    }

    let decalTexCoord: vec2<f32> = decalSpacePosition.xz + 0.5;

    out.outDiffuseMap = color * textureSample(diffuseTexture, sampler_2d, decalTexCoord);

    let fragmentTangent: vec3<f32> = dpdx(sceneWorldPosition);
    let fragmentBinormal: vec3<f32> = dpdy(sceneWorldPosition);
    let fragmentNormal: vec3<f32> = cross(fragmentTangent, fragmentBinormal);

    var tangentToWorld: mat3x3<f32>;
    tangentToWorld[0] = normalize(fragmentTangent);
    tangentToWorld[1] = normalize(fragmentBinormal);
    tangentToWorld[2] = normalize(fragmentNormal);

    let rawNormal: vec3<f32> = (textureSample(normalTexture, sampler_2d, decalTexCoord) * 2.0 - 1.0).xyz;
    let worldSpaceNormal: vec3<f32> = tangentToWorld * rawNormal;

    out.outNormalMap = vec4(worldSpaceNormal * 0.5 + 0.5, out.outDiffuseMap.a);

    return out;
}

fn S_UnProject(screenPos: vec3<f32>, inputMatrix: mat4x4<f32>) -> vec3<f32> {
    let clipSpacePos: vec4<f32> = vec4(screenPos * 2.0 - 1.0, 1.0);
    let position: vec4<f32> = inputMatrix * clipSpacePos;

    return position.xyz / position.w;
}
