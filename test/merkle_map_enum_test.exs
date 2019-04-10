defmodule MerkleTreeEnumTest do
  use ExUnit.Case

  test "enum works like we expect" do
    mm = MerkleMap.new(%{one: 1, two: 2, three: 3})
    assert 3 = Enum.count(mm)
    assert Enum.all?(mm, fn {_k, v} -> v < 4 end)
    assert Enum.member?(mm, {:one, 1})
  end
end
