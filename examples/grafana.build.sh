#!/usr/bin/env bash

#
# A rkt container pod for running a Statsd/Graphite/Grafana metrics stack.
#
# Start the containers with new data storage directory:
#
#   mkdir data
#   sudo rkt run \
#     --port=carbon:2003 \
#     --port=statsd:8125 \
#     --port=graphite-api:8888 \
#     --port=grafana-www:3000 \
#     --volume data,kind=host,source=$(pwd)/data \
#     woofwoofinc.dog/grafana-carbon --mount volume=data,target=/opt/graphite/storage/whisper \
#     woofwoofinc.dog/grafana-statsd \
#     woofwoofinc.dog/grafana-graphite-api --mount volume=data,target=/srv/graphite/whisper \
#     woofwoofinc.dog/grafana-www --mount volume=data,target=/usr/share/grafana/data
#
# Create some test metric data from the macOS host:
#
#    brew install watch
#    watch -n5 'echo "1d6:$(jot -r 1 1 6)|g" | nc -u -w0 rktmachine.local 8125'
#
# This metric can be inspected in a browser on the macOS host:
#
#    open 'http://rktmachine.local:8888/render?target=stats.gauges.1d6&from=-5min'
#
# Or by curl for the data in CSV format:
#
#    curl 'http://rktmachine.local:8888/render?target=stats.gauges.1d6&from=-5min&format=csv'
#
# The Grafana instance runs at http://rktmachine.local:3000 with default
# `admin` user with `admin` password.
#
# To configure the datasource in Grafana, select a Proxy source with URL
# http://0.0.0.0:8888. Using a proxy source means the graphite-api service does
# not have to be exposed on port 8888. Normally this is preferred because it is
# easier to secure the Grafana endpoint for authorized use.
#
# We expose the graphite-api port in the rkt run command here because it is
# convenient for data export. The datasource would still work if
# `--port=graphite-api:8888` was omitted.
#
# Similarly the Carbon `--port=carbon:2003` could be omitted but again it may
# be useful during development.
#
# Useful links for writing Carbon aggregation rules.
# - https://github.com/etsy/statsd/blob/master/docs/graphite.md
# - http://dieter.plaetinck.be/post/25-graphite-grafana-statsd-gotchas/
#

set -x

GRAFANA_VERSION=4.2.0
NODE_VERSION=6.10.2
STATSD_VERSION=0.8.0


################################################################################
# Setup
################################################################################

mkdir -p grafana
cd grafana


################################################################################
# Download Base Image
################################################################################

wget http://cdimage.ubuntu.com/ubuntu-base/releases/16.04.2/release/ubuntu-base-16.04-core-amd64.tar.gz


################################################################################
# Carbon Container
################################################################################

mkdir -p carbon
cd carbon

acbuild begin ../ubuntu-base-16.04-core-amd64.tar.gz
acbuild set-name woofwoofinc.dog/grafana-carbon

acbuild run -- apt-get update -qq
acbuild run -- apt-get upgrade -qq

# Python pip is in Ubuntu universe.
acbuild run -- apt-get install -qq software-properties-common
acbuild run -- apt-add-repository universe
acbuild run -- apt-get update -qq

acbuild run -- apt-get install -qq python2.7
acbuild run -- apt-get install -qq python-pip
acbuild run -- pip install -q --upgrade pip

acbuild run -- pip install -q --no-binary=:all: https://github.com/graphite-project/whisper/tarball/master
acbuild run -- pip install -q --no-binary=:all: https://github.com/graphite-project/carbon/tarball/master

acbuild run -- mv /opt/graphite/conf/carbon.conf.example /opt/graphite/conf/carbon.conf

cat > storage-schemas.conf <<EOF
# Schema definitions for Whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds.
#
#  [name]
#  pattern = regex
#  retentions = timePerPoint:timeToStore, timePerPoint:timeToStore, ...

# Carbon's internal metrics. This entry should match what is specified in
# CARBON_METRIC_PREFIX and CARBON_METRIC_INTERVAL settings
[carbon]
pattern = ^carbon\.
retentions = 60:14d

# Metric retention
# - 1 day of 10 second data
# - 7 days of 1 minute data
# - 5 years of 10 minute data
[default]
pattern = .*
retentions = 10s:1d,1m:7d,10m:1800d
EOF
acbuild copy storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
rm storage-schemas.conf

cat > storage-aggregation.conf <<EOF
# Aggregation methods for whisper files. Entries are scanned in order,
# and first match wins. This file is scanned for changes every 60 seconds
#
#  [name]
#  pattern = <regex>
#  xFilesFactor = <float between 0 and 1>
#  aggregationMethod = <average|sum|last|max|min>
#
#  name: Arbitrary unique name for the rule
#  pattern: Regex pattern to match against the metric name
#  xFilesFactor: Ratio of valid data points required for aggregation to the next retention to occur
#  aggregationMethod: function to apply to data points for aggregation
#

# Statsd downsampling rules.
[min]
pattern = \.lower$
xFilesFactor = 0.1
aggregationMethod = min

[max]
pattern = \.upper(_\d+)?$
xFilesFactor = 0.1
aggregationMethod = max

