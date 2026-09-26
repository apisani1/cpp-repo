#include "greeting.h"

#include "unity.h"

#include <string_view>

void setUp() {}
void tearDown() {}

namespace {

void greeting_is_usable_from_cpp() {
    const std::string_view greeting{greeting_text()};
    // greeting_text() guarantees NUL termination; string_view alone does not.
    TEST_ASSERT_EQUAL_STRING("Hello, world!", greeting.data());
    TEST_ASSERT_FALSE(greeting.empty());
}

} // namespace

int main() {
    UNITY_BEGIN();
    RUN_TEST(greeting_is_usable_from_cpp);
    return UNITY_END();
}
