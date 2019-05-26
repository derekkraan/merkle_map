defmodule MerkleMap.MerkleTree do
  @opaque t() :: %__MODULE__{}
  @type key :: term()
  @type value :: term()

  defstruct [:tree]

  alias MerkleMap.MerkleTreeImpl

  @spec new(Enumerable.t()) :: t()
  def new(enum) do
    %__MODULE__{tree: MerkleTreeImpl.new(enum)}
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

  @spec diff_keys(t(), t()) :: {t(), t(), [key()]}
  def diff_keys(%__MODULE__{tree: tree}, %__MODULE__{tree: tree2}) do
    {tree, tree2, keys} = MerkleTreeImpl.diff_keys(tree, tree2)
    {%__MODULE__{tree: tree}, %__MODULE__{tree: tree2}, keys}
  end

  @spec diff_keys(t(), t()) :: {t(), t(), boolean()}
  def equal?(%__MODULE__{tree: tree}, %__MODULE__{tree: tree2}) do
    MerkleTreeImpl.equal?(tree, tree2)
  end

  @spec keys(t()) :: [key()]
  def keys(%__MODULE__{tree: tree}) do
    MerkleTreeImpl.keys(tree)
  end
end
