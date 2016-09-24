require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PodTarget do
    before do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      @target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @target_definition.abstract = false
      @pod_target = PodTarget.new([spec], [@target_definition], config.sandbox)
      @pod_target.stubs(:platform).returns(Platform.ios)
    end

    describe 'Meta' do
      describe '#scope_suffix' do
        it 'returns target copies per target definition, which are scoped' do
          @pod_target.scope_suffix.should.be.nil
          @pod_target.scoped.first.scope_suffix.should == 'Pods'
          @pod_target.scope_suffix.should.be.nil
        end
      end
    end

    describe 'In general' do
      it 'returns the target definitions' do
        @pod_target.target_definitions.should == [@target_definition]
      end

      it 'is initialized with empty archs' do
        @pod_target.archs.should == []
      end

      it 'returns its name' do
        @pod_target.name.should == 'BananaLib'
        @pod_target.scoped.first.name.should == 'BananaLib-Pods'
      end

      it 'returns its label' do
        @pod_target.label.should == 'BananaLib'
        @pod_target.scoped.first.label.should == 'BananaLib-Pods'
      end

      it 'returns its label' do
        @pod_target.label.should == 'BananaLib'
        @pod_target.scoped.first.label.should == 'BananaLib-Pods'
        spec_scoped_pod_target = @pod_target.scoped.first.tap { |t| t.stubs(:scope_suffix).returns('.default-GreenBanana') }
        spec_scoped_pod_target.label.should == 'BananaLib.default-GreenBanana'
      end

      it 'returns the name of its product' do
        @pod_target.product_name.should == 'libBananaLib.a'
        @pod_target.scoped.first.product_name.should == 'libBananaLib-Pods.a'
      end

      it 'returns the spec consumers for the pod targets' do
        @pod_target.spec_consumers.should.not.nil?
      end

      it 'returns the root spec' do
        @pod_target.root_spec.name.should == 'BananaLib'
      end

      it 'returns the name of the Pod' do
        @pod_target.pod_name.should == 'BananaLib'
      end

      it 'returns the name of the resources bundle target' do
        @pod_target.resources_bundle_target_label('Fruits').should == 'BananaLib-Fruits'
        @pod_target.scoped.first.resources_bundle_target_label('Fruits').should == 'BananaLib-Pods-Fruits'
      end

      it 'returns the name of the Pods on which this target depends' do
        @pod_target.dependencies.should == ['monkey']
      end

      it 'returns whether it is whitelisted in a build configuration' do
        @target_definition.store_pod('BananaLib')
        @target_definition.whitelist_pod_for_configuration('BananaLib', 'debug')
        @pod_target.include_in_build_config?(@target_definition, 'Debug').should.be.true
        @pod_target.include_in_build_config?(@target_definition, 'Release').should.be.false
      end

      it 'is whitelisted on all build configurations of it is a dependency of other Pods' do
        @pod_target.include_in_build_config?(@target_definition, 'Debug').should.be.true
        @pod_target.include_in_build_config?(@target_definition, 'Release').should.be.true
      end

      it 'raises if a Pod is whitelisted for different build configurations' do
        @target_definition.store_pod('BananaLib')
        @target_definition.store_pod('BananaLib/Subspec')
        @target_definition.whitelist_pod_for_configuration('BananaLib', 'debug')
        message = should.raise Informative do
          @pod_target.include_in_build_config?(@target_definition, 'release').should.be.true
        end.message
        message.should.match /subspecs across different build configurations/
      end

      it 'builds a pod target if there are actual source files' do
        fa = Sandbox::FileAccessor.new(nil, @pod_target)
        fa.stubs(:source_files).returns([Pathname.new('foo.m')])
        @pod_target.stubs(:file_accessors).returns([fa])

        @pod_target.should_build?.should == true
      end

      it 'does not build a pod target if there are only header files' do
        fa = Sandbox::FileAccessor.new(nil, @pod_target)
        fa.stubs(:source_files).returns([Pathname.new('foo.h')])
        @pod_target.stubs(:file_accessors).returns([fa])

        @pod_target.should_build?.should == false
      end
    end

    describe 'Support files' do
      it 'returns the absolute path of the xcconfig file' do
        @pod_target.xcconfig_path('Release').to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.release.xcconfig',
        )
        @pod_target.scoped.first.xcconfig_path('Release').to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods.release.xcconfig',
        )
      end

      it 'escapes the file separators in variant build configuration name in the xcconfig file' do
        @pod_target.xcconfig_path("Release#{File::SEPARATOR}1").to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.release-1.xcconfig',
        )
        @pod_target.scoped.first.xcconfig_path("Release#{File::SEPARATOR}1").to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods.release-1.xcconfig',
        )
      end

      it 'returns the absolute path of the prefix header file' do
        @pod_target.prefix_header_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib-prefix.pch',
        )
        @pod_target.scoped.first.prefix_header_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods-prefix.pch',
        )
      end

      it 'returns the absolute path of the bridge support file' do
        @pod_target.bridge_support_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.bridgesupport',
        )
      end

      it 'returns the absolute path of the info plist file' do
        @pod_target.info_plist_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/Info.plist',
        )
        @pod_target.scoped.first.info_plist_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/Info.plist',
        )
      end

      it 'returns the absolute path of the dummy source file' do
        @pod_target.dummy_source_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib-dummy.m',
        )
        @pod_target.scoped.first.dummy_source_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods-dummy.m',
        )
      end

      it 'returns the absolute path of the public and private xcconfig files' do
        @pod_target.xcconfig_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.xcconfig',
        )
      end

      it 'returns the path for the CONFIGURATION_BUILD_DIR build setting' do
        @pod_target.configuration_build_dir.should == '$PODS_CONFIGURATION_BUILD_DIR/BananaLib'
        @pod_target.scoped.first.configuration_build_dir.should == '$PODS_CONFIGURATION_BUILD_DIR/BananaLib-Pods'
        @pod_target.configuration_build_dir('$PODS_BUILD_DIR').should == '$PODS_BUILD_DIR/BananaLib'
        @pod_target.scoped.first.configuration_build_dir('$PODS_BUILD_DIR').should == '$PODS_BUILD_DIR/BananaLib-Pods'
      end

      it 'returns the path for the CONFIGURATION_BUILD_DIR build setting' do
        @pod_target.build_product_path.should == '$PODS_CONFIGURATION_BUILD_DIR/BananaLib/libBananaLib.a'
        @pod_target.scoped.first.build_product_path.should == '$PODS_CONFIGURATION_BUILD_DIR/BananaLib-Pods/libBananaLib-Pods.a'
        @pod_target.build_product_path('$BUILT_PRODUCTS_DIR').should == '$BUILT_PRODUCTS_DIR/BananaLib/libBananaLib.a'
        @pod_target.scoped.first.build_product_path('$BUILT_PRODUCTS_DIR').should == '$BUILT_PRODUCTS_DIR/BananaLib-Pods/libBananaLib-Pods.a'
      end

      it 'returns the correct header search paths' do
        @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
        @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
        header_search_paths = @pod_target.recursive_target_header_search_paths
        header_search_paths.sort.should == [
          '${PODS_ROOT}/Headers/Private',
          '${PODS_ROOT}/Headers/Private/BananaLib',
          '${PODS_ROOT}/Headers/Public',
          '${PODS_ROOT}/Headers/Public/BananaLib',
        ]
      end

      it 'returns the correct header search paths recursively for dependent targets' do
        @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
        @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
        @pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
        monkey_spec = fixture_spec('monkey/monkey.podspec')
        monkey_pod_target = PodTarget.new([monkey_spec], [@target_definition], config.sandbox)
        monkey_pod_target.stubs(:platform).returns(Platform.ios)
        @pod_target.stubs(:dependent_targets).returns([monkey_pod_target])
        header_search_paths = @pod_target.recursive_target_header_search_paths
        header_search_paths.sort.should == [
          '${PODS_ROOT}/Headers/Private',
          '${PODS_ROOT}/Headers/Private/BananaLib',
          '${PODS_ROOT}/Headers/Public',
          '${PODS_ROOT}/Headers/Public/BananaLib',
          '${PODS_ROOT}/Headers/Public/monkey',
        ]
      end

      it 'returns the correct header search paths recursively for dependent targets excluding platform' do
        @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
        @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
        @pod_target.sandbox.public_headers.add_search_path('monkey', Platform.osx)
        monkey_spec = fixture_spec('monkey/monkey.podspec')
        monkey_pod_target = PodTarget.new([monkey_spec], [@target_definition], config.sandbox)
        monkey_pod_target.stubs(:platform).returns(Platform.ios)
        @pod_target.stubs(:dependent_targets).returns([monkey_pod_target])
        header_search_paths = @pod_target.recursive_target_header_search_paths
        # The monkey lib header search paths should not be present since they are only present in OSX.
        header_search_paths.sort.should == [
          '${PODS_ROOT}/Headers/Private',
          '${PODS_ROOT}/Headers/Private/BananaLib',
          '${PODS_ROOT}/Headers/Public',
          '${PODS_ROOT}/Headers/Public/BananaLib',
        ]
      end
    end

    describe 'Product type dependent helpers' do
      describe 'With libraries' do
        before do
          @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
        end

        it 'returns that it does not use swift' do
          @pod_target.uses_swift?.should == false
        end

        describe 'Host requires frameworks' do
          before do
            @pod_target.host_requires_frameworks = true
          end

          it 'returns the product name' do
            @pod_target.product_name.should == 'BananaLib.framework'
          end

          it 'returns the framework name' do
            @pod_target.framework_name.should == 'BananaLib.framework'
          end

          it 'returns the library name' do
            @pod_target.static_library_name.should == 'libBananaLib.a'
            @pod_target.scoped.first.static_library_name.should == 'libBananaLib-Pods.a'
          end

          it 'returns :framework as product type' do
            @pod_target.product_type.should == :framework
          end

          it 'returns that it requires being built as framework' do
            @pod_target.requires_frameworks?.should == true
          end

          it 'returns that it has no test specifications' do
            @pod_target.contains_test_specifications?.should == false
          end
        end

        describe 'Host does not requires frameworks' do
          it 'returns the product name' do
            @pod_target.product_name.should == 'libBananaLib.a'
            @pod_target.scoped.first.product_name.should == 'libBananaLib-Pods.a'
          end

          it 'returns the framework name' do
            @pod_target.framework_name.should == 'BananaLib.framework'
          end

          it 'returns the library name' do
            @pod_target.static_library_name.should == 'libBananaLib.a'
            @pod_target.scoped.first.static_library_name.should == 'libBananaLib-Pods.a'
          end

          it 'returns :static_library as product type' do
            @pod_target.product_type.should == :static_library
          end

          it 'returns that it does not require being built as framework' do
            @pod_target.requires_frameworks?.should == false
          end
        end
      end

      describe 'With frameworks' do
        before do
          @pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec')
          @pod_target.host_requires_frameworks = true
        end

        it 'returns that it uses swift' do
          @pod_target.uses_swift?.should == true
        end

        it 'returns the product module name' do
          @pod_target.product_module_name.should == 'OrangeFramework'
        end

        it 'returns the product name' do
          @pod_target.product_name.should == 'OrangeFramework.framework'
        end

        it 'returns the framework name' do
          @pod_target.framework_name.should == 'OrangeFramework.framework'
        end

        it 'returns the library name' do
          @pod_target.static_library_name.should == 'libOrangeFramework.a'
          @pod_target.scoped.first.static_library_name.should == 'libOrangeFramework-Pods.a'
        end

        it 'returns :framework as product type' do
          @pod_target.product_type.should == :framework
        end

        it 'returns that it requires being built as framework' do
          @pod_target.requires_frameworks?.should == true
        end
      end

      describe 'With dependencies' do
        before do
          @pod_dependency = fixture_pod_target('orange-framework/OrangeFramework.podspec')
          @pod_target.dependent_targets = [@pod_dependency]
        end

        it 'resolves simple dependencies' do
          @pod_target.recursive_dependent_targets.should == [@pod_dependency]
        end

        describe 'With cyclic dependencies' do
          before do
            @pod_dependency = fixture_pod_target('orange-framework/OrangeFramework.podspec')
            @pod_dependency.dependent_targets = [@pod_target]
            @pod_target.dependent_targets = [@pod_dependency]
          end

          it 'resolves the cycle' do
            @pod_target.recursive_dependent_targets.should == [@pod_dependency]
          end
        end
      end

      describe 'test spec support' do
        before do
          @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          @test_spec_target_definition = Podfile::TargetDefinition.new('Pods', nil)
          @test_spec_target_definition.abstract = false
          @test_pod_target = PodTarget.new([@coconut_spec, *@coconut_spec.recursive_subspecs], [@test_spec_target_definition], config.sandbox)
          @test_pod_target.stubs(:platform).returns(:ios)
        end

        it 'returns that it has test specifications' do
          @test_pod_target.contains_test_specifications?.should == true
        end

        it 'returns supported test types' do
          @test_pod_target.supported_test_types.should == [:unit]
        end

        it 'returns test label based on test type' do
          @test_pod_target.test_target_label(:unit).should == 'CoconutLib-Unit-Tests'
        end

        it 'returns the correct native target based on the consumer provided' do
          @test_pod_target.stubs(:native_target).returns(stub(:name => 'CoconutLib', :symbol_type => :dynamic_library, :product_reference => stub(:name => 'libCoconutLib.a')))
          @test_pod_target.stubs(:test_native_targets).returns([stub(:name => 'CoconutLib-Unit-Tests', :symbol_type => :unit_test_bundle, :product_reference => stub(:name => 'CoconutLib-Unit-Tests'))])
          native_target = @test_pod_target.native_target_for_spec(@coconut_spec)
          native_target.name.should == 'CoconutLib'
          native_target.product_reference.name.should == 'libCoconutLib.a'
          test_native_target = @test_pod_target.native_target_for_spec(@coconut_spec.test_specs.first)
          test_native_target.name.should == 'CoconutLib-Unit-Tests'
          test_native_target.product_reference.name.should == 'CoconutLib-Unit-Tests'
        end

        it 'returns the correct product type for test type' do
          @test_pod_target.product_type_for_test_type(:unit).should == :unit_test_bundle
        end

        it 'raises for unknown test type' do
          exception = lambda { @test_pod_target.product_type_for_test_type(:weird_test_type) }.should.raise Informative
          exception.message.should.include 'Unknown test type `weird_test_type`.'
        end
      end
    end
  end
end
