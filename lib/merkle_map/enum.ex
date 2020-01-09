defimpl Enumerable, for: MerkleMap do
  def count(%{map: map}), do: Enumerable.count(map)
  def member?(%{map: map}, elem), do: Enumerable.member?(map, elem)
  def reduce(%{map: map}, acc, fun), do: Enumerable.reduce(map, acc, fun)
  def slice(%{map: map}), do: Enumerable.slice(map)
end
