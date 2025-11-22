#include <iostream>
#include <vector>
#include <fstream>


struct Cell { char c; }; // store symbol
std::vector<Cell> grid;
int W,H;

void loadMap(const std::string &path){
  std::ifstream in(path);
  in>>W>>H;
  std::string row;
  grid.resize(W*H);
  for(int y=0;y<H;y++){
    in>>row;
    for(int x=0;x<W;x++) grid[y*W + x].c = row[x];
  }
}
