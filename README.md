# ArchivesSpace Sitemap Generation for the PUI

## Getting started

Download and unpack the latest release of the plugin into your
ArchivesSpace plugins directory:

```
    $ curl ...
    $ cd /path/to/archivesspace/plugins
    $ unzip ...
```

Add the plugin name to the list of enabled plugins in `config/config.rb`:

```
AppConfig[:plugins] = ['some_plugin','aspace_sitemap']
```

## What does it do?
The plugin adds a new job that generates a sitemap (or sitemaps with a sitemap index)
for the PUI. There are a number of configuration options

## Configuration

Configure the plugin by editing your `config.rb` file with the 
following entries - modified as appropriate.

1) Set the limit on the number of entries within each sitemap. 
If the total umber of published objects is larger than the limit, 
multiple sitemaps together with a sitemap index file will be generated.
Google allows 50000 entries or 50MB per file. Each entry is fairly lean,
so should not exceed the 50MB limit even when set to 50000 entries per sitemap.

```
# Google currently allows up to 50000 urls or up to a 50MB file size.
AppConfig[:aspace_sitemap_limit] = 50000
```
2) Set the base url for where you will place the sitemaps and sitemap index file
```
# set the base url *with* a trailing slash
AppConfig[:aspace_sitemap_baseurl] = "https://library.dartmouth.edu/sitemaps/"
```
3) Google requires verification that you own the site. 
One way is by a verification meta tag.
```
# set the meta tag from Google to verify site ownership
AppConfig[:google_verification_meta_tag] = "your_verification_meta_tag"
```
4) Set the typical update frequency for your published objects.
```
# set typical update frequency of urls, valid values can be found in the sitemap.org docs: 
# values include: always, hourly, daily, weekly, monthly, yearly, never
AppConfig[:aspace_sitemap_changefreq] = "yearly"
```

5) List the types of objects you wish to include in the sitemap
```
# list the objects/types you wish to include in the sitemap
# Allowable types are: ['resource','archival_object','digital_object','agent_person','agent_family','agent_corporate_entity']
AppConfig[:aspace_sitemap_types] = ['resource','archival_object','digital_object','agent_person','agent_family','agent_corporate_entity']
```

## Potential Enhancements & Notes
1. Allow the end user to configure the sitemap base url and the sitemap limit
when initiating the job.
2. The 'priority' key is not used in the sitemap since there is no mechanism in place to mark
objects in the staff interface. Given the large number of objects that are typically
published, it seems unlikely that 'priority' would be widely used.

Joshua Shaw (<Joshua.D.Shaw@Dartmouth.EDU>)  
Digital Library Technologies Group  
Dartmouth College Library  
