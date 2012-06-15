require 'sinatra'
require 'open3'

set :logging, true

before do
  parse_params
end

def exe_cmd(cmd)
  result = {}
  Open3.popen3(cmd) do |stdin, stdout, stderr|
    result[:stdout] = stdout.gets
    result[:stderr] = stderr.gets
  end
  result
end

get '/' do
  "Welcome to template_merger"
end

get '/merge_liquid_templates' do
  push = JSON.parse(params[:payload])
  branch = push["ref"].split("/").last

  if branch >= "2.2.5" || branch == "master"
    t = Thread.new do
      do_github_magic(branch)
    end
    "template merge requested"
  end
end



def do_github_magic(branch)
  `mkdir tmp`

  puts "git clone git@github.com:moxiespaces/social_navigator.git tmp/social_navigator"
  `git clone git@github.com:moxiespaces/social_navigator.git tmp/social_navigator`

  puts "cd tmp/social_navigator"
  Dir.chdir "tmp/social_navigator"

  puts "git checkout #{branch}"
  `git checkout #{branch}`

  puts "git pull"
  `git pull`

  puts "rm -rf tmp/spaces-liquid-templates"
  `rm -rf tmp/spaces-liquid-templates`

  puts "git clone git@github.com:moxiespaces/spaces-liquid-templates.git tmp/spaces-liquid-templates"
  `git clone git@github.com:moxiespaces/spaces-liquid-templates.git tmp/spaces-liquid-templates`

  puts "cd tmp/spaces-liquid-templates"
  Dir.chdir "tmp/spaces-liquid-templates"

  puts "git checkout #{branch}"
  result = exe_cmd("git checkout #{branch}")
  if !result[:stderr].empty? && !result[:stderr] =~ /Switched to a new branch '[^']+'/

    puts "checking if branch #{branch} exists for spaces-liquid-templates: #{result[:stderr]}"

    # branch does not exist yet... 
    if result[:stderr] =~ /error: pathspec '[^']+' did not match any file\(s\) known to git/
      puts "#{branch} doesn't exist"
      # create the branch based on master

      puts "git checkout -b #{branch} master"
      result = exe_cmd("git checkout -b #{branch} master")
      if result['stderr'].nil?

        # push the branch to github
        puts "git push origin #{branch}"
        result = exe_cmd("git push origin #{branch}")

        # something bad happened
        if result['stderr']
          # delete the local branch since there was an error
          puts "git branch -d #{branch}"
          exe_cmd("git branch -d #{branch}")
          exit
        end
      end

    else
      puts result[:stderr]
      puts "unknown error"
      exit
    end
  end

  puts "rm -rf liquid_views/*"
  `rm -rf liquid_views/*`

  puts "cp -r ../../app/liquid_views/* ./liquid_views/"
  `cp -r ../../app/liquid_views/* ./liquid_views/`

  puts "git add ."
  `git add .`

  puts "git commit -a --message=\"auto merge templates\""
  `git commit -a --message="auto merge templates"`

  puts "git push origin #{branch}"
  `git push origin #{branch}`

end