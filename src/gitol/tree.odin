package gitol

import "core:bytes"
import "core:encoding/hex"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "libs:failz"

TreeEntry :: struct {
	mode: int,
	name: string,
	hash: string,
}

Tree :: struct {
	hash:    string,
	entries: []TreeEntry,
}

new_tree :: proc(hash: string, data: []byte) -> Tree {
	using failz
	err: Error

	buffer: bytes.Buffer
	bytes.buffer_init(&buffer, data)

	entries := make([dynamic]TreeEntry)
	info: string
	entry_hash: []byte
	encoded_hash: string
	mode: string
	match: string
	name: string

	for !bytes.buffer_is_empty(&buffer) {
		info, err = bytes.buffer_read_string(&buffer, 0)
		catch(err, "failed to read tree entry info")

		entry_hash = bytes.buffer_next(&buffer, 20)
		catch(err, "failed to read tree entry hash")

		encoded_hash = transmute(string)hex.encode(entry_hash)
		defer delete(entry_hash)

		mode, match, name = strings.partition(info, " ")
		defer delete(mode)
		defer delete(match)
		defer delete(name)

		append(&entries, TreeEntry{strconv.atoi(mode), name, encoded_hash})
	}

	return Tree{hash, entries[:]}
}

print_tree :: proc(tree: Tree) {
	using failz

	err: Error
	entry_obj: ^Object
	for entry in tree.entries {
		entry_obj, err = read_object(entry.hash)
		catch(err, fmt.tprint(entry.hash))
		defer destroy_object(entry_obj)

		blob, ok := entry_obj.(Blob)
		kind := ok ? "blob" : "tree"

		output := fmt.tprintfln("%6d %s %s\t%s", entry.mode, kind, entry.hash, entry.name)
		catch(write_stdout(transmute([]byte)output))
	}
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


	//  NOTE: this implementation mimics git's `base_name_compare`
	//  -> https://sourcegraph.com/github.com/git/git@19981daefd7c147444462739375462b49412ce33/-/blob/tree.c?L99
	sort_files :: proc(a, b: os.File_Info) -> int {
		common_len := len(a.name) < len(b.name) ? len(a.name) - 1 : len(b.name) - 1
		cmp := strings.compare(a.name[:common_len], b.name[:common_len])

		if cmp != 0 do return cmp

		c1 := a.is_dir ? '/' : a.name[common_len]
		c2 := b.is_dir ? '/' : b.name[common_len]

		return sort.compare_u8s(c1, c2)
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

	tree_obj := bytes.concatenate({header, tree_contents})
	defer delete(tree_obj)

	tree_hash := hash_blob(tree_obj)
	defer delete(tree_hash)

	catch(write_object(tree_hash, tree_obj))

	return bytes.clone(tree_hash)
}
