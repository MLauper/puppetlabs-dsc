require 'erb'
require 'dsc_utils'
test_name 'MODULES-2230 - C88970 - Apply DSC Registry Resource with "Force" Enabled'

confine(:to, :platform => 'windows')

# Init
local_files_root_path = ENV['MANIFESTS'] || 'tests/manifests'

# ERB Manifest
dsc_type = 'registry'
dsc_props = {
  :dsc_ensure    => 'Present',
  :dsc_key       => 'HKEY_LOCAL_MACHINE\SOFTWARE\TestKey',
  :dsc_valuename => 'TestForceValue',
  :dsc_valuedata => 'Gif Party!',
  :dsc_valuetype => 'String'
}

dsc_manifest_template_path = File.join(local_files_root_path, 'basic_dsc_resources', 'dsc_single_resource.pp.erb')
dsc_manifest = ERB.new(File.read(dsc_manifest_template_path), 0, '>').result(binding)

# Teardown
teardown do
  step 'Remove Test Artifacts'
  set_dsc_resource(
    agents,
    dsc_type,
    :Ensure    => 'Absent',
    :Key       => dsc_props[:dsc_key],
    :ValueName => dsc_props[:dsc_valuename]
  )
end

# Tests
agents.each do |agent|
  step 'Apply Manifest to Create Value'
  on(agent, puppet('apply'), :stdin => dsc_manifest, :acceptable_exit_codes => [0,2]) do |result|
    assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
  end

  # New manifest to force value.
  dsc_props[:dsc_force] = 'true'
  dsc_props[:dsc_valuedata] = 'Meow Police!'
  dsc_force_manifest = ERB.new(File.read(dsc_manifest_template_path), 0, '>').result(binding)

  step 'Apply Manifest Again with Force Enabled'
  on(agent, puppet('apply'), :stdin => dsc_force_manifest, :acceptable_exit_codes => [0,2]) do |result|
    assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
  end

  step 'Verify Results'
  assert_dsc_resource(
    agent,
    dsc_type,
    :Ensure    => dsc_props[:dsc_ensure],
    :Key       => dsc_props[:dsc_key],
    :ValueName => dsc_props[:dsc_valuename],
    :ValueData => "@(\"#{dsc_props[:dsc_valuedata]}\")",
    :ValueType => dsc_props[:dsc_valuetype],
    :Force     => "$#{dsc_props[:dsc_force]}"
  )
end
