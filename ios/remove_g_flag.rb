# remove_g_flag.rb
module Pod
    class Installer
      class Xcode
        class Target
          alias_method :original_add_build_settings, :add_build_settings
          def add_build_settings(xcconfig, includes = nil)
            # Call the original method
            original_add_build_settings(xcconfig, includes)
            
            # Remove the -G flag from all build settings
            xcconfig.attributes.each do |key, value|
              if value.is_a?(String) && value.include?('-G')
                xcconfig.attributes[key] = value.gsub(/-G/, '')
              end
            end
          end
        end
      end
    end
  end