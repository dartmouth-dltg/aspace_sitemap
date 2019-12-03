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
AppConfig[:sitemap_frequencies] = ['yearly', 'monthly', 'daily', 'hourly', 'always', 'never']
AppConfig[:aspace_sitemap_default_limit] = 50000
