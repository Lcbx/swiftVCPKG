#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;
in vec4 fragColor;

in vec3 fragShadowClipSpace;

uniform sampler2D texture0; // diffuse texture keyword

uniform vec3 lightDir;
uniform mat4 lightVP;
uniform sampler2D texture_shadowmap;

out vec4 finalColor;


bool insideBox(vec2 v, vec2 bottomLeft, vec2 topRight) {
    vec2 s = step(bottomLeft, v) - step(topRight, v);
    return bool(s.x * s.y);   
}

void main()
{
    finalColor = fragColor * texture( texture0, fragTexCoord );
	
	vec2 shadowTexCoords = fragShadowClipSpace.xy;
	
	if(insideBox(shadowTexCoords, vec2(0), vec2(1) ) ){
		float fragmentDepthFromLight = fragShadowClipSpace.z;
		float shadowMapDepth = texture(texture_shadowmap, shadowTexCoords).r;
		
		// Calculate simple bias based on angle between normal and light
		float NDotL = dot(fragNormal, lightDir);
		float bias = max(0.005 * (1.0 - NDotL), 0.005);
		
		float shadow = fragmentDepthFromLight > shadowMapDepth + bias ? 0.5 : 1.0;
		
		finalColor = vec4( vec3(shadow) * finalColor.rgb, 1);
	}
}