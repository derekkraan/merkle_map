defmodule MerkleSet do
  alias MerkleMap.MerkleTree

  defstruct set: MapSet.new(), tree: MerkleTree.new()

  def new do
    %__MODULE__{}
  end

  def new(data) do
    Enum.reduce(data, new(), fn el, ms ->
      put(ms, el)
    end)
  end

  def new(data, fun) do
    Enum.reduce(data, new(), fn el, ms ->
      put(ms, fun.(el))
    end)
  end

  def delete(ms, el) do
    %{ms | set: MapSet.delete(ms.set, el), tree: MerkleTree.delete(ms.tree, el)}
  end

  def difference(ms1, ms2) do
    ms_int = intersection(ms1, ms2)

    MerkleTree.diff_keys(ms1.tree, ms_int.tree) |> new()
  end

  def disjoint?(ms1, ms2) do
    Enum.count(MerkleTree.diff_keys(ms1.tree, ms2.tree)) == size(ms1)
  end

  def equal?(ms1, ms2) do
    {h1, _, _} = ms1.tree.object
    {h2, _, _} = ms2.tree.object
    h1 == h2
  end

  def intersection(ms1, ms2) do
    Enum.reduce(MerkleTree.diff_keys(ms1.tree, ms2.tree), ms1, fn el, ms ->
      delete(ms, el)
    end)
  end

  def member?(ms, el) do
    MapSet.member?(ms.set, el)
  end

  def put(ms, el) do
    %{ms | set: MapSet.put(ms.set, el), tree: MerkleTree.put(ms.tree, el, 1)}
  end

  def size(ms) do
    map_size(ms.set)
  end

  def subset?(ms1, ms2) do
    !(MerkleTree.diff_keys(ms1.tree, ms2.tree)
      |> Enum.any?(fn el ->
        member?(ms1, el)
      end))
  end

  def to_list(ms) do
    MapSet.to_list(ms.set)
  end

  def union(ms1, ms2) do
    Enum.reduce(MerkleTree.diff_keys(ms1.tree, ms2.tree), ms1, fn el, ms ->
      put(ms, el)
    end)
  end
end
