require "test_helper"
require "generators/sightline/install/install_generator"

# bin/rails generate sightline:install, in an app laid out like `rails new` writes it.
class InstallGeneratorTest < Rails::Generators::TestCase
  tests Sightline::Generators::InstallGenerator
  destination File.expand_path("dummy/tmp/generator", __dir__)
  setup :prepare_destination

  DATABASE_YML = <<~YAML.freeze
    default: &default
      adapter: sqlite3
      pool: 5

    development:
      <<: *default
      database: storage/development.sqlite3

    test:
      <<: *default
      database: storage/test.sqlite3

    production:
      primary:
        <<: *default
        database: storage/production.sqlite3
      queue:
        <<: *default
        database: storage/production_queue.sqlite3
        migrations_paths: db/queue_migrate
  YAML

  EMPTY_ENVIRONMENT = "Rails.application.configure do\nend\n".freeze

  setup do
    write "config/routes.rb", "Rails.application.routes.draw do\nend\n"
    write "config/database.yml", DATABASE_YML
    %w[development test].each { |env| write "config/environments/#{env}.rb", EMPTY_ENVIRONMENT }
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(destination_root, path)))
    File.write(File.join(destination_root, path), content)
  end

  def assert_environments_untouched
    %w[development test].each do |env|
      assert_file("config/environments/#{env}.rb") { |content| assert_equal EMPTY_ENVIRONMENT, content }
    end
  end

  test "writes the initializer with the app's admin controller and mounts Sightline" do
    run_generator %w[--base-controller=Staff::BaseController --mount-at=/ops]
    assert_file "config/initializers/sightline.rb", /c\.base_controller = "Staff::BaseController"/
    assert_file "config/routes.rb", %r{mount Sightline::Engine, at: "/ops"}
  end

  test "gives development and test a queue database, and leaves production as it was" do
    run_generator
    database = YAML.safe_load_file(File.join(destination_root, "config/database.yml"), aliases: true)
    assert_equal "storage/development.sqlite3", database.dig("development", "primary", "database")
    assert_equal "storage/development_queue.sqlite3", database.dig("development", "queue", "database")
    assert_equal "db/queue_migrate", database.dig("test", "queue", "migrations_paths")
    assert_equal "sqlite3", database.dig("test", "queue", "adapter")
    assert_equal "storage/production_queue.sqlite3", database.dig("production", "queue", "database")
    assert_file "config/environments/development.rb", /solid_queue\.connects_to = \{ database: \{ writing: :queue \} \}/
    assert_file "config/environments/test.rb", /solid_queue\.connects_to/
  end

  test "running it again changes nothing more" do
    run_generator
    first = File.read(File.join(destination_root, "config/database.yml"))
    run_generator
    assert_equal first, File.read(File.join(destination_root, "config/database.yml"))
    assert_file("config/environments/test.rb") do |content|
      assert_equal 1, content.scan("solid_queue.connects_to").size
    end
  end

  test "an app whose production keeps Solid Queue in the primary database gets no queue databases" do
    postgres = <<~YAML
      default: &default
        adapter: postgresql

      development:
        <<: *default
        database: app_development

      production:
        <<: *default
        url: <%= ENV["DATABASE_URL"] %>
    YAML
    write "config/database.yml", postgres
    output = run_generator
    assert_equal postgres, File.read(File.join(destination_root, "config/database.yml"))
    assert_match(/Solid Queue stays in the primary database/, output)
    assert_no_match(/by hand/, output)
    assert_file("config/environments/development.rb") { |content| assert_no_match(/solid_queue\.connects_to/, content) }
    assert_file "config/initializers/sightline.rb", /# c\.storage_path = /
  end

  test "--queue-in-primary leaves even a plain SQLite database.yml alone" do
    run_generator %w[--queue-in-primary]
    assert_equal DATABASE_YML, File.read(File.join(destination_root, "config/database.yml"))
    assert_file("config/environments/test.rb") { |content| assert_no_match(/solid_queue\.connects_to/, content) }
    assert_file("config/initializers/sightline.rb") { |content| assert_no_match(/storage_path/, content) }
  end

  test "--no-queue-in-primary adds the queue databases although production has none" do
    production = "production:\n  <<: *default\n  database: storage/production.sqlite3\n"
    write "config/database.yml", DATABASE_YML.sub(/^production:.*/m, production)
    run_generator %w[--no-queue-in-primary]
    database = YAML.safe_load_file(File.join(destination_root, "config/database.yml"), aliases: true)
    assert_equal "storage/test_queue.sqlite3", database.dig("test", "queue", "database")
    assert_file "config/environments/test.rb", /solid_queue\.connects_to/
  end

  test "a database.yml it doesn't recognize is left alone, and so are the environments, with instructions for both" do
    postgres = "development:\n  adapter: postgresql\n  database: app_development\n"
    write "config/database.yml", postgres
    output = run_generator
    assert_equal postgres, File.read(File.join(destination_root, "config/database.yml"))
    assert_environments_untouched
    assert_match(/add a queue database to development and test by hand/, output)
    assert_match(/config\.solid_queue\.connects_to = \{ database: \{ writing: :queue \} \}/, output)
  end

  test "when only one environment has the plain shape, neither changes" do
    write "config/database.yml", DATABASE_YML.sub("test:\n  <<: *default\n", "test:\n  <<: *default\n  host: db\n")
                                             .sub("storage/test.sqlite3", "app_test")
    output = run_generator
    assert_no_match(/queue/, File.read(File.join(destination_root, "config/database.yml"))[/^development:.*?\n\n/m])
    assert_environments_untouched
    assert_match(/by hand/, output)
  end

  test "without a database.yml, the environments are left alone, with instructions" do
    FileUtils.rm(File.join(destination_root, "config/database.yml"))
    output = run_generator %w[--no-queue-in-primary]
    assert_environments_untouched
    assert_match(/connects_to/, output)
  end

  test "a database.yml that already has queue databases still gets the environments connected" do
    run_generator
    %w[development test].each { |env| write "config/environments/#{env}.rb", EMPTY_ENVIRONMENT }
    run_generator
    assert_file "config/environments/development.rb", /solid_queue\.connects_to/
    assert_file "config/environments/test.rb", /solid_queue\.connects_to/
  end
end
