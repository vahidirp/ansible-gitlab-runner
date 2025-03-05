# Gitlab Runner Ansible 
### Deploy and register Gitlab instance runner with Ansible and Docker.

#### Run generator for creating inventory file.
#### Passwords for Basic Auth of usersfile of Traefik will auto generate bcrypt, Runner metrics auth password not supported bcrypt natively and used as PlainText.
#### Change acme_email variable in default/main.yml.
> Stages 

* Install Docker
* Stop containers if exist
* Creating directories and copy docker compose as template
* Create network
* Deploy gitlab runner
* Deploy traefik as reverse proxy
* Config gitlab runner and register by default variable or by inventory variables for each host.
* Other gitlab runner configurations
* Config intervals of runner and prometheus monitoring of gitlab runner and expose on 9252


Gitlab runner exposed with traefik label configurations.

> Monitoring

Add this config to your central monitoring system prometheus : 

```
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'gitlab-runner'
    static_configs:
      - targets: ['runner.example.com:9252']

```


#### Please contribute and giving me feedback, Happy for any feature add or fixes from you.