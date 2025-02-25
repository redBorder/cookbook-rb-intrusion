# Cookbook:: ips
# Recipe:: default
# Copyright:: 2024, redborder
# License:: Affero General Public License, Version 3

include_recipe 'rb-intrusion::prepare_system'
include_recipe 'rb-intrusion::configure'
include_recipe 'rb-intrusion::configure_cron_tasks'
include_recipe 'rb-intrusion::configure_journald'
