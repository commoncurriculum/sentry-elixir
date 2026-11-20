defmodule PhoenixApp.RepoTest do
  use PhoenixApp.DataCase, async: false

  alias PhoenixApp.{Repo, Accounts.User}

  import Sentry.Test.Assertions

  setup do
    Sentry.Test.setup_sentry(collect_envelopes: true, traces_sample_rate: 1.0)
  end

  test "instrumented top-level ecto transaction span", %{ref: ref} do
    Repo.all(User) |> Enum.map(& &1.id)

    tx =
      assert_sentry_transaction(ref,
        transaction_info: %{"source" => "custom"},
        contexts: %{
          trace: %{
            op: "db",
            data: %{
              "db.system.name" => "sqlite",
              "db.namespace" => "db/test.sqlite3"
            }
          }
        }
      )

    trace = tx["contexts"]["trace"]

    assert String.starts_with?(trace["description"], "SELECT")
    assert String.starts_with?(trace["data"]["db.query.text"], "SELECT")
  end
end
