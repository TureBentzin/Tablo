#include "test_framework.h"

#include <viewport_utils.h>

#include <vector>

namespace {

ttp2::Networking::Viewport viewportAt(int xStart, int marker) {
  ttp2::Networking::Viewport viewport;
  viewport.xStart = xStart;
  viewport.xEnd = marker;
  return viewport;
}

}  // namespace

TABLO_TEST("master orders every viewport by its starting row") {
  auto sorted = tablo::master::sortViewportsByX(
      {viewportAt(30, 3), viewportAt(10, 1), viewportAt(40, 4), viewportAt(20, 2)});

  TABLO_CHECK_EQ(sorted.size(), static_cast<std::size_t>(4));
  TABLO_CHECK_EQ(sorted[0].xStart, 10);
  TABLO_CHECK_EQ(sorted[1].xStart, 20);
  TABLO_CHECK_EQ(sorted[2].xStart, 30);
  TABLO_CHECK_EQ(sorted[3].xStart, 40);
}

TABLO_TEST("master viewport ordering is stable") {
  auto sorted = tablo::master::sortViewportsByX(
      {viewportAt(20, 1), viewportAt(10, 2), viewportAt(20, 3)});

  TABLO_CHECK_EQ(sorted[0].xEnd, 2);
  TABLO_CHECK_EQ(sorted[1].xEnd, 1);
  TABLO_CHECK_EQ(sorted[2].xEnd, 3);
}

TABLO_TEST("master viewport ordering handles empty input") {
  auto sorted = tablo::master::sortViewportsByX({});
  TABLO_CHECK(sorted.empty());
}
