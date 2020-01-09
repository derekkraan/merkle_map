defimpl Inspect, for: MerkleMap do

  def inspect(%MerkleMap{map: map}, _) do
    "%" <> x = Kernel.inspect(map)
    "#MerkleMap#{x}"
  end
end
