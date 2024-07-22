require 'fastlane/action'
require_relative '../helper/gha_secrets_check_helper'
require 'yaml'

module Fastlane
  module Actions
    class GhaSecretsCheckAction < Action
      def self.run(params)
        workflow_files = Dir.glob("#{File.expand_path(params[:repo_dir])}/.github/workflows/*.{yml,yaml}")
        pass = true
        workflow_files.each do |file|
          workflow = YAML.safe_load(read_and_sanitize(file))

          workflow_call = workflow.dig('on', 'workflow_call')
          if workflow_call.nil?
            UI.message(" 🤷‍♀️ #{File.basename(file)} does not use workflow_call")
            next
          end

          workflow_call_secrets = Set.new(workflow_call.dig('secrets')&.keys || [])

          jobs = workflow['jobs'].to_s
          secrets = Set.new(jobs.scan(/\bsecrets\.[_A-Z0-9]+\b/).map { |s| s.gsub(/secrets\./, '') })

          if secrets.eql? workflow_call_secrets
            UI.message(" ✅ #{File.basename(file)}")
          elsif secrets.subset? workflow_call_secrets
            UI.message(" ⚠️ #{File.basename(file)} contains unused secrets:")
            (workflow_call_secrets - secrets).to_a.each { |s| UI.message("    - #{s}") }
          else
            UI.error(" ❌ #{File.basename(file)} contains undeclared secrets:")
            (secrets - workflow_call_secrets).to_a.each { |s| UI.error("    - #{s}") }
            pass = false
          end
        end
        pass
      end

      def self.description
        "This plugin verifies if secrets used by GitHub Actions workflows are correctly referenced in their workflow_call definitions"
      end

      def self.authors
        ["DuckDuckGo"]
      end

      def self.return_value
        "Returns true if all secrets are correctly referenced, false otherwise"
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :repo_dir,
                                       env_name: "GHA_SECRETS_CHECK_REPO_DIR",
                                       description: "Path to the repository directory",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      private

      def self.read_and_sanitize(file)
        # 'on', also 'on:' key is translated to a boolean value of true, unless quoted, so let's apply quoting.
        File.read(file).gsub(/\b(on|yes|no)\b/, '"\1"')
      end

    end
  end
end
