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

@group(1) @binding(0) var inputTexture: texture_2d<f32>;
@group(1) @binding(1) var sampler_2d: sampler;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let texelSize: vec2<f32> = 1.0 / vec2<f32>(textureDimensions(inputTexture, 0));
    var result: f32 = 0.0;

    for (var y = -2; y < 2; y += 1) {
        for (var x = -2; x < 2; x += 1) {
            let offset: vec2<f32> = vec2(f32(x), f32(y)) * texelSize;
            result += textureSample(inputTexture, sampler_2d, in.texCoord + offset).r;
        }
    }

    return vec4(result / 16.0, 0.0, 0.0, 0.0);
}
