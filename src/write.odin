package gitol

import "./failz"
import "core:bytes"
import "core:encoding/hex"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:sort"
import "core:strings"
import v_zlib "vendor:zlib"

GIT_OBJECTS_DIR :: ".git/objects"

BLOB_HEAD_BASE :: []byte{'b', 'l', 'o', 'b', ' '}
TREE_HEAD_BASE :: []byte{'t', 'r', 'e', 'e', ' '}
PARENT_HEAD_BASE :: []byte{'p', 'a', 'r', 'e', 'n', 't', ' '}
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
