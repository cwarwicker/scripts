require "tty-prompt"
require "git"
require "yaml"
require "parseconfig"

class SiteType

    UPGRADE_BRANCH_CORE = "upgrade-core"
    UPGRADE_BRANCH_SUBMODULES = "upgrade-submodules"
    UPGRADE_CONFIG_FILE = ".upgrade.yml"
    UPSTREAM_REPO_NAME = "upstream"
    NEW_REPO_NAME = "upgrade"
    GITMODULES = ".gitmodules"
    GITLAB_CI_FILE = ".gitlab-ci.yml"
    BRANCH_PRODUCTION = "production"
    BRANCH_STAGING = "staging"

    attr_accessor :git, :branch, :upstream_repo, :upstream_branch, :type, :branches, :old_version, :new_version, :config, :new_repo

    def initialize(branch, upstream_repo, upstream_branch, site_type, old_version, new_version, new_repo)
        @git = Git.open(Dir.pwd)
        @branch = branch
        @upstream_repo = upstream_repo
        @upstream_branch = upstream_branch
        @type = site_type
        @old_version = old_version
        @new_version = new_version
        @new_repo = new_repo

        # Build array of all local branches.
        branches = []
        self.git.branches.local.each do |b|
            branches.push(b.name)
        end

        @branches = branches

        # If the upgrade file doesn't exist yet, create it.
        if not File.exists?(SiteType::UPGRADE_CONFIG_FILE)
            File.write(SiteType::UPGRADE_CONFIG_FILE, '')
        end

        @config = YAML.load_file(SiteType::UPGRADE_CONFIG_FILE)

    end

    def process(command)
        io = IO.popen(command)
        output = io.read
        io.close
        return output.strip
    end

    def self.load(type, branch, upstream_repo, upstream_branch, old_version, new_version, new_repo)
        if type == 'moodle'
            return MoodleSite.new(branch, upstream_repo, upstream_branch, type, old_version, new_version, new_repo)
        elsif type == 'totara'
            return TotaraSite.new(branch, upstream_repo, upstream_branch, type, old_version, new_version, new_repo)
        else
            abort("Invalid site type")
        end
    end

    def run(stage)

        # Run the core upgrade stages.
        if stage >= 1 and stage <= 4
            self.run_core_upgrade(stage)
        elsif stage >= 5 and stage <= 6
            self.run_plugin_upgrade(stage)
        elsif stage === 7
            self.run_post_upgrade()
        end

    end

    def run_plugin_upgrade(stage)

        prompt = TTY::Prompt.new

        # Generate the plugin upgrade plan.
        if stage === 5

            puts "--- Creating plugin upgrade plan"
            plan = {}

                self.config['submodules'].each do |submod|

                    psubmod = {}
                    submod = submod[1]

                    # Have to create a new object with the same values, as otherwise the yaml file uses references and changes old values.
                    submod.keys.each do |k|
                        psubmod[k] = submod[k]
                    end

                    path = psubmod['path']
                    url = psubmod['url']

                    # Firstly, is it an automodule? If so, we don't want to change anything.
                    if psubmod.has_key? "autoupdate"
                        # Automodules do not need to be included in the plan as they are added by gitlab jobs.
                        puts "#{path} ... is an automodule ... removed from plan"
                    elsif url.include? "git.catalyst-eu.net:clients/"
                        # Or if it's in the /clients/ section, we don't want to change anything, but they still need including in the plan.
                        plan[path] = psubmod
                        puts "#{psubmod['path']} ... is a custom client plugin ... keeping same revision"
                    else

                        # Otherwise, if it's in upstream or somewhere else, we don't know what branch or tag to use unfortunately,
                        # as that depends on the plugin creator and how they name things. So we need to ask.
                        puts "#{path} ... requires action"

                        if psubmod.has_key? "branch" and !psubmod['branch'].nil?
                            default = psubmod['branch']
                        elsif psubmod.has_key? "rev" and !psubmod['rev'].nil?
                            default = psubmod['rev']
                        else
                            default = ""
                        end

                        rev = prompt.ask("What revision should be used for (#{psubmod['path']})? (Branch/Tag/Hash)", default: default)
                        puts "#{psubmod['path']} ... revision changed to: (#{rev})"
                        psubmod['rev'] = rev
                        psubmod.delete('branch')
                        plan[path] = psubmod

                    end

                end


            self.config['plan'] = plan
            File.write(SiteType::UPGRADE_CONFIG_FILE, self.config.to_yaml)

            puts "--- Plan completed"
            puts "If you wish to add any new plugins to the codebase, add them to the `plan` section of #{SiteType::UPGRADE_CONFIG_FILE} before running the next stage, in the format:"
            puts <<-FORMAT
                path/to/plugin:
                    path: <path>
                    url: <url>
                    rev: <revision>
            FORMAT

        elsif stage === 6

            puts "--- Executing plugin upgrade plan"

            # Make sure we are on the core upgrade branch still.
            puts "--- Checking out (#{SiteType::UPGRADE_BRANCH_CORE}) branch"
            self.git.branch(SiteType::UPGRADE_BRANCH_CORE).checkout

            # Create a new branch to contain the plugin upgrades.
            puts "--- Creating plugin upgrade branch"
            if self.branches.include? SiteType::UPGRADE_BRANCH_SUBMODULES
                self.git.branch(SiteType::UPGRADE_BRANCH_SUBMODULES).delete
            end
            self.git.branch(SiteType::UPGRADE_BRANCH_SUBMODULES).checkout

            # Loop through the plan and add all the submodules.
            self.config['plan'].each do |submod|

                submod = submod[1]

                puts "--- Adding submodule #{submod['path']}"
                self.process("git submodule add #{submod['url']} #{submod['path']}")

                # Checkout the correct revision.
                puts "--- Checking out revision (#{submod['rev']})"
                srepo = Git.open(submod['path'])
                srepo.checkout(submod['rev'])

                # Adding changed revision to index.
                self.git.add(submod['path'])

            end

            puts "--- Commiting changes"

            # Make sure .gitmodules is added to index.
            self.git.add(SiteType::GITMODULES)

            # Commit the changes.
            self.git.commit("Submodules: Added all required submodules to codebase")

        end

        self.set_stage(stage + 1)

    end

    def run_core_upgrade(stage)

        if stage === 1

            # First checkout the main branch of this repo which we are starting from.
            puts "--- Checking out (#{self.branch}) branch"
            self.git.branch(self.branch).checkout

            # Create new branches to use for the upgrade. Delete if already exists.
            puts "--- Creating core upgrade branch (#{SiteType::UPGRADE_BRANCH_CORE}) and checking out"
            if self.branches.include? SiteType::UPGRADE_BRANCH_CORE
                self.git.branch(SiteType::UPGRADE_BRANCH_CORE).delete
            end
            self.git.branch(SiteType::UPGRADE_BRANCH_CORE).checkout

            # Remove all submodules and untracked files (except upgrade config file).
            puts "--- Removing all submodules and cleaning repo"
            self.process("git submodule deinit -f .")
            self.process("git clean -dxff -e '#{SiteType::UPGRADE_CONFIG_FILE}'")
            self.process("rm .git/modules -rf")

            # Work out the point at which this repo branched off from the upstream.
            branch_point = self.get_branch_point()
            puts "--- Working out branch point (#{branch_point})"

            upstream_hash = self.get_latest_upstream_hash()
            puts "--- Working out latest upstream commit for upgrade (#{upstream_hash})"

            # Write new config details.
            self.config["branch_point"] = branch_point
            self.config['upstream_hash'] = upstream_hash

            puts "--- Updating upgrade config file (#{SiteType::UPGRADE_CONFIG_FILE})"
            File.write(SiteType::UPGRADE_CONFIG_FILE, self.config.to_yaml)

            # Clean up the history to remove all changes to submodules.
            puts "--- Cleaning up git history"
            self.process("git filter-branch -f --tree-filter 'git rm -rf --cached --ignore-unmatch .gitmodules #{self.config['submodules'].keys.join(' ')}' --prune-empty #{self.config['branch_point']}..HEAD")
            self.process("git filter-branch -f --tree-filter 'rm .gitmodules -f' --prune-empty #{branch_point}..HEAD")

        end

        if stage === 2
            puts "--- Running rebase clean-up rebase (in 5 seconds...)"
            puts "At this point please remove any remaining submodule commits, and any upstream commits, leaving only custom commits"
            sleep(5)
            # This runs with system() because it needs to open a file for a response.
            system("git rebase -i #{self.config['branch_point']} -X ignore-all-space")
        end

        if stage === 3

            puts "--- Running upgrade rebase (in 5 seconds...)"
            puts "Now we are rebasing the new version onto our old base. Please remove any upstream commits still listed, leaving only custom commits (in 5 seconds...)"
            sleep(5)

            # This runs with system() because it needs to open a file for a response.
            system("git rebase -i #{self.config['upstream_hash']}")

        end

        if stage === 4

            puts "--- Writing #{SiteType::GITLAB_CI_FILE} file"
            self.write_gitlab_ci()

            puts "--- Committing changes to #{SiteType::GITLAB_CI_FILE} file"
            self.git.add(SiteType::GITLAB_CI_FILE)
            self.git.commit("Updated #{SiteType::GITLAB_CI_FILE}")

        end

        self.set_stage(stage + 1)

    end

    def write_gitlab_ci()

        data = {
            "include" =>  [{
                "project" => "clients/project-tools/project-scripts",
                "ref" => "master",
                "file" => "/project-scripts.yml"
            }],
            "variables" => {
                "SOURCE_REPO" => "https://gitlab-ci-token:${CI_JOB_TOKEN}@git.catalyst-eu.net/#{self.type}/#{self.type}-#{self.new_version}-catalyst-eu.git",
                "SOURCE_BRANCH" => "main",
                "FRAMEWORK_VERSION" => "#{self.new_version}",
                "SITE_TYPE" => "#{self.get_site_type_git_gitlab_ci()}"
            }
        }

        File.write(SiteType::GITLAB_CI_FILE, data.to_yaml)


    end

    def run_pre_upgrade()

        # Check out the production branch.
        puts "--- Checking out branch (#{self.branch})"
        self.git.checkout(self.branch)

        # Delete the upgrade branches if they exist.
        puts "--- Deleting upgrade branches"

        if self.branches.include? SiteType::UPGRADE_BRANCH_CORE
            self.git.branch(SiteType::UPGRADE_BRANCH_CORE).delete
        end

        if self.branches.include? SiteType::UPGRADE_BRANCH_SUBMODULES
            self.git.branch(SiteType::UPGRADE_BRANCH_SUBMODULES).delete
        end

        # Make sure we have pulled down the latest changes to production branch of the current version.
        puts "--- Pulling latest changes to (#{self.branch})"
        self.git.pull('origin', self.branch)

        # Reset to origin.
        puts "--- Performing hard reset (origin/#{self.branch})"
        self.git.reset_hard("origin/#{self.branch}")

        # Checkout all submodules.
        puts "--- Checking out all submodules"
        self.process('git submodule update --init --recursive')

        # Add the upstream repo
        puts "--- Adding the upstream remote (#{SiteType::UPSTREAM_REPO_NAME}) (#{self.upstream_repo})"
        if not self.git.remote(SiteType::UPSTREAM_REPO_NAME).url.nil?
            self.git.remove_remote(SiteType::UPSTREAM_REPO_NAME)
        end
        self.git.add_remote(SiteType::UPSTREAM_REPO_NAME, self.upstream_repo)
        self.git.fetch(SiteType::UPSTREAM_REPO_NAME)

        puts "--- Adding the new repo remote (#{SiteType::NEW_REPO_NAME}) (#{self.new_repo})"
        if not self.git.remote(SiteType::NEW_REPO_NAME).url.nil?
            self.git.remove_remote(SiteType::NEW_REPO_NAME)
        end
        self.git.add_remote(SiteType::NEW_REPO_NAME, self.new_repo)
        self.git.fetch(SiteType::NEW_REPO_NAME)

        # Finding all submodules and adding them to config.
        submodules = {}
        modules = ParseConfig.new(SiteType::GITMODULES)
        modules.get_groups.each do |submod|

            submodules[modules[submod]['path']] = modules[submod]

            # Find the actual revision hash which is checked out.
            srepo = Git.open(modules[submod]['path'])
            submodules[modules[submod]['path']]['rev'] = srepo.object('HEAD').sha

        end

        config = {
            "branch" => self.branch,
            "upstream_repo" => self.upstream_repo,
            "upstream_branch" => self.upstream_branch,
            "type" => self.type,
            "old_version" => self.old_version,
            "new_version" => self.new_version,
            "new_repo" => self.new_repo,
            "submodules" => submodules,
            "stage" => 1
        }

        # Create an .upgrade file to store details in and write it.
        puts "--- Writing upgrade config file (#{SiteType::UPGRADE_CONFIG_FILE})"
        File.write(SiteType::UPGRADE_CONFIG_FILE, config.to_yaml)



    end

    def run_post_upgrade()

        # Make sure we are in the submodule upgrade branch.
        puts "--- Checking out (#{SiteType::UPGRADE_BRANCH_SUBMODULES}) branch"
        self.git.branch(SiteType::UPGRADE_BRANCH_SUBMODULES).checkout

        branches = [SiteType::BRANCH_STAGING, SiteType::BRANCH_PRODUCTION]
        branches.each do |branch|
            puts "--- Pushing branch (#{branch}) to new repo (#{self.new_repo})"
            self.process("git push -u #{self.new_repo} #{SiteType::UPGRADE_BRANCH_SUBMODULES}:#{branch}")
        end

        self.set_stage(99)

        puts "=================================================="
        puts "UPGRADE COMPLETE"

    end

    def set_stage(stage)

        self.config['stage'] = stage
        File.write(SiteType::UPGRADE_CONFIG_FILE, self.config.to_yaml)


    end

    def self.init()

        # Is the upgrade config file there? If so, we can load the object based on that.
        if not File.exists?(SiteType::UPGRADE_CONFIG_FILE)
            return false
        end

        config = YAML.load_file(SiteType::UPGRADE_CONFIG_FILE)
        if config == false or config['branch'].nil? or config['upstream_repo'].nil? or config['upstream_branch'].nil? or config['type'].nil? or config['old_version'].nil? or config['new_version'].nil? or config['new_repo'].nil?
            return false
        else
            return SiteType.load(config['type'], config['branch'], config['upstream_repo'], config['upstream_branch'], config['old_version'], config['new_version'], config['new_repo'])
        end

    end

    def get_latest_upstream_hash()
        return self.process("git rev-parse #{SiteType::UPSTREAM_REPO_NAME}/#{self.config['upstream_branch']}")
    end


end

class MoodleSite < SiteType

    def get_branch_point()
        return self.process("git log --oneline --grep 'Moodle release #{self.old_version}' | grep -v Merge -m1 | awk '{print $1}'")
    end

    def get_site_type_git_gitlab_ci()
        return "standard-moodle"
    end

end

class TotaraSite < SiteType

    def get_branch_point()
        return self.process("git log --oneline --grep 'Tagging version #{self.old_version}' | grep -v Merge -m1 | awk '{print $1}'")
    end

    def get_site_type_git_gitlab_ci()
        version = self.new_version.to_i
        if version > 12
            return "standard-txp"
        else
            return "standard-totara"
        end
    end

end