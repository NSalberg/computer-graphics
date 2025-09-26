// UMN CSCI 5607 2D Geometry Library Homework [HW0]
// TODO: For the 18 functions below, replace their sub function with a working
// version that matches the desciption.

#ifndef GEOM_LIB_H
#define GEOM_LIB_H

#include "multivector.h"
#include "pga.h"
#include "primitives.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <vector> // needed for std::vector

// Displace a point p on the direction d
// The result is a point
Point2D move(Point2D p, Dir2D d) {
  return Point2D(p.x + d.x, p.y + d.y); // Wrong, fix me...
}

// Compute the displacement vector between points p1 and p2
// The result is a direction
Dir2D displacement(Point2D p1, Point2D p2) {
  return Dir2D(0, 0); // Wrong, fix me...
}

// Compute the distance between points p1 and p2
// The result is a scalar
float dist(Point2D p1, Point2D p2) {
  return vee(p1.normalized(), p2.normalized()).magnitude();
}

// Compute the perpendicular distance from the point p the the line l
// The result is a scalar
float dist(Line2D l, Point2D p) {
  return std::abs(vee(p.normalized(), l.normalized()));
}

// Compute the perpendicular distance from the point p the the line l
// The result is a scalar
float dist(Point2D p, Line2D l) {
  return std::abs(vee(p.normalized(), l.normalized()));
}

// Compute the intersection point between lines l1 and l2
// You may assume the lines are not parallel
// The results is a a point that lies on both lines
Point2D intersect(Line2D l1, Line2D l2) {
  auto hp = wedge(l1, l2);
  return Point2D(hp.x, hp.y).scale(1 / hp.w);
}

// Compute the line that goes through the points p1 and p2
// The result is a line
Line2D join(Point2D p1, Point2D p2) { return vee(p1, p2); }

// Compute the projection of the point p onto line l
// The result is the closest point to p that lies on line l
Point2D project(Point2D p, Line2D l) {
  auto d = dot(l, p);
  return dot(d, l) + wedge(d, l);
}

// Compute the projection of the line l onto point p
// The result is a line that lies on point p in the same direction of l
Line2D project(Line2D l, Point2D p) {
  auto d = dot(l, p);
  return dot(d, p) + wedge(d, p);
}

// Compute the angle point between lines l1 and l2 in radians
// You may assume the lines are not parallel
// The results is a scalar
float angle(Line2D l1, Line2D l2) {

  return std::acos(dot(l1.normalized(), l2.normalized()));
}

// Compute if the line segment p1->p2 intersects the line segment a->b
// The result is a boolean
bool segmentSegmentIntersect(Point2D p1, Point2D p2, Point2D a, Point2D b) {
  // given two line segements (p1,p2), (p3,p4) the polygon formed by
  // (p1,p3,p2,p4) always be convex if the lines intersect
  auto l1 = join(a, b);
  auto dir1 = vee(p1, l1);
  auto dir2 = vee(p2, l1);
  // printf("segseg: d1:%f d2:%f\n", dir1, dir2);

  auto l2 = join(p1, p2);
  auto dir3 = vee(a, l2);
  auto dir4 = vee(b, l2);
  // printf("segseg: d3:%f d4:%f\n", dir3, dir4);
  if (dir1 * dir2 >= 0 or dir3 * dir4 >= 0)
    return false;
  return true;
}

// Compute if the point p lies inside the triangle t1,t2,t3
// Your code should work for both clockwise and counterclockwise windings
// The result is a bool
bool pointInTriangle(Point2D p, Point2D t1, Point2D t2, Point2D t3) {
  float d1 = vee(p, join(t1, t2));
  float d2 = vee(p, join(t2, t3));
  float d3 = vee(p, join(t3, t1));
  if (d1 * d2 >= 0 and d2 * d3 >= 0)
    return true;
  return false;
}

bool pointInPoly(Point2D p, const std::vector<Point2D> &poly) {
  int n = poly.size();
  if (n < 3)
    return false; // not a polygon
  float sin = sign(vee(p, join(poly[0], poly[(1) % n])));

  for (int i = 1; i < n; ++i) {
    auto edge = vee(p, join(poly[i], poly[(i + 1) % n]));
    if (sin != sign(edge)) {
      return false;
    }
  }

  return true;
}

// Compute the area of the triangle t1,t2,t3
// The result is a scalar
float areaTriangle(Point2D t1, Point2D t2, Point2D t3) {
  return vee(vee(t1.normalized(), t2.normalized()), t3.normalized()) / 2;
}

