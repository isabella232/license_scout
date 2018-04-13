#
# Copyright:: Copyright 2018, Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "mixlib/cli"
require "license_scout/config"
require "license_scout/collector"
require "license_scout/reporter"

module LicenseScout
  class CLI
    include Mixlib::CLI

    #
    # These config values should match values available in LicenseScout::Config
    #
    option :config_files,
      short: "-c CONFIG_FILES",
      long: "--config-files CONFIG_FILES",
      description: "Comma-separated list of local (or remote) YAML configuration file(s) evaluated in order specified (priority goes to last file)",
      proc: Proc.new { |c| c.split(",") }

    option :directories,
      short: "-d DIRECTORIES",
      long: "--directories DIRECTORIES",
      description: "Comma-separated list of directories to scan",
      proc: Proc.new { |d| d.split(",") }

    option :log_level,
      short: "-l LEVEL",
      long: "--log-level LEVEL",
      description: "Set the log level (debug, info, warn, error, fatal)",
      proc: Proc.new { |l| l.to_sym }

    option :only_show_failures,
      long: "--only-show-failures",
      description: "Only print results for dependencies with licenses that failed checks",
      boolean: true

    option :help,
      short: "-h",
      long: "--help",
      description: "Show this message",
      on: :tail,
      boolean: true,
      show_options: true,
      exit: 0

    def run(argv = ARGV)
      parse_options(argv)

      LicenseScout::Config.merge!(config)

      LicenseScout::Log.level = LicenseScout::Config.log_level
      LicenseScout::Log.formatter = proc do |sev, datetime, progname, msg|
        "#{sev.ljust(5)} #{msg}\n"
      end

      LicenseScout::Config.config_files.each do |config_file|
        if config_file =~ /^http/
          require "open-uri"

          LicenseScout::Log.info("[cli] Loading config from #{config_file}")

          Dir.mktmpdir do |dir|
            local_tmp_file = File.join(dir, File.basename(config_file))
            IO.copy_stream(open(config_file), local_tmp_file)
            LicenseScout::Config.from_file(local_tmp_file)
          end
        else
          full_config_file = File.expand_path(config_file)
          LicenseScout::Log.info("[cli] Loading config from #{full_config_file}")
          LicenseScout::Config.from_file(full_config_file)
        end
      end

      LicenseScout::Config.validate!

      collector = LicenseScout::Collector.new
      collector.collect

      reporter = LicenseScout::Reporter.new(collector.dependencies)
      reporter.report
    end
  end
end