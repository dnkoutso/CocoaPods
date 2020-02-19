require File.expand_path('../../../spec_helper', __FILE__)
require 'cocoapods/xcode/framework_paths'

module Pod
  module Xcode
    describe FrameworkPaths do
      before do
        @banana_framework_path = fixture('banana-lib/BananaFramework.framework')
        @monkey_framework_path = fixture('monkey/dynamic-monkey.framework')
      end

      describe '#==' do
        it 'compares equal framework paths as equal' do
          framework_paths0 = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths1 = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths0.should == framework_paths1
        end

        it 'compares unequal framework paths as unequal' do
          framework_paths0 = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths1 = FrameworkPaths.new(config.sandbox, @monkey_framework_path)
          framework_paths0.should != framework_paths1
        end

        it 'compares unequal classes as unequal' do
          framework_paths0 = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths0.should != 'String'
        end
      end

      describe '#relative_framework_path_from_sandbox' do
        it 'returns the relative framework path from sandbox' do
          framework_paths = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths.relative_framework_path_from_sandbox.should == '${PODS_ROOT}/../../spec/fixtures/banana-lib/BananaFramework.framework'
        end
      end

      describe '#dsym_path' do
        it 'returns the dsym path' do
          framework_paths = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths.dsym_path.to_s.should == "#{@banana_framework_path}.dSYM"
        end
      end

      describe '#relative_dsym_path_from_sandbox' do
        it 'returns the relative dSYM path from sandbox' do
          framework_paths = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths.relative_dsym_path_from_sandbox.should == '${PODS_ROOT}/../../spec/fixtures/banana-lib/BananaFramework.framework.dSYM'
        end
      end

      describe '#all_paths' do
        it 'returns all paths' do
          framework_paths = FrameworkPaths.new(config.sandbox, @banana_framework_path)
          framework_paths.all_paths.map(&:to_s).should == [
            @banana_framework_path.to_s,
            "#{@banana_framework_path}.dSYM",
          ]
        end
      end
    end
  end
end
