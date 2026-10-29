require "test_helper"

# The Overview, built from what the dummy app declares (test/dummy/config/initializers/sightline.rb).
class OverviewTest < Sightline::IntegrationTest
  def job(created_at:, finished_at: nil)
    SolidQueue::Job.create!(queue_name: "default", class_name: "ReportJob", arguments: {},
                            created_at: created_at, finished_at: finished_at)
  end

  test "stats, a trend chart, a bar chart and notes, from the declared blocks" do
    job(created_at: Time.current, finished_at: Time.current)
    job(created_at: 2.days.ago)
    job(created_at: 2.days.ago)
    job(created_at: 20.days.ago)
    get "/admin", headers: ADMIN
    assert_response :success

    assert_select ".sl-stat", 2
    assert_select ".sl-stat", /Jobs\s*4\s*all time/
    assert_select ".sl-stat", /Finished\s*25%\s*1 of 4/

    assert_equal [ "Last 14 days", "Jobs per day" ], css_select(".sl-section h2").map(&:text)
    assert_select ".sl-legend li", 2
    assert_select ".sl-legend li", /Queued\s*1,234/, "a declared total replaces the sum"
    assert_select ".sl-legend li", /Finished\s*1/
    assert_select ".sl-chart polyline", 2
    assert_select ".sl-chart[aria-label=?]", "Last 14 days: Queued and Finished by day"
    # A dot per day with any: queued today and two days ago, finished today.
    assert_select ".sl-chart circle", 3

    assert_select ".sl-bars li", 7
    assert_equal %w[0 0 0 0 2 0 1], css_select(".sl-bars li strong").map(&:text)
    assert_equal [ "Days are UTC.", "4 jobs kept." ], css_select(".sl-fine-print").map(&:text)
  end

  test "an empty app shows dashes and zeros, not errors" do
    get "/admin", headers: ADMIN
    assert_select ".sl-stat", /Finished\s*–\s*0 of 0/
    assert_select ".sl-chart circle", 0
    assert_equal %w[0] * 7, css_select(".sl-bars li strong").map(&:text)
  end

  test "the bar chart has no inline styles, so a strict Content Security Policy (style-src 'self') allows it" do
    job(created_at: Time.current)
    job(created_at: 2.days.ago)
    job(created_at: 2.days.ago)
    get "/admin", headers: ADMIN
    assert_select ".sl-bars[style], .sl-bars [style]", 0
    assert_not_includes css_select(".sl-bars").to_s, "style="
    # Each bar's height is its share of the tallest, as an SVG attribute: 0, 50% and 100% here.
    assert_equal %w[0% 0% 0% 0% 100% 0% 50%], css_select(".sl-bars .sl-bar").pluck("height")
  end

  test "daily values line up with the dates whether given as a list or keyed by day" do
    dates = [ Date.new(2026, 1, 1), Date.new(2026, 1, 2), Date.new(2026, 1, 3) ]
    assert_equal [ 0, 5, 2 ], Sightline::Overview.align(dates, { "2026-01-02" => 5, Date.new(2026, 1, 3) => 2 })
    assert_equal [ 1, 2, 3 ], Sightline::Overview.align(dates, [ 1, 2, 3 ])
    travel_to Time.utc(2026, 3, 10, 12) do
      assert_equal [ Date.new(2026, 3, 4), Date.new(2026, 3, 10) ], Sightline::Overview.dates(7).values_at(0, -1)
    end
  end
end
