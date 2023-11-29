// https://stackoverflow.com/questions/60819068/fisheye-skybox-shader

#if __VERSION__ >= 140

in vec4 position;

out vec4 v_position;

#else

attribute vec4 position;

varying vec4 v_position;

#endif


void main() {
    v_position = position;
    gl_Position = position;
    gl_Position.z = 1.0;
}


