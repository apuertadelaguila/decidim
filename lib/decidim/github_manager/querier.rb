# frozen_string_literal: true

require "faraday"
require "json"

module Decidim
  module GithubManager
    # Allows to make GET requests to GitHub Rest API about Issues and Pull Requests
    # @see https://docs.github.com/en/rest
    module Querier
      autoload :ByIssueId, "decidim/github_manager/querier/by_issue_id"
      autoload :ByLabel, "decidim/github_manager/querier/by_label"
      autoload :RelatedIssues, "decidim/github_manager/querier/related_issues"
    end
  end
end
