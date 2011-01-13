# gliss.rb
#
# lightweight glossing for git commit messages
#
# Copyright (c) 2011 Red Hat, Inc. and William C. Benton
# Author:  William Benton (willb@redhat.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'grit'
require 'optparse'

module Gliss
  Gloss = Struct.new(:sha, :tag, :text)
  CommitMsg = Struct.new(:sha, :log)
  GLOSS_RE=/^((?:[^\s]){3})(-?)(.*?)\1(.*)/
  GLOSS_TAG=3
  GLOSS_TEXT=4
  GLOSS_STRIP=2
  INDENT_RE=/^(\s+)(.*)$/
  INDENT_AMOUNT=1
  INDENTED_TEXT=2

  def self.glosses_between(repo, older, newer)
    commits_between(repo, older, newer).inject([]) do |acc, commit|
      acc + glosses_in(commit.log, commit.sha)
    end
  end

  def self.commits_between(repo, older, newer)
    if repo.is_a?(String)
      repo = Grit::Repo.new(repo)
    end

    commits = repo.commit_deltas_from(repo, older, newer).sort_by {|c| c.committed_date}
    commits.map do |commit_obj|
      CommitMsg.new(commit_obj.sha, commit_obj.message)
    end
  end

  def self.glosses_in(message, sha=nil)
    result = []
    continuing = false
    indent_matcher = nil

    message.each_line do |line|
      line.chomp!
      match = nil
      if continuing
        match = line.match((indent_matcher || INDENT_RE))
        
        if match
          indent_matcher ||= /^(#{match[INDENT_AMOUNT]})(.*)$/
          text = match[INDENTED_TEXT].strip
          result[-1].text << text
        else
          indent_matcher = nil
          continuing = false
        end
      end
          
      match = line.match(GLOSS_RE)
      if match
        continuing = true
        indent_matcher = nil
        tag = match[GLOSS_TAG].strip
        text = match[GLOSS_TEXT].strip
        result << Gloss.new(sha, tag, [text])
      end
    end

    result.each {|g| g.text.reject! {|t| t == ''}; g.text = g.text.join(" ")}
  end
  
  class App
    def initialize(args=nil)
      @args = (args || ARGV.dup)
    end
    
    def main
      begin
        process_args
        r = Grit::Repo.new(@repo)
        output_glosses(r)
      rescue Exception=>ex
        puts "fatal:  #{ex.inspect}"
      end
    end
    
    private
    def output_glosses(repo)
      Gliss::glosses_between(repo, @from, @to).each do |gloss|
        if gloss.tag =~ @filter
          sha = gloss.sha.slice(0,8)
          tag = gloss.tag
          msg = gloss.text
          puts "#{sha} (#{tag})"
          msg.each_line {|line| puts "  #{line.chomp}"}
        end
      end 
    end
    
    def process_args
      @repo = "."
      @filter = /.*/
      
      oparser.parse!(@args)
      unless @args.size <= 2 && @args.size >= 1
        puts "fatal:  you must specify at least one branch or tag name"
        puts oparser
        exit(1)
      end
      
      @from, @to = @args
      @to ||= "master"
    end
    
    def oparser
      @oparser ||= OptionParser.new do |opts|
        opts.banner = "gliss [options] FROM [TO]\nDisplays all gliss-formatted glosses reachable from TO but not from FROM.\nIf TO is not specified, use \"master\"."
        
        opts.on("-h", "--help", "Displays this message") do
          puts opts
          exit
        end
        
        opts.on("-r REPO", "--repo REPO", "Runs in the given repo (default is \".\")") do |repo|
          @repo = repo
        end
        
        opts.on("-f REGEX", "--filter REGEX", "Output only messages with tags matching REGEX", "(default is all tags)") do |filter|
          @filter = Regexp.new(filter)
        end
      end
    end
  end
end
