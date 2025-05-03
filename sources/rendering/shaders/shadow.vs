
#version 330

in vec3 vertexPosition;
uniform mat4 mvp;

void main(){
	vec4 vertex = vec4(vertexPosition, 1.0);
    gl_Position = mvp*vertex;
}