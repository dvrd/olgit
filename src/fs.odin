package gitol

import "core:bytes"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "failz"
import v_zlib "vendor:zlib"

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

	return write_blob(content, fi.size), nil
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
