#version 330

in vec3 fragNormal;
uniform vec3 lightDir;
out vec4 fragMoment;

float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

void main()
{
    float depth = gl_FragCoord.z;
    float depthSq = depth * depth;
	//float NDotL = dot(fragNormal, lightDir);
	//float bias = (1.5 - NDotL) * 0.002;
    //float noise = random(gl_FragCoord.xy);
	//depthSq -= bias;
	//float f = 0.001; 
	//depthSq += f * noise - f * 0.5;
	//depthSq *= (1.0 - f * 0.5 + f * noise);
	//depthSq *= abs(1.0 - f * 0.5  + f * noise);
    fragMoment = vec4(depthSq, 0.0, 0.0, 1.0);
}	