package failz

import "core:fmt"
import "core:os"

ensure :: proc(is_correct: bool, msg: string, args: ..any) {
	if !is_correct {
		fmt.println(ERROR, fmt.tprintf(msg, ..args))
		os.exit(1)
	}
}
