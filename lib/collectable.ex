defimpl Collectable, for: MerkleMap do
  def into(original) do
    collector_fun = fn
      mm, {:cont, {k, v}} -> MerkleMap.put(mm, k, v)
      mm, :done -> mm
      _mm, :halt -> :ok
    end

    {original, collector_fun}
  end
end
