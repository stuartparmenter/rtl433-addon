#!/usr/bin/with-contenv bashio
set -Ee -o pipefail
shopt -s nullglob

# /config is mapped from config.yaml's "map: [addon_config:rw]"
# which translates to /addon_configs/<slug>/ on the host
conf_directory="/config"
temp_directory=""

# Cleanup function
cleanup() {
    if [ -n "$temp_directory" ] && [ -d "$temp_directory" ]; then
        rm -rf "$temp_directory"
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

if bashio::services.available "mqtt"; then
    host=$(bashio::services "mqtt" "host")
    password=$(bashio::services "mqtt" "password")
    port=$(bashio::services "mqtt" "port")
    username=$(bashio::services "mqtt" "username")
    retain=$(bashio::config "retain")
    if [ "$retain" = "true" ] ; then
      retain=1
    else
      retain=0
    fi
else
    bashio::log.info "The mqtt addon is not available."
    bashio::log.info "This is not a problem if you are using an external MQTT broker."
    bashio::log.info "If you are using the Home Assistant Mosquitto Broker addon, try restarting it, and then restart the rtl_433 addon."
    bashio::log.info "For an external broker, manually update the output line in the configuration file with mqtt connection settings, and restart the addon."
    host=""
    password=""
    port=""
    username=""
    retain=0
fi

if [ ! -d "$conf_directory" ]; then
  mkdir -p "$conf_directory"
fi

# Check if the legacy configuration file is set and alert that it's deprecated.
conf_file=$(bashio::config "rtl_433_conf_file")

if [[ -n "$conf_file" ]]; then
    bashio::log.warning "rtl_433 now supports automatic configuration and multiple radios. The rtl_433_conf_file option is deprecated. See the documentation for migration instructions."
    conf_file="/config/$conf_file"

    echo "Starting rtl_433 -c $conf_file"
    rtl_433 -c "$conf_file"
    exit $?
fi

# Create a reasonable default configuration in /config.
if [ -z "$(compgen -G "$conf_directory/*.conf.template" || true)" ]; then
  cp /rtl_433.conf.template "$conf_directory/rtl_433.conf.template"
fi

# Create temporary directory for rendered configuration files
temp_directory=$(mktemp -d)

rtl_433_pids=()
for template in "$conf_directory"/*.conf.template
do
    # Remove '.template' from the file name and create in temp directory.
    live="$temp_directory/$(basename "$template" .template)"

    # Use envsubst to safely substitute environment variables in the template
    env host="$host" port="$port" username="$username" password="$password" retain="$retain" \
      envsubst '${host} ${port} ${username} ${password} ${retain}' \
      < "$template" > "$live"
    tag="$(basename "$live" .conf)"
    rtl_433 -c "$live" > >(sed -u "s/^/[$tag] /") 2> >(>&2 sed -u "s/^/[$tag] /") &
    rtl_433_pids+=("$!")
done

# If no templates matched, exit cleanly
if [ "${#rtl_433_pids[@]}" -eq 0 ]; then
  bashio::log.info "No *.conf.template files found in $conf_directory; nothing to run."
  exit 0
fi

wait -n "${rtl_433_pids[@]}"