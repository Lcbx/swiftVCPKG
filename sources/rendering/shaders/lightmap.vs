#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;

// Input uniform values
uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

uniform mat4 lightVP; // Light source view-projection matrix

out vec2 fragTexCoord;
out vec4 fragColor;
out vec2 fragShadowTexCoord;
out float fragShadowDepth;

void main(){
    gl_Position = mvp*vec4(vertexPosition, 1.0);
    //gl_Position = lightVP*matModel*vec4(vertexPosition, 1.0);
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    
    vec4 worldSpace = matModel*vec4(vertexPosition, 1.0); // position of the model in the scene
    vec4 screenSpace = lightVP*worldSpace; // equivalent to gl_Position above but for the light
    fragShadowDepth = screenSpace.z/screenSpace.w; // .z component is depth in screen space.
    fragShadowTexCoord = (screenSpace.xy/screenSpace.w)*.5+.5; // .xy is position on the screen
}


// out vec3 fragPosition;

// void main()
// {
//     // Send vertex attributes to fragment shader
//     fragPosition = vec3(matModel*vec4(vertexPosition, 1.0));
//     fragTexCoord = vertexTexCoord;
//     fragColor = vertexColor;
//     fragNormal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));

//     // Calculate final vertex position
//     gl_Position = mvp*vec4(vertexPosition, 1.0);
// }