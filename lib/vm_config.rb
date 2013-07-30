class VmConfig
  # Default config values
  DEFAULTS = {
    'vm' => {
      'ip' => '172.23.42.10',
      'hostname' => 'vagrant-lamp.local',
      'memory' => 1024,
    },
    'git' => {
      'ui.color' => 'auto',
    },
    'vhosts' => {},
  }

  class << self
    def load (config_file)
      vm_config = DEFAULTS.clone

      # Merge
      if File.exists? config_file then
        custom_config = YAML.load_file config_file
        vm_config.keys.each do |key|
          vm_config[key].merge! custom_config[key] if custom_config.key? key
        end
      end

      # Some checks
      raise "Hostname must be a fully qualified domain name." unless vm_config['vm']['hostname'].include? ?.

      # git stuff
      git_config = {}
      vm_config['git'].each do |key, value|
        git_config[key] = { 'value' => value }
      end
      vm_config['git'] = git_config

      # vhost stuff
      priority = 1
      vm_config['vhosts'].each_key do |i|
        raise "Path is required for a vhost." unless vm_config['vhosts'][i].key? "path"
        raise "Server aliases must be an array." if vm_config['vhosts'][i].key? 'server_aliases' and !vm_config['vhosts'][i]['server_aliases'].is_a? Array
        raise "Environment variables must be an array." if vm_config['vhosts'][i].key? 'env_variables' and !vm_config['vhosts'][i]['env_variables'].is_a? Array

        vm_config['vhosts'][i]['root_dir'] ||= ''
        vm_config['vhosts'][i]['priority'] ||= '%03d' % priority
        vm_config['vhosts'][i]['path'] = File.expand_path vm_config['vhosts'][i]['path']

        vm_config['vhosts'][i]['vhost_root'] = '/var/www/' + i
        vm_config['vhosts'][i]['docroot'] = vm_config['vhosts'][i]['vhost_root'] + vm_config['vhosts'][i]['root_dir']

        priority += 1
      end

      return vm_config
    end
  end
end
