package gitol

import "core:bytes"
import "core:encoding/hex"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "libs:failz"

print_blob :: proc(object: Blob) {
	using failz

	catch(write_stdout(object.data))
}

print_object :: proc(object_hash: string, print_commit_tree := false) {
	using failz

	object, err := read_object(object_hash)
	catch(err, "Could not read object from hash")
	defer destroy_object(object)

	switch kind in object {
	case Blob:
		print_blob(kind)
	case Tree:
		print_tree(kind)
	case Commit:
		print_commit(kind, print_commit_tree)
	case:
		msg := fmt.tprint("Unknown object type:", object)
		catch(write_stdout(transmute([]byte)msg))
	}
}
