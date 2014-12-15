include_recipe "deploy"

node[:deploy].each do |application, deploy|
  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  bash "docker-cleanup" do
    user "root"
    code <<-EOH
      if docker ps | grep #{deploy[:application]}; then
        docker stop #{deploy[:application]}
      end
      docker rm $(docker ps -a | grep -vi container | cut -f1 -d ' ')
      sleep 3
      if docker images | grep #{deploy[:application]}; then
        docker rmi #{deploy[:application]}
      fi
    EOH
  end

  bash "docker-build" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
      docker build -t=#{deploy[:application]} . > #{deploy[:application]}-docker.out
    EOH
  end

  dockerenvs = deploy[:environment_variables].map do |key, value|
    "--env #{key}=#{value}"
  end.join(" ")
  private_ip = node[:opsworks][:instance][:private_ip]

  string = <<-EOH
  docker run #{dockerenvs} -p #{private_ip}:80:80 --name #{deploy[:application]} \
    --restart=always -d #{deploy[:application]}
  EOH

  bash "docker-run" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code string
    action :nothing
  end.run_action :run
end
