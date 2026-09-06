#ifndef TABLO_TEST_FRAMEWORK_H
#define TABLO_TEST_FRAMEWORK_H

#include <functional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace tablo::test {

struct TestCase {
  std::string name;
  std::function<void()> function;
};

inline std::vector<TestCase>& registry() {
  static std::vector<TestCase> tests;
  return tests;
}

class Registrar {
 public:
  Registrar(std::string name, std::function<void()> function) {
    registry().push_back({std::move(name), std::move(function)});
  }
};

class Failure : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

inline void check(bool condition, const char* expression, const char* file, int line) {
  if (condition) {
    return;
  }

  std::ostringstream message;
  message << file << ':' << line << ": check failed: " << expression;
  throw Failure(message.str());
}

template <typename Actual, typename Expected>
void checkEqual(const Actual& actual, const Expected& expected, const char* actualExpression,
                const char* expectedExpression, const char* file, int line) {
  if (actual == expected) {
    return;
  }

  std::ostringstream message;
  message << file << ':' << line << ": expected " << actualExpression << " == "
          << expectedExpression << ", but got " << actual << " and " << expected;
  throw Failure(message.str());
}

}  // namespace tablo::test

#define TABLO_TEST_CONCAT_INNER(left, right) left##right
#define TABLO_TEST_CONCAT(left, right) TABLO_TEST_CONCAT_INNER(left, right)

#define TABLO_TEST(name)                                                                     \
  static void TABLO_TEST_CONCAT(tabloTestFunction, __LINE__)();                              \
  static ::tablo::test::Registrar TABLO_TEST_CONCAT(tabloTestRegistrar, __LINE__)(           \
      name, TABLO_TEST_CONCAT(tabloTestFunction, __LINE__));                                 \
  static void TABLO_TEST_CONCAT(tabloTestFunction, __LINE__)()

#define TABLO_CHECK(expression) \
  ::tablo::test::check(static_cast<bool>(expression), #expression, __FILE__, __LINE__)

#define TABLO_CHECK_EQ(actual, expected) \
  ::tablo::test::checkEqual((actual), (expected), #actual, #expected, __FILE__, __LINE__)

#endif
