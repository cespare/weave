Vagrant::Config.run do |config|
  def apply_common_config_options(c)
    c.vm.box = "precise64"
    c.vm.box_url = "http://files.vagrantup.com/precise64.box"
    c.vm.provision :shell, :inline =>
        "sudo mkdir -p /root/.ssh && sudo cp /home/vagrant/.ssh/authorized_keys /root/.ssh/"
  end

  config.vm.define :weave1 do |config|
    config.vm.host_name = "weave1"
    config.vm.network :hostonly, "1.2.3.90"
    config.vm.forward_port 22, 3220 # ssh
    apply_common_config_options(config)
  end

  config.vm.define :weave2 do |config|
    config.vm.host_name = "weave2"
    config.vm.network :hostonly, "1.2.3.91"
    config.vm.forward_port 22, 3221 #ssh
    apply_common_config_options(config)
  end
end
