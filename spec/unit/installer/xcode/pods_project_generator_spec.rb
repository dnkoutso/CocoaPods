require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      describe PodsProjectGenerator do
        # @return [Lockfile]
        #
        def generate_lockfile(lockfile_version: Pod::VERSION)
          hash = {}
          hash['PODS'] = []
          hash['DEPENDENCIES'] = []
          hash['SPEC CHECKSUMS'] = {}
          hash['COCOAPODS'] = lockfile_version
          Pod::Lockfile.new(hash)
        end

        # @return [Podfile]
        #
        def generate_podfile(pods = ['JSONKit'])
          Pod::Podfile.new do
            platform :ios
            project SpecHelper.create_sample_app_copy_from_fixture('SampleProject'), 'Test' => :debug, 'App Store' => :release
            target 'SampleProject' do
              pods.each { |name| pod name }
              target 'SampleProjectTests' do
                inherit! :search_paths
              end
            end
          end
        end

        # @return [Podfile]
        #
        def generate_local_podfile
          Pod::Podfile.new do
            platform :ios
            project SpecHelper.fixture('SampleProject/SampleProject'), 'Test' => :debug, 'App Store' => :release
            target 'SampleProject' do
              pod 'Reachability', :path => SpecHelper.fixture('integration/Reachability')
              target 'SampleProjectTests' do
                inherit! :search_paths
              end
            end
          end
        end

        describe 'Generating Pods Project' do
          before do
            podfile = generate_podfile
            lockfile = generate_lockfile
            @installer = Pod::Installer.new(config.sandbox, podfile, lockfile)
            @installer.send(:prepare)
            @installer.send(:analyze)
            @generator = @installer.send(:create_generator)
          end

          describe '#prepare' do
            before do
              @project = @generator.send(:prepare)
            end

            it "creates build configurations for all of the user's targets" do
              @project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
            end

            it 'sets STRIP_INSTALLED_PRODUCT to NO for all configurations for the whole project' do
              @project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              @project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              @project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              @project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            end

            it 'sets the SYMROOT to the default value for all configurations for the whole project' do
              @project.build_settings('Debug')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              @project.build_settings('Test')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              @project.build_settings('Release')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              @project.build_settings('App Store')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            end

            it 'creates the Pods project' do
              project = @generator.send(:prepare)
              project.class.should == Pod::Project
            end

            it 'preserves Pod paths specified as absolute or rooted to home' do
              local_podfile = generate_local_podfile
              local_installer = Pod::Installer.new(config.sandbox, local_podfile)
              local_installer.send(:analyze)
              local_generator = local_installer.send(:create_generator)
              project = local_generator.send(:prepare)
              group = project.group_for_spec('Reachability')
              Pathname.new(group.path).should.be.absolute
            end

            it 'adds the Podfile to the Pods project' do
              @generator.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
              project = @generator.send(:prepare)
              project['Podfile'].should.be.not.nil
            end

            it 'sets the deployment target for the whole project' do
              target_definition_osx = fixture_target_definition('OSX Target', Platform.new(:osx, '10.8'))
              target_definition_ios = fixture_target_definition('iOS Target', Platform.new(:ios, '6.0'))
              aggregate_target_osx = AggregateTarget.new(config.sandbox, false, {}, [], target_definition_osx, config.sandbox.root.dirname, nil, nil, [])
              aggregate_target_ios = AggregateTarget.new(config.sandbox, false, {}, [], target_definition_ios, config.sandbox.root.dirname, nil, nil, [])
              @generator.stubs(:aggregate_targets).returns([aggregate_target_osx, aggregate_target_ios])
              @generator.stubs(:pod_targets).returns([])
              project = @generator.send(:prepare)
              build_settings = project.build_configurations.map(&:build_settings)
              build_settings.each do |build_setting|
                build_setting['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
                build_setting['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
              end
            end
          end

          #-------------------------------------#

          describe '#install_file_references' do
            it 'installs the file references' do
              @generator.stubs(:pod_targets).returns([])
              PodsProjectGenerator::FileReferencesInstaller.any_instance.expects(:install!)
              @generator.generate
            end
          end

          #-------------------------------------#

          describe '#install_libraries' do
            it 'install the targets of the Pod project' do
              spec = fixture_spec('banana-lib/BananaLib.podspec')
              target_definition = Podfile::TargetDefinition.new(:default, nil)
              target_definition.set_platform(:ios, '8.0')
              target_definition.abstract = false
              target_definition.store_pod('BananaLib')
              pod_target = PodTarget.new(config.sandbox, false, {}, [], [spec], [target_definition], nil)
              @generator.stubs(:aggregate_targets).returns([])
              @generator.stubs(:pod_targets).returns([pod_target])
              PodsProjectGenerator::PodTargetInstaller.any_instance.expects(:install!)
              @generator.send(:install_libraries)
            end

            it 'does not skip empty pod targets' do
              spec = fixture_spec('banana-lib/BananaLib.podspec')
              target_definition = Podfile::TargetDefinition.new(:default, nil)
              target_definition.set_platform(:ios, '8.0')
              target_definition.abstract = false
              pod_target = PodTarget.new(config.sandbox, false, {}, [], [spec], [target_definition], nil)
              @generator.stubs(:aggregate_targets).returns([])
              @generator.stubs(:pod_targets).returns([pod_target])
              PodsProjectGenerator::PodTargetInstaller.any_instance.expects(:install!).once
              @generator.send(:install_libraries)
            end

            it 'adds the frameworks required by the pod to the project for informative purposes' do
              Specification::Consumer.any_instance.stubs(:frameworks).returns(['QuartzCore'])
              @installer.send(:install!)
              names = @installer.pods_project['Frameworks']['iOS'].children.map(&:name)
              names.sort.should == ['Foundation.framework', 'QuartzCore.framework']
            end
          end

          #-------------------------------------#

          describe '#set_target_dependencies' do
            def test_extension_target(symbol_type)
              mock_user_target = mock('usertarget', :symbol_type => symbol_type)
              @target.stubs(:user_targets).returns([mock_user_target])

              build_settings = {}
              mock_configuration = mock('buildconfiguration', :build_settings => build_settings)
              @mock_target.stubs(:build_configurations).returns([mock_configuration])

              @generator.send(:set_target_dependencies, @mock_project)

              build_settings.should == { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
            end

            before do
              spec = fixture_spec('banana-lib/BananaLib.podspec')

              target_definition = Podfile::TargetDefinition.new(:default, @installer.podfile.root_target_definitions.first)
              @pod_target = PodTarget.new(config.sandbox, false, {}, [], [spec], [target_definition], nil)
              @target = AggregateTarget.new(config.sandbox, false, {}, [], target_definition, config.sandbox.root.dirname, nil, nil, [])

              @mock_target = mock('PodNativeTarget')

              @mock_project = mock('PodsProject', :frameworks_group => mock('FrameworksGroup'))
              @generator.stubs(:generate).returns(@mock_project)

              @target.stubs(:native_target).returns(@mock_target)
              @target.stubs(:pod_targets).returns([@pod_target])
              @generator.stubs(:aggregate_targets).returns([@target])
            end

            it 'sets resource bundles for not build pods as target dependencies of the user target' do
              @pod_target.stubs(:resource_bundle_targets).returns(['dummy'])
              @pod_target.stubs(:should_build? => false)
              @mock_target.expects(:add_dependency).with('dummy')

              @generator.send(:set_target_dependencies, @mock_project)
            end

            it 'configures APPLICATION_EXTENSION_API_ONLY for app extension targets' do
              test_extension_target(:app_extension)
            end

            it 'configures APPLICATION_EXTENSION_API_ONLY for watch extension targets' do
              test_extension_target(:watch_extension)
            end

            it 'configures APPLICATION_EXTENSION_API_ONLY for watchOS 2 extension targets' do
              test_extension_target(:watch2_extension)
            end

            it 'configures APPLICATION_EXTENSION_API_ONLY for tvOS extension targets' do
              test_extension_target(:tv_extension)
            end

            it 'configures APPLICATION_EXTENSION_API_ONLY for Messages extension targets' do
              test_extension_target(:messages_extension)
            end

            it 'configures APPLICATION_EXTENSION_API_ONLY for targets where the user target has it set' do
              mock_user_target = mock('UserTarget', :symbol_type => :application)
              mock_user_target.expects(:common_resolved_build_setting).with('APPLICATION_EXTENSION_API_ONLY').returns('YES')
              @target.stubs(:user_targets).returns([mock_user_target])

              build_settings = {}
              mock_configuration = mock('BuildConfiguration', :build_settings => build_settings)
              @mock_target.stubs(:build_configurations).returns([mock_configuration])

              @generator.send(:set_target_dependencies, @mock_project)

              build_settings.should == { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
            end

            it 'does not try to set APPLICATION_EXTENSION_API_ONLY if there are no pod targets' do
              lambda do
                mock_user_target = mock('UserTarget', :symbol_type => :app_extension)
                @target.stubs(:user_targets).returns([mock_user_target])

                @target.stubs(:native_target).returns(nil)
                @target.stubs(:pod_targets).returns([])

                @generator.send(:set_target_dependencies, @mock_project)
              end.should.not.raise NoMethodError
            end
          end

          #--------------------------------------#

          describe '#set_test_target_dependencies' do
            before do
              spec = fixture_spec('coconut-lib/CoconutLib.podspec')

              target_definition = Podfile::TargetDefinition.new(:default, @installer.podfile.root_target_definitions.first)
              @pod_target = PodTarget.new(config.sandbox, false, {}, [], [spec, *spec.recursive_subspecs], [target_definition], nil)
              @target = AggregateTarget.new(config.sandbox, false, {}, [], target_definition, config.sandbox.root.dirname, nil, nil, [])

              @mock_target = mock('PodNativeTarget')

              @mock_project = mock('PodsProject', :frameworks_group => mock('FrameworksGroup'))
              @generator.stubs(:generate).returns(@mock_project)

              @target.stubs(:native_target).returns(@mock_target)
              @target.stubs(:pod_targets).returns([@pod_target])
              @generator.stubs(:aggregate_targets).returns([@target])
            end

            it 'adds all test dependent targets to test native targets' do
              mock_native_target = mock('CoconutLib')
              mock_test_native_target = mock('CoconutLib-Unit-Tests', :symbol_type => :unit_test_bundle)

              dependent_native_target = mock('DependentNativeTarget')
              test_dependent_native_target = mock('TestDependentNativeTarget')

              dependent_target = mock('dependent-target', :dependent_targets => [])
              dependent_target.stubs(:should_build?).returns(true)
              dependent_target.stubs(:native_target).returns(dependent_native_target)
              test_dependent_target = mock('dependent-test-target', :native_target => test_dependent_native_target, :test_dependent_targets => [])
              test_dependent_target.stubs(:should_build?).returns(true)

              @pod_target.stubs(:native_target).returns(mock_native_target)
              @pod_target.stubs(:test_native_targets).returns([mock_test_native_target])
              @pod_target.stubs(:dependent_targets).returns([dependent_target])
              @pod_target.stubs(:test_dependent_targets).returns([test_dependent_target])
              @pod_target.stubs(:should_build? => true)
              @mock_target.expects(:add_dependency).with(mock_native_target)

              mock_native_target.expects(:add_dependency).with(dependent_native_target)
              mock_native_target.expects(:add_dependency).with(test_dependent_native_target).never
              mock_native_target.expects(:add_dependency).with(mock_native_target).never

              mock_test_native_target.expects(:add_dependency).with(dependent_native_target)
              mock_test_native_target.expects(:add_dependency).with(test_dependent_native_target)
              mock_test_native_target.expects(:add_dependency).with(mock_native_target)

              @generator.send(:set_target_dependencies, @mock_project)
            end

            it 'adds all test dependent targets to test native targets for static frameworks' do
              mock_native_target = mock('CoconutLib')
              dependent_native_target = mock('DependentNativeTarget')

              dependent_target = mock('dependent-target')
              dependent_target.stubs(:should_build?).returns(true)
              dependent_target.stubs(:native_target).returns(dependent_native_target)

              @pod_target.stubs(:native_target).returns(mock_native_target)
              @pod_target.stubs(:dependent_targets).returns([dependent_target])
              @pod_target.stubs(:should_build? => true)
              @pod_target.stubs(:static_framework? => true)
              @mock_target.expects(:add_dependency).with(mock_native_target)

              mock_native_target.expects(:add_dependency).with(dependent_native_target)
              mock_native_target.expects(:add_dependency).with(mock_native_target).never

              @generator.send(:set_target_dependencies, @mock_project)
            end

            it 'adds dependencies to pod targets that are not part of any aggregate target' do
              @target.stubs(:pod_targets).returns([])
              @generator.expects(:pod_targets).returns([@pod_target])
              mock_native_target = mock('CoconutLib')
              mock_test_native_target = mock('CoconutLib-Unit-Tests', :symbol_type => :unit_test_bundle)

              dependent_native_target = mock('DependentNativeTarget')
              dependent_target = mock('dependent-target', :dependent_targets => [])
              dependent_target.stubs(:should_build?).returns(true)
              dependent_target.stubs(:native_target).returns(dependent_native_target)

              @pod_target.stubs(:native_target).returns(mock_native_target)
              @pod_target.stubs(:test_native_targets).returns([mock_test_native_target])
              @pod_target.stubs(:dependent_targets).returns([dependent_target])
              @pod_target.stubs(:test_dependent_targets).returns([])
              @pod_target.stubs(:should_build? => true)

              mock_native_target.expects(:add_dependency).with(dependent_native_target)
              mock_test_native_target.expects(:add_dependency).with(dependent_native_target)
              mock_test_native_target.expects(:add_dependency).with(mock_native_target)

              @generator.send(:set_target_dependencies, @mock_project)
            end

            it 'adds test dependencies to test native targets for a pod target that should not be built' do
              mock_test_native_target = mock('CoconutLib-Unit-Tests', :symbol_type => :unit_test_bundle)
              test_dependent_native_target = mock('TestDependentNativeTarget')
              test_dependent_target = mock('dependent-test-target', :should_build? => true, :native_target => test_dependent_native_target)
              test_dependent_target.expects(:should_build?).returns(true)

              @pod_target.stubs(:test_native_targets).returns([mock_test_native_target])
              @pod_target.stubs(:all_dependent_targets).returns([test_dependent_target])
              @pod_target.stubs(:should_build? => false)

              mock_test_native_target.expects(:add_dependency).with(test_dependent_native_target)

              @generator.send(:set_target_dependencies, @mock_project)
            end

            it 'sets resource bundles for not build pods as target dependencies of the test target' do
              mock_test_native_target = mock('CoconutLib-Unit-Tests', :symbol_type => :unit_test_bundle)

              @pod_target.stubs(:test_native_targets).returns([mock_test_native_target])
              @pod_target.stubs(:test_dependent_targets).returns([])
              @pod_target.stubs(:should_build? => false)
              @pod_target.stubs(:resource_bundle_targets).returns(['dummy'])

              @mock_target.expects(:add_dependency).with('dummy')
              mock_test_native_target.expects(:add_dependency).with('dummy')

              @generator.send(:set_target_dependencies, @mock_project)
            end

            it 'sets the app host dependency target to the test native target if test spec requires app host' do
              mock_app_host_target = mock(:name => 'AppHost-iOS-Unit-Tests')
              @mock_project.stubs(:targets).returns([mock_app_host_target])

              mock_test_native_target = mock('CoconutLib-Unit-Tests', :symbol_type => :unit_test_bundle)
              test_dependent_native_target = mock('TestDependentNativeTarget')
              test_dependent_target = mock('dependent-test-target', :should_build? => true, :native_target => test_dependent_native_target)
              test_dependent_target.expects(:should_build?).returns(true)

              @pod_target.test_specs.first.requires_app_host = true
              @pod_target.stubs(:test_native_targets).returns([mock_test_native_target])
              @pod_target.stubs(:all_dependent_targets).returns([test_dependent_target])
              @pod_target.stubs(:should_build? => false)

              mock_test_native_target.expects(:add_dependency).with(test_dependent_native_target)
              mock_test_native_target.expects(:add_dependency).with(mock_app_host_target)

              @generator.send(:set_target_dependencies, @mock_project)
            end
          end
        end
      end
    end
  end
end
