module Pod
  # Stores the information relative to the target used to compile a single test target
  # for a pod. Each test target is mapped to a single test spec.
  #
  class TestPodTarget < Target
    # @return [Specification] the test spec for this target.
    #
    attr_reader :spec

    # @return [PodTarget] the pod target being tested by this target.
    #
    attr_reader :pod_target

    # @return [Array<TestPodTarget>] the targets that this target has a dependency
    #         upon.
    #
    attr_accessor :dependent_targets

    # @return [Array<Sandbox::FileAccessor>] the file accessors for the
    #         specifications of this target.
    #
    attr_accessor :file_accessors

    # @return [PBXNativeTarget] the test target generated in the Pods project for
    #        this target.
    #
    attr_accessor :native_target

    # @return [Array<PBXNativeTarget>] the resource bundle targets belonging
    #         to this target.
    #
    attr_reader :resource_bundle_targets

    # Initialize a new instance
    #
    # @param [Sandbox] sandbox @see Target#sandbox
    # @param [Boolean] host_requires_frameworks @see Target#host_requires_frameworks
    # @param [Hash{String=>Symbol}] user_build_configurations @see Target#user_build_configurations
    # @param [Array<String>] archs @see Target#archs
    # @param [Specification] spec @see #spec
    # @param [PodTarget] pod_target @see #pod_target
    #
    def initialize(sandbox, host_requires_frameworks, user_build_configurations, archs, spec, pod_target)
      super(sandbox, host_requires_frameworks, user_build_configurations, archs)
      raise "Can't initialize a TestPodTarget without a spec!" if spec.nil?
      raise "Can't initialize a TestPodTarget without a test spec!" unless spec.test_specification?
      raise "Can't initialize a TestPodTarget without a pod target!" if pod_target.nil?
      @spec = spec.dup.freeze
      @pod_target = pod_target
      @dependent_targets = []
      @file_accessors = []
      @resource_bundle_targets = []
    end

    # @return [String] the label for this target.
    #
    def label
      "#{pod_target.label}-#{test_type.capitalize}-Tests"
    end

    # @return [Symbol] the test type for this target.
    #
    def test_type
      spec.test_type
    end

    # @return [Platform] the platform for this target.
    #
    def platform
      pod_target.platform
    end

    # @return [Array<PodTarget>] the recursive targets that this target has a
    #         dependency upon.
    #
    def recursive_dependent_targets
      @recursive_dependent_targets ||= begin
        targets = dependent_targets.clone

        targets.each do |target|
          target.dependent_targets.each do |t|
            targets.push(t) unless t == self || targets.include?(t)
          end
        end

        targets
      end
    end

    # @return [String] The label of the app host label to use given the platform and test type.
    #
    def app_host_label
      "AppHost-#{Platform.string_name(platform.symbolic_name)}-#{test_type.capitalize}-Tests"
    end

    # @return [Pathname] The absolute path of the copy resources script for the given test type.
    #
    def copy_resources_script_path
      support_files_dir + "#{label}-resources.sh"
    end

    # @return [Pathname] The absolute path of the embed frameworks script for the given test type.
    #
    def embed_frameworks_script_path
      support_files_dir + "#{label}-frameworks.sh"
    end

    # @return [Pathname] The absolute path of the Info.plist for the given test type.
    #
    def info_plist_path
      support_files_dir + "#{label}-Info.plist"
    end

    # @return [Pathname] the absolute path of the prefix header file for the given test type.
    #
    def prefix_header_path
      support_files_dir + "#{label}-prefix.pch"
    end

    # @return [Pathname] the folder where to store the support files of this
    #         library. For test targets this is the same folder as the one used for the parent pod target.
    #
    def support_files_dir
      sandbox.target_support_files_dir(pod_target.name)
    end

    # Returns the corresponding native product type to use given the test type.
    # This is primarily used when creating the native targets in order to produce the correct test bundle target
    # based on the type of tests included.
    #
    # @return [Symbol] The native product type to use.
    #
    def product_type
      case test_type
        when :unit
          :unit_test_bundle
        else
          raise Informative, "Unknown test type `#{test_type}`."
      end
    end

    # Returns the corresponding test type given the product type.
    #
    # @param  [Symbol] product_type
    #         The product type to map to a test type.
    #
    # @return [Symbol] The native product type to use.
    #
    def test_type_for_product_type(product_type)
      case product_type
        when :unit_test_bundle
          :unit
        else
          raise Informative, "Unknown product type `#{product_type}`."
      end
    end
  end
end
