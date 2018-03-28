require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PodTarget do
    before do
      @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
      @target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @target_definition.abstract = false
      @pod_target = PodTarget.new(config.sandbox, false, {}, [], [@coconut_spec], [@target_definition], nil)
      @pod_target.stubs(:platform).returns(Platform.ios)
      @test_pod_target = TestPodTarget.new(config.sandbox, false, {}, [], @coconut_spec.test_specs.first, @pod_target)
      @test_pod_target.stubs(:platform).returns(Platform.ios)
    end

    describe 'In general' do
      it 'returns test type' do
        @test_pod_target.test_type.should == :unit
      end

      it 'returns test label based on test type' do
        @test_pod_target.label.should == 'CoconutLib-Unit-Tests'
      end

      it 'returns app host label based on test type' do
        @test_pod_target.app_host_label.should == 'AppHost-iOS-Unit-Tests'
      end

      it 'returns the correct product type for test type' do
        @test_pod_target.product_type.should == :unit_test_bundle
      end

      it 'raises for unknown test type' do
        @test_pod_target.stubs(:test_type).returns(:weird_test_type)
        exception = lambda { @test_pod_target.product_type }.should.raise Informative
        exception.message.should.include 'Unknown test type `weird_test_type`.'
      end

      it 'returns the correct test type for product type' do
        @test_pod_target.test_type_for_product_type(:unit_test_bundle).should == :unit
      end

      it 'raises for unknown product type' do
        exception = lambda { @test_pod_target.test_type_for_product_type(:weird_product_type) }.should.raise Informative
        exception.message.should.include 'Unknown product type `weird_product_type`'
      end

      it 'returns correct copy resources script path for test unit test type' do
        @test_pod_target.copy_resources_script_path.to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources.sh'
      end

      it 'returns correct embed frameworks script path for test unit test type' do
        @test_pod_target.embed_frameworks_script_path.to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks.sh'
      end

      it 'returns correct prefix header path for test unit test type' do
        @test_pod_target.prefix_header_path.to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-prefix.pch'
      end

      it 'returns correct path for info plist for unit test type' do
        @test_pod_target.info_plist_path.to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-Info.plist'
      end

      it 'returns the correct resource path for test resource bundles' do
        fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        fa.stubs(:resource_bundles).returns('TestResourceBundle' => [Pathname.new('Model.xcdatamodeld')])
        fa.stubs(:resources).returns([])
        fa.stubs(:spec).returns(stub(:test_specification? => true))
        @test_pod_target.stubs(:file_accessors).returns([fa])
        @test_pod_target.resource_paths.should == ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
      end

      it 'includes framework paths from test specifications' do
        fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/Vendored.framework')])
        fa.stubs(:spec).returns(stub(:test_specification? => false))
        test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        test_fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/TestVendored.framework')])
        test_fa.stubs(:spec).returns(stub(:test_specification? => true))
        @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
        @test_pod_target.stubs(:should_build?).returns(true)
        @test_pod_target.framework_paths.should == [
            { :name => 'Vendored.framework',
              :input_path => '${PODS_ROOT}/Vendored/Vendored.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Vendored.framework' },
            { :name => 'TestVendored.framework',
              :input_path => '${PODS_ROOT}/Vendored/TestVendored.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/TestVendored.framework' },
        ]
      end

      it 'excludes framework paths from test specifications when not requested' do
        fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/Vendored.framework')])
        fa.stubs(:spec).returns(stub(:test_specification? => false))
        test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        test_fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/TestVendored.framework')])
        test_fa.stubs(:spec).returns(stub(:test_specification? => true))
        @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
        @test_pod_target.stubs(:should_build?).returns(true)
        @test_pod_target.framework_paths(false).should == [
            { :name => 'Vendored.framework',
              :input_path => '${PODS_ROOT}/Vendored/Vendored.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Vendored.framework' },
        ]
      end

      it 'includes resource paths from test specifications' do
        config.sandbox.stubs(:project => stub(:path => Pathname.new('ProjectPath')))
        fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        fa.stubs(:resource_bundles).returns({})
        fa.stubs(:resources).returns([Pathname.new('Model.xcdatamodeld')])
        fa.stubs(:spec).returns(stub(:test_specification? => false))
        test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        test_fa.stubs(:resource_bundles).returns({})
        test_fa.stubs(:resources).returns([Pathname.new('TestModel.xcdatamodeld')])
        test_fa.stubs(:spec).returns(stub(:test_specification? => true))
        @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
        @test_pod_target.resource_paths.should == ['${PODS_ROOT}/Model.xcdatamodeld', '${PODS_ROOT}/TestModel.xcdatamodeld']
      end

      it 'excludes resource paths from test specifications when not requested' do
        config.sandbox.stubs(:project => stub(:path => Pathname.new('ProjectPath')))
        fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        fa.stubs(:resource_bundles).returns({})
        fa.stubs(:resources).returns([Pathname.new('Model.xcdatamodeld')])
        fa.stubs(:spec).returns(stub(:test_specification? => false))
        test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
        test_fa.stubs(:resource_bundles).returns({})
        test_fa.stubs(:resources).returns([Pathname.new('TestModel.xcdatamodeld')])
        test_fa.stubs(:spec).returns(stub(:test_specification? => true))
        @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
        @test_pod_target.resource_paths(false).should == ['${PODS_ROOT}/Model.xcdatamodeld']
      end
    end
  end
end
