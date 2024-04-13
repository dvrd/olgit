package gitol

import "core:bytes"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import "libs:failz"

Commit :: struct {
	tree_hash:   string,
	parent_hash: Maybe(string),
	author:      string,
	committer:   string,
	message:     string,
}

AUTHOR :: []byte{'a', 'u', 't', 'h', 'o', 'r', ' '}
COMMITTER :: []byte{'c', 'o', 'm', 'm', 'i', 't', 't', 'e', 'r', ' '}

new_commit :: proc(hash: string, data: []byte) -> Commit {
	using failz
	err: Error

	buffer: bytes.Buffer
	bytes.buffer_init(&buffer, data)
	bytes.buffer_read(&buffer, TREE_HEAD_BASE)
	tree_hash := bytes.buffer_next(&buffer, 20)
	unknown := bytes.buffer_read_byte(&buffer)
	bytes.buffer_unread_byte(&buffer)
	if unknown == 'p' {
		bytes.buffer_read(&buffer, PARENT_HEAD_BASE)
		parent_hash := bytes.buffer_next(&buffer, 20)
	}
	bytes.buffer_read(&buffer, AUTHOR)
	author := bytes.buffer_read_string(&buffer, '\n')
	bytes.buffer_read(&buffer, COMMITTER)
	committer := bytes.buffer_read_string(&buffer, '\n')
	message := bytes.buffer_to_string(&buffer)

	return Commit{tree_hash, parent_hash, author, committer, message}
}

print_commit :: proc(commit: Commit, print_commit_tree: bool) {
	using failz

	if print_commit_tree {
		obj, err := read_object(commit.tree_hash)
		catch(err, "could not read object from commit tree hash")
		tree_obj, ok := obj.(Tree)
		ensure(ok, "corrupt commit object tree hash is not a tree")
		print_tree(tree_obj)
	} else {
		buffer: bytes.Buffer

		bytes.buffer_write_string(&buffer, fmt.tprintln("tree", commit.tree_hash))

		parent_hash, ok := commit.parent_hash.?
		if ok do bytes.buffer_write_string(&buffer, fmt.tprintln("parent", commit.parent_hash))

		bytes.buffer_write_string(&buffer, fmt.tprintln("author", commit.author))
		bytes.buffer_write_string(&buffer, fmt.tprintln("committer", commit.committer))
		bytes.buffer_write_string(&buffer, commit.message)
		bytes.buffer_write_string(&buffer, "\n")

		catch(write_stdout(bytes.buffer_to_bytes(&buffer)))
	}
}

write_commit :: proc(tree_hash, message: string, parent_hash: Maybe(string) = nil) -> []byte {
	using failz

	buf: bytes.Buffer
	defer bytes.buffer_destroy(&buf)

	timestamp := time.to_unix_seconds(time.now())
	utc_offset := timezone()
	author_time := fmt.tprint(
		"%v %v%2d%v",
		timestamp,
		'+' if utc_offset > 0 else '-',
		math.floor_div(abs(utc_offset), 3600),
		math.floor_div(abs(utc_offset), 60) % 60,
	)

	bytes.buffer_write_string(&buf, fmt.tprintln("tree", tree_hash))
	if hash_data, ok := parent_hash.?; ok {
		bytes.buffer_write_string(&buf, fmt.tprintln("parent", hash_data))
	}
	bytes.buffer_write_string(
		&buf,
		fmt.tprintln("author", "Dan Castrillo <dvrd@users.noreply.github.com>", author_time),
	)
	bytes.buffer_write_string(
		&buf,
		fmt.tprintln("committer", "Dan Castrillo <dvrd@users.noreply.github.com>", author_time),
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
