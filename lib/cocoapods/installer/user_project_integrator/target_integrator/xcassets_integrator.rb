module Pod
  class Installer
    class UserProjectIntegrator
      class TargetIntegrator
        # TODO
        #
        class XCAssetsIntegrator
          # TODO
          #
          def self.integrate(aggregate_target, targets)
            targets.each do |target|
              target.build_configurations.each do |config|
                xcasset_paths_for_config = aggregate_target.resource_paths_by_config.fetch(config.name, []).select { |r| r.end_with?('.xcassets') }
                xcasset_paths_for_config.each do |xcasset_path|
                  create_xcassets_ref(aggregate_target, config, xcasset_path)
                end
              end
            end

          end

          private

          # @!group Integration steps
          #-------------------------------------------------------------------#

          # @todo
          #
          def self.set_xcassets_for_target(aggregate_target, config, xcassets_paths)
            xcassets_paths.each do |xcassets_path|
              create_xcassets_ref(aggregate_target, config, xcassets_path)
            end
          end

          # @todo
          #
          def self.create_xcassets_ref(aggregate_target, config, xcassets_path)
            # Xcode root group's path is absolute, we must get the relative path of the sandbox to the user project
            group_path = aggregate_target.relative_pods_root_path
            group = config.project['Pods'] || config.project.new_group('Pods', group_path)

            # support user custom paths of Pods group and xcconfigs files.
            group_path = Pathname.new(group.real_path)
            path = xcassets_path.relative_path_from(group_path)

            filename = path.basename.to_s
            file_ref = group.files.find { |f| f.display_name == filename }
            if file_ref && file_ref.path != path
              file_ref_path = Pathname.new(file_ref.real_path)
              if !file_ref_path.exist? || !xcconfig_path.exist? || file_ref_path.realpath != xcconfig_path.realpath
                file_ref.path = path.to_s
              end
            end

            file_ref || group.new_file(path.to_s)
          end
        end
      end
    end
  end
end
