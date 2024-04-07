package gitol

import "core:bytes"
import "core:encoding/hex"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:sort"
import "core:strings"
import "libs:failz"
import v_zlib "vendor:zlib"

GIT_OBJECTS_DIR :: ".git/objects"

BLOB_HEAD_BASE :: []byte{'b', 'l', 'o', 'b', ' '}
TREE_HEAD_BASE :: []byte{'t', 'r', 'e', 'e', ' '}
COMMIT_HEAD_BASE :: []byte{'c', 'o', 'm', 'm', 'i', 't', ' '}

write_object :: proc(file_hash, content: []byte, target_dir := GIT_OBJECTS_DIR) -> failz.Error {
	using failz

	src_len := cast(u64)len(content)
	compressed_len := v_zlib.compressBound(src_len)
	compressed := make([]byte, compressed_len)
	defer delete(compressed)

	z_ok := v_zlib.compress(raw_data(compressed), &compressed_len, raw_data(content), src_len)
	if z_ok != v_zlib.OK {
		return AppError{.Compression, string(v_zlib.zError(z_ok))}
	}

	encoded_hash := transmute(string)hex.encode(file_hash)
	defer delete(encoded_hash)

	target_dir := filepath.join({target_dir, encoded_hash[:2]})
	defer delete(target_dir)

	if !os.exists(target_dir) {
		errno := os.make_directory(target_dir)
		if errno != os.ERROR_NONE do return Errno(errno)
	}

	target_file := filepath.join({target_dir, encoded_hash[2:]})
	defer delete(target_file)

	if !os.exists(target_file) {
		write_to_file(target_file, compressed) or_return
	}

	return nil
}

write_blob :: proc(content: []byte, size: i64) -> []byte {
	buf: bytes.Buffer

	bytes.buffer_write(&buf, BLOB_HEAD_BASE)
	bytes.buffer_write_string(&buf, fmt.tprint(size))
	bytes.buffer_write(&buf, {0})
	bytes.buffer_write(&buf, content)

	blob_obj := bytes.buffer_to_bytes(&buf)

	return blob_obj
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

write_commit :: proc(tree_hash, message: string, parent_hash: Maybe(string) = nil) -> []byte {
	using failz

	buf: bytes.Buffer
	defer bytes.buffer_destroy(&buf)

	bytes.buffer_write_string(&buf, fmt.tprintln("tree", tree_hash))
	if hash_data, ok := parent_hash.?; ok {
		bytes.buffer_write_string(&buf, fmt.tprintln("parent", hash_data))
	}
	bytes.buffer_write_string(
		&buf,
		fmt.tprintln(
			"author",
			"Dan Castrillo <126793278+dvrd@users.noreply.github.com> 1712514527 -0400",
		),
	)
	bytes.buffer_write_string(
		&buf,
		fmt.tprintln(
			"committer",
			"Dan Castrillo <126793278+dvrd@users.noreply.github.com> 1712514527 -0400",
		),
	)
	bytes.buffer_write_rune(&buf, '\n')
	bytes.buffer_write_string(&buf, message)
	bytes.buffer_write_rune(&buf, '\n')

	commit_contents := bytes.buffer_to_bytes(&buf)
	file_size := transmute([]byte)fmt.tprint(len(commit_contents))

	header := bytes.concatenate({COMMIT_HEAD_BASE, file_size, {0}})
	defer delete(header)

	commit_obj := bytes.concatenate({header, commit_contents})
	defer delete(commit_obj)

	commit_hash := hash_blob(commit_obj)
	defer delete(commit_hash)

	// catch(write_object(commit_hash, commit_obj))
	return bytes.clone(commit_hash)
}
