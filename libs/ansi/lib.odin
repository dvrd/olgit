package ansi

import "core:fmt"
import "core:strings"
import "core:testing"

END :: "\x1b[0m"

// STYLING
BOLD :: "\x1b[1m"
UNDERLINE :: "\x1b[4m"

bold :: proc(str: string) -> string {
	return strings.concatenate({BOLD, str, END})
}

underline :: proc(str: string) -> string {
	return strings.concatenate({UNDERLINE, str, END})
}

// COLORS
FG_BLACK :: "\x1B[30m"
FG_RED :: "\x1B[31m"
FG_GREEN :: "\x1B[32m"
FG_YELLOW :: "\x1B[33m"
FG_BLUE :: "\x1B[34m"
FG_MAGENTA :: "\x1B[35m"
FG_CYAN :: "\x1B[36m"
FG_WHITE :: "\x1B[37m"
BG_BLACK :: "\x1B[40m"
BG_RED :: "\x1B[41m"
BG_GREEN :: "\x1B[42m"
BG_YELLOW :: "\x1B[43m"
BG_BLUE :: "\x1B[44m"
BG_MAGENTA :: "\x1B[45m"
BG_CYAN :: "\x1B[46m"
BG_WHITE :: "\x1B[47m"

Color :: [3]byte
colorize :: proc(str: string, color: Color) -> string {
	color := fmt.tprintf("\x1B[38;2;%d;%d;%dm", color.r, color.g, color.b)
	return strings.concatenate({color, str, END})
}

@(test)
use_colors_test :: proc(t: ^testing.T) {
	using testing

	expect(
		t,
		bold("Hello, world!") == "\x1B[1mHello, world!\x1B[0m",
		fmt.tprintf("bold(\"Hello, world!\") == %s", bold("Hello, world!")),
	)

	expect(
		t,
		underline("Hello, world!") == "\x1B[4mHello, world!\x1B[0m",
		fmt.tprintf("underline(\"Hello, world!\") == %s", underline("Hello, world!")),
	)

	expect(
		t,
		colorize("Hello, world!", {255, 0, 0}) == "\x1B[38;2;255;0;0mHello, world!\x1B[0m",
		fmt.tprintf(
			"colorize(\"Hello, world!\", {255, 0, 0}) == %v",
			raw_data(colorize("Hello, world!", {255, 0, 0})),
		),
	)
}
