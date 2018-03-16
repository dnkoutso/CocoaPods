module Pod
  class Installer
    class Xcode
      class TargetInstallationResult
        # @return [Target] the target the installation happened for
        #
        attr_reader :target

        # @return [PBXNativeTarget] the native target that was created. This will be `nil` if the target
        #         did not require a native target, for example it is a pre-built pod with no sources.
        #
        attr_reader :native_target

        # Initialize a new instance
        #
        # @param [Target] target @see #target
        # @param [PBXNativeTarget] native_target @see #native_target
        #
        def initialize(target, native_target)
          @target = target
          @native_target = native_target
        end
      end
    end
  end
end
