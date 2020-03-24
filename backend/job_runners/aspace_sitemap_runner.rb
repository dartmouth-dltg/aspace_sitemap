require 'zip'
require 'date'
require 'nokogiri'
require 'fileutils'

class AspaceSitemapRunner < JobRunner
    
  register_for_job_type('aspace_sitemap_job')

  def run
    # make sure the sitemap_types actually are allowed
    @sitemap_types = @json.job['sitemap_types'].reject{|st| !AppConfig[:allowed_sitemap_types_hash].keys.include?(st)}

    # setup some of our other variables
    @use_slugs = AppConfig.has_key?(:use_human_readable_urls) && AppConfig[:use_human_readable_urls] ? @json.job['sitemap_use_slugs'] : false
    default_limit = AppConfig[:aspace_sitemap_default_limit]
    sitemap_limit = @json.job['sitemap_limit'].to_i
    sitemap_index_base_url = @json.job['sitemap_baseurl']
    
    # check to make sure either that write to fielsystem is selected or the sitemap base url is available
    if sitemap_index_base_url.nil? && @json.job['sitemap_use_filesys'] === false
      @job.write_output('Either "write to filesystem" must be selected or you must supply a sitemap base url. No sitemap generated.')
      return
    end
    
    unless sitemap_index_base_url.nil?
      # make sure the sitemap url ends in a "/"
      unless sitemap_index_base_url[-1] == "/"
        sitemap_index_base_url += "/"
      end
      # make sure the sitemap url starts with https://
      unless sitemap_index_base_url =~ /^https:\/\//
        if sitemap_index_base_url =~ /^http:\/\//
          sitemap_index_base_url.gsub!('http','https')
        else sitemap_index_base_url.prepend('https://')
        end
      end
    end
    
    refresh_freq = @json.job['sitemap_refresh_freq']
    @pui_base_url = AppConfig[:public_proxy_url]
    # make sure the public url ends in a "/"
    unless @pui_base_url[-1] == "/"
      @pui_base_url += "/"
    end
    
    # muck about with paths and filenames depending on if we are writing to the filesystem
    @index_filename = "sitemap-index"
    @sitemap_index_loc = @json.job['sitemap_use_filesys'] ? "#{@pui_base_url}" : sitemap_index_base_url
    @static_page_loc = File.join(AppConfig[:data_directory],"pui_sitemaps")
    @sitemap_filename_prefix = "aspace_sitemap_part_"

    # this should never happen
    if @sitemap_types.count == 0
      @job.write_output('No types selected for sitemap. No sitemap generated.')
      return
    end

    # make sure the sitemap limit is less than the default limit
    unless sitemap_limit <= default_limit
      sitemap_limit = default_limit
    end

    @job.write_output('Generating sitemap')
    
    # initialize some temp arrays
    pub_repos = []
    array = []
    has_ancs = []
    files = []
    hua_deletes = []

    begin
      # get the pubished repos so we can reject any objects that are marked published, but are part of an unpubbed repo
      DB.open do |db|
        db.fetch("SELECT id FROM repository WHERE publish = 1") do |repo|
          pub_repos << repo.to_hash[:id].to_i
        end
      end

      # fetch all of the objects marked as published
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
      
      # select published objects that can have ancestors so we can check them for unpubbed ancestors
      has_ancs = array.select { |row| AppConfig[:sitemap_has_ancestor_types].include?(row[:source]) }
      
      @job.write_output('Checking for unpublished ancestors')
      
      # use 25 for group size, though maybe tune this depending on memory?
      # build a list of objects with unpubbed ancestors
      has_ancs.each_slice(25).with_index do |group,i|
        if i % 400 == 0 && i != 0
          @job.write_output('Still checking for unpublished ancestors')
        end
        hua_deletes.concat(has_unpublished_ancestor(group))
      end
      
      # remove the objects with unpubbed ancestors from our list of published objects
      # also check for objects that are scoped to a repo but live in an unpubbed repo and remove those
      # do we really need to inform the end user about items not included? Useful or clutter?
      array.delete_if do |row|
        next if AppConfig[:sitemap_agent_types].include?(row[:source])
        if !pub_repos.include?(row[:repo_id].to_i)
          @job.write_output("Sitemap will not include /repositories/#{row[:repo_id]}/#{row[:source]}/#{row[:id]} since it is part of an unpublished repository")
          true
        elsif hua_deletes.include?(row[:uri])
          @job.write_output("Sitemap will not include /repositories/#{row[:repo_id]}/#{row[:source]}/#{row[:id]} since it has an unpublished ancestor")
          true
        end
      end

      # explicitly add some 'static' pages - like the homepage!
      static_pages = ["","search?reset=true"]
      static_pages.each do |sp|
        array.push({:loc => File.join("#{@pui_base_url}",sp), :lastmod => Time.now.strftime("%Y-%m-%d")})
      end

      # split the results set into chunks of less than the sitemap entry limit
      sitemap_parts = array.each_slice(sitemap_limit).to_a

      # initialize a zip file
      zip_file = ASUtils.tempfile("aspace_sitemap_zip")
      # open with the OutputStream class to initialize the zip structure correctly
      Zip::OutputStream.open(zip_file) { |zos| }

      # iterate through the sitemap pieces and build our xml files
      sitemap_parts.each_with_index do |sitemap,k|
        files[k] = Tempfile.new(["#{@sitemap_filename_prefix}#{k}", ".xml"])
        files[k].write(create_sitemap_file(sitemap, refresh_freq).to_xml)
        files[k].rewind
      end

      # create a sitemap index file
      index_file = Tempfile.new([@index_filename,".xml"])
      index_file.write(create_sitemap_index(files).to_xml)
      index_file.rewind

      # wrap them all into a zip file
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        files.each_with_index do |file,k|
          zip.add("#{@sitemap_filename_prefix}#{k}.xml", file.path)
        end
        zip.add("#{@index_filename}.xml", index_file.path)
      end

      # writing to local filesystem
      # these files will then be copied into the root directory on creation and on startup of the app
      # startup copy happens in public/plugin_init.rb
      if @json.job['sitemap_use_filesys']
        write_to_filesystem(files,index_file,get_rails_root_from_filesys)
      end

      # close it out
      @job.write_output('Adding Sitemap')
      @job.add_file(zip_file)
      self.success!
    rescue Exception => e
      @job.write_output(e.message)
      @job.write_output(e.backtrace)
      raise e
    ensure
      files.each do |file|
        file.close
        file.unlink
      end
      index_file.close
      index_file.unlink
      zip_file.close
      zip_file.unlink
      @job.write_output('Done.')
    end
  end
  
  def get_rails_root_from_filesys
    File.open(File.join("#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}","frontend","rails_path_to_pui.txt"), "r") do |f|
      return f.read.strip
    end
  end
  
  def write_to_filesystem(files,index_file,rails_root_from_pui)
    files.each_with_index do |file,k|
      FileUtils.cp(file, File.join("#{@static_page_loc}","#{@sitemap_filename_prefix}#{k}.xml"))
    end
    FileUtils.cp(index_file, File.join("#{@static_page_loc}","#{@index_filename}.xml"))
    
    # write to war space
    if rails_root_from_pui.end_with? 'WEB-INF'
      dest = Pathname.new(rails_root_from_pui)
      if dest.directory? && dest.writable?
        files.each_with_index do |file,k|
          FileUtils.cp(file, File.join("#{dest.dirname}","#{@sitemap_filename_prefix}#{k}.xml"))
        end
        FileUtils.cp(index_file, File.join("#{dest.dirname}","#{@index_filename}.xml"))
        @job.write_output("Copied sitemap files to PUI root.")
        
        # update the robots.txt file
        robtxt = Pathname.new( dest.dirname + 'robots.txt' )
        if robtxt.exist? && robtxt.file?
          @job.write_output("Checking robots.txt for sitemap entry")
          sitemaps_root_loc = File.join("#{@pui_base_url}","#{@index_filename}.xml")
          if File.foreach(robtxt).detect { |line| line =~ /sitemap/i }
            contents = File.read(robtxt)
            File.write(robtxt, contents.gsub(/sitemap.*$/i, "Sitemap: #{sitemaps_root_loc}\n"))
          else
            File.open(robtxt, 'a') { |f|
              f.write("\nSitemap: #{sitemaps_root_loc}.xml\n")
            }
          end
          @job.write_output("Updated robots.txt with entry for #{sitemaps_root_loc}")
        end
      end
    end
  end
  
  def create_sitemap_file(sitemap, refresh_freq)
    sitemap_build = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
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
    sitemap_build
  end

  def create_sitemap_index(files)
    index_build = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml.urlset('xmlns' => "https://www.sitemaps.org/schemas/sitemap/0.9") {
            files.each_with_index do |file,k|
              xml.sitemap {
                xml.loc File.join("#{@sitemap_index_loc}","#{@sitemap_filename_prefix}#{k}.xml")
                xml.lastmod Time.now.strftime("%Y-%m-%d")
              }
            end
          }
        end
    index_build
  end
  
  def has_unpublished_ancestor(rows)
    hua = []
    uris = []
    rows.each do |row|
      uris << row[:uri]
    end
    # the SOLR index has an entry for unpublished ancestors, so we search in groups
    # iterate through that set and add any uris that do have unpublished ancestors
    response = Search.records_for_uris(uris)
    response["results"].each do |res|
      if ASUtils.json_parse(res['json'])['has_unpublished_ancestor']
        hua << res["uri"]
      end
    end
    hua
  end

  def fix_row(row)
    # we add the uri since we'll need it for deleting entries that have unpublished ancestors
    if AppConfig[:sitemap_agent_types].include?(row[:source])
      row[:uri] = ["agents",row[:source],row[:id]].join("/")
    else
      row[:uri] = ["repositories",row[:repo_id],row[:source],row[:id]].join("/")
    end
    # use slugs if set, otherwise use the standard url form based on ids
    if @use_slugs && !row[:slug].nil?
      # agents have a different location string pattern
      if AppConfig[:sitemap_agent_types].include?(row[:source])
        row[:source] = "agents"
      end
      row[:loc] = ["#{@pui_base_url.chop}",row[:source],row[:slug]].join("/")
    else
      row[:loc] = ["#{@pui_base_url.chop}",row[:uri]].join("/")
    end
    # pop a "/" on the front of the uri for use later
    row[:uri].prepend("/")
    row[:lastmod] = row[:lastmod].strftime("%Y-%m-%d")

    # remove columns we don't need
    row.delete(:publish)
    row.delete(:slug) if @use_slugs
  end

  def query_string
    queries = []
    slug_query = @use_slugs ? "slug," : ""

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
          #{slug_query}
          user_mtime AS lastmod,
          '#{AppConfig[:allowed_sitemap_types_hash][type]}' AS source
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
