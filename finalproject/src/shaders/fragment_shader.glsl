in vec3 fragPos;
in vec3 normal;
in vec2 texCoord;
in vec3 vertColor;
out vec4 outColor;
// uniform vec3 lightPos;
uniform vec3 viewPos;
uniform float ambient;
void main() {
    vec3 color = vertColor;
    // Ambient
    vec3 ambientLight = ambient * color;
    // Diffuse
    vec3 norm = normalize(normal);
    vec3 lightDir = normalize(viewPos - fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * color;
    // // Specular
    // vec3 viewDir = normalize(viewPos - fragPos);
    // vec3 reflectDir = reflect(-lightDir, norm);
    // float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    // vec3 specular = 0.3 * spec * vec3(1.0);
    // outColor = vec4(ambientLight + diffuse + specular, 1.0);
    outColor = vec4(ambientLight + diffuse , 1.0);
}
