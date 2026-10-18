require_relative "lib/sightline/version"

Gem::Specification.new do |spec|
  spec.name = "sightline"
  spec.version = Sightline::VERSION
  spec.authors = [ "André Brás" ]
  spec.summary = "An admin area for a Rails app: an overview, health checks and its jobs."
  spec.description = "A Rails engine with three sections, Overview, Health and Jobs, declared from one initializer " \
                     "and rendered inside the app's own layout, behind the app's own admin controller."
  spec.license = "MIT"
  spec.homepage = "https://github.com/andrebras/sightline"
  spec.required_ruby_version = ">= 3.4"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["{app,config,lib}/**/*", "README.md", "LICENSE"]

  # Rails, and Mission Control – Jobs on Solid Queue for the Jobs section.
  spec.add_dependency "actionpack", ">= 8.0"
  spec.add_dependency "activerecord", ">= 8.0"
  spec.add_dependency "mission_control-jobs", "~> 1.3"
  spec.add_dependency "railties", ">= 8.0"
  spec.add_dependency "solid_queue", ">= 1.0"
end
