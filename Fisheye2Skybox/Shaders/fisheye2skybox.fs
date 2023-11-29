#ifdef GL_ES
precision highp float;
#endif

#if __VERSION__ >= 140

in vec4 v_position;

out vec4 FragColor;

#else

varying vec4 v_position;

#endif

uniform sampler2D u_skybox;
// The inverse of MVP
uniform mat4 u_viewDirectionProjectionInverse;

#define PI radians(180.0)

void main() {
    vec4 t = u_viewDirectionProjectionInverse * v_position;
    // Do a perspective division and convert to a unit vector.
    vec3 n = normalize(t.xyz / t.w);

    // Convert from direction (n) to texcoord (uv)
    // Range for r: [-2.0, 2.0]
    float r = 2.0 * atan(length(n.xy), abs(n.z)) / PI;
    // Range for theta: [-π, π]
    // Flip n.x when n.z is negative
    float theta = atan(n.y, n.x * sign(n.z));
    vec2 uv = vec2(cos(theta), sin(theta)) * r * 0.5 + vec2(0.5);

    /*
     Equivalent to:
         uv.x = cos(theta)*r*0.5 + 0.5;
         uv.y = sin(theta)*r*0.5 + 0.5;
     */

#if __VERSION__ >= 140
    FragColor = texture(u_skybox, uv);
#else
    gl_FragColor = texture2D(u_skybox, uv);
#endif
}

