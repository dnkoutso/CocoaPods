require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe XCConfigHelper do
        before do
          @sut = XCConfigHelper
        end

        #---------------------------------------------------------------------#

        describe '::default_ld_flags' do
          it 'returns the default linker flags' do
            podfile = stub(:set_arc_compatibility_flag? => false)
            target = stub(:podfile => podfile)
            result = @sut.default_ld_flags(target)
            result.should == ''

            result = @sut.default_ld_flags(target, true)
            result.should == '-ObjC'
          end

          it 'includes the ARC compatibility flag if required by the Podfile' do
            podfile = stub(:set_arc_compatibility_flag? => true)
            spec_consumer = stub(:requires_arc? => true)
            target = stub(:podfile => podfile, :spec_consumers => [spec_consumer])
            result = @sut.default_ld_flags(target)
            result.should == '-fobjc-arc'

            result = @sut.default_ld_flags(target, true)
            result.should == '-ObjC -fobjc-arc'
          end
        end

        #---------------------------------------------------------------------#

        describe '::quote' do
          it 'quotes strings' do
            result = @sut.quote(%w(string1 string2))
            result.should == '"string1" "string2"'
          end

          it 'inserts an optional string and then the normal quoted string' do
            result = @sut.quote(%w(string1 string2), '-isystem')
            result.should == '-isystem "string1" -isystem "string2"'
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_spec_build_settings_to_xcconfig' do
          it 'adds the libraries of the xcconfig' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => ['xml2'],
              :frameworks => [],
              :weak_frameworks => [],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-l"xml2"'
          end

          it 'check that subspec subsets are removed from frameworks search paths' do
            target1 = stub(
              :specs => %w(A, B),
              :should_build? => true,
              :requires_frameworks? => true,
              :configuration_build_dir => 'AB',
            )
            target2 = stub(
              :specs => ['B'],
              :should_build? => true,
              :requires_frameworks? => true,
              :configuration_build_dir => 'B',
            )
            dependent_targets = [target1, target2]
            build_settings = @sut.settings_for_dependent_targets(nil, dependent_targets)
            build_settings['FRAMEWORK_SEARCH_PATHS'].should == '"AB"'
          end

          it 'adds the frameworks of the xcconfig' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => ['CoreAnimation'],
              :weak_frameworks => [],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-framework "CoreAnimation"'
          end

          it 'adds the weak frameworks of the xcconfig' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => [],
              :weak_frameworks => ['iAd'],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-weak_framework "iAd"'
          end

          it 'adds the ios developer frameworks search paths if needed' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => ['SenTestingKit'],
              :weak_frameworks => [],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('SDKROOT')
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('DEVELOPER_LIBRARY_DIR')
          end

          it 'adds the osx developer frameworks search paths if needed' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => ['SenTestingKit'],
              :weak_frameworks => [],
              :platform_name => :osx,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('DEVELOPER_LIBRARY_DIR')
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('SDKROOT')
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_framework_build_settings' do
          it 'adds the build settings of a framework to the given xcconfig' do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == '-framework "Parse"'
            hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"${PODS_ROOT}/Parse"'
          end

          it "doesn't override existing linker flags" do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework CoreAnimation')
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == '-framework "CoreAnimation" -framework "Parse"'
          end

          it "doesn't override existing frameworks search paths" do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new('FRAMEWORK_SEARCH_PATHS' => '"path/to/frameworks"')
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"path/to/frameworks" "${PODS_ROOT}/Parse"'
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_library_build_settings' do
          it 'adds the build settings of a framework to the given xcconfig' do
            path = config.sandbox.root + 'MapBox/Proj4/libProj4.a'
            xcconfig = Xcodeproj::Config.new
            @sut.add_library_build_settings(path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == '-l"Proj4"'
            hash_config['LIBRARY_SEARCH_PATHS'].should == '"${PODS_ROOT}/MapBox/Proj4"'
          end

          it 'adds dylib build settings to the given xcconfig' do
            path = config.sandbox.root + 'MapBox/Proj4/libProj4.dylib'
            xcconfig = Xcodeproj::Config.new
            @sut.add_library_build_settings(path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == '-l"Proj4"'
            hash_config['LIBRARY_SEARCH_PATHS'].should == '"${PODS_ROOT}/MapBox/Proj4"'
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_developers_frameworks_if_needed' do
          it 'adds the developer frameworks search paths to the xcconfig if SenTestingKit has been detected' do
            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework SenTestingKit')
            @sut.add_developers_frameworks_if_needed(xcconfig)
            frameworks_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            frameworks_search_paths.should.include?('$(inherited)')
            frameworks_search_paths.should.not.include?('"$(SDKROOT)/Developer/Library/Frameworks"')
            frameworks_search_paths.should.not.include?('"$(DEVELOPER_LIBRARY_DIR)/Frameworks"')
          end

          it 'adds the developer frameworks search paths to the xcconfig if XCTest has been detected' do
            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework XCTest')
            @sut.add_developers_frameworks_if_needed(xcconfig)
            frameworks_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            frameworks_search_paths.should.include?('$(inherited)')
            frameworks_search_paths.should.not.include?('"$(SDKROOT)/Developer/Library/Frameworks"')
            frameworks_path = '"$(PLATFORM_DIR)/Developer/Library/Frameworks"'
            frameworks_search_paths.should.include?(frameworks_path)
            frameworks_search_paths.should.not.include?('"$(DEVELOPER_LIBRARY_DIR)/Frameworks"')
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_language_specific_settings' do
          it 'does not add OTHER_SWIFT_FLAGS to the xcconfig if the target does not use swift' do
            target = stub(:uses_swift? => false)
            xcconfig = Xcodeproj::Config.new
            @sut.add_language_specific_settings(target, xcconfig)
            other_swift_flags = xcconfig.to_hash['OTHER_SWIFT_FLAGS']
            other_swift_flags.should.nil?
          end

          it 'does not add the -suppress-warnings flag to the xcconfig if the target uses swift, but does not inhibit warnings' do
            target = stub(:uses_swift? => true, :inhibit_warnings? => false)
            xcconfig = Xcodeproj::Config.new
            @sut.add_language_specific_settings(target, xcconfig)
            other_swift_flags = xcconfig.to_hash['OTHER_SWIFT_FLAGS']
            other_swift_flags.should.not.include?('-suppress-warnings')
          end

          it 'adds the -suppress-warnings flag to the xcconfig if the target uses swift and inhibits warnings' do
            target = stub(:uses_swift? => true, :inhibit_warnings? => true)
            xcconfig = Xcodeproj::Config.new
            @sut.add_language_specific_settings(target, xcconfig)
            other_swift_flags = xcconfig.to_hash['OTHER_SWIFT_FLAGS']
            other_swift_flags.should.include?('-suppress-warnings')
          end
        end

        #---------------------------------------------------------------------#

        describe 'concerning settings for file accessors' do
          it 'does not propagate framework or libraries from a test specification to an aggregate target' do
            spec = stub(:test_specification? => true)
            consumer = stub(
              :libraries => ['xml2'],
              :frameworks => ['XCTest'],
              :weak_frameworks => [],
              :spec => spec,
            )
            file_accessor = stub(
              :spec => spec,
              :spec_consumer => consumer,
              :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
              :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
              :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
              :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
            )
            pod_target = stub(
              :file_accessors => [file_accessor],
              :requires_frameworks? => true,
              :dependent_targets => [],
              :sandbox => config.sandbox,
            )
            target_definition = stub(:inheritance => 'complete')
            aggregate_target = stub(:target_definition => target_definition)
            xcconfig = Xcodeproj::Config.new
            @sut.add_settings_for_file_accessors_of_target(aggregate_target, pod_target, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should.be.nil
          end

          it 'does propagate framework or libraries from a non test specification to an aggregate target' do
            spec = stub(:test_specification? => false)
            consumer = stub(
              :libraries => ['xml2'],
              :frameworks => ['XCTest'],
              :weak_frameworks => [],
              :spec => spec,
            )
            file_accessor = stub(
              :spec => spec,
              :spec_consumer => consumer,
              :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
              :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
              :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
              :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
            )
            pod_target = stub(
              :file_accessors => [file_accessor],
              :requires_frameworks? => true,
              :dependent_targets => [],
              :sandbox => config.sandbox,
            )
            target_definition = stub(:inheritance => 'complete')
            aggregate_target = stub(:target_definition => target_definition)
            xcconfig = Xcodeproj::Config.new
            @sut.add_settings_for_file_accessors_of_target(aggregate_target, pod_target, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should.be == '-l"StaticLibrary" -l"VendoredDyld" -l"xml2" -framework "StaticFramework" -framework "VendoredFramework" -framework "XCTest"'
          end

          it 'does propagate framework or libraries to a nil aggregate target' do
            spec = stub(:test_specification? => false)
            consumer = stub(
              :libraries => ['xml2'],
              :frameworks => ['XCTest'],
              :weak_frameworks => [],
              :spec => spec,
            )
            file_accessor = stub(
              :spec => spec,
              :spec_consumer => consumer,
              :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
              :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
              :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
              :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
            )
            pod_target = stub(
              :file_accessors => [file_accessor],
              :requires_frameworks? => true,
              :dependent_targets => [],
              :sandbox => config.sandbox,
            )
            xcconfig = Xcodeproj::Config.new
            @sut.add_settings_for_file_accessors_of_target(nil, pod_target, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should.be == '-l"StaticLibrary" -l"VendoredDyld" -l"xml2" -framework "StaticFramework" -framework "VendoredFramework" -framework "XCTest"'
          end
        end

        describe 'for proper other ld flags' do
          before do
            @root = fixture('banana-lib')
            @path_list = Sandbox::PathList.new(@root)
            @spec = fixture_spec('banana-lib/BananaLib.podspec')
            @spec_consumer = @spec.consumer(:ios)
            @accessor = Pod::Sandbox::FileAccessor.new(@path_list, @spec_consumer)
          end

          it 'should not include static framework other ld flags when inheriting search paths' do
            target_definition = stub(:inheritance => 'search_paths')
            aggregate_target = stub(:target_definition => target_definition, :pod_targets => [], :search_paths_aggregate_targets => [])
            pod_target = stub(:sandbox => config.sandbox)
            xcconfig = Xcodeproj::Config.new
            @sut.add_static_dependency_build_settings(aggregate_target, pod_target, xcconfig, @accessor)
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['OTHER_LDFLAGS'].should.be.nil
          end

          it 'should include static framework other ld flags when inheriting search paths but explicitly declared' do
            target_definition = stub(:inheritance => 'search_paths')
            pod_target = stub(:name => 'BananaLib', :sandbox => config.sandbox)
            aggregate_target = stub(:target_definition => target_definition, :pod_targets => [pod_target], :search_paths_aggregate_targets => [])
            xcconfig = Xcodeproj::Config.new
            @sut.add_static_dependency_build_settings(aggregate_target, pod_target, xcconfig, @accessor)
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-l"Bananalib" -framework "Bananalib"'
          end

          it 'should include static framework other ld flags when not inheriting search paths' do
            target_definition = stub(:inheritance => 'complete')
            aggregate_target = stub(:target_definition => target_definition)
            pod_target = stub(:sandbox => config.sandbox)
            xcconfig = Xcodeproj::Config.new
            @sut.add_static_dependency_build_settings(aggregate_target, pod_target, xcconfig, @accessor)
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-l"Bananalib" -framework "Bananalib"'
          end

          it 'should include static framework for pod targets' do
            pod_target = stub(:sandbox => config.sandbox)
            xcconfig = Xcodeproj::Config.new
            @sut.add_static_dependency_build_settings(nil, pod_target, xcconfig, @accessor)
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '"${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-l"Bananalib" -framework "Bananalib"'
          end

          it 'should link static dependency for pod targets' do
            pod_target = stub(:name => 'BananaLib', :sandbox => config.sandbox)
            @sut.links_dependency?(nil, pod_target).should.be.true
          end

          it 'should link static dependency when target explicitly specifies it' do
            target_definition = stub(:inheritance => 'complete')
            pod_target = stub(:name => 'BananaLib', :sandbox => config.sandbox)
            aggregate_target = stub(:target_definition => target_definition, :pod_targets => [pod_target], :search_paths_aggregate_targets => [])
            @sut.links_dependency?(aggregate_target, pod_target).should.be.true
          end

          it 'should link static dependency when target explicitly specifies it even with search paths' do
            target_definition = stub(:inheritance => 'search_paths')
            pod_target = stub(:name => 'BananaLib', :sandbox => config.sandbox)
            aggregate_target = stub(:target_definition => target_definition, :pod_targets => [pod_target], :search_paths_aggregate_targets => [])
            @sut.links_dependency?(aggregate_target, pod_target).should.be.true
          end

          it 'should not link static dependency when inheriting search paths and parent includes dependency' do
            parent_target_definition = stub
            child_target_definition = stub(:inheritance => 'search_paths')
            pod_target = stub(:name => 'BananaLib', :sandbox => config.sandbox)
            parent_aggregate_target = stub(:target_definition => parent_target_definition, :pod_targets => [pod_target], :search_paths_aggregate_targets => [])
            child_aggregate_target = stub(:target_definition => child_target_definition, :pod_targets => [], :search_paths_aggregate_targets => [parent_aggregate_target])
            @sut.links_dependency?(child_aggregate_target, pod_target).should.be.false
          end

          it 'should link static transitive dependencies if the parent does not link them' do
            child_pod_target = stub(:name => 'ChildPod', :sandbox => config.sandbox)
            parent_pod_target = stub(:name => 'ParentPod', :sandbox => config.sandbox, :dependent_targets => [child_pod_target])

            parent_target_definition = stub
            child_target_definition = stub(:inheritance => 'search_paths')

            parent_aggregate_target = stub(:target_definition => parent_target_definition, :pod_targets => [], :search_paths_aggregate_targets => [])
            child_aggregate_target = stub(:target_definition => child_target_definition, :pod_targets => [parent_pod_target, child_pod_target], :search_paths_aggregate_targets => [parent_aggregate_target])
            @sut.links_dependency?(child_aggregate_target, child_pod_target).should.be.true
            @sut.links_dependency?(child_aggregate_target, parent_pod_target).should.be.true
          end

          it 'should link static only transitive dependencies that the parent does not link' do
            child_pod_target = stub(:name => 'ChildPod', :sandbox => config.sandbox)
            parent_pod_target = stub(:name => 'ParentPod', :sandbox => config.sandbox, :dependent_targets => [child_pod_target])

            parent_target_definition = stub
            child_target_definition = stub(:inheritance => 'search_paths')

            parent_aggregate_target = stub(:target_definition => parent_target_definition, :pod_targets => [child_pod_target], :search_paths_aggregate_targets => [])
            child_aggregate_target = stub(:target_definition => child_target_definition, :pod_targets => [parent_pod_target, child_pod_target], :search_paths_aggregate_targets => [parent_aggregate_target])
            @sut.links_dependency?(child_aggregate_target, child_pod_target).should.be.false
            @sut.links_dependency?(child_aggregate_target, parent_pod_target).should.be.true
          end
        end

        #---------------------------------------------------------------------#
      end
    end
  end
end
