#
# Cookbook Name:: netdev
# Provider:: lag
#
# Copyright 2014, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/resource'
require 'chef/provider'

require_relative '_helper'
require_relative '_junos_api_client'
require_relative 'resource_lag'

class Chef
  class Provider::NetdevLinkAggregationGroup::Junos < Provider
    include Netdev::Helper

    #
    # This provider supports why-run mode.
    #
    def whyrun_supported?
      true
    end

    def load_current_resource
      @current_resource = Chef::Resource::NetdevLinkAggregationGroup.new(new_resource.name)
      @current_resource.lag_name(new_resource.lag_name)

      if (lag = junos_client.managed_resource) && lag.exists?
        @current_resource.links(lag[:links].to_a)
        @current_resource.minimum_links(lag[:minimum_links])

        # junos-ez-stdlib uses the past tense
        if lag[:lacp].to_s == 'disabled'
          @current_resource.lacp('disable')
        else
          @current_resource.lacp(lag[:lacp].to_s)
        end

        @current_resource.active = lag[:_active]
        @current_resource.exists = true
      else
        @current_resource.active = false
        @current_resource.exists = false
      end
      @current_resource
    end

    #
    # Create the given link aggregation group.
    #
    def action_create
      new_values = new_resource.state
      current_values = current_resource.state

      # junos-ez-stdlib uses the past tense
      new_values[:lacp] = 'disabled' if new_resource.lacp == 'disable'
      current_values[:lacp] = 'disabled' if current_resource.lacp == 'disable'

      updated_values = junos_client.updated_changed_properties(new_values,
                                                               current_values)
      unless updated_values.empty?
        message = "create link aggregation group #{new_resource.name} with values:"
        message << " #{pretty_print_updated_values(updated_values)}"
        converge_by(message) do
          junos_client.write!
        end
      end
    end

    #
    # Delete the given link aggregation group.
    #
    def action_delete
      if current_resource.exists?
        converge_by("delete existing link aggregation group #{new_resource.name}") do
          junos_client.delete!
        end
      end
    end

    private

    def junos_client
      @junos_client ||= Netdev::Junos::ApiClient::LAGports.new(new_resource.lag_name)
    end
  end
end
