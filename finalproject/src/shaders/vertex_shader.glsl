layout(location = 0) in vec3 position;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inTexCoord;
out vec3 fragPos;
out vec3 normal;
out vec2 texCoord;
out vec3 vertColor;
uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;
uniform vec3 objectColor;
void main() {
    fragPos = vec3(model * vec4(position, 1.0));
    normal = mat3(transpose(inverse(model))) * inNormal;
    texCoord = inTexCoord;
    vertColor = objectColor;
    gl_Position = proj * view * model * vec4(position, 1.0);
 }
