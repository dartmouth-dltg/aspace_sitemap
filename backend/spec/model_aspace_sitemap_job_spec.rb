require 'spec_helper'

def aspace_sitemap_job
  build(
    :json_job,
    :job => build(:aspace_sitemap_job,
                  :format => "zip",
                  :sitemap_baseurl => 'https://my.local.host/',
                  :sitemap_limit => "50000",
                  :sitemap_refresh_freq => "yearly",
                  :sitemap_types => ['resource']
                  )
  )
end

describe "Generate Aspace Sitemap job" do

  let(:user) { create_nobody_user }

  it "results in a sitemap being generated for published resources" do
    json = aspace_sitemap_job
    job = Job.create_from_json(
      json,
      :repo_id => $repo_id,
      :user => user
    )

    jr = JobRunner.for(job)
    jr.run
    job.refresh

    expect(job).not_to be_nil
    expect(job.job_type).to eq("aspace_sitemap_job")
    expect(job.owner.username).to eq('nobody')
    expect(job.job_files.length).to eq(1)
  end

end
