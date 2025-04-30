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
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
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
		
		//float NDotL = dot(fragNormal, lightDir);
		//float bias = 0.001 * (1.5 - NDotL);
		
		float occlusionDistance = fragmentDepth - occluderDepth;
		//occlusionDistance = fragmentDepth - (occluderDepth + bias);
		
		float mipLevel = occlusionDistance * 8.0;
		
		float mean = textureLod(texture_shadowmap, shadowTexCoords, mipLevel).r;
		float meanSq = textureLod(texture_shadowmap2, shadowTexCoords, mipLevel).r;
		
		//mean -= bias;
		
        float variance = max(meanSq - mean * mean, 0.00002);
        float d = fragmentDepth - mean;
        float p = variance / (variance + d * d);
		
		//p = occlusionDistance < 0 ? 1.0 : 0.5;
		
		// combat light bleeding
		p = (p - 0.2) / (1.0 - 0.2);
		
		float noiseStrength = 0.15;
		float noise = random(gl_FragCoord.xy) * noiseStrength;
		p = p - noiseStrength + noise < 0.1 ? .5 : 1.0;
		
		//finalColor.rgb = fragNormal;
		finalColor.rgb *= p;
    }
	
	
}
