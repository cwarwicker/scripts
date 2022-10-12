# Read the contents of a gitmodules file and generate a list of submodule add commands to add them all back.

# If no arguments assume the .gitmodules is in the current working directory.
if ARGV[0].nil?
  file = '.gitmodules'
elsif ['help', '--help'].include?(ARGV[0].downcase)
  puts "Usage: ruby build-modules.rb </path/to/.gitmodules>"
  puts "If no path is specified, it will try to use .gitmodules from current directory"
else
  file = ARGV[0]
end

# Define regex patterns.
pattern = /\[submodule .*?\]([^\[]+)/
path_pattern = /path = (.*+)/
url_pattern = /url = (.*+)/

# Open the .gitmodules file.
fh = File.open(file)

# Get the contents, stripping any whitespace.
data = fh.readlines.map{ |line| line.strip}.join("\n")

data.scan(pattern).each do |match|

  path = path_pattern.match(match[0])[1]
  url = url_pattern.match(match[0])[1]

  # Display the git command to add the submodule back to the project.
  puts "git submodule add #{url} #{path}"

end

# Close the file.
fh.close