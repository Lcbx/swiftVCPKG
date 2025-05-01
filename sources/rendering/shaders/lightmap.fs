#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;
in vec4 fragColor;

uniform vec3 lightDir;
in vec4 fragShadowClipSpace;

uniform sampler2D texture0;   
uniform sampler2D texture_shadowmap;  
uniform sampler2D texture_shadowmap2;

out vec4 finalColor;

bool between(vec2 v, vec2 bottomLeft, vec2 topRight) {
    vec2 s = step(bottomLeft, v) - step(topRight, v);
    return bool(s.x * s.y);   
}

float random(vec2 co) {
    return fract(dot(co, vec2(3,8)) * dot(co.yx, vec2(7,5)) * 0.03);
}

void main()
{
    finalColor = fragColor * texture(texture0, fragTexCoord);

    vec3 projCoords = fragShadowClipSpace.xyz / fragShadowClipSpace.w;
    projCoords = projCoords * 0.5 + 0.5;

    vec2 shadowTexCoords = projCoords.xy;

    if (between(shadowTexCoords, vec2(0.0), vec2(1.0))) {
        float fragmentDepth = projCoords.z;
        float occluderDepth = texture(texture_shadowmap, shadowTexCoords).r;
		float noise = random(gl_FragCoord.xy);
		
		//float NDotL = dot(fragNormal, lightDir);
		//float bias = 0.001 * (1.5 - NDotL);
		
		float occlusionDistance = fragmentDepth - occluderDepth;
		//occlusionDistance = fragmentDepth - (occluderDepth + bias);
		
		if (occlusionDistance < 0.005) return;
		
		float mipLevel = occlusionDistance * 12;
		mipLevel = min(mipLevel, 2);
		float noiseStrength = 0.6;
		mipLevel *= (1.0 + noise * noiseStrength - noiseStrength);
				
		float mean = textureLod(texture_shadowmap, shadowTexCoords, mipLevel).r;
		float meanSq = textureLod(texture_shadowmap2, shadowTexCoords, mipLevel).r;
		
        float variance = max(meanSq - mean * mean, 0.00002);
        float d = fragmentDepth - mean;
        float p = variance / (variance + d * d);
		
		// combat light bleeding
		//float factor = 0.2;
		//p = (p - factor) / (1.0 - factor);
		
		noiseStrength = 0.5;
		
		p = smoothstep(0.5, 0., p);
		p *= (1.0 + noise * noiseStrength);
		p = clamp(p, 0, 1);
		p = 1.0 - p;
		p = mix(0.5, 1., p);
		
		//finalColor.rgb = fragNormal;
		finalColor.rgb *= p;
		//finalColor.rgb *= noise;
		
		//if (occlusionDistance < 0.005) return;
		//finalColor.rgb *= 0.5;
    }
	
	
}
