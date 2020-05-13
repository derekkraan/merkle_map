defmodule MerkleMap.MerkleTree do
  @moduledoc false

  @opaque t() :: %__MODULE__{}
  @type key :: term()
  @type value :: term()

  defstruct [:tree]

  alias MerkleMap.MerkleTreeImpl
  alias MerkleMap.MerkleTree.Diff

  @spec new(Enumerable.t()) :: t()
  def new(enum) do
    Enum.reduce(enum, new(), fn {k, v}, tree ->
      put(tree, k, v)
    end)
  end

  @spec new() :: t()
  def new() do
    %__MODULE__{tree: MerkleTreeImpl.new()}
  end

  @spec put(t(), key(), value()) :: t()
  def put(%__MODULE__{tree: tree}, key, value) do
    %__MODULE__{tree: MerkleTreeImpl.put(tree, key, value)}
  end

  @spec delete(t(), key()) :: t()
  def delete(%__MODULE__{tree: tree}, key) do
    %__MODULE__{tree: MerkleTreeImpl.delete(tree, key)}
  end

  @spec diff_keys(t(), t(), depth :: integer()) :: {t(), t(), [key()]}
  def diff_keys(%__MODULE__{tree: tree}, %__MODULE__{tree: tree2}, depth \\ 0)
      when is_integer(depth) and depth >= 0 do
    MerkleTreeImpl.diff_keys(tree, tree2, depth)
  end

  @spec diff_keys(t(), t()) :: {t(), t(), boolean()}
  def equal?(%__MODULE__{tree: tree}, %__MODULE__{tree: tree2}) do
    MerkleTreeImpl.equal?(tree, tree2)
  end

  @spec keys(t()) :: [key()]
  def keys(%__MODULE__{tree: tree}) do
    MerkleTreeImpl.keys(tree)
  end

  def subtree(%__MODULE__{tree: tree}, location, depth)
      when is_bitstring(location) and is_integer(depth) and depth > 0 do
    %__MODULE__{tree: MerkleTreeImpl.subtree(tree, location, depth)}
  end

  def max_depth(%__MODULE__{tree: tree}) do
    MerkleTreeImpl.max_depth(tree)
  end

  def update_hashes(%__MODULE__{tree: tree}) do
    %__MODULE__{tree: MerkleTreeImpl.calculate_hashes(tree)}
  end

  def prepare_partial_diff(merkle_tree, depth) do
    {:continue, %Diff{trees: [{<<>>, subtree(merkle_tree, <<>>, depth)}]}}
  end

  def continue_partial_diff(merkle_tree, %Diff{} = partial, depth)
      when is_integer(depth) and depth > 0 do
    {partials, keys} =
      partial.trees
      |> Enum.flat_map(fn {loc, tree} ->
        merkle_tree
        |> subtree(loc, depth)
        |> diff_keys(tree, bit_size(loc))
      end)
      |> Enum.split_with(fn
        {:partial, _loc} -> true
        _ -> false
      end)

    trees =
      Enum.map(partials, fn {:partial, loc} ->
        {loc, subtree(merkle_tree, loc, depth)}
      end)

    case trees do
      [] -> {:ok, partial.keys ++ keys}
      trees -> {:continue, %Diff{keys: partial.keys ++ keys, trees: trees}}
    end
  end

  def truncate_diff(%Diff{} = diff, amount) do
    keys = Enum.take(diff.keys, amount)
    trees = Enum.take(diff.trees, amount - length(keys))
    %{diff | keys: keys, trees: trees}
  end
end
