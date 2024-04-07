package gitol

import "core:bytes"
import "core:encoding/hex"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "libs:clodin"
import "libs:failz"

print_tree :: proc(object: ^Object) {
	using failz

	err: failz.Error
	entry_info: string
	entry_contents: []byte
	entry_hash: string
	mode_n_name: []string
	mode, name: string
	obj_ref: ^Object

	for !bytes.buffer_is_empty(&object.buf) {
		entry_info, err = bytes.buffer_read_string(&object.buf, 0)
		catch(err, "failed to read tree entry info")

		entry_contents = bytes.buffer_next(&object.buf, 20)
		catch(err, "failed to read object contents")

		entry_hash = transmute(string)hex.encode(entry_contents)
		defer delete(entry_hash)

		mode_n_name = strings.split_n(entry_info, " ", 2)
		defer delete(mode_n_name)

		mode = mode_n_name[0]
		name = mode_n_name[1]

		obj_ref, err = read_object(entry_hash)
		catch(err, fmt.tprint(entry_hash))
		defer destroy_object(obj_ref)

		output := fmt.tprintfln(
			"%6d %s %s\t%s",
			strconv.atoi(mode),
			strings.to_lower(fmt.tprint(obj_ref.kind)),
			entry_hash,
			name,
		)
		catch(write_stdout(transmute([]byte)output))
	}
}

print_commit :: proc(object: ^Object, print_commit_tree: bool) {
	using failz

	if print_commit_tree {
		kind, err := bytes.buffer_read_string(&object.buf, ' ')
		catch(err, "failed to read commit tree info")

		kind = strings.trim_space(kind)
		if kind == "tree" {
			tree_hash := bytes.buffer_next(&object.buf, 40)
			print_object(transmute(string)tree_hash)
		} else {
			fmt.printfln("fatal: not a tree object (found: %s)", kind)
		}
	} else {
		file_contents := bytes.buffer_to_bytes(&object.buf)
		defer delete(file_contents)
		catch(write_stdout(file_contents))
	}
}

print_blob :: proc(object: ^Object) {
	using failz

	file_contents := bytes.buffer_to_bytes(&object.buf)
	defer delete(file_contents)
	catch(write_stdout(file_contents))
}

print_object :: proc(object_hash: string, print_commit_tree := false) {
	using failz

	object, err := read_object(object_hash)
	catch(err, "Could not read object from hash")
	defer destroy_object(object)

	switch object.kind {
	case .Blob:
		print_blob(object)
	case .Tree:
		print_tree(object)
	case .Commit:
		print_commit(object, print_commit_tree)
	case:
		msg := fmt.tprint("Unknown object type:", object.kind)
		catch(write_stdout(transmute([]byte)msg))
	}
}
