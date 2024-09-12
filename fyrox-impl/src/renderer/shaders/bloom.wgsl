@group(0) @binding(0) var hdrTexture: texture_2d<f32>;
@group(0) @binding(1) var sampler_2d: sampler;

struct VertexOutput {
    @location(0) texCoord: vec2<f32>
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    var outBrightColor: vec4<f32>;
    let hdrPixel = textureSample(hdrTexture, sampler_2d, in.texCoord).rgb;

    if (S_Luminance(hdrPixel) > 1.0) {
        outBrightColor = vec4(hdrPixel, 0.0);
    } else {
        outBrightColor = vec4(0.0);
    }

    return outBrightColor;
}

fn S_Luminance(x: vec3<f32>) -> f32 {
    return dot(x, vec3(0.299, 0.587, 0.114));
}
