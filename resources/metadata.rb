# frozen_string_literal: true

name             'rb-intrusion'
maintainer       'Eneo Tecnología S.L.'
maintainer_email 'git@redborder.com'
license          'AGPL-3.0'
description      'Installs/Configures redborder ips'
version          '1.1.0'

depends 'rb-common'
depends 'snmp'
depends 'rbmonitor'
depends 'rsyslog'
depends 'rb-selinux'
depends 'rb-exporter'
depends 'cron'
depends 'rbcgroup'
depends 'rb-clamav'
depends 'rb-chrony'
depends 'snort3'
