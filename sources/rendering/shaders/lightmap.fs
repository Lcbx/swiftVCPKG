#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;
in vec4 fragColor;

in vec2 fragShadowTexCoord;
in float fragShadowDepth;

uniform sampler2D texture0; // diffuse texture keyword, DrawMesh uses this
uniform sampler2D texture_shadowmap; // custom uniform

out vec4 finalColor;

void main(){
    finalColor = fragColor * texture( texture0, fragTexCoord );
    float shadowDepth = texture(texture_shadowmap, fragShadowTexCoord).r;
    if(fragShadowDepth + 0.001 > shadowDepth){
        finalColor = vec4(finalColor.rgb*.2,finalColor.a);
    }
	//finalColor = texture(texture_shadowmap, fragTexCoord);
	finalColor = vec4(mix(vec3(shadowDepth), fragColor.rgb, 0.5),1);
}