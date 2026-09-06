#ifndef TABLO_VIEWPORT_UTILS_H
#define TABLO_VIEWPORT_UTILS_H

#include <networking.h>

#include <algorithm>
#include <vector>

namespace tablo::master {

inline std::vector<ttp2::Networking::Viewport> sortViewportsByX(
    std::vector<ttp2::Networking::Viewport> viewports) {
  std::stable_sort(viewports.begin(), viewports.end(), [](const auto& left, const auto& right) {
    return left.xStart < right.xStart;
  });
  return viewports;
}

}  // namespace tablo::master

#endif
