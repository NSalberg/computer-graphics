// 3D First-Person Maze Game with Keys and Doors
#include <SDL3/SDL_mouse.h>
#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "glad/glad.h"
#if defined(__APPLE__) || defined(__linux__)
#include <SDL3/SDL.h>
#include <SDL3/SDL_opengl.h>
#else
#include <SDL.h>
#include <SDL_opengl.h>
#endif
#include <cmath>
#include <cstdio>
#include <fstream>
#include <set>
#include <string>
#include <vector>

#define GLM_FORCE_RADIANS
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"

// Window settings
int screen_width = 1024;
int screen_height = 768;
bool fullscreen = false;
char window_title[] = "3D Maze Game";

// Player state
glm::vec3 playerPos;
float playerYaw = 0.0f; // Horizontal rotation
float playerPitch = 0.0f;
const float PLAYER_HEIGHT = 0.5f;
const float PLAYER_RADIUS = 0.2f;
const float MOVE_SPEED = 2.5f;
const float ROTATE_SPEED = 2.0f;
const float MOUSE_SENSITIVITY = 0.002f;

// Map data
int mapWidth, mapHeight;
std::vector<std::string> gameMap;
glm::vec2 goalPos;
std::set<char> collectedKeys;
bool gameWon = false;

// Shader sources
const GLchar *vertexSource = R"(
#version 150 core
in vec3 position;
in vec3 inNormal;
in vec2 inTexCoord;
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
)";

