#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
# set -e

# Echo fn that outputs to stderr http://stackoverflow.com/a/2990533/511069
echoerr() {
  cat <<< "$@" 1>&2;
}

# Print error and exit
die () {
  local error_msg=$1
  local opt_exit_code=$2
  local opt_perform_shutdown=$3

  echoerr "ERROR: $error_msg"
  if [ "$opt_perform_shutdown" = "true" ]; then
    shutdown
  fi
  # if $opt_exit_code is defined AND NOT EMPTY, use
  # $opt_exit_code; otherwise, set to "1"
  local errnum=${opt_exit_code-1}
  exit $errnum
}

# Kill process gracefully or force it if is resilient
kill_pid_gracefully() {
  local the_pid=$1
  local pdesc=$2
  [ -z "$the_pid" ] && die "Need to set PID as 1st param for kill_pid_gracefully()" 4
  [ -z "$pdesc" ]   && die "Need to set Description as 2nd param for kill_pid_gracefully()" 5
  if [ "$the_pid" -gt "0" ] && [ -d /proc/$the_pid ]; then
    echo "Shutting down $pdesc PID: $the_pid.."
    sudo kill -s SIGTERM $the_pid
    local wait_msg="waiting for $pdesc PID: $the_pid to die..."
    timeout 1 bash -c "while [ -d /proc/$the_pid ]; do sleep 0.1 && echo $wait_msg; done"
    if [ -d /proc/$the_pid ]; then
      echo "$pdesc PID: $the_pid still running, forcing with kill -SIGKILL..."
      sudo kill -SIGKILL $the_pid
      # Better not to wait since docker will terminate the cleanup anyway
      # echo "waiting for $pdesc PID: $the_pid to finally terminate.."
      # wait $the_pid
    fi
  fi
}

# Retries a command a with backoff.
#
# The retry count is given by $MAX_WAIT_RETRY_ATTEMPTS,
# the initial backoff timeout sleep is given by
# Timeout in seconds is $RETRY_START_SLEEP_SECS
#
# Successive backoffs double the timeout.
#
# Beware of set -e killing your whole script!
function with_backoff_and_slient {
  local max_attempts=$MAX_WAIT_RETRY_ATTEMPTS
  local timeout=$RETRY_START_SLEEP_SECS
  local attempt=0
  local exitCode=0
  local cmd_desc=$CMD_DESC_PARAM
  local cmd=$CMD_PARAM
  local log_file=$LOG_FILE_PARAM
  [ -z "$log_file" ] && log_file=/dev/null

  # while [[ $attempt < $max_attempts ]]; do
  while [ "$attempt" -lt "$max_attempts" ]; do
    # Silent but keep the log for later reporting
    bash -a -c "$cmd" >$log_file 2>&1
    exitCode=$?

    if [[ $exitCode == 0 ]]; then
      break
    fi

    echo "-- Retrying/waiting for $cmd_desc in $timeout seconds..."
    sleep $timeout
    attempt=$(( attempt + 1 ))
    # timeout=$(( timeout * 2 ))
    timeout=$(echo "scale=2; $timeout*2" | bc)
  done

  if [[ $exitCode != 0 ]]; then
    echo "$cmd_desc failed me for the last time! ($cmd)" 1>&2
    [ -f "$log_file" ] && cat $log_file
    exit $exitCode
  fi

  return $exitCode
}

# Exit all child processes properly
function shutdown {
  echo "Trapped SIGTERM or SIGINT so shutting down gracefully..."
  kill_pid_gracefully $CATALINA_PID "Tomcat Catalina server"
  kill_pid_gracefully $GUACD_PID "Guacamole server"
  echo "Shutdown complete."
}

# These values are only available when the container started
export DOCKER_HOST_IP=$(netstat -nr | grep '^0\.0\.0\.0' | awk '{print $2}')
export CONTAINER_IP=$(ip addr show dev eth0 | grep "inet " | awk '{print $2}' | cut -d '/' -f 1)


# Generate config files based on env vars before starting guacamole
genereate_guaca_configs.sh || die "Failed to start genereate_guaca_configs!" 9 true

# Run guacd
# -f     Causes guacd to run in the foreground, rather than automatically forking into the background.
guacd -f -b "0.0.0.0" -l ${GUACAMOLE_SERVER_PORT} 2>&1 | tee ${GUACD_LOG} &
GUACD_PID=$!

# For guacd
CMD_DESC_PARAM="guacd server"
# CMD_PARAM="nc -z localhost ${GUACAMOLE_SERVER_PORT}"
CMD_PARAM="grep \"Guacamole proxy daemon (guacd) version ${GUACAMOLE_VERSION} started\" ${GUACD_LOG}"
LOG_FILE_PARAM="$GUACD_POLL_LOG"
with_backoff_and_slient

# Generate TOMCAT_CONF with dynamic port
#
export TOMCAT_DIR_CONF=${HOME}/tomcat/conf
export TOMCAT_CONF=${TOMCAT_DIR_CONF}/new_server.xml

# http://examples.javacodegeeks.com/enterprise-java/tomcat/tomcat-server-xml-configuration-example/
cat >${TOMCAT_CONF} <<EOF
<?xml version='1.0' encoding='utf-8'?>
<Server port="${TOMCAT_SHUTDOWN_PORT}" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>
  <Service name="Catalina">
    <Connector port="${TOMCAT_PORT}" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="${TOMCAT_REDIRECT_PORT}" />
    <Connector port="${TOMCAT_AJP_PORT}" protocol="AJP/1.3" redirectPort="${TOMCAT_REDIRECT_PORT}" />
    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>
      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />
      </Host>
    </Engine>
  </Service>
</Server>
EOF

# Run tomcat to start guacamole web-server
catalina.sh run -config ${TOMCAT_CONF} 2>&1 | tee ${CATALINA_LOG} &
CATALINA_PID=$!

CMD_DESC_PARAM="Tomcat Catalina server"
CMD_PARAM="grep \"org.apache.catalina.startup.Catalina.start Server startup in\" ${CATALINA_LOG}"
# LOG_FILE_PARAM="$TOMCAT_POLL_LOG"
with_backoff_and_slient

echo
echo "Container docker internal IP: $CONTAINER_IP"
echo "Note if you're in Mac (OSX) 'boot2docker ip' will tell you the relevant IP"
echo "entry.sh all done and ready"

# Run function shutdown() when this process receives SIGTERM or SIGINT
trap shutdown SIGTERM SIGINT

# tells bash to wait until child processes have exited
wait
