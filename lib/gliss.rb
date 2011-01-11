# gliss.rb
#
# lightweight glossing for git commit messages
#
# Copyright (c) 2011 Red Hat, Inc.
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

module Gliss
  Gloss = Struct.new(:sha, :tag, :text)
  CommitMsg = Struct.new(:sha, :log)
  GLOSS_RE = /^===(-?)(.*?)===(.*)/
  INDENT_RE = /^(\s+)(.*)?/

  def self.commits_between(repo, older, newer)
    if repo.is_a?(String)
      repo = Grit::Repo.new(repo)
    end

    repo.commit_deltas_from(repo, older, newer).map do |commit_obj|
      CommitMsg.new(commit_obj.sha, commit_obj.message)
    end
  end

  def self.glosses_between(repo, older, newer)
    commits_between(repo, older, newer).inject([]) do |acc, val|
      # XXX
    end
  end

  def self.glosses_in(message, sha=nil)
    result = []
    continuing = false
    indent_matcher = nil

    message.each_line do |line|
      match = nil
      if continuing
        match = indent_matcher ? line.match(indent_matcher) : line.match(INDENT_RE)
        
        if match
          indent_matcher = /^(#{match[1]})(.*)$/
          result[-1].text << " " << match[2]
        else
          indent_matcher = nil
          continuing = false
        end
      end
          
      match = line.match(GLOSS_RE)
      if match
        continuing = true
        puts "matched a gloss with tag '#{match[2]}' and first line '#{match[3]}'"
        result << Gloss.new(sha, match[2], match[3])
      end
    end
    result
  end
end
