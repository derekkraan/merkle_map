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
    assert [:bar, :foo] = MerkleTree.keys(MerkleTree.new(%{foo: "bar", bar: "baz"}))
  end

  test "diff_keys maps" do
    m1 = MerkleTree.new(%{foo: "bar", food: "good"})
    m2 = MerkleTree.new(%{foo: "baz", food: "good", drink: "also good"})
    {_m1, _m2, diff_keys} = MerkleTree.diff_keys(m1, m2)
    assert Enum.sort([:foo, :drink]) == Enum.sort(diff_keys)
  end

  test "remove a key" do
    m1 = MerkleTree.new(%{foo: "bar", bar: "baz"})
    m2 = MerkleTree.new(%{foo: "bar"})

    removed = MerkleTree.delete(m1, :bar)

    assert {_, _, []} = MerkleTree.diff_keys(m2, removed)
    assert {_, _, true} = MerkleTree.equal?(m2, removed)
  end

  test "equal?" do
    tree_one = MerkleTree.put(MerkleTree.new(), "foo", "bar")
    assert {_, _, true} = MerkleTree.equal?(tree_one, tree_one)

    tree_two = MerkleTree.put(MerkleTree.new(), "foo", "baz")
    assert {_, _, false} = MerkleTree.equal?(tree_one, tree_two)
  end

  test "show diff_keys" do
    tree_one = MerkleTree.put(MerkleTree.new(), "foo", "bar")
    assert {_, _, []} = MerkleTree.diff_keys(tree_one, tree_one)
    tree_two = MerkleTree.put(MerkleTree.new(), "foo", "baz")
    assert {_, _, ["foo"]} = MerkleTree.diff_keys(tree_one, tree_two)
    tree_three = MerkleTree.put(tree_one, "bar", "baz")

    assert {_, _, ["bar"]} = MerkleTree.diff_keys(tree_one, tree_three)
    {_, _, diff_keys} = MerkleTree.diff_keys(tree_two, tree_three)
    assert Enum.sort(["foo", "bar"]) == Enum.sort(diff_keys)
  end

  property "diff_keys of itself is always empty" do
    check all key <- term(),
              value <- term() do
      map = %{key => value}
      tree = MerkleTree.new(map)
      assert {_, _, []} = MerkleTree.diff_keys(tree, tree)
    end
  end

  property "diff_keys identifies missing key" do
    check all key <- term(),
              value <- term() do
      map = %{key => value}
      tree = MerkleTree.new(map)
      assert {_, _, [key]} = MerkleTree.diff_keys(MerkleTree.new(), tree)
    end
  end

  property "arbitrarily large map can still find one changed key" do
    tree =
      Map.new(1..1000, fn x -> {x, x * x} end)
      |> MerkleTree.new()

    check all key <- term(),
              value <- term() do
      new_tree = MerkleTree.put(tree, key, value)
      assert {_, _, [key]} = MerkleTree.diff_keys(new_tree, tree)
    end
  end
end
