/**
 * @file greeting.h
 * @brief Public interface of the greeting module.
 *
 * Placeholder module demonstrating the library/executable split: the logic
 * lives in the core library so that both `main` and the tests can reach it.
 * Replace it with your own code.
 */

#ifndef GREETING_H
#define GREETING_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Returns the greeting printed by the application.
 *
 * @return A NUL-terminated string with static storage duration. The caller
 *         does not own it and must not free or modify it.
 */
const char *greeting_text(void);

#ifdef __cplusplus
}
#endif

#endif /* GREETING_H */
