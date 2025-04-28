#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

uniform mat4 mvp; // default keyword
uniform mat4 matLightVP;

out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragShadowClipSpace;

void main(){
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
	
	vec4 vertex = vec4(vertexPosition, 1.0);
    gl_Position = mvp*vertex;
	
    vec4 lightSpacePos = matLightVP*vertex;
    vec3 projCoords = lightSpacePos.xyz / lightSpacePos.w;
    projCoords = projCoords * 0.5 + 0.5;
	
	fragShadowClipSpace = projCoords;
}