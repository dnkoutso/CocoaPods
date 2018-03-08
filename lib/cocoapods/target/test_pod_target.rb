module Pod
  # Stores the information relative to the target used to compile a test target for a Pod.
  # A pod can have one or more activated test specs.
  #
  class TestPodTarget < Target
    # @return [PodTarget] The parent pod target of this test pod target.
    #
    attr_reader :pod_target

    # @return [Array<Specification>] the test spec for the target.
    #
    attr_reader :specs

    # @return [Array<PBXNativeTarget>] the resource bundles test targets belonging
    #         to this target.
    #
    attr_reader :resource_bundle_targets

    # return [Array<PBXNativeTarget>] the test targets generated in the Pods project for
    #         this library or `nil` if there are no test targets created.
    #
    attr_accessor :native_targets

    # @return [Array<TestPodTarget>] the test targets that this target has a test dependency
    #         upon.
    #
    attr_accessor :dependent_targets

    # @param [PodTarget] pod_target @see #pod_target
    # @param [Array<Specification>] specs @see #specs
    #
    def initialize(pod_target, specs)
      raise "Can't initialize a TestPodTarget without a parent PodTarget!" if pod_target.nil?
      raise "Can't initialize a TestPodTarget without test specs!" if test_specs.nil? || test_specs.empty?
      raise "Can't initialize a TestPodTarget with a test spec that is not a test specification!" unless test_specs.all?(&:test_specification?)
      super()
      @pod_target = pod_target
      @specs = specs.dup.freeze
      @file_accessors = []
      @resource_bundle_targets = []
      @test_native_targets = []
      @dependent_targets = []
    end

    # @return [Array<TestPodTarget>] the recursive test targets that this target has a
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

    # Returns the corresponding native product type to use given the test type.
    # This is primarily used when creating the native targets in order to produce the correct test bundle target
    # based on the type of tests included.
    #
    # @param  [Symbol] test_type
    #         The test type to map to provided by the test specification DSL.
    #
    # @return [Symbol] The native product type to use.
    #
    def product_type_for_test_type(test_type)
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

    # @param  [Symbol] test_type
    #         The test type to use for producing the test label.
    #
    # @return [String] The label of the app host label to use given the platform and test type.
    #
    def app_host_label(test_type)
      "AppHost-#{Platform.string_name(platform.symbolic_name)}-#{test_type.capitalize}-Tests"
    end

    # @return [Array<Symbol>] All of the test supported types within this target.
    #
    def supported_test_types
      test_specs.map(&:test_type).uniq
    end

    # @param  [Symbol] test_type
    #         The test type to use for producing the test label.
    #
    # @return [String] The derived name of the test target.
    #
    def test_target_label(test_type)
      "#{label}-#{test_type.capitalize}-Tests"
    end

    # @param  [Symbol] test_type
    #         The test type prefix header path is for.
    #
    # @return [Pathname] the absolute path of the prefix header file for the given test type.
    #
    def prefix_header_path_for_test_type(test_type)
      support_files_dir + "#{test_target_label(test_type)}-prefix.pch"
    end

    # @param  [Symbol] test_type
    #         The test type this embed frameworks script path is for.
    #
    # @return [Pathname] The absolute path of the embed frameworks script for the given test type.
    #
    def embed_frameworks_script_path_for_test_type(test_type)
      support_files_dir + "#{test_target_label(test_type)}-frameworks.sh"
    end

    # @param  [Symbol] test_type
    #         The test type this embed frameworks script path is for.
    #
    # @return [Pathname] The absolute path of the copy resources script for the given test type.
    #
    def copy_resources_script_path_for_test_type(test_type)
      support_files_dir + "#{test_target_label(test_type)}-resources.sh"
    end
  end
end
