//CSCI 5607 OpenGL Tutorial (HW 4)
//1 - Blank Screen

#include <cstdio>
#include "glad/glad.h"  //Include order can matter here
#if defined(__APPLE__) || defined(__linux__)
 #include <SDL3/SDL.h>
 #include <SDL3/SDL_opengl.h>
#else
 #include <SDL.h>
 #include <SDL_opengl.h>
#endif

//For Visual Studios
#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#endif

bool fullscreen = false;
int screen_width = 800;
int screen_height = 600;

char window_title[] = "My OpenGL Program";

float avg_render_time = 0;

int main(int argc, char *argv[]){
   SDL_Init(SDL_INIT_VIDEO);  //Initialize Graphics (for OpenGL)

  //Print the version of SDL we are using (should be 3.x or higher)
  const int sdl_linked = SDL_GetVersion();
  printf("\nCompiled against SDL version %d.%d.%d ...\n", SDL_VERSIONNUM_MAJOR(SDL_VERSION), SDL_VERSIONNUM_MINOR(SDL_VERSION), SDL_VERSIONNUM_MICRO(SDL_VERSION));
  printf("Linking against SDL version %d.%d.%d.\n", SDL_VERSIONNUM_MAJOR(sdl_linked), SDL_VERSIONNUM_MINOR(sdl_linked), SDL_VERSIONNUM_MICRO(sdl_linked));
    
  //Ask SDL to get a recent version of OpenGL (3.2 or greater)
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
  
  //Create a window (offsetx, offsety, width, height, flags)
  // SDL_Window* window = SDL_CreateWindow(window_title, 100, 100, screen_width, screen_height, SDL_WINDOW_OPENGL);
  
  //Create a window (title, width, height, flags)
  SDL_Window* window = SDL_CreateWindow(window_title, screen_width, screen_height, SDL_WINDOW_OPENGL);
  float aspect = screen_width/(float)screen_height; //aspect ratio (needs to be updated if the window is resized)  

  //The above window cannot be resized which makes some code slightly easier.
  //Below we show how to make a full screen window or allow resizing
  //SDL_Window* window = SDL_CreateWindow(window_title, screen_width, screen_height, SDL_WINDOW_FULLSCREEN|SDL_WINDOW_OPENGL);
  //SDL_Window* window = SDL_CreateWindow(window_title, screen_width, screen_height, SDL_WINDOW_RESIZABLE|SDL_WINDOW_OPENGL);
  //Also check out SDL_SetWindowFullscreenMode for "fake" borderless full screen windows
   if (!window) {
    printf("SDL_CreateWindow Error: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
  }
  
  //Create a context to draw in
  SDL_GLContext context = SDL_GL_CreateContext(window);
    
  //OpenGL functions using glad library
    if (gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress)){
       printf("\nOpenGL loaded\n");
       printf("Vendor:   %s\n", glGetString(GL_VENDOR));
       printf("Renderer: %s\n", glGetString(GL_RENDERER));
       printf("Version:  %s\n\n", glGetString(GL_VERSION));
    }
    else {
        printf("ERROR: Failed to initialize OpenGL context.\n");
        return -1;
    }
  
  GLuint vertexBuffer;
  glGenBuffers(1, &vertexBuffer);
  printf("Generated Vertex Buffer: #%u\n", vertexBuffer);
  
  
  //Event Loop (Loop forever processing each event as fast as possible
  SDL_Event windowEvent;
  bool quit = false;
  while (!quit){
    float t_start = SDL_GetTicks();

    while (SDL_PollEvent(&windowEvent)){
      if (windowEvent.type == SDL_EVENT_QUIT) quit=true; //Exit event loop
      if (windowEvent.type == SDL_EVENT_KEY_UP && windowEvent.key.key == SDLK_ESCAPE) 
        quit=true; //Exit event loop
      if (windowEvent.type == SDL_EVENT_KEY_UP && windowEvent.key.key == SDLK_F) { //If "f" is pressed
        fullscreen = !fullscreen;
        SDL_SetWindowFullscreen(window, fullscreen ? SDL_WINDOW_FULLSCREEN : 0); //Toggle fullscreen 
      }
    }
    
    glClearColor(.2f, 0.4f, 0.8f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    float t_end = SDL_GetTicks();
    float time_per_frame = t_end-t_start;
    avg_render_time = .98*avg_render_time + .02*time_per_frame; //Weighted average for smoothing
    char update_title[100];
    snprintf(update_title,100,"%s [Update: %3.0f ms]\n",window_title,avg_render_time);
    SDL_SetWindowTitle(window, update_title);

    SDL_GL_SwapWindow(window);
  }

  //Clean Up
  SDL_GL_DestroyContext(context);
  SDL_Quit();
  return 0;
}