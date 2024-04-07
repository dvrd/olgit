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

TREE_HEAD_BASE :: []byte{'t', 'r', 'e', 'e', ' '}
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
	if size != bytes.buffer_length(&buf) {
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

write_tree :: proc(from, to: string) -> []byte {
	using failz

	fd, errno := os.open(from)
	catch(Errno(errno), fmt.tprintf("failed to open `%s`", from))
	defer os.close(fd)

	fis: []os.File_Info
	defer os.file_info_slice_delete(fis)
	fis, errno = os.read_dir(fd, -1)
	catch(Errno(errno), fmt.tprintf("failed to read `%s`", from))


	// NOTE: details about this sort -> https://sourcegraph.com/github.com/git/git@19981daefd7c147444462739375462b49412ce33/-/blob/tree.c?L99
	sort_files :: proc(a, b: os.File_Info) -> int {
		common_len := len(a.name) < len(b.name) ? len(a.name) - 1 : len(b.name) - 1
		cmp := strings.compare(a.name[:common_len], b.name[:common_len])

		if cmp != 0 do return cmp

		c1 := a.name[common_len]
		if a.is_dir do c1 = '/'

		c2 := b.name[common_len]
		if b.is_dir do c2 = '/'

		return c1 < c2 ? -1 : c1 > c2 ? 1 : 0
	}
	sort.bubble_sort_proc(fis, sort_files)

	entries: bytes.Buffer
	defer bytes.buffer_destroy(&entries)

	mode: int
	entry, file_hash, kind: []byte
	for fi in fis {
		if should_ignore(fi.fullpath) do continue

		if fi.is_dir {
			file_hash = write_tree(fi.fullpath, to)
			if len(file_hash) == 0 do continue
		} else {
			file_hash = hash_object(fi.fullpath, should_write = true)
		}
		ensure(
			len(file_hash) == 20,
			fmt.tprintf("`%s` hash is too short: %d", fi.fullpath, len(file_hash)),
		)
		defer delete(file_hash)

		mode = get_git_mode(fi)
		mode_n_name := transmute([]byte)fmt.tprintf("%d %s", mode, fi.name)
		entry = bytes.concatenate({mode_n_name, {0}, file_hash})
		defer delete(entry)

		bytes.buffer_write(&entries, entry)
	}

	if bytes.buffer_length(&entries) == 0 do return []byte{}

	tree_contents := bytes.buffer_to_bytes(&entries)
	file_size := transmute([]byte)fmt.tprint(len(tree_contents))

	header := bytes.concatenate({TREE_HEAD_BASE, file_size, {0}})
	defer delete(header)

	tree_blob := bytes.concatenate({header, tree_contents})
	defer delete(tree_blob)

	tree_hash := hash_blob(tree_blob)
	defer delete(tree_hash)

	catch(write_object(tree_hash, tree_blob))

	return bytes.clone(tree_hash)
}
