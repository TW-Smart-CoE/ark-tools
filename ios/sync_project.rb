

root_dir = "#{ARGV[0]}"

`cd #{root_dir}`

# Load gems in to LOAD_LIBRARY
`bundle install`
gems = `bundle show --paths`.split("\n")
gems.map { |d| d + "/lib/" }.each { |d| $:.unshift(d) }

require 'dotenv'
require 'xcodeproj'

# Load .env to ENV
Dotenv.load(root_dir + "/.env")

ark_projct = {
    :name => "ARK-iOS",
    :test => "ARK-iOSTests",
    :path => root_dir + "/ARK-iOS.xcodeproj"
}

target_project = {
    :name => ENV["KEY_PROJECT_NAME"],
    :test => ENV["KEY_PROJECT_NAME"] + "Tests",
    :path => root_dir + "/#{ ENV["KEY_PROJECT"] }"
}

# Rename project to target
`mv #{ark_projct[:path]} #{target_project[:path]}` 

# Get project
project = Xcodeproj::Project.open(target_project[:path])

# Rename targets
target = project.targets.select { |t| t.name == ark_projct[:name] }.first
target.name = target_project[:name]

test_target = project.targets.select { |t| t.name == ark_projct[:test] }.first
test_target.name = target_project[:test]
test_target.product_name = target_project[:test]
test_target.build_configuration_list.set_setting("PRODUCT_BUNDLE_IDENTIFIER", ENV["KEY_APP_IDENTIFIER"] + ".#{ENV["KEY_PROJECT_NAME"]}")

# Update schemes
schemes_dir = Xcodeproj::XCScheme.shared_data_dir(target_project[:path]).to_s

ark_scheme_path = schemes_dir + "/#{ark_projct[:name]}.xcscheme"
target_scheme = Xcodeproj::XCScheme.new(ark_scheme_path)
target_scheme.set_launch_target(target)
target_scheme.build_action.entries = [Xcodeproj::XCScheme::BuildAction::Entry.new(target)]
target_scheme.test_action.testables = [Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)]
target_scheme.save_as(target_project[:path], target_project[:name])

test_scheme_path = schemes_dir + "/All-Tests.xcscheme"
test_scheme = Xcodeproj::XCScheme.new(test_scheme_path)
test_scheme.set_launch_target(target)
test_scheme.build_action.entries = test_scheme.build_action.entries.select { |e|
    e.buildable_references.first.target_name != ark_projct[:name]
}
test_scheme.test_action.testables = test_scheme.test_action.testables.map { |t|
    if t.buildable_references.first.target_name == ark_projct[:test]
        Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
    else
        t
    end
}
test_scheme.test_action.code_coverage_targets = test_scheme.test_action.code_coverage_targets.map { |r|
    if r.target_name == ark_projct[:name]
        Xcodeproj::XCScheme::BuildableReference.new(target)
    else
        r
    end
}
test_scheme.save!

# Update groups
products_group = project.products_group

# puts products_group.recursive_children.class

products_group.recursive_children.each { |p|
    if p.is_a?(Xcodeproj::Project::Object::PBXFileReference) && p.display_name == "ARK-iOSTests.xctest"
        p.path = target_project[:test] + ".xctest"
    end
}

project['Pods'].clear
project.frameworks_group.clear

# Delete ARK-iOS scheme
File.delete(ark_scheme_path) if File.exist?(ark_scheme_path)

# Save project
project.save


