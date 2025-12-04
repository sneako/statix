defmodule BenchTags do
  use Statix, runtime_config: true
end

BenchTags.connect()

tags = Enum.map(1..50, &"tag-#{&1}:value-#{&1}")

Benchee.run(%{
  "increment_with_50_tags" => fn ->
    BenchTags.increment("benchmark.key", 1, tags: tags)
  end
}, time: 5, memory_time: 2)