package failz

import "core:os"
import "libs:ansi"

// This icons requires a nerd font installed to be displayed correctly
INFO := ansi.bold(ansi.colorize("  ", {80, 150, 225}))
ERROR := ansi.colorize("  ", {220, 20, 60})
WARNING := ansi.colorize("  ", {255, 210, 0})
MESSAGE := ansi.colorize("  ", {0, 144, 255})
DEBUG := ansi.colorize("  ", {204, 146, 255})
PROMPT := ansi.colorize(" 󰠗 ", {0, 144, 255})
BAIL := ansi.colorize("  ", {0, 144, 255})

@(init)
check_icons_enabled :: proc() {
	is_enabled := os.get_env("FAILZ_ICONS_ENABLED") == "true"
	if !is_enabled {
		INFO = "[INFO]"
		ERROR = "[ERROR]"
		WARNING = "[WARNING]"
		MESSAGE = "[MESSAGE]"
		DEBUG = "[DEBUG]"
		PROMPT = "[PROMPT]"
		BAIL = "[BAIL]"
	}
}
