module Sightline
  class Engine < ::Rails::Engine
    isolate_namespace Sightline

    # When this process started serving, for the System card.
    config.after_initialize { Sightline.booted_at ||= Time.current }
  end
end
