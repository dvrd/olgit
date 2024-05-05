package gitol

import "core:bytes"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import "failz"

Commit :: struct {
	hash:        string,
	tree_hash:   string,
	parent_hash: Maybe(string),
	author:      string,
	committer:   string,
	message:     string,
	buffer:      bytes.Buffer,
}

AUTHOR :: []byte{'a', 'u', 't', 'h', 'o', 'r', ' '}
COMMITTER :: []byte{'c', 'o', 'm', 'm', 'i', 't', 't', 'e', 'r', ' '}

new_commit :: proc(hash: string, data: []byte) -> Commit {
	using failz

	err: Error
	buffer: bytes.Buffer
	line_kind: string
	tree_hash: string
	parent_hash: Maybe(string)
	author: string
	committer: string

	bytes.buffer_init(&buffer, data)

	line_kind, err = bytes.buffer_read_string(&buffer, ' ')
	ensure(line_kind == "tree ", "corrupt commit object missing tree hash: %v", line_kind)
	catch(err, "could not read first line kind from commit object")

	tree_hash, err = bytes.buffer_read_string(&buffer, '\n')
	catch(err, "could not read tree hash from commit object")
	tree_hash = strings.trim_right(tree_hash, "\n")

	line_kind, err = bytes.buffer_read_string(&buffer, ' ')
	catch(err, "could not read second line kind from commit object")
	if line_kind == "parent " {
		parent_hash, err = bytes.buffer_read_string(&buffer, '\n')
		catch(err, "could not read parent hash from commit object")
		parent_hash = strings.trim_right(parent_hash.(string), "\n")

		line_kind, err = bytes.buffer_read_string(&buffer, ' ')
		catch(err, "could not read third line kind from commit object")
	}

	author, err = bytes.buffer_read_string(&buffer, '\n')
	author = strings.trim_right(author, "\n")
	catch(err, "could not read author from commit object")

	line_kind, err = bytes.buffer_read_string(&buffer, ' ')
	catch(err, "could not read third/fourth line kind from commit object")

	committer, err = bytes.buffer_read_string(&buffer, '\n')
	committer = strings.trim_right(committer, "\n")
	catch(err, "could not read committer from commit object")

	message := bytes.buffer_to_string(&buffer)

	return Commit{hash, string(tree_hash), parent_hash, author, committer, message, buffer}
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
		defer bytes.buffer_destroy(&buffer)

		bytes.buffer_write_string(&buffer, fmt.tprint("tree", commit.tree_hash))
		bytes.buffer_write_rune(&buffer, '\n')

		if parent_hash, ok := commit.parent_hash.?; ok {
			bytes.buffer_write_string(&buffer, fmt.tprint("parent", commit.parent_hash))
			bytes.buffer_write_rune(&buffer, '\n')
		}

		bytes.buffer_write_string(&buffer, fmt.tprint("author", commit.author))
		bytes.buffer_write_rune(&buffer, '\n')
		bytes.buffer_write_string(&buffer, fmt.tprint("committer", commit.committer))
		bytes.buffer_write_rune(&buffer, '\n')
		bytes.buffer_write_string(&buffer, commit.message)

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

	catch(write_object(commit_hash, commit_obj))
	return bytes.clone(commit_hash)
}
