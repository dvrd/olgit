package gitol

import "core:bytes"
import "core:compress/zlib"
import "core:fmt"
import "core:os"
import "core:path/slashpath"
import "core:sort"
import "core:strconv"
import "core:strings"
import "libs:failz"

PWD := os.get_current_directory()
GITIGNORE_PATH := slashpath.join({PWD, ".gitignore"})

ObjectKind :: enum {
	Tree,
	Blob,
	Commit,
}

Object :: struct {
	kind: ObjectKind,
	buf:  bytes.Buffer,
}

new_object :: proc(kind: string, buf: bytes.Buffer) -> ^Object {
	object := new(Object)
	switch kind {
	case "tree":
		object^ = Object{.Tree, buf}
	case "commit":
		object^ = Object{.Commit, buf}
	case "blob":
		object^ = Object{.Blob, buf}
	}
	return object
}

destroy_object :: proc(object: ^Object) {
	bytes.buffer_destroy(&object.buf)
	free(object)
}

read_object :: proc(obj_hash: string) -> (obj: ^Object, err: failz.Error) {
	using failz

	obj_hash_path := slashpath.join({GIT_OBJECTS_DIR, obj_hash[:2], obj_hash[2:]})
	defer delete(obj_hash_path)

	contents, success := os.read_entire_file(obj_hash_path)
	defer delete(contents)
	if !success do return nil, SystemError{.FileRead, "could not read object file"}

	buf: bytes.Buffer
	zlib.inflate(contents, &buf)

	header := bytes.buffer_read_string(&buf, 0) or_return
	split_header := strings.split(header, " ")
	defer delete(split_header)

	if len(split_header) != 2 do return nil, AppError{.WrongFormat, ".git/objects file header corrupted"}

	kind := split_header[0]
	size := strconv.atoi(split_header[1])
	if size != bytes.buffer_length(&buf) { 	// remember this calculates from the offset
		msg := fmt.tprintf(
			".git/objects file was not the expected size (expected: %d, actual: %d)",
			size,
			bytes.buffer_length(&buf),
		)
		return nil, AppError{.InvalidSize, msg}
	}

	return new_object(kind, buf), nil
}

hash_object :: proc(file_path: string, should_write := false) -> (file_hash: []byte) {
	using failz

	ensure(os.exists(file_path), fmt.tprintf("object `%s` does not exist", file_path))

	blob_content, err := read_blob_from_path(file_path)
	catch(err, fmt.tprintf("failed to read blob from file `%s`", file_path))
	defer delete(blob_content)

	file_hash = hash_blob(blob_content)

	if should_write do catch(write_object(file_hash, blob_content))

	return
}
