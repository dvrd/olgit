package gitol

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
