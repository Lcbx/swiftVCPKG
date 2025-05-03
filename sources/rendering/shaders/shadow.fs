#version 330

out vec4 fragMoment;

void main()
{
	float d = gl_FragCoord.z;
	gl_FragDepth = d;
	
	float EVSM_C = 5.0;
	
	float e1 = exp(EVSM_C * d);
    float e2 = exp(2.0 * EVSM_C * d);
	
	float lightIntensity = 0.0; // TODO
	
    fragMoment = vec4(e1, e2, lightIntensity, 1.0);
}	