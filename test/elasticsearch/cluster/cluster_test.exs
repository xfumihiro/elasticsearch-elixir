defmodule Elasticsearch.ClusterTest do
  use ExUnit.Case, async: false

  def valid_config do
    %{
      api: Elasticsearch.API.HTTP,
      bulk_page_size: 5000,
      bulk_wait_interval: 5000,
      json_library: Poison,
      url: "http://localhost:9200",
      username: "username",
      password: "password",
      indexes: %{
        posts: %{
          settings: "test/support/settings/posts.json",
          store: Elasticsearch.Test.Store,
          sources: [Post]
        }
      }
    }
  end

  setup do
    Application.put_env(
      :elasticsearch,
      Elasticsearch.ClusterTest.MixConfiguredCluster,
      valid_config()
    )
  end

  defmodule Cluster do
    use Elasticsearch.Cluster
  end

  defmodule MixConfiguredCluster do
    use Elasticsearch.Cluster, otp_app: :elasticsearch
  end

  defmodule InitConfiguredCluster do
    use Elasticsearch.Cluster

    def init(_config) do
      {:ok, Elasticsearch.ClusterTest.valid_config()}
    end
  end

  describe "configuration" do
    test "accepts Mix configuration" do
      assert {:ok, _pid} = MixConfiguredCluster.start_link()
      assert MixConfiguredCluster.__config__() == valid_config()
    end

    test "accepts init configuration" do
      assert {:ok, _pid} = InitConfiguredCluster.start_link()
      assert InitConfiguredCluster.__config__() == valid_config()
    end

    test "accepts configuration on startup" do
      assert {:ok, _pid} = Cluster.start_link(valid_config())
      assert Cluster.__config__() == valid_config()
    end
  end

  describe ".start_link/1" do
    test "validates url" do
      refute errors_on(url: "http://localhost:9200")[:url]
      assert errors_on(url: "werlkjweoqwelj").url
    end

    test "validates username" do
      assert {"must be present", validation: :presence} in errors_on(%{password: "password"}).username
      refute errors_on([])[:username]
    end

    test "validates password" do
      assert {"must be present", validation: :presence} in errors_on(%{username: "username"}).password
      refute errors_on([])[:password]
    end

    test "validates api" do
      assert {"must be present", validation: :presence} in errors_on([]).api

      for invalid <- [Nonexistent.Module, "string"] do
        assert {"must be valid", validation: :by} in errors_on(api: invalid).api
      end
    end

    test "validates json_library" do
      refute errors_on([])[:json_library]
      refute errors_on(json_library: Poison)[:json_library]

      assert {"must be valid", validation: :by} in errors_on(json_library: Nonexistent.Module).json_library
    end

    test "validates bulk_page_size" do
      assert {"must be present", validation: :presence} in errors_on([]).bulk_page_size

      for invalid <- [nil, "string", :atom] do
        assert {"must be valid", validation: :by} in errors_on(bulk_page_size: invalid).bulk_page_size
      end
    end

    test "validates bulk_wait_interval" do
      assert {"must be present", validation: :presence} in errors_on([]).bulk_wait_interval

      for invalid <- [nil, "string", :atom] do
        assert {"must be valid", validation: :by} in errors_on(bulk_wait_interval: invalid).bulk_wait_interval
      end
    end

    test "validates indexes" do
      errors = errors_on(%{valid_config() | indexes: %{example: %{}}})

      for field <- [:settings, :store, :sources] do
        assert {"must be present", validation: :presence} in errors[field]
      end

      errors =
        errors_on(%{
          valid_config()
          | indexes: %{example: %{settings: :atom, store: Nonexistent.Module, sources: 123}}
        })

      for field <- [:settings, :store, :sources] do
        assert {"must be valid", validation: :by} in errors[field]
      end
    end

    test "accepts valid configuration" do
      assert {:ok, pid} = Cluster.start_link(valid_config())
      assert is_pid(pid)
    end
  end

  defp errors_on(config) do
    {:error, errors} = Cluster.start_link(config)
    errors
  end
end