const GLchar *fragmentSource = R"(
#version 150 core
in vec3 fragPos;
in vec3 normal;
in vec2 texCoord;
in vec3 vertColor;
out vec4 outColor;
uniform vec3 lightPos;
uniform vec3 viewPos;
uniform float ambient;
uniform float useCheckerboard;
void main() {
    vec3 color = vertColor;
    // Checkerboard pattern for floor
    if (useCheckerboard > 0.5) {
        float scale = 2.0;
        int cx = int(floor(texCoord.x * scale));
        int cy = int(floor(texCoord.y * scale));
        if ((cx + cy) % 2 == 0) color *= 0.7;
    }
    // Ambient
    vec3 ambientLight = ambient * color;
    // Diffuse
    vec3 norm = normalize(normal);
    vec3 lightDir = normalize(lightPos - fragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * color;
    // Specular
    vec3 viewDir = normalize(viewPos - fragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    vec3 specular = 0.3 * spec * vec3(1.0);
    outColor = vec4(ambientLight + diffuse + specular, 1.0);
}
)";

// Geometry data
GLuint wallVAO, wallVBO;
GLuint floorVAO, floorVBO;
GLuint keyVAO, keyVBO;
int keyVertexCount;
GLuint shaderProgram;

// Generate cube vertices (for walls)
std::vector<float> generateCube() {
  std::vector<float> v;
  // Each face: 2 triangles, 6 vertices, each with pos(3) + normal(3) + uv(2)
  float d[][3] = {// Front (Z+)
                  {-0.5f, -0.5f, 0.5f},
                  {0.5f, -0.5f, 0.5f},
                  {0.5f, 0.5f, 0.5f},
                  {-0.5f, -0.5f, 0.5f},
                  {0.5f, 0.5f, 0.5f},
                  {-0.5f, 0.5f, 0.5f},
                  // Back (Z-)
                  {0.5f, -0.5f, -0.5f},
                  {-0.5f, -0.5f, -0.5f},
                  {-0.5f, 0.5f, -0.5f},
                  {0.5f, -0.5f, -0.5f},
                  {-0.5f, 0.5f, -0.5f},
                  {0.5f, 0.5f, -0.5f},
                  // Left (X-)
                  {-0.5f, -0.5f, -0.5f},
                  {-0.5f, -0.5f, 0.5f},
                  {-0.5f, 0.5f, 0.5f},
                  {-0.5f, -0.5f, -0.5f},
                  {-0.5f, 0.5f, 0.5f},
                  {-0.5f, 0.5f, -0.5f},
                  // Right (X+)
                  {0.5f, -0.5f, 0.5f},
                  {0.5f, -0.5f, -0.5f},
                  {0.5f, 0.5f, -0.5f},
                  {0.5f, -0.5f, 0.5f},
                  {0.5f, 0.5f, -0.5f},
                  {0.5f, 0.5f, 0.5f},
                  // Top (Y+)
                  {-0.5f, 0.5f, 0.5f},
                  {0.5f, 0.5f, 0.5f},
                  {0.5f, 0.5f, -0.5f},
                  {-0.5f, 0.5f, 0.5f},
                  {0.5f, 0.5f, -0.5f},
                  {-0.5f, 0.5f, -0.5f},
                  // Bottom (Y-)
                  {-0.5f, -0.5f, -0.5f},
                  {0.5f, -0.5f, -0.5f},
                  {0.5f, -0.5f, 0.5f},
                  {-0.5f, -0.5f, -0.5f},
                  {0.5f, -0.5f, 0.5f},
                  {-0.5f, -0.5f, 0.5f}};
  float n[][3] = {
      {0, 0, 1},  {0, 0, 1},  {0, 0, 1},  {0, 0, 1},  {0, 0, 1},  {0, 0, 1},
      {0, 0, -1}, {0, 0, -1}, {0, 0, -1}, {0, 0, -1}, {0, 0, -1}, {0, 0, -1},
      {-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0}, {-1, 0, 0},
      {1, 0, 0},  {1, 0, 0},  {1, 0, 0},  {1, 0, 0},  {1, 0, 0},  {1, 0, 0},
      {0, 1, 0},  {0, 1, 0},  {0, 1, 0},  {0, 1, 0},  {0, 1, 0},  {0, 1, 0},
      {0, -1, 0}, {0, -1, 0}, {0, -1, 0}, {0, -1, 0}, {0, -1, 0}, {0, -1, 0}};
  float uv[][2] = {
      {0, 0}, {1, 0}, {1, 1}, {0, 0}, {1, 1}, {0, 1}, {0, 0}, {1, 0}, {1, 1},
      {0, 0}, {1, 1}, {0, 1}, {0, 0}, {1, 0}, {1, 1}, {0, 0}, {1, 1}, {0, 1},
      {0, 0}, {1, 0}, {1, 1}, {0, 0}, {1, 1}, {0, 1}, {0, 0}, {1, 0}, {1, 1},
      {0, 0}, {1, 1}, {0, 1}, {0, 0}, {1, 0}, {1, 1}, {0, 0}, {1, 1}, {0, 1}};
  for (int i = 0; i < 36; i++) {
    v.push_back(d[i][0]);
    v.push_back(d[i][1]);
    v.push_back(d[i][2]);
    v.push_back(n[i][0]);
    v.push_back(n[i][1]);
    v.push_back(n[i][2]);
    v.push_back(uv[i][0]);
    v.push_back(uv[i][1]);
  }
  return v;
}

// Generate key model (simple 3D key shape)
std::vector<float> generateKey() {
  std::vector<float> v;
  // Simplified key: cylinder handle + rectangular shaft
  int segments = 12;
  float handleR = 0.15f, handleH = 0.05f;
  float shaftW = 0.05f, shaftL = 0.3f;
  // Handle ring (torus approximation with cylinders)
  for (int i = 0; i < segments; i++) {
    float a1 = 2.0f * M_PI * i / segments;
    float a2 = 2.0f * M_PI * (i + 1) / segments;
    float x1 = handleR * cos(a1), z1 = handleR * sin(a1);
    float x2 = handleR * cos(a2), z2 = handleR * sin(a2);
    // Outer face
    v.insert(v.end(), {x1, -handleH, z1, x1, 0, z1, 0, 0});
    v.insert(v.end(), {x2, -handleH, z2, x2, 0, z2, 1, 0});
    v.insert(v.end(), {x2, handleH, z2, x2, 0, z2, 1, 1});
    v.insert(v.end(), {x1, -handleH, z1, x1, 0, z1, 0, 0});
    v.insert(v.end(), {x2, handleH, z2, x2, 0, z2, 1, 1});
    v.insert(v.end(), {x1, handleH, z1, x1, 0, z1, 0, 1});
  }
  // Shaft (box)
  float sx = shaftW, sy = handleH, sz = shaftL;
  float ox = handleR + sz / 2;
  float box[][3] = {{-sx + ox, -sy, -sz / 2}, {sx + ox, -sy, -sz / 2},
                    {sx + ox, sy, -sz / 2},   {-sx + ox, -sy, -sz / 2},
                    {sx + ox, sy, -sz / 2},   {-sx + ox, sy, -sz / 2},
                    {sx + ox, -sy, sz / 2},   {-sx + ox, -sy, sz / 2},
                    {-sx + ox, sy, sz / 2},   {sx + ox, -sy, sz / 2},
                    {-sx + ox, sy, sz / 2},   {sx + ox, sy, sz / 2},
                    {-sx + ox, -sy, sz / 2},  {-sx + ox, -sy, -sz / 2},
                    {-sx + ox, sy, -sz / 2},  {-sx + ox, -sy, sz / 2},
                    {-sx + ox, sy, -sz / 2},  {-sx + ox, sy, sz / 2},
                    {sx + ox, -sy, -sz / 2},  {sx + ox, -sy, sz / 2},
                    {sx + ox, sy, sz / 2},    {sx + ox, -sy, -sz / 2},
                    {sx + ox, sy, sz / 2},    {sx + ox, sy, -sz / 2},
                    {-sx + ox, sy, -sz / 2},  {sx + ox, sy, -sz / 2},
                    {sx + ox, sy, sz / 2},    {-sx + ox, sy, -sz / 2},
                    {sx + ox, sy, sz / 2},    {-sx + ox, sy, sz / 2},
                    {-sx + ox, -sy, sz / 2},  {sx + ox, -sy, sz / 2},
                    {sx + ox, -sy, -sz / 2},  {-sx + ox, -sy, sz / 2},
                    {sx + ox, -sy, -sz / 2},  {-sx + ox, -sy, -sz / 2}};
  for (int i = 0; i < 36; i++) {
    v.insert(v.end(), {box[i][0], box[i][1], box[i][2], 0, 1, 0, 0, 0});
  }
  return v;
}

void setupGeometry() {
  auto cube = generateCube();
  glGenVertexArrays(1, &wallVAO);
  glGenBuffers(1, &wallVBO);
  glBindVertexArray(wallVAO);
  glBindBuffer(GL_ARRAY_BUFFER, wallVBO);
  glBufferData(GL_ARRAY_BUFFER, cube.size() * sizeof(float), cube.data(),
               GL_STATIC_DRAW);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(3 * sizeof(float)));
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(6 * sizeof(float)));
  glEnableVertexAttribArray(2);

  // Floor quad
  float floor[] = {0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0,
                   1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0,
                   1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1};
  glGenVertexArrays(1, &floorVAO);
  glGenBuffers(1, &floorVBO);
  glBindVertexArray(floorVAO);
  glBindBuffer(GL_ARRAY_BUFFER, floorVBO);
  glBufferData(GL_ARRAY_BUFFER, sizeof(floor), floor, GL_STATIC_DRAW);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(3 * sizeof(float)));
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(6 * sizeof(float)));
  glEnableVertexAttribArray(2);

  // Key model
  auto key = generateKey();
  keyVertexCount = key.size() / 8;
  glGenVertexArrays(1, &keyVAO);
  glGenBuffers(1, &keyVBO);
  glBindVertexArray(keyVAO);
  glBindBuffer(GL_ARRAY_BUFFER, keyVBO);
  glBufferData(GL_ARRAY_BUFFER, key.size() * sizeof(float), key.data(),
               GL_STATIC_DRAW);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(3 * sizeof(float)));
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(6 * sizeof(float)));
  glEnableVertexAttribArray(2);
}

