require_relative "lib/sightline/version"

Gem::Specification.new do |spec|
  spec.name = "sightline"
  spec.version = Sightline::VERSION
  spec.authors = [ "André Brás" ]
  spec.summary = "An admin area for a Rails app: an overview, health checks and a link to its jobs."
  spec.description = "A Rails engine with three sections, Overview, Health and Jobs, declared from one initializer " \
                     "and rendered inside the app's own layout, behind the app's own admin controller."
  spec.required_ruby_version = ">= 3.4"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{app,config,lib}/**/*", "README.md"]

  spec.add_dependency "actionpack", ">= 8.0"
  spec.add_dependency "activerecord", ">= 8.0"
  spec.add_dependency "railties", ">= 8.0"
end