float pointSegmentDistance(Point2D p, Point2D a, Point2D b) {
  float t = dot(vee(a,p), vee(a,b).normalized());
  t = clamp(t, 0, vee(a,b).magnitude());
  MultiVector fasdf = t*(b-a).normalized();
  Point2D p_proj = fasdf.add(a);
  return dist(p_proj,p);
}

// Compute the distance from the point p to the triangle t1,t2,t3 as defined
// by it's distance from the edge closest to p.
// The result is a scalar
// NOTE: There are some tricky cases to consider here that do not show up in the
// test cases!
float pointPolyEdgeDist(Point2D p, const std::vector<Point2D> &poly) {

  int n = poly.size();
  if (n < 3)
    return false; // not a polygon

  float d = pointSegmentDistance(p,poly[0], poly[1]);
  for (int i = 1; i < n; ++i) {
    d = std::min(d, pointSegmentDistance(p, poly[i], poly[(i + 1) % n]));
  }
  return d;
}

// Compute the distance from the point p to the triangle t1,t2,t3 as defined
// by it's distance from the edge closest to p.
// The result is a scalar
// NOTE: There are some tricky cases to consider here that do not show up in the
// test cases!
float pointTriangleEdgeDist(Point2D p, Point2D t1, Point2D t2, Point2D t3) {
  if (pointInTriangle(p, t1, t2, t3)) {
    float d1 = dist(p, join(t1, t2));
    float d2 = dist(p, join(t2, t3));
    float d3 = dist(p, join(t3, t1));

    return std::min(std::min(d1, d2), d3);
  }

  // need a way to find the closest point to a line segment
  // the closest edge has to involve the line segment of the closest triable
  // point
  Point2D points[3] = {t1, t2, t3};

  auto dot1 = dot(join(p, points[0]).normalized(),
                  join(points[0], points[1]).normalized());
  auto dot2 = dot(join(p, points[0]).normalized(),
                  join(points[0], points[2]).normalized());
  // printf("dot1 %f, dot2 %f \n", dot1, dot2);
  if (dot1 < 0.0f) {
    return dist(p.normalized(), join(points[0], points[1]).normalized());
  } else if (dot2 < 0.0f) {
    return dist(p.normalized(), join(points[0], points[2]).normalized());
  } else {
    return dist(p.normalized(), points[0].normalized());
  }
}

float pointPolyCornerDist(Point2D p, const std::vector<Point2D> &poly) {
  int n = poly.size();
  if (n < 3)
    return -1.0; // not a polygon
  float dist = join(p, poly[0]).magnitude();

  for (int i = 1; i < n; ++i) {
    dist = std::min(dist, join(p, poly[i]).magnitude());
  }
  return dist;
}

// Compute the distance from the point p to the closest of three corners of
//  the triangle t1,t2,t3
// The result is a scalar
float pointTriangleCornerDist(Point2D p, Point2D t1, Point2D t2, Point2D t3) {
  float m1 = join(p, t1).magnitude();
  float m2 = join(p, t2).magnitude();
  float m3 = join(p, t3).magnitude();
  return std::min(std::min(m1, m2), m3);
}

// Compute if the quad (p1,p2,p3,p4) is convex.
// Your code should work for both clockwise and counterclockwise windings
// The result is a boolean
bool isConvex_Quad(Point2D p1, Point2D p2, Point2D p3, Point2D p4) {
  auto a1 = areaTriangle(p1, p2, p3) > 0;
  auto a2 = areaTriangle(p2, p3, p4) > 0;
  auto a3 = areaTriangle(p3, p4, p1) > 0;
  auto a4 = areaTriangle(p4, p1, p2) > 0;

  if (a1 == a2 and a2 == a3 and a3 == a4)
    return true;

  return false; // Wrong, fix me...
}

// Compute the reflection of the point p about the line l
// The result is a point
Point2D reflect(Point2D p, Line2D l) {
  MultiVector c_a_para = project(p, l);
  MultiVector c_a_perp = MultiVector(p) - c_a_para;
  return Point2D(c_a_perp - c_a_para);
}

// Compute the reflection of the line d about the line l
// The result is a line
Line2D reflect(Line2D d, Line2D l) {
  MultiVector l_mv =
      MultiVector(l).normalized(); // Convert reflection line to multivector
  MultiVector reflected = l_mv.mul(-1) * d * l_mv.reverse();
  return Line2D(reflected);
}

#endif
