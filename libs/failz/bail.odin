package failz

import "core:fmt"
import "core:os"

bail :: proc(did_fail := true, msg: string, args: ..any) {
	if did_fail {
		fmt.println(BAIL, fmt.tprintf(msg, ..args))
		os.exit(1)
	}
}
