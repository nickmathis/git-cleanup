#! /usr/bin/env ruby

def current_branch
   b = `git branch`.split("\n").find { |i| i.match(/^\*/) }
   b.gsub("* ","")
end

class GitCleanup
  def initialize(mode = nil)
    @force  = false
    @dry = false

    case mode
      when 'force'
        @force = true
      when 'dry'
        @dry = true
    end
  end

  def clean_all!
    if !on_master?
      puts "Must run against master"
      return
    end

    fetch
    if @dry
      merged_branches(true)
    else
      prune_branches!
      merged_branches
      clean_local!
      clean_remote!
    end
  end

  def fetch
    `git fetch`
  end

  def merged_branches(output = false)
    puts "\n********************************************\nBranches already merged into #{current_branch}\n********************************************"
    @local_branches = []
    @remote_branches = []
    `git branch -a --merged`.split("\n").each do |branch|
      next if branch.nil?
      branch = branch.gsub("*", '').strip
      if !!branch.match('remotes')
        branch.gsub!('remotes/', '')
        git_remote, branch_name = branch.split('/')

        next if never_remove_remote.include?(branch_name)
        next if branch_name.match /HEAD/
        @remote_branches << branch
      else
        next if never_remove_local.include?(branch)
        @local_branches << branch
        puts "-   #{branch}" if output
      end
    end
  end

  def on_master?
    current_branch == 'master'
  end

  def clean_remote!
    if !on_master?
      puts "Must run against master"
      return
    end

    puts "#{@remote_branches.size} remote branches ready for cleanup"
    clean_branches!(@remote_branches, true)
  end

  def clean_local!
    if !on_master?
      puts "Must run against master"
      return
    end

    puts "#{@local_branches.size} local branches ready for cleanup"
    clean_branches!(@local_branches, false)
  end

  def never_remove_local
    @never_remove_local ||= ['master', 'staging', 'production', 'preproduction','training'] << current_branch
  end

  def never_remove_remote
    @never_remove_remote ||= ['master', 'staging', 'production', 'preproduction','training'] << current_branch
  end

  def managed_remotes
    ['origin']
  end

  def prune_branches!
    `git remote`.split("\n").each do |remote|
      print "Pruning remote #{remote}..."
      STDOUT.flush
      system "git remote prune #{remote}"
      puts " done!"
    end
  end

  private
  def clean_branches!(branch_list, remote)
    branch_list.each do |branch|
      branch_name = branch
      git_remote, branch_name = branch.split('/') if remote
      if git_remote && !managed_remotes.include?(git_remote)
        puts "Skipping #{git_remote}/#{branch_name} (reason: remote not managed)"
        next
      end

      if @force
        puts print "Removing #{branch}"
        clean_branch(remote, git_remote, branch_name)
      else
        invalid_response = true
        while (invalid_response)
          print "Remove #{branch}? [y/n] "
          STDOUT.flush
          response = gets.chomp.downcase

          if response.match(/^[yn]$/)
            invalid_response = false
            if response == 'y'
              clean_branch(remote, git_remote, branch_name)
            else
              puts "skipping #{branch_name}"
            end
          else
            puts "Please enter y or n"
          end
        end
      end
    end
  end

  def clean_branch(remote, git_remote, branch_name)
    command = remote ? "git push #{git_remote} :#{branch_name}" : "git branch -d #{branch_name}"
    system "#{command}"
  end
end

mode = nil
ARGV.each do|a|
  mode = 'force' if a == "--force"
  mode = 'dry'   if a == "--dry"
end

gc = GitCleanup.new(mode)
gc.clean_all!
