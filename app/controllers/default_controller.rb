  class DefaultController < ApplicationController
    def index
  	render :text => 'welcome to Liquid Templates Merge'
    end

    def merge_liquid_templates
      logger.info "github payload: #{params[:payload]}"
      if params[:payload].blank?
        return render :text => 'no github payload!'
      end
      push = JSON.parse(params[:payload])
      branch = push["ref"].split("/").last


      if branch.start_with?("release-") || branch == "master"
        t = Thread.new do
          do_github_magic(branch)
        end
        render :text => "template merge requested"
      else
        render :text => 'branch must start with "release-" or branch master to be automerged'
      end
    end


    private

    def logger
      Rails.logger
    end

    def do_github_magic(branch)

      liquid_templates_branch = if branch == "master"
        "master"
      else
        "release-#{branch}"
      end
      `mkdir tmp`

      logger.info "git clone git@github.com:moxiespaces/social_navigator.git tmp/social_navigator_#{branch}"
      `git clone git@github.com:moxiespaces/social_navigator.git tmp/social_navigator_#{branch}`

      logger.info "cd tmp/social_navigator_#{branch}"
      Dir.chdir "tmp/social_navigator_#{branch}"

      logger.info "git checkout #{branch}"
      `git checkout #{branch}`

      logger.info "git pull"
      `git pull`

      logger.info "rm -rf tmp/spaces-liquid-templates_#{liquid_templates_branch}"
      `rm -rf tmp/spaces-liquid-templates_#{liquid_templates_branch}`

      logger.info "git clone git@github.com:moxiespaces/spaces-liquid-templates.git tmp/spaces-liquid-templates_#{liquid_templates_branch}"
      `git clone git@github.com:moxiespaces/spaces-liquid-templates.git tmp/spaces-liquid-templates_#{liquid_templates_branch}`

      logger.info "cd tmp/spaces-liquid-templates_#{liquid_templates_branch}"
      Dir.chdir "tmp/spaces-liquid-templates_#{liquid_templates_branch}"

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
  end
