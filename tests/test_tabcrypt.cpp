#include "test_framework.h"

#include <tabcrypt.h>

#include <string>

TABLO_TEST("tabcrypt round-trips text") {
  const std::string secret = "correct horse battery staple";
  const std::string message = "Tablo: spaces, punctuation, and 1234";

  TABLO_CHECK_EQ(tabcrypt::decrypt(secret, tabcrypt::encrypt(secret, message)), message);
}

TABLO_TEST("tabcrypt round-trips an empty message") {
  const std::string secret = "secret";
  const std::string message;

  TABLO_CHECK_EQ(tabcrypt::decrypt(secret, tabcrypt::encrypt(secret, message)), message);
}
