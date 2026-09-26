#include "greeting.h"

#include "unity.h"

/*
 * Unity calls setUp/tearDown around every test case, so each test_*.c must
 * define them - each file is its own executable. Leave them empty when there
 * is nothing to prepare or clean up.
 */
void setUp(void) {}
void tearDown(void) {}

static void greeting_text_returns_the_greeting(void) {
    TEST_ASSERT_EQUAL_STRING("Hello, world!", greeting_text());
}

static void greeting_text_is_not_empty(void) {
    TEST_ASSERT_NOT_EQUAL('\0', greeting_text()[0]);
}

int main(void) {
    UNITY_BEGIN();

    RUN_TEST(greeting_text_returns_the_greeting);
    RUN_TEST(greeting_text_is_not_empty);

    return UNITY_END();
}
