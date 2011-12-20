require 'launchy'
require 'engineyard-api-client/errors'

module EY
  class APIClient
    class AppEnvironment < ApiStruct.new(:id, :app, :environment, :perform_migration, :migration_command)

      def initialize(api, attrs)
        super

        raise ArgumentError, 'AppEnvironment created without app!' unless app
        raise ArgumentError, 'AppEnvironment created without environment!' unless environment

        if environment.deployment_configurations
          extract_deploy_config(environment.deployment_configurations[app.name])
        end
      end

      def app=(app_or_hash)
        super App.from_hash(api, app_or_hash)
      end

      def environment=(env_or_hash)
        super Environment.from_hash(api, env_or_hash)
      end

      def account_name
        app.account_name
      end

      def app_name
        app.name
      end

      def environment_name
        environment.name
      end

      def repository_uri
        app.repository_uri
      end

      # hack for legacy api.
      def extract_deploy_config(deploy_config)
        if deploy_config
          self.migration_command = deploy_config['migrate']['command']
          self.perform_migration = deploy_config['migrate']['perform']
        end
      end

      def last_deployment
        Deployment.last(api, self)
      end

      def deploy(ref, deploy_options={})
        migration_command = determine_migration_command(deploy_options)
        deployment = Deployment.started(api, self, ref, migration_command)

        environment.bridge!.deploy(
          deployment,
          config.merge(deploy_options['extras']),
          deploy_options['verbose']
        )
      ensure
        if deployment
          deployment.finished
          EY.ui.info "#{deployment.successful? ? 'Successful' : 'Failed'} deployment recorded on EY Cloud"
        end
      end

      def rollback(extra_deploy_hook_options={}, verbose=false)
        environment.bridge!.rollback(
          self,
          config.merge(extra_deploy_hook_options),
          verbose)
      end

      def take_down_maintenance_page(verbose=false)
        environment.bridge!.take_down_maintenance_page(app, verbose)
      end

      def put_up_maintenance_page(verbose=false)
        environment.bridge!.put_up_maintenance_page(app, verbose)
      end

      # If force_ref is a string, use it as the ref, otherwise use it as a boolean.
      def resolve_branch(ref, force_ref=false)
        if String === force_ref
          ref, force_ref = force_ref, true
        end

        if !ref
          default_branch
        elsif force_ref || !default_branch || ref == default_branch
          ref
        else
          raise BranchMismatchError.new(default_branch, ref)
        end
      end

      def configuration
        EY.config.environments[environment.name] || {}
      end
      alias_method :config, :configuration

      def default_branch
        EY.config.default_branch(environment.name)
      end

      def short_environment_name
        environment.name.gsub(/^#{Regexp.quote(app.name)}_/, '')
      end

      def launch
        Launchy.open(environment.bridge!.hostname_url)
      end

      def determine_migration_command(cli_options)
        # regarding deploy_options['migrate']:
        #
        # missing means migrate how the yaml file says to
        # nil means don't migrate
        # true means migrate w/custom command (if present) or default
        # a string means migrate with this specific command
        return nil if no_migrate?(cli_options)
        command = migration_command_from_command_line(cli_options['migrate'])
        unless command
          return nil if no_migrate?(config)
          command = migration_command_from_config
        end
        command = migration_command_from_environment unless command
        command
      end

      private

      def no_migrate?(deploy_options)
        deploy_options.key?('migrate') && deploy_options['migrate'] == false
      end

      def migration_command_from_config
        config['migration_command'] if config['migrate'] || config['migration_command']
      end

      def migration_command_from_command_line(migrate)
        if migrate
          if migrate.respond_to?(:to_str)
            migrate.to_str
          else
            config['migration_command'] || default_migration_command
          end
        end
      end

      def migration_command_from_environment
        migration_command if perform_migration
      end

      def default_migration_command
        'rake db:migrate'
      end
    end
  end
end
