# Gitlab Runner Ansible 
### Deploy and register Gitlab instance runner with Ansible and Docker.

> Stages 

* Install Docker
* Stop containers if exist
* Creating directories and copy docker compose as template
* Create network
* Deploy gitlab runner
* Config gitlab runner and register by default variable or by inventory variables for each host.
* Config intervals of runner and prometheus monitoring of gitlab runner and expose on 9252


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
