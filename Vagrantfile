require './lib/vm_config'

vm_config = VmConfig.load 'config.yml'

Vagrant.require_plugin "vagrant-hostmanager"

Vagrant.configure("2") do |config|
  config.vm.box = "precise32"
  config.vm.box_url = "http://files.vagrantup.com/precise32.box"

  config.vm.hostname = vm_config['vm']['hostname']

  config.vm.network :private_network, ip: vm_config['vm']['ip']
  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--memory", vm_config['vm']['memory']]
    v.customize ["modifyvm", :id, "--name", config.vm.hostname]
  end

  # HostManager Config
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  host_aliases = ["phpmyadmin.#{config.vm.hostname}"]

  # vhost config
  vhosts = {}
  vm_config['vhosts'].each do |name, vhost|
    if vhost['server_aliases'].is_a? Array then
      host_aliases += vhost['server_aliases']
    end
    config.vm.synced_folder vhost['path'], vhost['vhost_root']
    # Delete params unrecognized by puppet
    vhost.delete 'path'
    vhost.delete 'vhost_root'
    vhost.delete 'root_dir'
    vhosts[name] = vhost
  end

  config.hostmanager.aliases = host_aliases
  config.vm.provision :hostmanager

  config.vm.provision :shell, :inline => 'echo "
deb http://nz.archive.ubuntu.com/ubuntu/ precise          main restricted universe multiverse
deb http://nz.archive.ubuntu.com/ubuntu/ precise-updates  main restricted universe multiverse
deb http://nz.archive.ubuntu.com/ubuntu/ precise-security main restricted universe multiverse
" > /etc/apt/sources.list'
  config.vm.provision :shell, :inline => "sudo apt-get update"

  config.vm.provision :shell, :inline => 'echo -e "mysql_root_password=root
controluser_password=awesome" > /etc/phpmyadmin.facts;'

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "manifests"
    puppet.module_path = "modules"
    puppet.options = ['--verbose']
    puppet.facter = {
      'git_config' => vm_config['git'].to_json,
      'vhosts' => vhosts.to_json,
      'timezone' => vm_config['vm']['timezone'],
    }
  end
end
