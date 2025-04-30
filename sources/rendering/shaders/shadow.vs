
#version 330
in vec3 vertexPosition;
in vec3 vertexNormal;
uniform mat4 mvp;
uniform mat4 matModel;
out vec3 fragNormal;

void main(){
	vec4 vertex = vec4(vertexPosition, 1.0);
    gl_Position = mvp*vertex;
	fragNormal = normalize(mat3(matModel) * vertexNormal);
}