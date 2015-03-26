{% from "influxdb/map.jinja" import influxdb_settings with context %}

{% if grains['os_family'] == 'Debian' %}
{% if influxdb_settings['version'] is defined %}
  {% set filename = "influxdb_" + influxdb_settings['version'] + "_" + grains['osarch'] + ".deb" %}
{% else %}
  {% set filename = "influxdb_latest_" + grains['osarch'] + ".deb" %}
{% endif %}
{% elif grains['os_family'] == 'RedHat' %}
{% if influxdb_settings['version'] is defined %}
  {% set filename = "influxdb-" + influxdb_settings['version'] + "-1." + grains['osarch'] + ".rpm" %}
{% else %}
  {% set filename = "influxdb-latest-1." + grains['osarch'] + ".rpm" %}
{% endif %}
{% endif %}

influxdb_package:
  cmd.run:
    - name: wget -qO /tmp/{{ filename }} http://s3.amazonaws.com/influxdb/{{ filename }}
    - unless: test -f /tmp/{{ filename }}

influxdb_install:
  pkg.installed:
    - sources:
      - influxdb: /tmp/{{ filename }}
    - require:
      - cmd: influxdb_package
    - watch:
      - cmd: influxdb_package

influxdb_confdir:
  file.directory:
    - name: {{ influxdb_settings.conf_dir }}
    - owner: root
    - group: root
    - mode: 755

influxdb_config:
  file.managed:
    - name: {{ influxdb_settings.config }}
    - source: salt://influxdb/templates/config.toml.jinja
    - user: root
    - group: root
    - mode: 644
    - template: jinja

influxdb_init:
  file.managed:
    - name: {{ influxdb_settings.init_dir }}/{{ influxdb_settings.service }}
    - source: salt://influxdb/templates/influxdb.service.jinja
    - user: root
    - group: root
    - mode: 755
    - template: jinja

influxdb_group:
  group.present:
    - name: {{ influxdb_settings.group }}
    - system: True

influxdb_user:
  user.present:
    - name: {{ influxdb_settings.user }}
    - fullname: {{ influxdb_settings.fullname }}
    - shell: {{ influxdb_settings.shell }}
    - home: {{ influxdb_settings.home }}
    - gid_from_name: True
    - require:
      - group: influxdb_group

influxdb_log:
  file.directory:
    - name: {{ influxdb_settings.logging.directory }}
    - user: {{ influxdb_settings.user }}
    - group: {{ influxdb_settings.group }}
    - mode: 755
    - require:
      - group: influxdb_group
      - user: influxdb_user

influxdb_logrotate:
  file.managed:
    - name: {{ influxdb_settings.logrotate_conf }}
    - source: salt://influxdb/templates/logrotate.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - watch:
      - file: influxdb_log

influxdb_start:
  service.running:
    - name: {{ influxdb_settings.service }}
    - enable: True
    - watch:
      - pkg: influxdb_install
      - file: influxdb_config
    - require:
      - pkg: influxdb_install
      - file: influxdb_config
