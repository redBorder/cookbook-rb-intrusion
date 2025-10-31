# Add manager node ip addr to /etc/hosts
# We need this for the kafka problem
# Is replaying with manager.domain and
# The ips need to be able to resolv this

ruby_block 'update_hosts_file_if_needed' do
  block do
    extend RbIps::Helpers

    unless node['redborder']['cloud']
      # Read webui_host from the rb_init_conf.yml file
      webui_host_command = "grep '^webui_host:' /etc/redborder/rb_init_conf.yml | awk '{print $2}'"
      webui_host = manager_to_ip `#{webui_host_command}`.strip

      # Search for a node matching the webui_host IP address
      matching_node_name = search(:node, "ipaddress:#{webui_host}").first&.name

      # Update /etc/hosts if a matching node is found
      if matching_node_name
        node_name_with_suffix = "#{matching_node_name}.node"
        hosts_file = '/etc/hosts'

        unless ::File.readlines(hosts_file).grep(/#{Regexp.escape(node_name_with_suffix)}/).any?
          ::File.open(hosts_file, 'a') { |file| file.puts "#{webui_host} #{node_name_with_suffix}" }
        end
      end
    end
  end
  action :run
end
