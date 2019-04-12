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

  test "diff_keyss maps" do
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

  test "can calculate partial diff_keys from partial tree" do
    tree_one = MerkleTree.new(%{foo: "bar"})
    tree_two = MerkleTree.new(%{foo: "baz"})

    assert partial = MerkleTree.partial_tree(tree_one, 8)
    assert [partial: x] = MerkleTree.diff_keys(partial, tree_two)

    assert partial2 = MerkleTree.partial_tree(tree_one, 8, x)
    assert [partial: y] = MerkleTree.diff_keys(partial2, MerkleTree.partial_tree(tree_two, 8, x))

    assert partial3 = MerkleTree.partial_tree(tree_one, 8, <<x::bits, y::bits>>)

    assert [partial: z] =
             MerkleTree.diff_keys(
               partial3,
               MerkleTree.partial_tree(tree_two, 8, <<x::bits, y::bits>>)
             )

    assert partial4 = MerkleTree.partial_tree(tree_one, 8, <<x::bits, y::bits, z::bits>>)

    assert [partial: zz] =
             MerkleTree.diff_keys(
               partial4,
               MerkleTree.partial_tree(tree_two, 8, <<x::bits, y::bits, z::bits>>)
             )

    assert partial5 =
             MerkleTree.partial_tree(tree_one, 8, <<x::bits, y::bits, z::bits, zz::bits>>)

    assert [:foo] =
             MerkleTree.diff_keys(
               partial5,
               MerkleTree.partial_tree(tree_two, 8, <<x::bits, y::bits, z::bits, zz::bits>>)
             )

    # [partial, partial2, partial3, partial4, partial5]
    # |> Enum.map(&:erts_debug.size/1)
    # |> IO.inspect()
  end
end
