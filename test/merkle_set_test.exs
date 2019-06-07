# defmodule MerkleSetTest do
#   use ExUnit.Case

#   test "put/2 and delete/2 and equal?/2" do
#     ms1 =
#       MerkleSet.new()
#       |> MerkleSet.put("foo")
#       |> MerkleSet.put("bar")

#     ms2 = MerkleSet.new(["foo", "bar"])

#     ms3 =
#       MerkleSet.new(["foo", "bar"])
#       |> MerkleSet.delete("bar")

#     ms4 = MerkleSet.new(["foo"])

#     assert MerkleSet.equal?(ms1, ms2)
#     assert MerkleSet.equal?(ms3, ms4)

#     refute MerkleSet.equal?(ms1, ms3)
#   end

#   test "union" do
#     ms1 = MerkleSet.new(["foo", "bar"])
#     ms2 = MerkleSet.new(["bar", "baz"])
#     ms3 = MerkleSet.new(["foo", "bar", "baz"])
#     assert MerkleSet.equal?(MerkleSet.union(ms1, ms2), ms3)
#   end

#   test "intersection" do
#     ms1 = MerkleSet.new(["foo", "bar"])
#     ms2 = MerkleSet.new(["bar", "baz"])
#     ms3 = MerkleSet.new(["bar"])
#     assert MerkleSet.equal?(MerkleSet.intersection(ms1, ms2), ms3)
#   end

#   test "difference" do
#     ms1 = MerkleSet.new(["foo", "bar"])
#     ms2 = MerkleSet.new(["bar", "baz"])

#     assert ["foo"] = MerkleSet.to_list(MerkleSet.difference(ms1, ms2))
#   end

#   test "disjoint" do
#     ms1 = MerkleSet.new(["foo", "bar"])
#     ms2 = MerkleSet.new(["bar", "baz"])
#     ms3 = MerkleSet.new(["baz"])

#     assert MerkleSet.disjoint?(ms1, ms3)
#     refute MerkleSet.disjoint?(ms1, ms2)
#     refute MerkleSet.disjoint?(ms2, ms3)
#   end

#   test "subset?" do
#     ms1 = MerkleSet.new(["bar"])
#     ms2 = MerkleSet.new(["foo", "bar"])

#     assert MerkleSet.subset?(ms1, ms1)
#     assert MerkleSet.subset?(ms1, ms2)
#     assert MerkleSet.subset?(ms1, ms2)
#     refute MerkleSet.subset?(ms2, ms1)
#   end
# end
