ArchivesSpace Sitemap Generation for the PUI
==================================

Getting started
-------------

Download and unpack the latest release of the plugin into your
ArchivesSpace plugins directory:

```
    $ curl ...
    $ cd /path/to/archivesspace/plugins
    $ unzip ...
```

Configure the plugin by updating 
```
backend/plugin_init.rb
```
modified as appropriate to
your local situation

1) Set the limit onthe number of entries within each sitemap. 
If the total umber of published objects is larger than the limit, 
multiple sitemaps together with a sitemap index file will be generated.
Google allows 50000 entries or 50MB per file. Each entry is fairly lean,
so should not exceed the 50MB limit even when set to 50000 entries per sitemap.

```
# Google currently allows up to 50000 urls or up to a 50MB file size.
AppConfig[:aspace_sitemap_limit] = 50000
```
2) Set the base url for where you will place the sitemaps and sitempa index file
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

Joshua Shaw (<Joshua.D.Shaw@Dartmouth.EDU>)  
Digital Library Technologies Group  
Dartmouth College Library  

---
