require 'sinatra'
require 'open3'
require 'json'

set :logging, true

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

post '/merge_liquid_templates' do
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
  liquid_templates_branch = "release-#{branch}"
  `mkdir tmp`

  logger.info "git clone git@github.com:moxiespaces/social_navigator.git tmp/social_navigator"
  `git clone git@github.com:moxiespaces/social_navigator.git tmp/social_navigator`

  logger.info "cd tmp/social_navigator"
  Dir.chdir "tmp/social_navigator"

  logger.info "git checkout #{branch}"
  `git checkout #{branch}`

  logger.info "git pull"
  `git pull`

  logger.info "rm -rf tmp/spaces-liquid-templates"
  `rm -rf tmp/spaces-liquid-templates`

  logger.info "git clone git@github.com:moxiespaces/spaces-liquid-templates.git tmp/spaces-liquid-templates"
  `git clone git@github.com:moxiespaces/spaces-liquid-templates.git tmp/spaces-liquid-templates`

  logger.info "cd tmp/spaces-liquid-templates"
  Dir.chdir "tmp/spaces-liquid-templates"

  logger.info "git checkout #{liquid_templates_branch}"
  result = exe_cmd("git checkout #{liquid_templates_branch}")
  switch_to_branch = result[:stderr] =~ /Switched to a new branch '[^']+'/
  if !result[:stderr].empty? && switch_to_branch.nil?

    logger.info "checking if branch #{liquid_templates_branch} exists for spaces-liquid-templates: #{result[:stderr]}"

    # branch does not exist yet... 
    if result[:stderr] =~ /error: pathspec '[^']+' did not match any file\(s\) known to git/
      logger.info "#{liquid_templates_branch} doesn't exist"
      # create the branch based on master

      logger.info "git checkout -b #{liquid_templates_branch} master"
      result = exe_cmd("git checkout -b #{liquid_templates_branch} master")
      if result['stderr'].nil?

        # push the branch to github
        logger.info "git push origin #{liquid_templates_branch}"
        result = exe_cmd("git push origin #{liquid_templates_branch}")

        # something bad happened
        if result['stderr']
          # delete the local branch since there was an error
          logger.info "git branch -d #{liquid_templates_branch}"
          exe_cmd("git branch -d #{liquid_templates_branch}")
          exit
        end
      end

    else
      logger.info result[:stderr]
      logger.info "unknown error"
      exit
    end
  end

  logger.info "rm -rf liquid_views/*"
  `rm -rf liquid_views/*`

  logger.info "cp -r ../../app/liquid_views/* ./liquid_views/"
  `cp -r ../../app/liquid_views/* ./liquid_views/`

  logger.info "git add ."
  `git add .`

  logger.info "git commit -a --message=\"auto merge templates\""
  `git commit -a --message="auto merge templates"`

  logger.info "git push origin #{liquid_templates_branch}"
  `git push origin #{liquid_templates_branch}`

end