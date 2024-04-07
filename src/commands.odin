package cli

import "libs:clodin"

Command :: union {
	Init,
	Cat_File,
	Hash_Object,
	Ls_Tree,
	Write_Tree,
	Commit_Tree,
}

Init :: struct {}

Cat_File :: struct {
	pretty: bool,
	hash:   string,
}

Hash_Object :: struct {
	write: bool,
	file:  string,
}

Ls_Tree :: struct {
	hash:       string,
	only_names: bool,
}

Write_Tree :: struct {}

Commit_Tree :: struct {
	tree_hash:   string,
	parent_hash: Maybe(string),
	message:     Maybe(string),
}

parsing_proc :: proc(input: string) -> (res: Command, ok: bool) {
	using clodin

	switch input {
	case "init":
		return Init{}, true
	case "cat-file":
		return Cat_File {
				flag("p", "pretty print the object"),
				pos_string("blob", "object hash for the blob"),
			},
			true
	case "hash-object":
		return Hash_Object {
				flag("w", "write the object to the git database"),
				pos_string("file", "file to hash"),
			},
			true
	case "ls-tree":
		return Ls_Tree{pos_string("tree", "tree hash"), flag("name-only")}, true
	case "write-tree":
		return Write_Tree{}, true
	case "commit-tree":
		return Commit_Tree {
				pos_string("tree", "tree hash"),
				opt_string("p", "parent hash"),
				opt_string("m", "commit message"),
			},
			true
	}
	return nil, false
}
