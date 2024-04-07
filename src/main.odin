package cli

import "core:bytes"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"
import "libs:clodin"
import "libs:failz"
import "src:gitol"

USAGE :: `
init			- initialize a new git repository
cat-file	- read from a git hash
hash-object	- write to a git hash
ls-tree		- list the contents of a tree
write-tree	- write a tree to the git database
`
GIT_OBJECTS_DIR :: ".git/objects"

write_stdout :: proc(data: []byte) -> failz.Error {
	stdout := os.stream_from_handle(os.stdout)

	bits, err := io.write(stdout, data)
	if err != nil {
		err_msg := fmt.tprintf("[%v] Could not write to stdout", failz.purple(fmt.tprint(err)))
		return failz.SystemError{.FileWrite, err_msg}
	}
	return nil
}

write_to_file :: proc(path: string, content: []byte) -> failz.Errno {
	using failz
	fd, err := os.open(
		path,
		os.O_RDWR | os.O_CREATE,
		os.S_IFREG | os.S_IRUSR | os.S_IRGRP | os.S_IROTH,
	)
	if err != os.ERROR_NONE do return Errno(err)
	defer os.close(fd)

	_, err = os.write(fd, content)
	if err != os.ERROR_NONE do return Errno(err)

	return .ERROR_NONE
}

main :: proc() {
	using failz
	using clodin

	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	start_os_args()

	input_cmd := pos_arg(parsing_proc, nil, "COMMAND", USAGE)

	if _, is_init := input_cmd.(Init); !is_init {
		ensure(
			os.exists(".git"),
			"fatal: not a git repository (or any of the parent directories): .git",
		)
	}

	switch data in input_cmd {
	case nil:
		display_usage()
	case Init:
		bail(os.make_directory(".git") != 0, "git already initialized")
		bail(os.make_directory(".git/objects") != 0, "git already initialized")
		bail(os.make_directory(".git/refs") != 0, "git already initialized")

		file_contents := "ref: refs/heads/main\n"
		catch(write_to_file(".git/HEAD", transmute([]byte)file_contents))

		out := "Initialized empty git repository\n"
		catch(write_stdout(transmute([]byte)out))
	case Cat_File:
		ensure(data.pretty, "missing -p (pretty print) flag")

		gitol.print_object(data.hash)
	case Hash_Object:
		file_hash := gitol.hash_object(data.file, data.write)
		defer delete(file_hash)

		encoded_hash := hex.encode(file_hash)
		defer delete(encoded_hash)

		out := bytes.concatenate({encoded_hash, {'\n'}})
		defer delete(out)
		catch(write_stdout(out))
	case Ls_Tree:
		gitol.print_object(data.hash, print_commit_tree = true)
	case Write_Tree:
		pwd := os.get_current_directory()
		defer delete(pwd)

		tree_hash := gitol.write_tree(pwd, GIT_OBJECTS_DIR)
		defer delete(tree_hash)

		encoded_hash := hex.encode(tree_hash)
		defer delete(encoded_hash)

		out := bytes.concatenate({encoded_hash, {'\n'}})
		defer delete(out)
		catch(write_stdout(out))
	}

	finish()
}
