#version 330

out vec4 fragMoment;

void main()
{
	float d = gl_FragCoord.z;
	gl_FragDepth = d;
    fragMoment = vec4(d*d, 0.0, 0.0, 1.0);
}	