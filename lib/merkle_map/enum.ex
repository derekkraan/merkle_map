defimpl Enumerable, for: MerkleMap do
  def count(mm), do: Enumerable.count(mm.map)
  def member?(mm, elem), do: Enumerable.member?(mm.map, elem)
  def reduce(mm, acc, fun), do: Enumerable.reduce(mm.map, acc, fun)
  def slice(mm), do: Enumerable.slice(mm.map)
end
