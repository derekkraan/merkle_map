defmodule MerkleMap.MerkleTree.Diff do
  @moduledoc false

  defstruct trees: [], keys: []

  def truncate_diff(%__MODULE__{} = diff, amount) do
    keys = Enum.take(diff.keys, amount)
    trees = Enum.take(diff.trees, amount - length(keys))
    %{diff | keys: keys, trees: trees}
  end
end
