package gitol

import "core:c/libc"
import "core:os"
import "core:path/slashpath"
import "core:strings"

get_git_mode :: proc(fi: os.File_Info) -> (mode: int) {
	mode = 100644 // regular file
	if fi.is_dir {
		mode = 40000 // directory
	} else if fi.mode == os.File_Mode_Sym_Link {
		mode = 120000 // symlink
	} else if fi.mode & 0o111 != 0 { 	// this checks if at least 1 exec bit is set
		mode = 100755 // executable
	}

	return
}

should_ignore :: proc(target: string) -> bool {
	if slashpath.base(target) == ".git" do return true

	if os.exists(GITIGNORE_PATH) {
		contents, success := os.read_entire_file(".gitignore")
		defer delete(contents)
		if !success do return false

		prefix := strings.concatenate({PWD, "/"})
		defer delete(prefix)

		target := strings.trim_prefix(target, prefix)
		patterns := transmute(string)contents
		for pattern in strings.split_iterator(&patterns, "\n") {
			matched, _ := slashpath.match(pattern, target)
			if matched do return true
		}
	}

	return false
}

timezone :: proc() -> int {
	epoch_plus_11h: libc.time_t = 60 * 60 * 11
	local_time := libc.localtime(&epoch_plus_11h).tm_hour
	gm_time := libc.gmtime(&epoch_plus_11h).tm_hour
	return cast(int)(local_time - gm_time)
}
