#include "test_framework.h"

#include <tablog.h>
#include <tablog_registry.h>

#include <algorithm>
#include <exception>
#include <iostream>
#include <memory>
#include <string>

namespace {

void configureQuietLogger() {
  tablog::Tablog::LoglevelConfig hidden;
  hidden.visible = false;

  auto logger = std::make_shared<tablog::Tablog>();
  logger->configure("Tablo-Node-Test", false, false, false, false, hidden, hidden, hidden, hidden,
                    hidden);
  tablog::TablogRegistry::getInstance().registerLogger("Tablo-Node", logger);
}

void printUsage(const char* program) {
  std::cout << "Usage: " << program << " [--list] [name-filter]\n"
            << "Run every test, list available tests, or run tests whose names contain a filter.\n";
}

}  // namespace

int main(int argc, char** argv) {
  configureQuietLogger();

  auto& tests = tablo::test::registry();
  std::sort(tests.begin(), tests.end(), [](const auto& left, const auto& right) {
    return left.name < right.name;
  });

  std::string filter;
  if (argc > 1) {
    const std::string argument = argv[1];
    if (argument == "--help" || argument == "-h") {
      printUsage(argv[0]);
      return 0;
    }
    if (argument == "--list") {
      for (const auto& test : tests) {
        std::cout << test.name << '\n';
      }
      return 0;
    }
    filter = argument;
  }

  int selected = 0;
  int failed = 0;
  for (const auto& test : tests) {
    if (!filter.empty() && test.name.find(filter) == std::string::npos) {
      continue;
    }

    ++selected;
    try {
      test.function();
      std::cout << "[PASS] " << test.name << '\n';
    } catch (const std::exception& exception) {
      ++failed;
      std::cout << "[FAIL] " << test.name << "\n       " << exception.what() << '\n';
    } catch (...) {
      ++failed;
      std::cout << "[FAIL] " << test.name << "\n       unknown exception\n";
    }
  }

  if (selected == 0) {
    std::cout << "No tests matched '" << filter << "'. Use --list to see available tests.\n";
    return 2;
  }

  std::cout << "\n" << (selected - failed) << '/' << selected << " tests passed.\n";
  return failed == 0 ? 0 : 1;
}
