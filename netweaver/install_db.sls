{%- from "netweaver/map.jinja" import netweaver with context -%}
{% set host = grains['host'] %}

{% for node in netweaver.nodes if node.host == host and node.sap_instance == 'db' %}

{% set instance = '{:0>2}'.format(node.instance) %}
{% set instance_name =  node.sid~'_'~instance %}

create_db_inifile_{{ instance_name }}:
  file.managed:
    - source: salt://netweaver/templates/db.inifile.params.j2
    - name: /tmp/db.inifile.params
    - template: jinja
    - context: # set up context for template db.inifile.params.j2
        master_password: {{ node.master_password }}
        sid: {{ node.sid }}
        instance: {{ instance }}
        virtual_hostname: {{ node.virtual_host }}
        download_basket: /swpm/{{ netweaver.sapexe_folder }}
        schema_name: {{ netweaver.schema.name|default('SAPABAP1') }}
        schema_password: {{ netweaver.schema.password }}
        hana_host: {{ netweaver.hana.host }}
        hana_sid: {{ netweaver.hana.sid }}
        hana_password: {{ netweaver.hana.password }}
        hana_inst: {{ netweaver.hana.instance }}

wait_for_hana_{{ instance_name }}:
  hana.available:
    - name: {{ netweaver.hana.host }}
    - port: 3{{ netweaver.hana.instance }}13
    - user: SYSTEM
    - password: {{ netweaver.hana.password }}
    - timeout: 5000
    - interval: 30

netweaver_install_{{ instance_name }}:
  netweaver.db_installed:
    - name: {{ netweaver.hana.host }}
    - port: 3{{ netweaver.hana.instance }}13
    - schema_name: {{ netweaver.schema.name|default('SAPABAP1') }}
    - schema_password: {{ netweaver.schema.password }}
    - software_path: /swpm/{{ netweaver.swpm_folder }}
    - root_user: {{ node.root_user }}
    - root_password: {{ node.root_password }}
    - config_file: /tmp/db.inifile.params
    - virtual_host: {{ node.virtual_host }}
    - virtual_host_interface: {{ node.virtual_host_interface|default('eth1') }}
    - product_id: NW_ABAP_DB:NW750.HDB.ABAPHA
    - cwd: {{ netweaver.installation_folder }}
    - additional_dvds: {{ netweaver.additional_dvds }}
    - require:
      - create_db_inifile_{{ instance_name }}
      - wait_for_hana_{{ instance_name }}
    - retry:
        attempts: {{ node.attempts|default(5) }}
        interval: 60

remove_db_inifile_{{ instance_name }}:
  file.absent:
    - name: /tmp/db.inifile.params
    - require:
      - create_db_inifile_{{ instance_name }}

{% endfor %}
