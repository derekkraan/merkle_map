defmodule MerkleMap.MerkleTree.Diff do
  @moduledoc false

  # Trees: Subtrees that need further exploration (or represent larger differences)
  # Keys: tree leaf differences
  defstruct trees: [], keys: []

  @doc """
  Truncates an existing (potentially partial) diff of a MerkleTree, prioritizing keys over trees.
  """
  def truncate_diff(%__MODULE__{} = diff, amount) do
    keys = Enum.take(diff.keys, amount)
    trees = Enum.take(diff.trees, amount - length(keys))
    %{diff | keys: keys, trees: trees}
  end
end
