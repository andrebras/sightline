require "test_helper"

# Who gets in, the app's layout around the pages, and the navigation.
class FrameTest < Sightline::IntegrationTest
  test "the app's admin check decides who sees the pages" do
    get "/admin"
    assert_response :not_found
    get "/admin/health"
    assert_response :not_found
    get "/admin", headers: ADMIN
    assert_response :success
  end

  test "the app's controller code can use its own route helpers" do
    get "/admin/health", headers: { "X-Admin" => "none" }
    assert_redirected_to "/things"
  end

  test "pages render inside the app's layout, whose own links still go to the app" do
    get "/admin/health", headers: ADMIN
    assert_select "title", "Health · Dummy"
    assert_select ".app-nav a[href='/']", "Home"
    assert_select ".app-nav a[href='/things']", "Things"
    assert_select ".sl h1", "Health"
    assert_select ".sl-eyebrow", "Dummy"
  end

  test "the navigation has Overview, Health, Jobs and the app's own pages" do
    get "/admin", headers: ADMIN
    assert_select ".sl-nav a", 4
    assert_select ".sl-nav a.sl-current[href='/admin/']", "Overview"
    assert_select ".sl-nav a[href='/admin/health']", "Health"
    assert_select ".sl-nav a[href='/admin/jobs']", "Jobs"
    assert_select ".sl-nav a[href='/admin/reports']", "Reports"
    assert_select ".sl-intro", "How the dummy app is doing."
  end

  test "an app whose layout links the sections turns the navigation off" do
    with_config(navigation: false) do
      get "/admin", headers: ADMIN
      assert_select ".sl-nav", 0
      assert_select ".sl h1", "Overview"
    end
  end

  test "the jobs link can point elsewhere" do
    with_config(jobs_path: "/ops/jobs") do
      get "/admin", headers: ADMIN
      assert_select ".sl-nav a[href='/ops/jobs']", "Jobs"
    end
  end

  test "the app's own pages render inside the frame; other paths fall through to the app" do
    get "/admin/reports", headers: ADMIN
    assert_select ".sl h1", "Reports"
    assert_select ".sl-nav a.sl-current", "Reports"
    assert_select ".sl p.reports"
    get "/admin/elsewhere"
    assert_equal "home", response.body
  end
end
