struct VertexInput {
    @location(0) vertexPosition: vec3<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texCoord: vec3<f32>
}

@group(0) @binding(0) var<uniform> worldViewProjection: mat4x4<f32>;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.texCoord = in.vertexPosition;
    out.position = worldViewProjection * vec4(in.vertexPosition, 1.0);

    return out;
}

@group(1) @binding(0) var cubemapTexture: texture_cube<f32>;
@group(1) @binding(1) var sampler_cube: sampler;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return S_SRGBToLinear(textureSample(cubemapTexture, sampler_cube, in.texCoord));
}

fn S_SRGBToLinear(color: vec4<f32>) -> vec4<f32> {
    var a: vec3<f32> = color.rgb / 12.92;
    var b: vec3<f32> = pow((color.rgb + 0.055) / 1.055, vec3(2.4));
    var c: vec3<f32> = step(vec3(0.04045), color.rgb);
    var rgb: vec3<f32> = mix(a, b, c);

    return vec4(rgb, color.a);
}
