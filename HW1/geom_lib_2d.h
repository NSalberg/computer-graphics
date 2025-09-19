//UMN CSCI 5607 2D Geometry Library Homework [HW0]
//TODO: For the 18 functions below, replace their sub function with a working version that matches the desciption.

#ifndef GEOM_LIB_H
#define GEOM_LIB_H

#include "PGA/multivector.h"
#include "PGA/pga.h"
#include "PGA/primitives.h"

//Displace a point p on the direction d
//The result is a point
Point2D move(Point2D p, Dir2D d){
  return Point2D(p.x + d.x,p.y + d.y); //Wrong, fix me...
}

//Compute the displacement vector between points p1 and p2
//The result is a direction 
Dir2D displacement(Point2D p1, Point2D p2){
  return Dir2D(0,0); //Wrong, fix me...
}

//Compute the distance between points p1 and p2
//The result is a scalar 
float dist(Point2D p1, Point2D p2){
  return vee(p1.normalized(), p2.normalized()).magnitude();
}

//Compute the perpendicular distance from the point p the the line l
//The result is a scalar 
float dist(Line2D l, Point2D p){
  return vee(p.normalized(),l.normalized());
}

//Compute the perpendicular distance from the point p the the line l
//The result is a scalar 
float dist(Point2D p, Line2D l){
  return vee(p.normalized(),l.normalized());
}

//Compute the intersection point between lines l1 and l2
//You may assume the lines are not parallel
//The results is a a point that lies on both lines
Point2D intersect(Line2D l1, Line2D l2){
  auto hp = wedge(l1,l2);
  return Point2D(hp.x,hp.y).scale(1/hp.w);
}

//Compute the line that goes through the points p1 and p2
//The result is a line 
Line2D join(Point2D p1, Point2D p2){
  return vee(p1,p2);
}

//Compute the projection of the point p onto line l
//The result is the closest point to p that lies on line l
Point2D project(Point2D p, Line2D l){
  auto d = dot(l,p);
  return dot(d,l) + wedge(d,l);
}

//Compute the projection of the line l onto point p
//The result is a line that lies on point p in the same direction of l
Line2D project(Line2D l, Point2D p){
  auto d = dot(l,p);
  return dot(d,p) + wedge(d,p);
}

//Compute the angle point between lines l1 and l2 in radians
//You may assume the lines are not parallel
//The results is a scalar
float angle(Line2D l1, Line2D l2){
  return 0; //Wrong, fix me...
}

//Compute if the line segment p1->p2 intersects the line segment a->b
//The result is a boolean
bool segmentSegmentIntersect(Point2D p1, Point2D p2, Point2D a, Point2D b){
  return wedge(join(p1, p2), join(a, b)).w != 0.0;
}

//Compute if the point p lies inside the triangle t1,t2,t3
//Your code should work for both clockwise and counterclockwise windings
//The result is a bool
bool pointInTriangle(Point2D p, Point2D t1, Point2D t2, Point2D t3){
  return false; //Wrong, fix me...
}

//Compute the area of the triangle t1,t2,t3
//The result is a scalar
float areaTriangle(Point2D t1, Point2D t2, Point2D t3){
  return 0; //Wrong, fix me...
}

//Compute the distance from the point p to the triangle t1,t2,t3 as defined 
//by it's distance from the edge closest to p.
//The result is a scalar
//NOTE: There are some tricky cases to consider here that do not show up in the test cases!
float pointTriangleEdgeDist(Point2D p, Point2D t1, Point2D t2, Point2D t3){
  return 0; //Wrong, fix me...
}

//Compute the distance from the point p to the closest of three corners of
// the triangle t1,t2,t3
//The result is a scalar
float pointTriangleCornerDist(Point2D p, Point2D t1, Point2D t2, Point2D t3){
  return 0; //Wrong, fix me...
}

//Compute if the quad (p1,p2,p3,p4) is convex.
//Your code should work for both clockwise and counterclockwise windings
//The result is a boolean
bool isConvex_Quad(Point2D p1, Point2D p2, Point2D p3, Point2D p4){
  return false; //Wrong, fix me...
}

//Compute the reflection of the point p about the line l
//The result is a point
Point2D reflect(Point2D p, Line2D l){
  return Point2D(0,0); //Wrong, fix me...
}

//Compute the reflection of the line d about the line l
//The result is a line
Line2D reflect(Line2D d, Line2D l){
  return Line2D(0,0,0); //Wrong, fix me...
}

#endif
