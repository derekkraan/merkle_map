defmodule MerkleTreeTest do
  use ExUnit.Case
  use ExUnitProperties

  alias MerkleMap.MerkleTree

  test "init a merkle tree" do
    assert MerkleTree.put(MerkleTree.new(), "foo", "bar")
           |> MerkleTree.put("bar", "baz")
  end

  test "init a whole map" do
    assert MerkleTree.new(%{foo: "bar", bar: "baz"})
  end

  test "keys/1" do
    assert Enum.sort([:bar, :foo]) ==
             Enum.sort(MerkleTree.keys(MerkleTree.new(%{foo: "bar", bar: "baz"})))
  end

  test "diff_keys maps" do
    m1 = MerkleTree.new(%{foo: "bar", food: "good"}) |> MerkleTree.update_hashes()

    m2 =
      MerkleTree.new(%{foo: "baz", food: "good", drink: "also good"})
      |> MerkleTree.update_hashes()

    assert Enum.sort([:foo, :drink]) == Enum.sort(MerkleTree.diff_keys(m1, m2))
  end

  test "remove a key" do
    m1 = MerkleTree.new(%{foo: "bar", bar: "baz"}) |> MerkleTree.update_hashes()
    m2 = MerkleTree.new(%{foo: "bar"}) |> MerkleTree.update_hashes()

    removed = MerkleTree.delete(m1, :bar) |> MerkleTree.update_hashes()

    assert [] = MerkleTree.diff_keys(m2, removed)
    assert MerkleTree.equal?(m2, removed)
  end

  test "equal?" do
    tree_one = MerkleTree.put(MerkleTree.new(), "foo", "bar") |> MerkleTree.update_hashes()
    assert MerkleTree.equal?(tree_one, tree_one)

    tree_two = MerkleTree.put(MerkleTree.new(), "foo", "baz") |> MerkleTree.update_hashes()
    refute MerkleTree.equal?(tree_one, tree_two)
  end

  test "show diff_keys" do
    tree_one = MerkleTree.put(MerkleTree.new(), "foo", "bar") |> MerkleTree.update_hashes()
    assert [] = MerkleTree.diff_keys(tree_one, tree_one)
    tree_two = MerkleTree.put(MerkleTree.new(), "foo", "baz") |> MerkleTree.update_hashes()
    assert ["foo"] = MerkleTree.diff_keys(tree_one, tree_two)
    tree_three = MerkleTree.put(tree_one, "bar", "baz") |> MerkleTree.update_hashes()

    assert ["bar"] = MerkleTree.diff_keys(tree_one, tree_three)
    diff_keys = MerkleTree.diff_keys(tree_two, tree_three)
    assert Enum.sort(["foo", "bar"]) == Enum.sort(diff_keys)
  end

  test "subtree computes a sub tree" do
    subtree =
      Map.new(1..10_000, fn x -> {x, x} end)
      |> MerkleTree.new()
      |> MerkleTree.update_hashes()
      |> MerkleTree.subtree("", 4)

    assert 4 = MerkleTree.max_depth(subtree)
  end

  property "diff_keys of itself is always empty" do
    check all(
            key <- term(),
            value <- term()
          ) do
      map = %{key => value}
      tree = MerkleTree.new(map) |> MerkleTree.update_hashes()
      assert [] = MerkleTree.diff_keys(tree, tree)
    end
  end

  property "diff_keys identifies missing key" do
    check all(
            key <- term(),
            value <- term()
          ) do
      map = %{key => value}
      tree = MerkleTree.new(map) |> MerkleTree.update_hashes()
      assert diff_keys = MerkleTree.diff_keys(MerkleTree.new() |> MerkleTree.update_hashes(), tree)
      assert Enum.count(diff_keys) == 1
    end
  end

  property "arbitrarily large map can still find one changed key" do
    tree =
      Map.new(1..1000, fn x -> {x, x * x} end) |> MerkleTree.new() |> MerkleTree.update_hashes()

    check all(
            key <- term(),
            value <- term()
          ) do
      new_tree = MerkleTree.put(tree, key, value) |> MerkleTree.update_hashes()
      assert diff_keys = MerkleTree.diff_keys(new_tree, tree)
      assert Enum.count(diff_keys) == 1
    end
  end
end
