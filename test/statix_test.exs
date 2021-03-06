defmodule StatixTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  defmodule Server do
    use GenServer

    def start_link(port) do
      GenServer.start_link(__MODULE__, port, name: __MODULE__)
    end

    def set_current_test(test) do
      GenServer.call(__MODULE__, {:set_current_test, test})
    end

    def init(port) do
      {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
      {:ok, %{socket: socket, test: nil}}
    end

    def handle_call({:set_current_test, current_test}, _from, %{test: test} = state) do
      if is_nil(test) or is_nil(current_test) do
        {:reply, :ok, %{state | test: current_test}}
      else
        {:reply, :error, state}
      end
    end

    def handle_info({:udp, socket, _, _, packet}, %{socket: socket, test: test} = state) do
      send(test, {:server, packet})
      {:noreply, state}
    end
  end

  runtime_config? = System.get_env("STATIX_TEST_RUNTIME_CONFIG") in ["1", "true"]

  content =
    quote do
      use Statix, runtime_config: unquote(runtime_config?)

      def close_port() do
        %Statix.Conn{sock: sock} = current_conn()
        Port.close(sock)
      end
    end

  Module.create(TestStatix, content, Macro.Env.location(__ENV__))

  defmodule OverridingStatix do
    use Statix

    def increment(key, val, options) do
      super([key, "-overridden"], val, options)
    end

    def decrement(key, val, options) do
      super([key, "-overridden"], val, options)
    end

    def gauge(key, val, options) do
      super([key, "-overridden"], val, options)
    end

    def histogram(key, val, options) do
      super([key, "-overridden"], val, options)
    end

    def timing(key, val, options) do
      super([key, "-overridden"], val, options)
    end

    def measure(key, options, fun) do
      super([key, "-measure"], options, fun)
    end

    def set(key, val, options) do
      super([key, "-overridden"], val, options)
    end

    def event(title, text, options) do
      super("#{title}-overridden", text, options)
    end

    def service_check(name, status, options) do
      super("#{name}-overridden", status, options)
    end
  end

  setup_all do
    {:ok, _} = Server.start_link(8125)
    :ok
  end

  setup do
    :ok = Server.set_current_test(self())
    TestStatix.connect()
    OverridingStatix.connect()
    on_exit(fn -> Server.set_current_test(nil) end)
  end

  test "increment/1,2,3" do
    TestStatix.increment("sample")
    assert_receive {:server, "sample:1|c"}

    TestStatix.increment(["sample"], 2)
    assert_receive {:server, "sample:2|c"}

    TestStatix.increment("sample", 2.1)
    assert_receive {:server, "sample:2.1|c"}

    TestStatix.increment("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|c|#foo:bar,baz"}

    TestStatix.increment("sample", 3, tags: ["baz", foo: "bar"])
    assert_receive {:server, "sample:3|c|#baz,foo:bar"}

    TestStatix.increment("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|c|@1.0|#foo,bar"}

    TestStatix.increment("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "decrement/1,2,3" do
    TestStatix.decrement("sample")
    assert_receive {:server, "sample:-1|c"}

    TestStatix.decrement(["sample"], 2)
    assert_receive {:server, "sample:-2|c"}

    TestStatix.decrement("sample", 2.1)
    assert_receive {:server, "sample:-2.1|c"}

    TestStatix.decrement("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:-3|c|#foo:bar,baz"}

    TestStatix.decrement("sample", 3, tags: ["baz", foo: "bar"])
    assert_receive {:server, "sample:-3|c|#baz,foo:bar"}

    TestStatix.decrement("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:-3|c|@1.0|#foo,bar"}

    TestStatix.decrement("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "gauge/2,3" do
    TestStatix.gauge(["sample"], 2)
    assert_receive {:server, "sample:2|g"}

    TestStatix.gauge("sample", 2.1)
    assert_receive {:server, "sample:2.1|g"}

    TestStatix.gauge("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|g|#foo:bar,baz"}

    TestStatix.gauge("sample", 3, tags: ["baz", foo: "bar"])
    assert_receive {:server, "sample:3|g|#baz,foo:bar"}

    TestStatix.gauge("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|g|@1.0|#foo,bar"}

    TestStatix.gauge("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "histogram/2,3" do
    TestStatix.histogram("sample", 2)
    assert_receive {:server, "sample:2|h"}

    TestStatix.histogram("sample", 2.1)
    assert_receive {:server, "sample:2.1|h"}

    TestStatix.histogram("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|h|#foo:bar,baz"}

    TestStatix.histogram("sample", 3, tags: ["baz", foo: "bar"])
    assert_receive {:server, "sample:3|h|#baz,foo:bar"}

    TestStatix.histogram("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|h|@1.0|#foo,bar"}

    TestStatix.histogram("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "timing/2,3" do
    TestStatix.timing(["sample"], 2)
    assert_receive {:server, "sample:2|ms"}

    TestStatix.timing("sample", 2.1)
    assert_receive {:server, "sample:2.1|ms"}

    TestStatix.timing("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|ms|#foo:bar,baz"}

    TestStatix.timing("sample", 3, tags: ["baz", foo: "bar"])
    assert_receive {:server, "sample:3|ms|#baz,foo:bar"}

    TestStatix.timing("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|ms|@1.0|#foo,bar"}

    TestStatix.timing("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "measure/2,3" do
    expected = "the stuff"

    result =
      TestStatix.measure(["sample"], fn ->
        :timer.sleep(100)
        expected
      end)

    assert_receive {:server, <<"sample:10", _, "|ms">>}
    assert result == expected

    TestStatix.measure("sample", [sample_rate: 1.0, tags: ["foo", "bar"]], fn ->
      :timer.sleep(100)
    end)

    assert_receive {:server, <<"sample:10", _, "|ms|@1.0|#foo,bar">>}

    refute_received _any
  end

  test "set/2,3" do
    TestStatix.set(["sample"], 2)
    assert_receive {:server, "sample:2|s"}

    TestStatix.set("sample", 2.1)
    assert_receive {:server, "sample:2.1|s"}

    TestStatix.set("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|s|#foo:bar,baz"}

    TestStatix.set("sample", 3, tags: ["baz", foo: "bar"])
    assert_receive {:server, "sample:3|s|#baz,foo:bar"}

    TestStatix.set("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|s|@1.0|#foo,bar"}

    TestStatix.set("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "event/2,3" do
    # a generic Unix time
    now_unix = 1234

    TestStatix.event("sample title", "sample text")
    assert_receive {:server, "_e{12,11}:sample title|sample text"}

    TestStatix.event("sample title", "sample text", timestamp: now_unix)
    s = "_e{12,11}:sample title|sample text|d:#{now_unix}"
    assert_receive {:server, ^s}

    TestStatix.event("sample title", "sample text", hostname: "sample.hostname")
    assert_receive {:server, "_e{12,11}:sample title|sample text|h:sample.hostname"}

    TestStatix.event("sample title", "sample text", aggregation_key: "sample_aggregation_key")
    assert_receive {:server, "_e{12,11}:sample title|sample text|k:sample_aggregation_key"}

    TestStatix.event("sample title", "sample text", priority: :normal)
    assert_receive {:server, "_e{12,11}:sample title|sample text|p:normal"}

    TestStatix.event("sample title", "sample text", source_type_name: "sample source type")
    assert_receive {:server, "_e{12,11}:sample title|sample text|s:sample source type"}

    TestStatix.event("sample title", "sample text", alert_type: :warning)
    assert_receive {:server, "_e{12,11}:sample title|sample text|t:warning"}

    TestStatix.event("sample title", "sample text", tags: ["foo", "bar"])
    assert_receive {:server, "_e{12,11}:sample title|sample text|#foo,bar"}

    TestStatix.event("sample title", "sample text",
      timestamp: now_unix,
      hostname: "H",
      aggregation_key: "K",
      priority: :low,
      source_type_name: "S",
      alert_type: "T",
      tags: ["F", "B"]
    )

    s = "_e{12,11}:sample title|sample text|d:#{now_unix}|h:H|k:K|p:low|s:S|t:T|#F,B"
    assert_receive {:server, ^s}

    refute_received _any
  end

  test "service_check/2,3" do
    # a generic Unix time
    now_unix = 1234

    TestStatix.service_check("sample name", :ok)
    assert_receive {:server, "_sc|sample name|0"}

    TestStatix.service_check("sample name", :ok, timestamp: now_unix)
    s = "_sc|sample name|0|d:#{now_unix}"
    assert_receive {:server, ^s}

    TestStatix.service_check("sample name", :ok, hostname: "sample.hostname")
    assert_receive {:server, "_sc|sample name|0|h:sample.hostname"}

    TestStatix.service_check("sample name", :ok, tags: ["foo", "bar"])
    assert_receive {:server, "_sc|sample name|0|#foo,bar"}

    TestStatix.service_check("sample name", :ok, message: "sample message")
    assert_receive {:server, "_sc|sample name|0|m:sample message"}

    TestStatix.service_check("sample name", :warning,
      timestamp: now_unix,
      hostname: "H",
      tags: ["F", "B"],
      message: "M"
    )

    s = "_sc|sample name|1|d:#{now_unix}|h:H|#F,B|m:M"
    assert_receive {:server, ^s}

    refute_received _any
  end

  test "overridden callbacks" do
    OverridingStatix.increment("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample-overridden:3|c|#foo"}

    OverridingStatix.decrement("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample-overridden:-3|c|#foo"}

    OverridingStatix.gauge("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample-overridden:3|g|#foo"}

    OverridingStatix.histogram("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample-overridden:3|h|#foo"}

    OverridingStatix.timing("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample-overridden:3|ms|#foo"}

    OverridingStatix.measure("sample", [tags: ["foo"]], fn ->
      :timer.sleep(100)
    end)

    assert_receive {:server, <<"sample-measure-overridden:10", _, "|ms|#foo">>}

    OverridingStatix.set("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample-overridden:3|s|#foo"}

    OverridingStatix.event("sample-title", "sample-text", tags: ["foo"])
    assert_receive {:server, "_e{23,11}:sample-title-overridden|sample-text|#foo"}

    OverridingStatix.service_check("sample-name", :ok, tags: ["foo"])
    assert_receive {:server, "_sc|sample-name-overridden|0|#foo"}
  end

  test "sends global tags when present" do
    Application.put_env(:statix, :tags, ["tag:test"])

    TestStatix.increment("sample", 3)
    assert_receive {:server, "sample:3|c|#tag:test"}

    TestStatix.increment("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample:3|c|#foo,tag:test"}
  after
    Application.delete_env(:statix, :tags)
  end

  test "sends global connection-specific tags" do
    Application.put_env(:statix, TestStatix, tags: ["tag:test"])

    TestStatix.increment("sample", 3)
    assert_receive {:server, "sample:3|c|#tag:test"}

    TestStatix.increment("sample", 3, tags: ["foo"])
    assert_receive {:server, "sample:3|c|#foo,tag:test"}
  after
    Application.delete_env(:statix, TestStatix)
  end

  test "port closed" do
    TestStatix.close_port()

    assert capture_log(fn ->
             assert {:error, :port_closed} == TestStatix.increment("sample")
           end) =~ "counter metric \"sample\" lost value 1 due to port closure"

    assert capture_log(fn ->
             assert {:error, :port_closed} == TestStatix.decrement("sample")
           end) =~ "counter metric \"sample\" lost value -1 due to port closure"

    assert capture_log(fn ->
             assert {:error, :port_closed} == TestStatix.gauge("sample", 2)
           end) =~ "gauge metric \"sample\" lost value 2 due to port closure"

    assert capture_log(fn ->
             assert {:error, :port_closed} == TestStatix.histogram("sample", 3)
           end) =~ "histogram metric \"sample\" lost value 3 due to port closure"

    assert capture_log(fn ->
             assert {:error, :port_closed} == TestStatix.timing("sample", 2.5)
           end) =~ "timing metric \"sample\" lost value 2.5 due to port closure"
  end
end