[sum]
pattern = \.sum$
xFilesFactor = 0
aggregationMethod = sum

[count]
pattern = \.count$
xFilesFactor = 0
aggregationMethod = sum

[count_legacy]
pattern = ^stats_counts.*
xFilesFactor = 0
aggregationMethod = sum

[default_average]
pattern = .*
xFilesFactor = 0.3
aggregationMethod = average
EOF
acbuild copy storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf
rm storage-aggregation.conf

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild port add carbon tcp 2003
acbuild set-exec -- /opt/graphite/bin/carbon-cache.py --nodaemon start
acbuild write --overwrite grafana-carbon.aci

acbuild end

rkt --insecure-options=image fetch ./grafana-carbon.aci

cd ..


################################################################################
# Statsd Container
################################################################################

mkdir -p statsd
cd statsd

acbuild begin ../ubuntu-base-16.04-core-amd64.tar.gz
acbuild set-name woofwoofinc.dog/grafana-statsd

acbuild run -- apt-get update -qq
acbuild run -- apt-get upgrade -qq

acbuild run -- apt-get install -qq wget
acbuild run -- apt-get install -qq build-essential

acbuild run -- wget -q https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz
acbuild run -- tar xJf node-v${NODE_VERSION}-linux-x64.tar.xz -C /usr/ --strip-components=1
acbuild run -- rm node-v${NODE_VERSION}-linux-x64.tar.xz

acbuild run -- wget -q https://github.com/etsy/statsd/archive/v${STATSD_VERSION}.tar.gz
acbuild run -- mkdir -p /opt/statsd
acbuild run -- tar xzf v${STATSD_VERSION}.tar.gz -C /opt/statsd --strip-components=1
acbuild run -- rm v${STATSD_VERSION}.tar.gz

cat > config.js <<EOF
{
  port: 8125,
  graphiteHost: "0.0.0.0",
  graphitePort: 2003,
  backends: [ "./backends/graphite" ],
  flushInterval: 10000,
  deleteIdleStats: true
}
EOF
acbuild copy config.js /opt/statsd/config.js
rm config.js

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild port add statsd udp 8125

acbuild set-exec -- /usr/bin/node /opt/statsd/stats.js /opt/statsd/config.js
acbuild write --overwrite grafana-statsd.aci

acbuild end

rkt --insecure-options=image fetch ./grafana-statsd.aci

cd ..


################################################################################
# Graphite API Container
################################################################################

mkdir -p graphite-api
cd graphite-api

acbuild begin ../ubuntu-base-16.04-core-amd64.tar.gz
acbuild set-name woofwoofinc.dog/grafana-graphite-api

acbuild run -- apt-get update -qq
acbuild run -- apt-get upgrade -qq

acbuild run -- apt-get install -qq build-essential

# Python pip is in Ubuntu universe.
acbuild run -- apt-get install -qq software-properties-common
acbuild run -- apt-add-repository universe
acbuild run -- apt-get update -qq

acbuild run -- apt-get install -qq python2.7
acbuild run -- apt-get install -qq python-dev
acbuild run -- apt-get install -qq python-pip
acbuild run -- pip install -q --upgrade pip

acbuild run -- apt-get install -qq libcairo2-dev
acbuild run -- apt-get install -qq libffi-dev

acbuild run -- pip install -q graphite-api

# Add configuration to allow cross-origin requests from Grafana.
cat > graphite-api.yaml <<EOF
allowed_origins:
  - '*'
EOF
acbuild copy graphite-api.yaml /etc/graphite-api.yaml
rm graphite-api.yaml

acbuild run -- pip install -q gunicorn

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild port add graphite-api tcp 8888
acbuild set-exec -- /usr/local/bin/gunicorn -w2 graphite_api.app:app -b 0.0.0.0:8888
acbuild write --overwrite grafana-graphite-api.aci

acbuild end

rkt --insecure-options=image fetch ./grafana-graphite-api.aci

cd ..


################################################################################
# Grafana Container
################################################################################

mkdir -p www
cd www

acbuild begin ../ubuntu-base-16.04-core-amd64.tar.gz
acbuild set-name woofwoofinc.dog/grafana-www

acbuild run -- apt-get update -qq
acbuild run -- apt-get upgrade -qq

acbuild run -- apt-get install -qq wget

acbuild run -- apt-get install -qq adduser libfontconfig
acbuild run -- wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana_${GRAFANA_VERSION}_amd64.deb
acbuild run -- dpkg -i grafana_${GRAFANA_VERSION}_amd64.deb
acbuild run -- rm grafana_${GRAFANA_VERSION}_amd64.deb

acbuild run -- apt-get -qq autoclean
acbuild run -- apt-get -qq autoremove
acbuild run -- apt-get -qq clean

acbuild port add grafana-www tcp 3000
acbuild set-exec -- /usr/sbin/grafana-server -homepath /usr/share/grafana
acbuild write --overwrite grafana-www.aci

acbuild end

rkt --insecure-options=image fetch ./grafana-www.aci

cd ..


################################################################################
# Cleanup
################################################################################

cd ..
rm -fr grafana
