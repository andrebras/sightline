require "open3"

module Sightline
  # Free space on the volume holding the databases, read with `df -Pk` (POSIX output, in kilobytes, on Linux and
  # macOS alike), and the size of each SQLite database file. The path is an argument, so tests can point it anywhere.
  class Storage
    Space = Data.define(:total, :available) do
      def percent_free = total.zero? ? 0 : 100.0 * available / total
    end
    DatabaseFile = Data.define(:name, :path, :size)
    # SQLite's write-ahead log and shared memory files sit beside each database and hold its recent writes.
    SQLITE_SUFFIXES = [ "", "-wal", "-shm" ].freeze

    # label is what Health shows for the volume: the path as the app configured it, or, for the directory Sightline
    # found itself, a short name (label_for), so the machine's full path, which can name its user, doesn't show.
    attr_reader :path, :label

    def initialize(path:, label: nil, database_paths: [], warning_below: 20, problem_below: 10)
      @path = path.to_s
      @label = label || @path
      @database_paths = database_paths
      @warning_below = warning_below
      @problem_below = problem_below
    end

    # The SQLite databases of this environment, from config/database.yml, and the directory of the first one.
    def self.from_app(config)
      paths = sqlite_paths
      found = paths.any? ? File.dirname(paths.first) : Rails.root.join("storage").to_s
      new(path: config.storage_path || found, label: config.storage_path&.to_s || label_for(found),
          database_paths: paths,
          warning_below: config.storage_warning_below, problem_below: config.storage_problem_below)
    end

    def self.sqlite_paths
      ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).filter_map do |db_config|
        database = db_config.database.to_s
        next unless db_config.adapter.to_s.include?("sqlite") && database.exclude?(":memory:")

        File.expand_path(database, Rails.root)
      end
    end

    # The directory relative to the app (storage, db/sqlite), or its own name when it's the app's or outside it.
    def self.label_for(directory)
      relative = Pathname(directory).relative_path_from(Rails.root).to_s
      relative == "." || relative.start_with?("..") ? File.basename(directory) : relative
    end

    def space
      return @space if defined?(@space)

      @space = read_space
    end

    # Each database's size, with its write-ahead log and shared memory files.
    def database_files
      @database_paths.map do |database|
        size = SQLITE_SUFFIXES.sum { |suffix| File.size?("#{database}#{suffix}").to_i }
        DatabaseFile.new(name: File.basename(database), path: database, size: size)
      end
    end

    def result
      return Sightline.warning("Couldn't read free space", detail: "df gave no answer for #{label}.") unless space

      free = space.percent_free
      summary = "#{format_bytes(space.available)} free of #{format_bytes(space.total)} (#{free.round}%)"
      status = if free < @problem_below then :problem
               elsif free < @warning_below then :warning
               else :ok
               end
      Result.new(status: status, summary: summary,
                 detail: ("Below #{status == :problem ? @problem_below : @warning_below}% free" unless status == :ok))
    end

    private

    def read_space
      output, status = Open3.capture2("df", "-Pk", path, err: File::NULL)
      blocks, _used, available = output.lines.last.to_s.match(/\s(\d+)\s+(\d+)\s+(\d+)\s+\d+%\s/)&.captures
      Space.new(total: Integer(blocks) * 1024, available: Integer(available) * 1024) if status.success? && blocks
    rescue SystemCallError
      nil
    end

    def format_bytes(bytes) = ActiveSupport::NumberHelper.number_to_human_size(bytes)
  end
end