bool loadMap(const std::string &filename) {
  std::ifstream f(filename);
  if (!f.is_open())
    return false;
  f >> mapWidth >> mapHeight;
  gameMap.resize(mapHeight);
  for (int y = 0; y < mapHeight; y++) {
    f >> gameMap[y];
    for (int x = 0; x < mapWidth; x++) {
      char c = gameMap[y][x];
      if (c == 'S') {
        playerPos = glm::vec3(x + 0.5f, PLAYER_HEIGHT, y + 0.5f);
        gameMap[y][x] = '0';
      } else if (c == 'G') {
        goalPos = glm::vec2(x + 0.5f, y + 0.5f);
      }
    }
  }
  return true;
}

bool canMoveTo(float x, float z) {
  int gx = (int)x, gz = (int)z;
  if (gx < 0 || gx >= mapWidth || gz < 0 || gz >= mapHeight)
    return false;
  char c = gameMap[gz][gx];
  if (c == 'W')
    return false;
  if (c >= 'A' && c <= 'E') {
    char needed = c - 'A' + 'a';
    return collectedKeys.count(needed) > 0;
  }
  return true;
}

void checkCollisions() {
  int gx = (int)playerPos.x, gz = (int)playerPos.z;
  if (gx >= 0 && gx < mapWidth && gz >= 0 && gz < mapHeight) {
    char &c = gameMap[gz][gx];
    if (c >= 'a' && c <= 'e') {
      collectedKeys.insert(c);
      printf("Collected key: %c\n", c);
      c = '0';
    }
    if (c == 'G') {
      gameWon = true;
      printf("You Win!\n");
    }
  }
}

