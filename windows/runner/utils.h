#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both the runner and the Flutter library.
void CreateAndAttachConsole();

// Takes a command line argument string and returns the parsed list of arguments.
std::vector<std::string> GetCommandLineArguments();

// Encodes a wide (UTF-16) string to a UTF-8 string.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

#endif  // RUNNER_UTILS_H_
