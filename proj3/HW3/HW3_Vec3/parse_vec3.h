
// Set the global scene parameter variables
// TODO: Set the scene parameters based on the values in the scene file

#ifndef PARSE_VEC3_H
#include "vec3.h"
#define PARSE_VEC3_H

#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
// Camera & Scene Parameters (Global Variables)
// Here we set default values, override them in parseSceneFile()

// Image Parameters
int img_width = 800, img_height = 600;
std::string imgName = "raytraced.png";

// Camera Parameters
vec3 eye = vec3(0, 0, 0);
vec3 forward = vec3(0, 0, -1).normalized();
vec3 up = vec3(0, 1, 0).normalized();
vec3 right;
float halfAngleVFOV = 35;

// Scene (Sphere) Parameters
vec3 spherePos = vec3(0, 0, 2);
float sphereRadius = 1;


void parseSceneFile(std::string fileName) {
  // TODO: Override the default values with new data from the file "fileName"
  //
  std::ifstream cgFile;
  cgFile.open(fileName);
  if (!cgFile) {
    printf("ERROR: Scene file '%s' not found.\n", fileName.c_str());
    exit(1);
  }

  std::string line;
  while (std::getline(cgFile, line)) {
    if (!line.empty() && line.at(0) == '#') {
      continue;
    }
    std::istringstream iss(line);
    std::string command, values;
    std::getline(iss, command, ':');
    std::getline(iss, values);
    std::istringstream vals(values);
    if (command == "sphere") {
      float x, y, z, r;
      vals >> x >> y >> z >> r;

      spherePos = vec3(x, y, z);
      sphereRadius = r;

    } else if (command == "image_resolution ") {
      vals >> img_width >> img_height;
    } else if (command == "output_image") {
      vals >> imgName;

    } else if (command == "camera_pos") {
      float x, y, z;
      vals >> x >> y >> z;
      eye = vec3(x, y, z);
    } else if (command == "camera_fwd") {
      float x, y, z;
      vals >> x >> y >> z;
      forward = vec3(x, y, z).normalized();
    } else if (command == "camera_up") {
      float x, y, z;
      vals >> x >> y >> z;
      up = vec3(x, y, z).normalized();
    } else if (command == "camera_fov_ha") {
      vals >> halfAngleVFOV;
    }
  }
  right = cross(up,forward).normalized();

  // TODO: Create an orthogonal camera basis, based on the provided up and right
  // vectors
  printf("Orthogonal Camera Basis:\n");
  printf("forward: %f,%f,%f\n", forward.x, forward.y, forward.z);
  printf("right: %f,%f,%f\n", right.x, right.y, right.z);
  printf("up: %f,%f,%f\n", up.x, up.y, up.z);
}

#endif
