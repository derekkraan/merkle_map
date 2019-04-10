defmodule MerkleMap.MixProject do
  use Mix.Project

  def project do
    [
      app: :merkle_map,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: "merkle_map",
      description: "A faster Map, augmented with a MerkleTree",
      licenses: ["MIT"],
      maintainers: ["Derek Kraan"],
      links: %{GitHub: "https://github.com/derekkraan/merkle_map.ex"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:murmur, "~> 1.0", optional: true},
      {:stream_data, "~> 0.4", only: :test},
      {:benchee, "> 0.0.0", only: :dev},
      {:ex_doc, "> 0.0.0", only: :dev}
    ]
  end
end
