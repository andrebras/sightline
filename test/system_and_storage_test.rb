require "test_helper"

# The System and Storage cards, and the disk space check. Paths and the environment are passed in, never stubbed.
class SystemAndStorageTest < Sightline::IntegrationTest
  setup do
    @dir = Dir.mktmpdir("sightline")
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "memory comes from /proc on Linux" do
    status = File.join(@dir, "status")
    File.write(status, "Name:\truby\nVmPeak:\t  999999 kB\nVmRSS:\t  123456 kB\nThreads:\t5\n")
    assert_equal 123_456 * 1024, Sightline::System.new(proc_status: status).memory
  end

  test "without /proc, memory comes from ps" do
    memory = Sightline::System.new(proc_status: File.join(@dir, "missing")).memory
    assert_operator memory, :>, 1024 * 1024
  end

  test "on Fly, the deployment and region; anywhere else, running locally" do
    fly = Sightline::System.new(env: { "FLY_IMAGE_REF" => "registry.fly.io/plymico:deployment-01K8Q2ZX9ABCDEFG",
                                       "FLY_REGION" => "lhr" })
    assert_equal "9abcdefg", fly.deployment
    assert_equal "Fly.io · deployment 9abcdefg · region lhr", fly.running_on
    assert_equal "Running locally", Sightline::System.new(env: {}).running_on
  end

  test "free space on the directory's volume, and its database files with their logs" do
    database = File.join(@dir, "app.sqlite3")
    File.write(database, "x" * 3000)
    File.write("#{database}-wal", "x" * 1000)
    storage = Sightline::Storage.new(path: @dir, database_paths: [ database ], warning_below: 0, problem_below: 0)
    assert_operator storage.space.total, :>, 0
    assert_operator storage.space.available, :<=, storage.space.total
    assert_equal([ [ "app.sqlite3", 4000 ] ], storage.database_files.map { |file| [ file.name, file.size ] })
    assert_predicate storage.result, :ok?
    assert_match(/free of .* \(\d+%\)/, storage.result.summary)
  end

  test "below the thresholds, a warning and then a problem" do
    warning = Sightline::Storage.new(path: @dir, warning_below: 101, problem_below: 0).result
    assert_equal :warning, warning.status
    assert_equal "Below 101% free", warning.detail
    assert_equal :problem, Sightline::Storage.new(path: @dir, warning_below: 101, problem_below: 101).result.status
  end

  test "a path df can't read is a warning, not an error" do
    result = Sightline::Storage.new(path: File.join(@dir, "missing")).result
    assert_equal :warning, result.status
    assert_equal "Couldn't read free space", result.summary
  end

  test "Health shows the System and Storage cards and the disk space check" do
    get "/admin/health", headers: ADMIN
    assert_equal [ "Ruby", "Rails", "Booted", "Memory", "Running on" ], css_select("#sl-system dt").map(&:text)
    assert_select "#sl-system dd", /\A#{Regexp.escape(RUBY_VERSION)}/o
    assert_select "#sl-system dd", Rails.version
    assert_select "#sl-system dd", "Running locally"
    assert_select "#sl-system dd", /\d+(\.\d+)? MB/
    assert_select "#sl-storage dt", "test.sqlite3"
    assert_select "#sl-storage dd", File.expand_path("dummy/tmp", __dir__)
    assert_select ".sl-check.sl-ok .sl-check-name", "Disk space"
  end

  test "the disk check follows the configured path and thresholds" do
    with_config(storage_path: @dir, storage_warning_below: 101) do
      get "/admin/health", headers: ADMIN
    end
    assert_select "#sl-storage dd", @dir
    assert_select ".sl-check.sl-warning .sl-check-name", "Disk space"
  end

  test "the storage card and check can be left out" do
    with_config(storage_check: false) do
      get "/admin/health", headers: ADMIN
    end
    assert_select "#sl-storage", 0
    assert_select ".sl-check-name", text: "Disk space", count: 0
  end
end