glm::vec3 getDoorColor(char door) {
  switch (door) {
  case 'A':
    return glm::vec3(1.0f, 0.2f, 0.2f); // Red
  case 'B':
    return glm::vec3(0.2f, 1.0f, 0.2f); // Green
  case 'C':
    return glm::vec3(0.2f, 0.2f, 1.0f); // Blue
  case 'D':
    return glm::vec3(1.0f, 1.0f, 0.2f); // Yellow
  case 'E':
    return glm::vec3(1.0f, 0.2f, 1.0f); // Magenta
  default:
    return glm::vec3(0.5f);
  }
}

glm::vec3 getKeyColor(char key) { return getDoorColor(key - 'a' + 'A'); }

void render(float aspect) {
  glClearColor(0.1f, 0.1f, 0.15f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glUseProgram(shaderProgram);

  // Camera
  glm::vec3 front(cos(playerYaw), 0, sin(playerYaw));
  glm::mat4 view =
      glm::lookAt(playerPos, playerPos + front, glm::vec3(0, 1, 0));
  glm::mat4 proj = glm::perspective(glm::radians(70.0f), aspect, 0.1f, 100.0f);

  glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "view"), 1, GL_FALSE,
                     glm::value_ptr(view));
  glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "proj"), 1, GL_FALSE,
                     glm::value_ptr(proj));
  glUniform3fv(glGetUniformLocation(shaderProgram, "viewPos"), 1,
               glm::value_ptr(playerPos));
  glUniform3f(glGetUniformLocation(shaderProgram, "lightPos"), playerPos.x,
              playerPos.y + 2, playerPos.z);
  glUniform1f(glGetUniformLocation(shaderProgram, "ambient"), 0.3f);

  // Draw floor
  glBindVertexArray(floorVAO);
  glUniform1f(glGetUniformLocation(shaderProgram, "useCheckerboard"), 1.0f);
  glUniform3f(glGetUniformLocation(shaderProgram, "objectColor"), 0.4f, 0.35f,
              0.3f);
  for (int z = 0; z < mapHeight; z++) {
    for (int x = 0; x < mapWidth; x++) {
      glm::mat4 model = glm::translate(glm::mat4(1), glm::vec3(x, 0, z));
      glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "model"), 1,
                         GL_FALSE, glm::value_ptr(model));
      glDrawArrays(GL_TRIANGLES, 0, 6);
    }
  }
  glUniform1f(glGetUniformLocation(shaderProgram, "useCheckerboard"), 0.0f);

  // Draw walls and doors
  glBindVertexArray(wallVAO);
  for (int z = 0; z < mapHeight; z++) {
    for (int x = 0; x < mapWidth; x++) {
      char c = gameMap[z][x];
      glm::vec3 color;
      bool draw = false;
      if (c == 'W') {
        color = glm::vec3(0.6f, 0.6f, 0.65f);
        draw = true;
      } else if (c >= 'A' && c <= 'E') {
        color = getDoorColor(c);
        draw = true;
      } else if (c == 'G') {
        color = glm::vec3(1.0f, 0.84f, 0.0f);
        draw = true;
      }
      if (draw) {
        glm::mat4 model =
            glm::translate(glm::mat4(1), glm::vec3(x + 0.5f, 0.5f, z + 0.5f));
        glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "model"), 1,
                           GL_FALSE, glm::value_ptr(model));
        glUniform3fv(glGetUniformLocation(shaderProgram, "objectColor"), 1,
                     glm::value_ptr(color));
        glDrawArrays(GL_TRIANGLES, 0, 36);
      }
    }
  }

  // Draw keys in world
  glBindVertexArray(keyVAO);
  for (int z = 0; z < mapHeight; z++) {
    for (int x = 0; x < mapWidth; x++) {
      char c = gameMap[z][x];
      if (c >= 'a' && c <= 'e') {
        glm::vec3 color = getKeyColor(c);
        float bob = sin(SDL_GetTicks() / 300.0f) * 0.1f;
        glm::mat4 model = glm::translate(
            glm::mat4(1), glm::vec3(x + 0.5f, 0.3f + bob, z + 0.5f));
        model = glm::rotate(model, (float)SDL_GetTicks() / 500.0f,
                            glm::vec3(0, 1, 0));
        model = glm::scale(model, glm::vec3(0.5f));
        glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "model"), 1,
                           GL_FALSE, glm::value_ptr(model));
        glUniform3fv(glGetUniformLocation(shaderProgram, "objectColor"), 1,
                     glm::value_ptr(color));
        glDrawArrays(GL_TRIANGLES, 0, keyVertexCount);
      }
    }
  }

  // Draw collected keys in front of player (HUD-style in 3D)
  glDisable(GL_DEPTH_TEST);
  int i = 0;
  for (char k : collectedKeys) {
    glm::vec3 offset = front * 0.4f + glm::vec3(0, -0.15f, 0);
    offset += glm::vec3(-front.z, 0, front.x) *
              (0.15f * (i - (int)collectedKeys.size() / 2.0f));
    glm::mat4 model = glm::translate(glm::mat4(1), playerPos + offset);
    model = glm::rotate(model, -playerYaw + glm::radians(90.0f),
                        glm::vec3(0, 1, 0));
    model = glm::scale(model, glm::vec3(0.15f));
    glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "model"), 1,
                       GL_FALSE, glm::value_ptr(model));
    glUniform3fv(glGetUniformLocation(shaderProgram, "objectColor"), 1,
                 glm::value_ptr(getKeyColor(k)));
    glDrawArrays(GL_TRIANGLES, 0, keyVertexCount);
    i++;
  }
  glEnable(GL_DEPTH_TEST);
}

