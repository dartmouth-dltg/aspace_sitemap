require 'fileutils'

# this is ugly since we set these in both the frontend and backend
# better to have end user set in config or not?
AppConfig[:allowed_sitemap_types_hash] = {'resource' => 'resources',
                                          'accession' => 'accessions',
                                          'archival_object' => 'archival_objects',
                                          'digital_object' => 'digital_objects',
                                          'digital_object_component' => 'digital_object_components',
                                          'agent_person' => 'people', 
                                          'agent_family' => 'families',
                                          'agent_corporate_entity' => 'corporate_entities',
                                          'agent_software' => 'software'
                                          }
AppConfig[:sitemap_has_ancestor_types] = ['archival_objects','digital_object_components']
AppConfig[:sitemap_agent_types] = ['people','families','corporate_entities','software']
AppConfig[:sitemap_frequencies] = ['yearly', 'monthly', 'daily', 'hourly', 'always', 'never']

# 10-20k is a best guess limit for performance
unless AppConfig.has_key?(:aspace_sitemap_default_limit)
  AppConfig[:aspace_sitemap_default_limit] = 20000
end

# absolute limit is 50k
if AppConfig[:aspace_sitemap_default_limit] > 50000
  AppConfig[:aspace_sitemap_default_limit] = 50000
end

unless AppConfig.has_key?(:aspace_sitemap_use_slugs)
  AppConfig[:aspace_sitemap_use_slugs] = false
end

unless AppConfig.has_key?(:aspace_sitemap_use_filesystem)
  AppConfig[:aspace_sitemap_use_filesystem] = true
end

unless AppConfig.has_key?(:aspace_sitemap_default_frequency)
  AppConfig[:aspace_sitemap_default_frequency] = 'yearly'
end

# This isn't really used *except* to allow the job to be scoped
# The sitemap scans *all* repos that are public
unless AppConfig.has_key?(:aspace_sitemap_default_repo_id)
  AppConfig[:aspace_sitemap_default_repo_id] = 2
end

unless AppConfig.has_key?(:aspace_sitemap_default_base_url)
  AppConfig[:aspace_sitemap_default_base_url] = nil
end

unless AppConfig.has_key?(:aspace_sitemap_cron)
  AppConfig[:aspace_sitemap_cron] = "0 1 * * 7" # every Saturday at 1 am
end

ArchivesSpaceService.settings.scheduler.cron(AppConfig[:aspace_sitemap_cron], :allow_overlapping => false) do  

  sitemap_job = {
    "format" => "zip",
    "job_type" => "aspace_sitemap_job",
    "jsonmodel_type" => "aspace_sitemap_job",
    "sitemap_types" =>  sitemap_types,
    "sitemap_refresh_freq" => AppConfig[:aspace_sitemap_default_frequency],
    "sitemap_use_filesys" => AppConfig[:aspace_sitemap_use_filesystem],
    "sitemap_limit" => AppConfig[:aspace_sitemap_default_limit].to_s,
    "sitemap_use_slugs" => AppConfig[:aspace_sitemap_use_slugs],
    "repo_id" => AppConfig[:aspace_sitemap_default_repo_id],
    "sitemap_baseurl" => AppConfig[:aspace_sitemap_default_base_url]
  }

  sitemap_cron_job = JSONModel(:job).from_hash(:job_type => 'aspace_sitemap_jon',
                                     :job => sitemap_job,
                                     :job_params =>  ASUtils.to_json(nil) )
  
  staff_user = User.find(:username => AppConfig[:staff_username])

  Job.create_from_json(sitemap_cron_job,
                      { :user => staff_user, 
                        :repo_id => AppConfig[:aspace_sitemap_default_repo_id]} )

end

# create the pui sitemaps directory if it does not already exist
ArchivesSpaceService.loaded_hook do
  dirname = File.join(AppConfig[:data_directory], "pui_sitemaps")
  unless File.directory?(dirname)
    FileUtils.mkdir_p(dirname)
  end  
end