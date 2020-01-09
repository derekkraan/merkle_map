defmodule MerkleMap do
  @moduledoc """
  MerkleMap is a drop-in replacement for Map that optimizes certain operations, making heavy use of Merkle Trees.
  """

  alias MerkleMap.MerkleTree
  alias MerkleMap.MerkleTreeImpl

  defstruct [
    map: %{},
    merkle_tree: MerkleTreeImpl.new()
  ]

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

  def delete(%{map: map, merkle_tree: tree} = mm, k) do
    %{mm | map: Map.delete(map, k), merkle_tree: MerkleTreeImpl.delete(tree, k)}
  end

  def has_key?(%{map: m}, k) do
    Map.has_key?(m, k)
  end

  def equal?(%{merkle_tree: tree1}, %{merkle_tree: tree2}) do
    MerkleTreeImpl.equal?(tree1, tree2)
  end

  def put(%{map: map, merkle_tree: tree} = mm, k, v) do
    %{mm | map: :maps.put(k, v, map), merkle_tree: MerkleTreeImpl.put(tree, k, v)}
  end

  def values(%__MODULE__{} = mm) do
    Map.values(mm.map)
  end

  def fetch(%{map: map}, key) do
    Map.fetch(map, key)
  end

  def fetch!(%{map: map}, key) do
    Map.fetch!(map, key)
  end

  def to_list(%{map: map}) do
    Map.to_list(map)
  end

  def from_struct(struct) do
    Map.from_struct(struct) |> new()
  end

  def get(%{map: map}, key, default \\ nil) do
    :maps.get(key, map, default)
  end

  def keys(%{map: map}) do
    :maps.keys(map)
  end

  def drop(%{map: map, merkle_tree: tree} = mm, keys) do
    new_tree =
      Enum.reduce(keys, tree, fn key, mt ->
        MerkleTreeImpl.delete(mt, key)
      end)

    %__MODULE__{mm | map: Map.drop(map, keys), merkle_tree: new_tree}
  end

  def take(%{map: map}, keys) do
    Map.take(map, keys) |> new()
  end

  def update_hashes(%{merkle_tree: tree} = mm) do
    %__MODULE__{mm | merkle_tree: MerkleTreeImpl.calculate_hashes(tree)}
  end

  # Is wrapping into `{:ok, _}` really necessary?
  # If yes, why is there no `{:error, _} | :error` case?
  def diff_keys(%{merkle_tree: tree1}, %{merkle_tree: tree2}) do
    {:ok, MerkleTreeImpl.diff_keys(tree1, tree2, 0)}
  end

  def prepare_partial_diff(%{merkle_tree: tree}, depth) do
    {
      :continue,
      %MerkleTree.Diff{trees: [{<<>>, MerkleTreeImpl.subtree(tree, <<>>, depth)}]}
    }
  end

  def continue_partial_diff(mm1, %MerkleTree.Diff{} = partial, depth) do
    continue_partial_diff(partial, mm1, depth)
  end

  def continue_partial_diff(
    %{trees: trees, keys: partial_keys},
    %{merkle_tree: merkle_tree},
    depth) when is_integer(depth) and depth > 0
  do
    diff_keys =
      Enum.reduce(trees, [], fn {loc, tree}, acc_keys ->
        sub_tree = MerkleTreeImpl.subtree(merkle_tree, loc, depth)
        diff_keys = MerkleTreeImpl.diff_keys(sub_tree, tree, bit_size(loc))
        [diff_keys | acc_keys]
      end)

    {partials, keys} =
      List.flatten(diff_keys) # Why don't we use `diff_keys ++ acc_keys` on the line above?
      |> Enum.split_with(fn
        {:partial, _loc} -> true
        _ -> false
      end)

    trees =
      Enum.map(partials, fn {:partial, loc} ->
        sub_tree = MerkleTreeImpl.subtree(merkle_tree, loc, depth)
        {loc, sub_tree}
      end)

    case trees do
      [] -> {:ok, partial_keys ++ keys}
      trees -> {:continue, %MerkleTree.Diff{keys: partial_keys ++ keys, trees: trees}}
    end
  end

  def truncate_diff(%MerkleTree.Diff{keys: keys, trees: trees} = diff, amount) do
    keys = Enum.take(keys, amount)
    trees = Enum.take(trees, amount - length(keys))
    %{diff | keys: keys, trees: trees}
  end

  def merge(mm1, %{map: map2} = mm2) do
    {:ok, diff_keys} = diff_keys(mm1, mm2)

    Enum.reduce(diff_keys, mm1, fn key, mm ->
      case map2 do
        %{^key => val} -> put(mm, key, val)
        _ -> mm
      end
    end)
  end

  def merge(%{map: map1} = mm1, %{map: map2} = mm2, update_fun) do
    {:ok, diff_keys} = diff_keys(mm1, mm2)

    Enum.reduce(diff_keys, mm1, fn key, mm ->
      case {map1, map2} do
        {%{^key => val1}, %{^key => val2}} ->
          val = update_fun.(key, val1, val2)
          put(mm, key, val)

        {_, %{^key => val}} ->
          put(mm, key, val)

        # then the key is only in mm
        _ ->
          mm
      end
    end)
  end

  def pop(%{map: map, merkle_tree: tree}, key) do
    {val, map} = Map.pop(map, key)
    {val, %__MODULE__{map: map, merkle_tree: MerkleTreeImpl.delete(tree, key)}}
  end

  def pop_lazy(%{map: map, merkle_tree: tree}, key, fun) do
    {val, map} = Map.pop_lazy(map, key, fun)
    {val, %__MODULE__{map: map, merkle_tree: MerkleTreeImpl.delete(tree, key)}}
  end

  def put_new(%{map: map} = mm, key, value) do
    case map do
      %{^key => _} -> mm
      _ -> put(mm, key, value)
    end
  end

  def put_new_lazy(%{map: map} = mm, key, fun) do
    case map do
      %{^key => _} -> mm
      _ -> put(mm, key, fun.())
    end
  end

  def get_lazy(%{map: map}, key, fun) do
    case map do
      %{^key => val} -> val
      _ -> fun.()
    end
  end

  #TODO can be optimized to use one `Map.split`
  def split(mm1, keys) do
    {take(mm1, keys), drop(mm1, keys)}
  end

  def update(%{map: map} = mm, key, initial, fun) do
    case map do
      %{^key => val} -> put(mm, key, fun.(val))
      _ -> put(mm, key, initial)
    end
  end

  def update!(%{map: map, merkle_tree: tree}, key, fun) do
    map = %{^key => value} = Map.update!(map, key, fun)
    %__MODULE__{map: map, merkle_tree: MerkleTreeImpl.put(tree, key, value)}
  end

  def replace!(%{map: map, merkle_tree: tree}, key, value) do
    map = Map.replace!(map, key, value)
    %__MODULE__{map: map, merkle_tree: MerkleTreeImpl.put(tree, key, value)}
  end

  def get_and_update(%{map: map} = mm, key, fun) do
    {val, map} = Map.get_and_update(map, key, fun)
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
