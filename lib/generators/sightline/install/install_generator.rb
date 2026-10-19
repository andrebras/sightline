require "rails/generators"

module Sightline
  module Generators
    # bin/rails generate sightline:install [--base-controller=Admin::BaseController] [--mount-at=/admin]
    #                                      [--[no-]queue-in-primary]
    #
    # Writes config/initializers/sightline.rb, mounts Sightline, and gives development and test their own Solid Queue
    # database, as production has, so Health and Jobs show real jobs locally. database.yml is only changed when it has
    # the plain SQLite shape `rails new` writes; otherwise the generator says what to add.
    #
    # An app that keeps Solid Queue's tables in its primary database (--queue-in-primary, or found when production in
    # database.yml has no queue database) gets no queue databases: its development and test are left as they are.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :base_controller, default: "Admin::BaseController",
                                     desc: "The app's controller whose sign-in and admin check guard the admin area"
      class_option :mount_at, default: "/admin", desc: "Where the admin area lives"
      class_option :queue_in_primary, type: :boolean, default: nil,
                                      desc: "Solid Queue's tables are in the primary database, so add no queue " \
                                            "databases (default: when production in database.yml has no queue database)"

      QUEUE_ENVIRONMENTS = %w[development test].freeze

      def create_initializer
        template "sightline.rb.tt", "config/initializers/sightline.rb"
      end

      def mount_engine
        route %(mount Sightline::Engine, at: "#{mount_path}")
      end

      def add_queue_databases
        return say_status(:skip, "config/database.yml: Solid Queue stays in the primary database") if queue_in_primary?
        return say_queue_instructions unless database_yml

        yaml = database_yml
        changed = QUEUE_ENVIRONMENTS.reduce(yaml) { |text, env| with_queue_database(text, env) }
        return say_queue_instructions if changed.nil?

        File.write(File.join(destination_root, "config/database.yml"), changed) unless changed == yaml
        say_status(changed == yaml ? :identical : :update, "config/database.yml")
      end

      def connect_solid_queue
        return if queue_in_primary?

        QUEUE_ENVIRONMENTS.each do |env|
          file = "config/environments/#{env}.rb"
          next unless File.exist?(File.join(destination_root, file))
          next if File.read(File.join(destination_root, file)).include?("solid_queue.connects_to")

          inject_into_file file, after: /configure do\n/ do
            "  config.solid_queue.connects_to = { database: { writing: :queue } }\n"
          end
        end
      end

      def say_next_steps
        say <<~TEXT

          Sightline is mounted at #{mount_path}. Next:
            1. Make sure #{options[:base_controller]} exists and refuses everyone but admins.
            2. Your layout should `yield :head`, for Jobs' scripts.
            3. bin/rails db:prepare, then run the jobs locally with bin/jobs (or SOLID_QUEUE_IN_PUMA=1).
        TEXT
      end

      private

      def mount_path = "/#{options[:mount_at].delete_prefix("/")}"
      def app_title = Rails.application.class.module_parent_name.titleize

      def database_yml
        return @database_yml if defined?(@database_yml)

        path = File.join(destination_root, "config/database.yml")
        @database_yml = File.exist?(path) ? File.read(path) : nil
      end

      # The option when given; otherwise whether production, in database.yml, has no queue database of its own.
      # Read as text, not YAML, since database.yml often holds ERB.
      def queue_in_primary?
        return options[:queue_in_primary] unless options[:queue_in_primary].nil?

        production = database_yml&.[](/^production:\n(?:[ \t]+.*\n?|\n)*/)
        production.present? && !production.match?(/^\s+queue:/)
      end

      # Whether the app's databases are SQLite, which Health's disk space check looks for by default.
      def sqlite? = database_yml.nil? || database_yml.match?(/^\s*adapter:\s*["']?sqlite3/)

      # The env's block with a queue database added: the plain SQLite shape (`<<: *default` and a .sqlite3 database)
      # becomes primary and queue. Unchanged when it already has a queue; nil when its shape isn't the plain one.
      def with_queue_database(yaml, env)
        return if yaml.nil?

        block = yaml[/^#{env}:\n(?:[ \t]+.*\n?|\n)*/]
        return yaml if block&.match?(/^\s+queue:/)
        return if block.nil? || block.match?(/^\s+primary:/)
        return unless (database = block[/^\s+database:\s*(\S+\.sqlite3)\s*$/, 1])

        indent = block[/^([ \t]+)\S/, 1]
        queue = database.sub(/\.sqlite3\z/, "_queue.sqlite3")
        lines = block.lines.drop(1).compact_blank.map { |line| indent + line }
        replacement = "#{env}:\n#{indent}primary:\n#{lines.join}" \
                      "#{indent}queue:\n#{indent * 2}<<: *default\n#{indent * 2}database: #{queue}\n" \
                      "#{indent * 2}migrations_paths: db/queue_migrate\n"
        yaml.sub(block, block.end_with?("\n\n") ? "#{replacement}\n" : replacement)
      end

      def say_queue_instructions
        say_status :skip, "config/database.yml: add a queue database to development and test by hand " \
                          "(see production's), with migrations_paths: db/queue_migrate", :yellow
      end
    end
  end
end
