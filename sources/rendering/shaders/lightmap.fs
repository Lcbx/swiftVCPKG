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

float depthFromEVSM(float f){
	return log2(f)/40.0;
}

void main()
{
    finalColor = fragColor * texture(texture0, fragTexCoord);

    vec3 projCoords = fragShadowClipSpace.xyz / fragShadowClipSpace.w;
    projCoords = projCoords * 0.5 + 0.5;

    vec2 shadowTexCoords = projCoords.xy;

    if (!between(shadowTexCoords, vec2(0.0), vec2(1.0))) return;
	
	float noise = random(gl_FragCoord.xy);
	
	float fragmentDepth = projCoords.z;
	float occluderDepth = texture(texture_shadowmap2, shadowTexCoords).r;
	
	float NDotL = dot(fragNormal, lightDir);
	float bias = 0.001 * (1.5 - NDotL);
	float occlusionDistance = fragmentDepth - (occluderDepth + bias);
	
    if (occlusionDistance < 0.0) return;
	
	float mipLevel = occlusionDistance * 5.0;
	float size     = float(textureSize(texture_shadowmap, 0).x);
	mipLevel = clamp(mipLevel, 0.2, log2(size));
	//float noiseStrength = 0.3;
	//mipLevel *= (1.0 + noise * noiseStrength - noiseStrength);
	
	vec3 M = textureLod(texture_shadowmap, shadowTexCoords, mipLevel).rgb;
	float mean = M.r,
		  meanSq = M.g,
		  lightIntensity = M.b; // TODO
	
	float variance = max(meanSq - mean*mean, 0.00002);
	float d = fragmentDepth - mean;
	float p = variance / (variance + d * d);
	
	p = smoothstep(0.5, 0.0, p);
	//p += noise * 0.5;
	p = clamp(p, 0.0, 1.0);
	
	float p_lit = 1.0 - p;
	p_lit = mix(0.5, 1.0, p_lit);
	
	finalColor.rgb *= p_lit;
	//finalColor.rgb *= p;
}
