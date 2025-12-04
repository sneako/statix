Code.require_file("support/test_server.exs", __DIR__)

ExUnit.start()

defmodule Statix.TestCase do
  use ExUnit.CaseTemplate

  using _options do
    quote do
      setup_all do
        {:ok, _pid} = Statix.TestServer.start_link(0, __MODULE__.Server)
        port = Statix.TestServer.port(__MODULE__.Server)
        Application.put_env(:statix, :port, port)
        {:ok, [statix_port: port]}
      end

      setup do
        Statix.TestServer.setup(__MODULE__.Server)
      end
    end
  end
end
