module Pod
  module Xcode
    # A class that makes it easy to deal with frameworks, paths and files associated with them.
    #
    class FrameworkPaths
      # @return [Sandbox] The sandbox of the current project
      #
      attr_reader :sandbox

      # @return [String, Pathname] the path to the .framework
      #
      attr_reader :framework_path

      def initialize(sandbox, framework_path)
        @sandbox = sandbox
        @framework_path = Pathname.new(framework_path).tap do |p|
          raise 'Absolute path is required' unless p.absolute?
        end
      end

      def ==(other)
        return false if other.class != self.class
        other.framework_path == framework_path && other.dsym_path == dsym_path && other.bcsymbolmap_paths == bcsymbolmap_paths
      end

      alias eql? ==

      def hash
        [framework_path, dsym_path, bcsymbolmap_paths].hash
      end

      def all_paths
        [framework_path, dsym_path, bcsymbolmap_paths].flatten.compact
      end

      def all_relative_paths
        [relative_bcsymbolmap_paths_from_sandbox, relative_dsym_path_from_sandbox, relative_bcsymbolmap_paths_from_sandbox].flatten.compact
      end

      def dsym_path
        # Until this can be configured, assume the dSYM file uses the file name as the framework.
        # See https://github.com/CocoaPods/CocoaPods/issues/1698
        @dsym_path ||= begin
                         dsym_name = "#{framework_path.basename}.dSYM"
                         Pathname.new("#{framework_path.dirname}/#{dsym_name}")
                       end
      end

      def bcsymbolmap_paths
        @bcsymbolmap_paths ||= Pathname.glob(framework_path.dirname + '*.bcsymbolmap')
      end

      def relative_framework_path_from_sandbox
        "${PODS_ROOT}/#{framework_path.relative_path_from(sandbox.root)}"
      end

      def relative_dsym_path_from_sandbox
        "#{relative_framework_path_from_sandbox}.dSYM"
      end

      def relative_bcsymbolmap_paths_from_sandbox
        bcsymbolmap_paths.map { |bcsymbolmap_path| "${PODS_ROOT}/#{bcsymbolmap_path.relative_path_from(sandbox.root)}" }
      end
    end
  end
end
