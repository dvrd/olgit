package gitol

import "core:bytes"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "libs:failz"
import v_zlib "vendor:zlib"

BLOB_HEAD_BASE :: []byte{'b', 'l', 'o', 'b', ' '}

read_blob_from_path :: proc(path: string) -> ([]byte, failz.Error) {
	using failz
	buf: bytes.Buffer

	fd, errno := os.open(path)
	if errno != os.ERROR_NONE do return nil, Errno(errno)
	defer os.close(fd)

	fi: os.File_Info
	fi, errno = os.fstat(fd)
	if errno != os.ERROR_NONE do return nil, Errno(errno)
	defer delete(fi.fullpath)

	content, success := os.read_entire_file(fd)
	if !success do return nil, SystemError{.FileRead, os.get_last_error_string()}
	defer delete(content)

	bytes.buffer_write(&buf, BLOB_HEAD_BASE)
	bytes.buffer_write_string(&buf, fmt.tprint(fi.size))
	bytes.buffer_write(&buf, {0})
	bytes.buffer_write(&buf, content)

	return bytes.buffer_to_bytes(&buf), nil
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

GIT_OBJECTS_DIR :: ".git/objects"
write_object :: proc(file_hash, content: []byte, target_dir := GIT_OBJECTS_DIR) -> failz.Error {
	using failz

	src_len := cast(u64)len(content)
	compressed_len := v_zlib.compressBound(src_len)
	compressed := make([]byte, compressed_len)
	defer delete(compressed)

	z_ok := v_zlib.compress(raw_data(compressed), &compressed_len, raw_data(content), src_len)
	if z_ok != v_zlib.OK do return AppError{.Compression, string(v_zlib.zError(z_ok))}

	encoded_hash := string(hex.encode(file_hash))
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

hash_blob :: proc(contents: []byte) -> (file_hash: []byte) {
	using failz

	ctx: hash.Context
	hash.init(&ctx, .Insecure_SHA1)
	hash.update(&ctx, contents)
	file_hash = make([]byte, hash.DIGEST_SIZES[.Insecure_SHA1])
	hash.final(&ctx, file_hash)

	return
}

write_stdout :: proc(data: []byte) -> failz.Error {
	stdout := os.stream_from_handle(os.stdout)

	bits, err := io.write(stdout, data)
	if err != nil {
		err_msg := fmt.tprintf("[%v] Could not write to stdout", failz.purple(fmt.tprint(err)))
		return failz.SystemError{.FileWrite, err_msg}
	}
	return nil
}
