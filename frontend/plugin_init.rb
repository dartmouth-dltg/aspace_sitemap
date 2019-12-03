require_relative 'helpers/aspace_form_helper'

# this is ugly since we set these in both the frontend and backend
# better to have end user set in config or not?
Rails.application.config.after_initialize do
  AppConfig[:allowed_sitemap_types] = ['resource','accession','archival_object','digital_object','digital_object_component','agent_person','agent_family','agent_corporate_entity','agent_software']
  AppConfig[:sitemap_frequencies] = ['yearly', 'monthly', 'daily', 'hourly', 'always', 'never']
  AppConfig[:aspace_sitemap_default_limit] = 50000
end