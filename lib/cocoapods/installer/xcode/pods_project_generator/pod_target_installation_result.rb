module Pod
  class Installer
    class Xcode
      class PodTargetInstallationResult < TargetInstallationResult
        # @return [Array<PBXNativeTarget] the test native targets that were created or empty if none were needed.
        #
        attr_reader :native_test_targets

        # @return [Array<PBXNativeTarget>] the app host targets that were created or empty if none were needed.
        #         App host targets are generated for pods that use test specs and require an app host.
        #
        attr_reader :app_host_targets

        # @return [Array<PBXNativeTarget>] the resource bundle targets that were created or empty if none were needed.
        #
        attr_reader :resource_bundle_targets

        # @return [Array<PBXNativeTarget>] the resource bundle targets that were created for test specs or empty if
        #         none were needed.
        #
        attr_reader :test_resource_bundle_targets

        # Initialize a new instance
        #
        # @param [Target] target @see TargetInstallationResult#target
        # @param [PBXNativeTarget] native_target @see TargetInstallationResult#native_target
        # @param [Array<PBXNativeTarget>] native_test_targets @see #native_test_targets
        # @param [Array<PBXNativeTarget>] app_host_targets @see #app_host_targets
        # @param [Array<PBXNativeTarget>] resource_bundle_targets @see #resource_bundle_targets
        # @param [Array<PBXNativeTarget>] test_resource_bundle_targets @see #test_resource_bundle_targets
        #
        def initialize(target, native_target = nil, native_test_targets = [], app_host_targets = [], resource_bundle_targets = [], test_resource_bundle_targets = [])
          super(target, native_target)
          @native_test_targets = native_test_targets
          @app_host_targets = app_host_targets
          @resource_bundle_targets = resource_bundle_targets
          @test_resource_bundle_targets = test_resource_bundle_targets
        end

        # @return [Bool] Whether or not this target should be built.
        #
        def should_build?
          target.should_build?
        end

        # @return [String] the name of the target that was installed.
        #
        def name
          target.name
        end
      end
    end
  end
end
