Vagrant.require_plugin "vagrant-hostmanager"

Vagrant.configure("2") do |config|
  config.vm.box = "precise32"
  config.vm.box_url = "http://files.vagrantup.com/precise32.box"

  config.vm.hostname = "satmed-php53.local"

  config.vm.network :private_network, ip: "172.23.42.10"
  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--memory", 1024]
    v.customize ["modifyvm", :id, "--name", config.vm.hostname]
  end

  config.vm.synced_folder "./", "/var/www", id: "vagrant-root"

  # HostManager Config
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.aliases = ["phpmyadmin.#{config.vm.hostname}"]

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
  end
end
