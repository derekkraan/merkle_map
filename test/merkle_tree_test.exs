defmodule MerkleTreeTest do
  use ExUnit.Case
  use ExUnitProperties

  alias MerkleMap.MerkleTree

  property "diff_keys of itself is always empty" do
    check all key <- term(),
              value <- term() do
      map = %{key => value}
      tree = MerkleTree.new(map)
      assert [] = MerkleTree.diff_keys(tree, tree)
    end
  end

  property "diff_keys identifies missing key" do
    check all key <- term(),
              value <- term() do
      map = %{key => value}
      tree = MerkleTree.new(map)
      assert [key] = MerkleTree.diff_keys(MerkleTree.new(), tree)
    end
  end

  property "arbitrarily large map can still find one changed key" do
    tree =
      Map.new(1..1000, fn x -> {x, x * x} end)
      |> MerkleTree.new()

    check all key <- term(),
              value <- term() do
      new_tree = MerkleTree.put(tree, key, value)
      assert [key] = MerkleTree.diff_keys(new_tree, tree)
    end
  end

  test "init a merkle tree" do
    assert MerkleTree.put(MerkleTree.new(), "foo", "bar")
           |> MerkleTree.put("bar", "baz")
  end

  test "init a whole map" do
    assert MerkleTree.new(%{foo: "bar", bar: "baz"})
  end

  test "keys/1" do
    assert [:foo, :bar] = MerkleTree.keys(MerkleTree.new(%{foo: "bar", bar: "baz"}))
  end

  test "diff_keys maps" do
    m1 = MerkleTree.new(%{foo: "bar", food: "good"})
    m2 = MerkleTree.new(%{foo: "baz", food: "good", drink: "also good"})
    assert Enum.sort([:foo, :drink]) == Enum.sort(MerkleTree.diff_keys(m1, m2))
  end

  test "remove a key" do
    m1 = MerkleTree.new(%{foo: "bar", bar: "baz"})
    m2 = MerkleTree.new(%{foo: "bar"})

    removed = MerkleTree.delete(m1, :bar)

    assert [] = MerkleTree.diff_keys(m2, removed)
    assert MerkleTree.equal?(m2, removed)
  end

  test "equal?" do
    tree_one = MerkleTree.put(MerkleTree.new(), "foo", "bar")
    assert MerkleTree.equal?(tree_one, tree_one)

    tree_two = MerkleTree.put(MerkleTree.new(), "foo", "baz")
    refute MerkleTree.equal?(tree_one, tree_two)
  end

  test "show diff_keys" do
    tree_one = MerkleTree.put(MerkleTree.new(), "foo", "bar")
    assert [] = MerkleTree.diff_keys(tree_one, tree_one)
    tree_two = MerkleTree.put(MerkleTree.new(), "foo", "baz")
    assert ["foo"] = MerkleTree.diff_keys(tree_one, tree_two)
    tree_three = MerkleTree.put(tree_one, "bar", "baz")

    assert ["bar"] = MerkleTree.diff_keys(tree_one, tree_three)
    assert Enum.sort(["foo", "bar"]) == Enum.sort(MerkleTree.diff_keys(tree_two, tree_three))
  end
end
