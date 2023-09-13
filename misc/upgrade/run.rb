require "tty-prompt"
require "git"
require_relative "upgrader.rb"
require 'optparse'

prompt = TTY::Prompt.new

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: run.rb [options]"

  opts.on('-s', '--stage [STAGE]', 'Which stage to run', Integer) { |stage| options[:stage] = stage }

end.parse!


# Have we already got the upgrade configuration?
if site = SiteType.init

    current_stage = site.config['stage']

    # If we specified a particular stage we want to run, do that instead.
    if !options[:stage].nil?
        current_stage = options[:stage]
    end

    if current_stage > 7
        puts "The upgrade is complete. If you want to reset and run it again, delete the #{SiteType::UPGRADE_CONFIG_FILE} file and re-run this script"
        abort
    end

    # Which stage do we want to run?
    stage = prompt.select("Which stage of the upgrade do you want to run?", default: current_stage) do |menu|
        menu.enum "."
        menu.choice "CORE :: Clean-up Git History", 1
        menu.choice "CORE :: Remove Submodules", 2
        menu.choice "CORE :: Rebase New Version", 3
        menu.choice "CORE :: Finalise", 4
        menu.choice "PLUGIN :: Create Plan", 5
        menu.choice "PLUGIN :: Execute Plan", 6
        menu.choice "OVERALL :: Finalise", 7
    end

    site.run(stage)

else

    # Not yet configured, so ask the user some questions so we can write the config file.

    # What is the git repo we currently have checked out?
    repo = Git.open(Dir.pwd)

    branches = []
    repo.branches.local.each do |b|
        branches.push(b.name)
    end

    # Check which branch to use (assuming production).
    branch = prompt.select("Which branch is the current production branch for this repo?", branches)

    # What is the new project repo for the upgraded version?
    new_repo = prompt.ask("What is the new repo we will be pushing the upgraded version to?")

    # Upstream info.
    upstream_repo = prompt.ask("What is the upstream repo for the new version we are upgrading to?")
    upstream_branch = prompt.ask("What branch are we using from the upstream repo?")

    # What type of site are we trying to upgrade?
    site_type = prompt.select("What type of site are we upgrading?", ["moodle", "totara"])

    # What version are we upgrading from?
    old_version = prompt.ask("What version of #{site_type} are we currently on?")

    # What version will we be upgrading to?
    new_version = prompt.ask("What version of #{site_type} are we upgrading to?")

    # Check if everything is correct.
    if !prompt.yes?("Is this all correct?\nWorking Repo: #{repo.remote('origin').url}\nWorking Branch: #{branch}\nUpstream Repo: #{upstream_repo}\nUpstream Branch: #{upstream_branch}\nNew Repo: #{new_repo}\nSite Type: #{site_type}\nCurrent Version: #{old_version}\nNew Version: #{new_version}")
        abort()
    end

    # Load the site object.
    site = SiteType.load(site_type, branch, upstream_repo, upstream_branch, old_version, new_version, new_repo)

    # Run the pre-upgrade config.
    site.run_pre_upgrade()

end


