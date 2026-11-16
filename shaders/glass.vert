#version 440
// glass.frag's vertices: also where each one lands in the window (0–1), worked out from qt_Matrix, so the
// glass knows what's behind it however its parents move
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 uv;
layout(location = 1) out vec2 inWin;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 win;
    vec4 at;
    vec2 size;
    vec2 screen;
    vec4 tint;
    vec4 light;
    float radius;
    float inset;
    float round;
    float back;
    float edge;
    vec4 tune;
    vec4 wave;
};

void main() {
    uv = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
    vec2 ndc = gl_Position.xy / gl_Position.w;
    inWin = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
}
