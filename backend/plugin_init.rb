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
AppConfig[:sitemap_ark_types] = ['resource','archival_object']
AppConfig[:sitemap_frequencies] = ['yearly', 'monthly', 'daily', 'hourly', 'always', 'never']
AppConfig[:aspace_sitemap_default_limit] = 50000

# create the pui sitemaps directory if it does not already exist
ArchivesSpaceService.loaded_hook do
  dirname = File.join(AppConfig[:data_directory], "pui_sitemaps")
  unless File.directory?(dirname)
    FileUtils.mkdir_p(dirname)
  end  
end