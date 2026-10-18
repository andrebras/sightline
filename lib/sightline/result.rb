module Sightline
  # What a health check found: ok, warning or problem, a short summary, and optionally a detail
  # (a string or a list of lines) and a link ([label, url]).
  class Result < Data.define(:status, :summary, :detail, :link)
    STATUSES = %i[ok warning problem].freeze

    def initialize(status:, summary:, detail: nil, link: nil)
      raise ArgumentError, "status must be one of #{STATUSES.join(", ")}" unless STATUSES.include?(status)

      super
    end

    def ok? = status == :ok
    def lines = Array(detail).compact_blank
    def with_link(label, url) = url ? with(link: [ label, url ]) : self
  end

  class << self
    def ok(summary, detail: nil) = Result.new(status: :ok, summary: summary, detail: detail)
    def warning(summary, detail: nil) = Result.new(status: :warning, summary: summary, detail: detail)
    def problem(summary, detail: nil) = Result.new(status: :problem, summary: summary, detail: detail)
  end

  # A named check: its block returns a Result (Sightline.ok, .warning or .problem). A check that raises,
  # or returns anything else, shows as a problem rather than breaking the page.
  Check = Data.define(:name, :block) do
    def run
      result = block.call
      return result if result.is_a?(Result)

      Sightline.problem("The check returned #{result.class.name}, not Sightline.ok, .warning or .problem")
    rescue StandardError => error
      Sightline.problem("The check failed", detail: "#{error.class.name}: #{error.message.truncate(200)}")
    end
  end
end
