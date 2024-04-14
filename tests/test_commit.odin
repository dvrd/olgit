package gitol_tests

import "core:fmt"
import "core:strings"
import "core:testing"
import "src:gitol"

EXAMPLE_COMMIT_HASH :: "81601c2290fe321a24e53671e30511e13919bd70"
EXAMPLE_COMMIT: string : `
commit 230tree 18b9295636aff97646c44a1986fc7a41d2a48c66
parent 7ceb74adfd4349585070ec3d16aa043495552af4
author Some Author <some-author@email.io> 1713094202 -0400
committer Some Author <some-author@email.io> 1713094202 -0400

feat: some feature
`
@(test)
test_new_commit :: proc(t: ^testing.T) {
	using testing

	example_commit := strings.trim_left(EXAMPLE_COMMIT, "\ncommit 230")
	commit := gitol.new_commit(EXAMPLE_COMMIT_HASH, transmute([]byte)example_commit)

	expect(t, commit.hash == EXAMPLE_COMMIT_HASH, "commit.hash is not correct")
	expect(
		t,
		commit.tree_hash == "18b9295636aff97646c44a1986fc7a41d2a48c66",
		"commit.tree_hash is not correct",
	)
	expect(
		t,
		commit.parent_hash == "7ceb74adfd4349585070ec3d16aa043495552af4",
		"commit.parent_hash is not correct",
	)
	expect(
		t,
		commit.author == "Some Author <some-author@email.io> 1713094202 -0400",
		"commit.author is not correct",
	)
	expect(
		t,
		commit.committer == "Some Author <some-author@email.io> 1713094202 -0400",
		"commit.committer is not correct",
	)
	expect(t, commit.message == "\nfeat: some feature", "commit.message is not correct")
}

@(test)
test_write_commit :: proc(t: ^testing.T) {
	using testing

	example_commit := strings.trim_space(EXAMPLE_COMMIT)
	commit := gitol.new_commit(EXAMPLE_COMMIT_HASH, transmute([]byte)example_commit)

	expect(t, commit.hash == EXAMPLE_COMMIT_HASH, "commit.hash is not correct")
	expect(
		t,
		commit.tree_hash == "18b9295636aff97646c44a1986fc7a41d2a48c66",
		"commit.tree_hash is not correct",
	)
	expect(
		t,
		commit.parent_hash == "7ceb74adfd4349585070ec3d16aa043495552af4",
		"commit.parent_hash is not correct",
	)
	expect(
		t,
		commit.author == "Some Author <some-author@email.io> 1713094202 -0400",
		"commit.author is not correct",
	)
	expect(
		t,
		commit.committer == "Some Author <some-author@email.io> 1713094202 -0400",
		"commit.committer is not correct",
	)
	expect(t, commit.message == "\nfeat: some feature", "commit.message is not correct")
}
