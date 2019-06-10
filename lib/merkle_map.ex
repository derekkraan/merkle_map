defmodule MerkleMap do
  @moduledoc """
  MerkleMap is a drop-in replacement for Map that optimizes certain operations, making heavy use of Merkle Trees.
  """

  alias MerkleMap.MerkleTree

  defstruct map: %{},
            merkle_tree: MerkleTree.new()

  @opaque t() :: %__MODULE__{}

  def new() do
    %__MODULE__{}
  end

  def new(enum) do
    Enum.reduce(enum, new(), fn {k, v}, mm -> put(mm, k, v) end)
  end

  def new(enum, tform) do
    Enum.reduce(enum, new(), fn elem, mm ->
      {k, v} = tform.(elem)
      put(mm, k, v)
    end)
  end

  def delete(%__MODULE__{} = mm, k) do
    %{mm | map: Map.delete(mm.map, k), merkle_tree: MerkleTree.delete(mm.merkle_tree, k)}
  end

  def has_key?(%__MODULE__{map: m}, k) do
    Map.has_key?(m, k)
  end

  def equal?(mm1, mm2) do
    MerkleTree.equal?(mm1.merkle_tree, mm2.merkle_tree)
  end

  def put(%__MODULE__{} = mm, k, v) do
    %{mm | map: Map.put(mm.map, k, v), merkle_tree: MerkleTree.put(mm.merkle_tree, k, v)}
  end

  def values(%__MODULE__{} = mm) do
    Map.values(mm.map)
  end

  def fetch(mm, key) do
    Map.fetch(mm.map, key)
  end

  def fetch!(mm, key) do
    Map.fetch!(mm.map, key)
  end

  def to_list(mm) do
    Map.to_list(mm.map)
  end

  def from_struct(struct) do
    Map.from_struct(struct) |> new()
  end

  def get(mm, key, default \\ nil) do
    Map.get(mm.map, key, default)
  end

  def keys(mm) do
    Map.keys(mm.map)
  end

  def drop(%__MODULE__{} = mm, keys) do
    mm = %{mm | map: Map.drop(mm.map, keys)}

    new_mm =
      Enum.reduce(keys, mm.merkle_tree, fn key, mt ->
        MerkleTree.delete(mt, key)
      end)

    Map.put(mm, :merkle_tree, new_mm)
  end

  def take(%__MODULE__{} = mm, keys) do
    Map.take(mm.map, keys) |> new()
  end

  def update_hashes(mm) do
    %__MODULE__{mm | merkle_tree: MerkleTree.update_hashes(mm.merkle_tree)}
  end

  def prepare_partial_diff(mm, depth) do
    {:continue,
     %MerkleTree.Diff{trees: [{<<>>, MerkleTree.subtree(mm.merkle_tree, <<>>, depth)}]}}
  end

  def diff_keys(mm1, mm2, depth \\ :full)

  def diff_keys(%__MODULE__{} = mm1, %__MODULE__{} = mm2, _) do
    {:ok, MerkleTree.diff_keys(mm1.merkle_tree, mm2.merkle_tree)}
  end

  def diff_keys(mm1, %__MODULE__.MerkleTree.Diff{} = partial, depth) do
    diff_keys(partial, mm1, depth)
  end

  def diff_keys(%__MODULE__.MerkleTree.Diff{} = partial, %__MODULE__{} = mm, depth)
      when is_integer(depth) and depth > 0 do
    {diff_keys, _mm_merkle_tree} =
      Enum.reduce(partial.trees, {[], mm.merkle_tree}, fn {loc, tree},
                                                          {acc_keys, mm_merkle_tree} ->
        {mm_merkle_tree, sub_tree} = MerkleTree.subtree(mm_merkle_tree, loc, depth)
        {:ok, _mm_merkle_tree, _t, diff_keys} = MerkleTree.diff_keys(sub_tree, tree)

        Enum.map(diff_keys, fn
          {:partial, partial_loc} -> {:partial, <<loc::bitstring, partial_loc::bitstring>>}
          other -> other
        end)

        {[diff_keys | acc_keys], mm_merkle_tree}
      end)

    {partials, keys} =
      List.flatten(diff_keys)
      |> Enum.split_with(fn
        {:partial, _loc} -> true
        _ -> false
      end)

    trees =
      Enum.map(partials, fn {:partial, loc} ->
        {_, sub_tree} = MerkleTree.subtree(mm.merkle_tree, loc, depth)
        {loc, sub_tree}
      end)

    case trees do
      [] -> {:ok, partial.keys ++ keys}
      trees -> {:continue, %__MODULE__.MerkleTree.Diff{keys: partial.keys ++ keys, trees: trees}}
    end
  end

  def truncate_diff(%__MODULE__.MerkleTree.Diff{} = diff, amount) do
    keys = Enum.take(diff.keys, amount)
    trees = Enum.take(diff.trees, amount - length(keys))
    %{diff | keys: keys, trees: trees}
  end

  def merge(mm1, mm2) do
    {:ok, diff_keys} = diff_keys(mm1, mm2)

    Enum.reduce(diff_keys, mm1, fn key, mm ->
      if Map.has_key?(mm2.map, key) do
        put(mm, key, get(mm2, key))
      else
        mm
      end
    end)
  end

  def merge(mm1, mm2, update_fun) do
    {:ok, diff_keys} = diff_keys(mm1, mm2)

    Enum.reduce(diff_keys, mm1, fn key, mm ->
      cond do
        has_key?(mm, key) && has_key?(mm2, key) ->
          val = update_fun.(key, get(mm, key), get(mm2, key))
          put(mm, key, val)

        has_key?(mm2, key) ->
          put(mm, key, get(mm2, key))

        # then the key is only in mm
        true ->
          mm
      end
    end)
  end

  def pop(mm, key) do
    {val, map} = Map.pop(mm.map, key)
    {val, %{mm | map: map, merkle_tree: MerkleTree.delete(mm.merkle_tree, key)}}
  end

  def pop_lazy(mm, key, fun) do
    {val, map} = Map.pop_lazy(mm.map, key, fun)
    {val, %{mm | map: map, merkle_tree: MerkleTree.delete(mm.merkle_tree, key)}}
  end

  def put_new(mm, key, value) do
    cond do
      has_key?(mm, key) -> mm
      true -> put(mm, key, value)
    end
  end

  def put_new_lazy(mm, key, fun) do
    cond do
      has_key?(mm, key) -> mm
      true -> put(mm, key, fun.())
    end
  end

  def get_lazy(mm, key, fun) do
    cond do
      has_key?(mm, key) -> get(mm, key)
      true -> fun.()
    end
  end

  def split(mm1, keys) do
    {take(mm1, keys), drop(mm1, keys)}
  end

  def update(mm, key, initial, fun) do
    cond do
      has_key?(mm, key) -> put(mm, key, fun.(get(mm, key)))
      true -> put(mm, key, initial)
    end
  end

  def update!(mm, key, fun) do
    map = Map.update!(mm.map, key, fun)
    %{mm | map: map, merkle_tree: MerkleTree.put(mm.merkle_tree, key, Map.get(map, key))}
  end

  def replace!(mm, key, value) do
    map = Map.replace!(mm.map, key, value)
    %{mm | map: map, merkle_tree: MerkleTree.put(mm.merkle_tree, key, Map.get(map, key))}
  end

  def get_and_update(mm, key, fun) do
    {val, map} = Map.get_and_update(mm.map, key, fun)
    new_mm = %{mm | map: map}
    new_mm = put(new_mm, key, get(new_mm, key))
    {val, new_mm}
  end

  def get_and_update!(mm, key, fun) do
    {val, map} = Map.get_and_update!(mm.map, key, fun)
    new_mm = %{mm | map: map}
    new_mm = put(new_mm, key, get(new_mm, key))
    {val, new_mm}
  end
end
