defmodule CollectableTest do
  use ExUnit.Case

  test "collection" do
    into_map = Enum.into([a: 1, b: 2], MerkleMap.new())

    assert MerkleMap.equal?(MerkleMap.new(%{a: 1, b: 2}), into_map)
  end
end
