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
require 'set'
begin
  require 'maruku'
  $HAS_MARUKU=true
rescue LoadError=>le
  $HAS_MARUKU=false
end

module Gliss
  Gloss = Struct.new(:sha, :tag, :text)
  CommitMsg = Struct.new(:sha, :log)
  GLOSS_TAG_RE=/(([^\s])\3\3)(-?)(.*?)\2(.*)/
  GLOSS_INDENTED_RE=/^(\s*)#{GLOSS_TAG_RE}/
  GLOSS_MIDLINE_RE=/^(.*?)#{GLOSS_TAG_RE}/
  GLOSS_RE=/^()#{GLOSS_TAG_RE}/
  
  GLOSS_TAG=5
  GLOSS_TEXT=6
  GLOSS_STRIP=4
  GLOSS_BEFORE=1

  BARE_INDENT_RE=/(\s+)(.*)/
  INDENT_AMOUNT=1
  INDENTED_TEXT=2

  attr_reader :filter

  def self.glosses_between(repo, older, newer, allow_indented=false)
    commits_between(repo, older, newer).inject([]) do |acc, commit|
      acc + glosses_in(commit.log, commit.sha, allow_indented)
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

  def self.glosses_in(message, sha=nil, allow_indented=false)
    result = []
    continuing = false
    ws = ""
    indent_matcher = nil

    message.each_line do |line|
      line.chomp!
      match = nil
      if continuing
        match = line.match((indent_matcher || /^(?:#{ws})#{BARE_INDENT_RE}$/))
        
        if match
          indent_matcher ||= /^(?:#{ws})(#{match[INDENT_AMOUNT]})(.*)$/
          text = match[INDENTED_TEXT].strip
          result[-1].text << text
          next
        else
          indent_matcher = nil
          continuing = false
        end
      end
      
      match = begins_gloss(line, sha, allow_indented)
      if match
        continuing, indent_matcher, ws, new_gloss = match
        result << new_gloss
      end
    end

    result.each {|g| g.text.reject! {|t| t == ''}; g.text = g.text.join(" ")}
  end
  
  def self.begins_gloss(line, sha, allow_indented=false)
    match = line.match(allow_indented ? GLOSS_INDENTED_RE : GLOSS_RE)
    if match
      ws = match[GLOSS_BEFORE]
      tag = match[GLOSS_TAG].strip
      text = match[GLOSS_TEXT].strip
      return [true, nil, ws, Gloss.new(sha, tag, [text])]
    end
    nil
  end
  
  def self.split_glosses(gloss, split_glosses=false)
    if split_glosses
      result_glosses = [gloss]
      text = gloss.text
      match = text.match(GLOSS_MIDLINE_RE)
      while match
        result_glosses[-1].text = match[GLOSS_BEFORE].strip if result_glosses[-1]
        tag = match[GLOSS_TAG].strip
        text = match[GLOSS_TEXT].strip
        result_glosses << Gloss.new(gloss.sha, tag, text)
        match = text.match(GLOSS_MIDLINE_RE)
      end

      if block_given?
        result_glosses.each do |g|
          yield g
        end
      else
        result_glosses
      end
    else
      if block_given?
        yield gloss
      else
        return [gloss]
      end
    end
  end

  class App
    OUTPUT_KINDS=%w{html latex}
    
    def initialize(args=nil)
      @args = (args || ARGV.dup)
    end
    
    def main
      begin
        process_args
        @the_repo = Grit::Repo.new(@repo)
        output_glosses(@the_repo)
      rescue SystemExit=>ex
          exit!(ex.status)
      rescue Exception=>ex
        puts "fatal:  #{ex.inspect}"
      end
    end
    
    private
    def output_glosses(repo)
      Gliss::glosses_between(repo, @from, @to, @allow_indented_glosses).each do |gloss|
        Gliss::split_glosses(gloss, @split_glosses) do |gl|
          if gl.tag =~ @filter
            @output_proc.call(gl)
          end
        end
      end 
    end
    
    def process_args
      @repo = "."
      @output_proc = Proc.new do |gloss|
        sha = gloss.sha.slice(0,8)
        tag = gloss.tag
        msg = gloss.text
        puts "#{sha} (#{tag})"
        if @format_glosses && tag =~ @output_tag_filter
          puts Maruku.new(msg).send(@markdown_backend_msg)
        else
          msg.each_line {|line| puts "  #{line.chomp}"}
        end
      end
      
      @output_filter_kind = :latex
      @output_tag_filter = nil
      @markdown_list = ""
      
      oparser.parse!(@args)
      unless @args.size <= 2 && @args.size >= 1
        puts "fatal:  you must specify at least one branch or tag name"
        puts oparser
        exit(1)
      end

      if @whole_commit && @format_glosses
        puts "fatal:  --whole-commit is incompatible with --format-glosses-matching; please\nchoose at most one of these options"
        exit(1)
      end

      @filter ||= /.*/
      
      @from, @to = @args
      @to ||= "master"
      
      @markdown_backend_msg = "to_#{@output_filter_kind}#{@markdown_list}"
    end
    
    def oparser
      @oparser ||= OptionParser.new do |opts|
        opts.banner = "gliss [options] FROM [TO]\nDisplays all gliss-formatted glosses reachable from TO but not from FROM.\nTO and FROM are commit SHAs, branch names, or tag names.\nIf TO is not specified, gliss will use \"master\" as the TO argument."
        
        opts.separator("\nGeneral options:")
        
        opts.on("-h", "--help", "Displays this message") do
          puts opts
          exit
        end
        
        opts.on("-r REPO", "--repo REPO", "Runs in the given repo (default is \".\")") do |repo|
          @repo = repo
        end
        
        opts.on("-f REGEX", "--filter REGEX", "Output only messages with tags matching", "REGEX (default is all tags).", "Applying this multiple times will select", "tags matching any supplied expression.") do |filter|
          new_filter = Regexp.new(filter)
          @filter = @filter ? Regexp.union(@filter, new_filter) : new_filter
        end
        
        opts.separator("\nFormatting options:")
        
        opts.on("-w", "--whole-commit", "Output entire commit messages that", "contain glosses") do
          @whole_commit = true
          @seen_messages = Set.new
          @output_proc = Proc.new do |gloss|
            unless @seen_messages.include?(gloss.sha)
              @seen_messages << gloss.sha
              commit, = @the_repo.commits(gloss.sha)
              sha = commit.to_s.slice(0,8)
              # puts commit.inspect
              puts sha
              commit.message.each_line {|line| puts "  #{line}"}
            end
          end
        end
        
        if $HAS_MARUKU
          opts.on("--format-glosses-matching REGEX", "Apply Markdown formatting to tags matching", "REGEX (default is format no tags)", "Applying this multiple times will select", "tags matching any supplied expression.") do |re|
            @format_glosses = true
            new_oft_re = Regexp.new(re)
            @output_tag_filter = @output_tag_filter ? Regexp.union(@output_tag_filter, new_oft_re) : new_oft_re
          end
          
          opts.on("--markdown-output KIND", OUTPUT_KINDS, "Select the type of Markdown output","to generate: #{OUTPUT_KINDS.join(" or ")}. (The default","is latex)") do |ok|
            @output_filter_kind = ok.to_sym
          end
          
          opts.on("--markdown-as-list", "Output Markdown glosses as list items") {@markdown_list="_li"}
        else
          opts.separator("More formatting options are available if you install the maruku gem\nwith 'gem install maruku'")
        end
        
        opts.separator("\nOptions to handle potentially-malformed input:")
        
        opts.on("--split-glosses", "Attempt to find multiple glosses in a", "line. Note that this option may return","spurious glosses") do
          @split_glosses = true
        end
        
        opts.on("--allow-indented-glosses", "Find glosses that don't begin at the","beginning of a line. Note that this","option may return spurious glosses.") do
          @allow_indented_glosses = true
        end
        
        opts.on("--permissive", "Find as many malformed gloss candidates as","possible. Implies --allow-indented-glosses", "and --split-glosses") do
          @split_glosses = true
          @allow_indented_glosses = true
        end
        
      end
    end
  end
end
