package failz

import "libs:ansi"

purple :: proc(str: string) -> string {
	return ansi.colorize(str, {204, 146, 255})
}

