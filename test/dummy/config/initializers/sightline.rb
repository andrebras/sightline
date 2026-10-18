Sightline.configure do |c|
  c.base_controller = "AdminController"
  c.title = "Dummy"
  c.overview_intro = "How the dummy app is doing."
  c.page "Reports", path: "reports", template: "admin_pages/reports"
end