int main(int argc, char *argv[]) {
  SDL_Init(SDL_INIT_VIDEO);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);

  SDL_Window *window = SDL_CreateWindow(window_title, screen_width,
                                        screen_height, SDL_WINDOW_OPENGL);
  SDL_GLContext context = SDL_GL_CreateContext(window);

  if (gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress)) {
    printf("\nOpenGL loaded\n");
    printf("Vendor:   %s\n", glGetString(GL_VENDOR));
    printf("Renderer: %s\n", glGetString(GL_RENDERER));
    printf("Version:  %s\n\n", glGetString(GL_VERSION));
  }

  // Compile shaders
  GLuint vs = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vs, 1, &vertexSource, NULL);
  glCompileShader(vs);
  GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fs, 1, &fragmentSource, NULL);
  glCompileShader(fs);
  shaderProgram = glCreateProgram();
  glAttachShader(shaderProgram, vs);
  glAttachShader(shaderProgram, fs);
  glLinkProgram(shaderProgram);

  setupGeometry();
  if (!loadMap("maps/level2.txt")) {
    printf("Failed to load map!\n");
    return 1;
  }

  glEnable(GL_DEPTH_TEST);
  SDL_SetWindowRelativeMouseMode(window, true);

  float aspect = screen_width / (float)screen_height;
  Uint64 lastTime = SDL_GetTicks();
  bool quit = false;
  SDL_Event e;

  while (!quit) {
    Uint64 now = SDL_GetTicks();
    float dt = (now - lastTime) / 1000.0f;
    lastTime = now;

    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_EVENT_QUIT)
        quit = true;
      if (e.type == SDL_EVENT_KEY_UP && e.key.key == SDLK_ESCAPE)
        quit = true;
      if (e.type == SDL_EVENT_MOUSE_MOTION) {
        playerYaw += e.motion.xrel * MOUSE_SENSITIVITY;
      }
    }

    const bool *keys = SDL_GetKeyboardState(NULL);
    glm::vec3 front(cos(playerYaw), 0, sin(playerYaw));
    glm::vec3 right(-front.z, 0, front.x);
    glm::vec3 move(0);
    if (keys[SDL_SCANCODE_W] || keys[SDL_SCANCODE_UP])
      move += front;
    if (keys[SDL_SCANCODE_S] || keys[SDL_SCANCODE_DOWN])
      move -= front;
    if (keys[SDL_SCANCODE_A])
      move -= right;
    if (keys[SDL_SCANCODE_D])
      move += right;
    if (keys[SDL_SCANCODE_LEFT])
      playerYaw -= ROTATE_SPEED * dt;
    if (keys[SDL_SCANCODE_RIGHT])
      playerYaw += ROTATE_SPEED * dt;

    if (glm::length(move) > 0) {
      move = glm::normalize(move) * MOVE_SPEED * dt;
      glm::vec3 newPos = playerPos + move;
      // Check collision with radius
      if (canMoveTo(newPos.x + PLAYER_RADIUS, newPos.z) &&
          canMoveTo(newPos.x - PLAYER_RADIUS, newPos.z) &&
          canMoveTo(newPos.x, newPos.z + PLAYER_RADIUS) &&
          canMoveTo(newPos.x, newPos.z - PLAYER_RADIUS)) {
        playerPos = newPos;
      }
    }
    checkCollisions();
    render(aspect);
    SDL_GL_SwapWindow(window);
  }

  SDL_GL_DestroyContext(context);
  SDL_Quit();
  return 0;
}
