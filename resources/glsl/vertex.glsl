
#version 410

layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 textPos;

out vec2 outTextPos;

void main() {
    gl_Position = vec4(pos, 1.0);
    outTextPos = textPos;
}

