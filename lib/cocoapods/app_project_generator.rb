module Pod
  # TODO
  #
  class AppProjectGenerator

    # TODO
    #
    attr_reader :path

    # TODO
    #
    attr_reader :name

    def initialize(path, name = 'App.xcodeproj')
      @path = path
      @name = name
    end

    # TODO
    #
    def create_app_project(platform_name, deployment_target)
      @project = Xcodeproj::Project.new(project_path)
      @project.new_target(:application, 'App', platform_name, deployment_target)
    end

    # TODO
    #
    def add_app_project_import(pod_target, platform_name, use_frameworks, swift_version, include_xctest)
      source_file = write_app_import_source_file(pod_target, platform_name, use_frameworks)
      source_file_ref = @project.new_group('App', 'App').new_file(source_file)
      app_target = @project.targets.first
      app_target.add_file_references([source_file_ref])
      add_swift_version(app_target, swift_version)
      add_xctest(app_target) if include_xctest
    end

    def project_path
      @path + @name
    end

    def save
      @project.save
    end

    def recreate_user_schemes
      @project.recreate_user_schemes
    end

    private

    def write_app_import_source_file(pod_target, platform_name, use_frameworks)
      language = pod_target.uses_swift? ? :swift : :objc

      if language == :swift
        source_file = @path.+('App/main.swift')
        source_file.parent.mkpath
        import_statement = use_frameworks && pod_target.should_build? ? "import #{pod_target.product_module_name}\n" : ''
        source_file.open('w') { |f| f << import_statement }
      else
        source_file = @path.+('App/main.m')
        source_file.parent.mkpath
        import_statement = if use_frameworks && pod_target.should_build?
                             "@import #{pod_target.product_module_name};\n"
                           else
                             header_name = "#{pod_target.product_module_name}/#{pod_target.product_module_name}.h"
                             if pod_target.sandbox.public_headers.root.+(header_name).file?
                               "#import <#{header_name}>\n"
                             else
                               ''
                             end
                           end
        source_file.open('w') do |f|
          f << "@import Foundation;\n"
          f << "@import UIKit;\n" if platform_name == :ios || platform_name == :tvos
          f << "@import Cocoa;\n" if platform_name == :osx
          f << "#{import_statement}int main() {}\n"
        end
      end
      source_file
    end

    def add_xctest(app_target)
      app_target.build_configurations.each do |configuration|
        search_paths = configuration.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= '$(inherited)'
        search_paths << ' "$(PLATFORM_DIR)/Developer/Library/Frameworks"'
      end
    end

    def add_swift_version(app_target, swift_version)
      app_target.build_configurations.each do |configuration|
        configuration.build_settings['SWIFT_VERSION'] = swift_version
      end
    end
  end
end
