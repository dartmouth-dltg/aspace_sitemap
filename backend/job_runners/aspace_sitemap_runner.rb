require 'zip'
require 'date'
require 'nokogiri'
require 'fileutils'
require 'aspace_logger'

class AspaceSitemapRunner < JobRunner
  
  register_for_job_type('aspace_sitemap_job')
  
  def run
    
    logger=Logger.new($stderr)
    
    # make sure the sitemap_types actually are allowed
    allowed_sitemap_types = ['resource','accession','archival_object','digital_object','agent_person','agent_family','agent_corporate_entity']
    @sitemap_types = @json.job['sitemap_types'].reject{|st| !allowed_sitemap_types.include?(st)}
    
    # this should never happen
    if @sitemap_types.count == 0
      @job.write_output('No types selected for sitemap. No sitemap generated.')
      return
    end
    
    @use_slugs = @json.job['sitemap_use_slugs']
    default_limit = AppConfig.has_key?(:aspace_sitemap_default_limit) ? AppConfig[:aspace_sitemap_default_limit] : 50000
    sitemap_limit = @json.job['sitemap_limit'].to_i
    sitemap_index_base_url = @json.job['sitemap_baseurl']
    refresh_freq = @json.job['sitemap_refresh_freq']
    timestamp = Time.now.strftime("%Y-%m-%d") # add '-%H-%M-%S-%L' if need additional granualrity
    
    # make sure the sitemap limit is less than the google limit
    unless sitemap_limit <= default_limit
      sitemap_limit = google_limit
    end
    
    # make sure the sitemap url ends in a "/"
    unless sitemap_index_base_url[-1] == "/"
      sitemap_index_base_url + "/"
    end
    
    @job.write_output('Generating sitemap')
    array = []
    files = []
    
    begin
      DB.open do |db|
        db.fetch(query_string) do |result|
          row = result.to_hash
          fix_row(row)
          array.push(row)
        end
      end
      
      if array.count == 0
        @job.write_output('No published objects found. No sitemap generated.')
        return
      end
      
      # split the results set into chunks of less than the sitemap entry limit
      sitemap_parts = array.each_slice(sitemap_limit).to_a

      # initialize a zip file
      zip_file = ASUtils.tempfile("aspace_sitemap_zip_#{timestamp}")
      # open with the OutputStream class to initialize the zip struture correctly
      Zip::OutputStream.open(zip_file) { |zos| }

      # iterate through the sitemap pieces and build our xml files
      sitemap_parts.each_with_index do |sitemap,k|
        files[k] = Tempfile.new(["aspace_sitemap_#{timestamp}_part_#{k}", ".xml"])
      
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
            sitemap.each do |entry|
              xml.url {
                xml.loc entry[:loc]
                xml.lastmod entry[:lastmod]
                xml.changefreq refresh_freq
              }
            end
          }
        end
        files[k].write(builder.to_xml)
        files[k].rewind
      end
      
      # create a sitemap index file if necessary
      if sitemap_parts.count > 1
        index_file = Tempfile.new(["aspace_sitemap_index_#{timestamp}",".xml"])

        index_builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
            xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
              files.each_with_index do |file,k|
                xml.sitemap {
                  xml.loc "#{sitemap_index_base_url}aspace_sitemap_#{timestamp}_part_#{k}.xml"
                  xml.lastmod timestamp
                }
              end
            }
          end
        index_file.write(index_builder.to_xml)
        index_file.rewind
      end
      
      # wrap them all into a zip file
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        files.each_with_index do |file,k|
          zip.add("aspace_sitemap_#{timestamp}_part_#{k}.xml", file.path)
        end
        zip.add("aspace_sitemap_index_#{timestamp}.xml", index_file.path) if sitemap_parts.count > 1
      end
      
      @job.write_output('Adding Sitemap')
      @job.add_file(zip_file)
      self.success!
    rescue Exception => e
      @job.write_output(e.message)
      @job.write_output(e.backtrace)
      raise e
    ensure
      static_page_loc = "#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}/public/pages/"
      files.each do |file|
        FileUtils.cp(file, static_page_loc)
        file.close
        file.unlink
      end
      if sitemap_parts.count > 1
        FileUtils.cp(index_file, static_page_loc)
        index_file.close 
        index_file.unlink
      end
      zip_file.close
      zip_file.unlink
      @job.write_output('Done.')
    end
  end
  
  def fix_row(row)

    # use slugs if set, otherwise use the standard url form based on ids
    if @use_slugs && !row[:slug].nil?
      object_url_part = row[:slug]
    else
      object_url_part = row[:id]
    end
    
    # agents have a different location string pattern
    if ['people','families','corporate_entities'].include?(row[:source])
      row[:loc] = ["#{AppConfig[:public_proxy_url]}","agents",row[:source],object_url_part].join("/")
    else
      row[:loc] = ["#{AppConfig[:public_proxy_url]}","repositories",row[:repo_id],row[:source],object_url_part].join("/")
    end

    row[:lastmod] = row[:lastmod].strftime("%Y-%m-%d")
    
    # remove columns we don't need
    row.delete(:id)
    row.delete(:repo_id)
    row.delete(:publish)
    row.delete(:source)
    row.delete(:slug)
  end
  
  def query_string
    
    sitemap_types_map = {'resource' => 'resources',
                         'accession' => 'accessions',
                         'archival_object' => 'archival_objects',
                         'digital_object' => 'digital_objects',
                         'agent_person' => 'people', 
                         'agent_family' => 'families',
                         'agent_corporate_entity' => 'corporate_entities'
                         }
    
    queries = []
    
    @sitemap_types.each do |type|
      
      # agents don't have a repo_id so we have to supply one to make the columns match up
      if type.include?('agent')
        repo_line = "'0' AS repo_id"
      else repo_line = "repo_id"
      end
      
      queries <<
      "(SELECT
          publish,
          #{repo_line},
          id,
          slug,
          user_mtime AS lastmod,
          '#{sitemap_types_map[type]}' AS source
        FROM
          #{type}
        WHERE
          publish = 1)"
    end
    
   return queries.compact.join("UNION")
    
    # query_string will become something like the below
    #"(SELECT
    #  publish,
    #  repo_id,
    #  id,
    #  slug,
    #  user_mtime AS lastmod,
    #  'archival_objects' AS source
    #FROM
    #  archival_object
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  repo_id,
    #  id,
    #  slug,
    #  user_mtime AS lastmod,
    #  'resources' AS source
    #FROM
    #  resource
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  repo_id,
    #  id,
    #  slug,
    #  user_mtime AS lastmod,
    #  'digital_objects' AS source
    #FROM
    #  digital_object
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  '0' AS repo_id,
    #  id,
    #  slug,
    #  user_mtime AS lastmod,
    #  'people' AS source
    #FROM
    #  agent_person
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  '0' AS repo_id,
    #  id,
    #  slug,
    #  user_mtime AS lastmod,
    #  'families' AS source
    #FROM
    #  agent_family
    #WHERE
    #  publish = 1)
    #UNION
    #(SELECT
    #  publish,
    #  '0' AS repo_id,
    #  id,
    #  slug,
    #  user_mtime AS lastmod,
    #  'corporate_entities' AS source
    #FROM
    #  agent_corporate_entity
    #WHERE
    #  publish = 1)"
  end
  
end