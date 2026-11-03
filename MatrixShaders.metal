// This file is part of Red Pill
// A 3D Metal "Matrix" screensaver for Mac OS X
// Copyright (C) 2002, 2003 mathew <meta@pobox.com>
// Copyright (C) 2016 px3 <rr@rdsroot.net>
// Copyright (C) 2025 AkimoA
//
// Red Pill is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.

#include <metal_stdlib>
using namespace metal;

// One vertex as written by MatrixStrip: x,y,z, r,g,b,a, u,v (9 floats, tightly packed)
struct MatrixVertex {
    packed_float3 position;
    packed_float4 color;
    packed_float2 texCoord;
};

// Must match MatrixUniforms in MatrixRenderer.swift
struct MatrixUniforms {
    float4x4 projection;
    float fogStart;
    float fogEnd;
    uint fogEnabled;
    uint padding;
};

struct MatrixVertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
    float eyeDepth;
};

// Quads are drawn as two triangles each (6 vertices per quad, 4 vertices stored per quad):
// corners 0,1,2 and 0,2,3 of the bottom left, bottom right, top right, top left quad.
vertex MatrixVertexOut matrixVertex(uint vid [[vertex_id]],
                                    const device MatrixVertex *verts [[buffer(0)]],
                                    constant MatrixUniforms &uniforms [[buffer(1)]])
{
    uint quad = vid / 6u;
    uint c = vid % 6u;
    uint corner = (c < 3u) ? c : ((c == 3u) ? 0u : (c - 2u));
    MatrixVertex v = verts[quad * 4u + corner];

    float3 p = float3(v.position);

    MatrixVertexOut out;
    out.position = uniforms.projection * float4(p, 1.0);
    out.color = float4(v.color);
    out.texCoord = float2(v.texCoord);
    // Distance from the eye, used for linear fog
    out.eyeDepth = -p.z;
    return out;
}

fragment float4 matrixFragment(MatrixVertexOut in [[stage_in]],
                               texture2d<float> glyphs [[texture(0)]],
                               constant MatrixUniforms &uniforms [[buffer(1)]])
{
    constexpr sampler glyphSampler(coord::normalized, address::clamp_to_edge, filter::linear);

    // The texture modulates the brightness and alpha of the quad (GL_MODULATE)
    float4 color = glyphs.sample(glyphSampler, in.texCoord) * in.color;

    // Linear fog towards black (GL_FOG_MODE = GL_LINEAR), alpha is not touched
    if (uniforms.fogEnabled != 0u) {
        float f = saturate((uniforms.fogEnd - in.eyeDepth) / (uniforms.fogEnd - uniforms.fogStart));
        color.rgb = mix(float3(0.0), color.rgb, f);
    }

    // Blending (src alpha, one minus src alpha) is done by the pipeline state
    return color;
}
