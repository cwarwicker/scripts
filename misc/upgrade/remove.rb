require "git"
require_relative "upgrader.rb"

if site = SiteType.init

    p "git filter-branch -f --tree-filter 'git rm -rf --cached --ignore-unmatch .gitmodules #{site.config['submodules'].keys.join(' ')}' --prune-empty #{site.config['branch_point']}..HEAD"

end