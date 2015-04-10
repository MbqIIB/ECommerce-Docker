#! /bin/bash

cleanUp() {
  (cd ECommerce-Tomcat && rm -f AppServerAgent.zip MachineAgent.zip)
  (cd ECommerce-Tomcat && rm -rf monitors ECommerce-Java)
  (cd ECommerce-Synapse && rm -f AppServerAgent.zip MachineAgent.zip)
  (cd ECommerce-DBAgent && rm -f dbagent.zip)
  (cd ECommerce-Load && rm -rf ECommerce-Load)

  # Remove dangling images left-over from build
  if [[ `docker images -q --filter "dangling=true"` ]]
  then
    echo
    echo "Deleting intermediate containers..."
    docker images -q --filter "dangling=true" | xargs docker rmi;
  fi
}

promptForAgents() {
  read -e -p "Enter path to App Server Agent: " APP_SERVER_AGENT
  read -e -p "Enter path to Machine Agent: " MACHINE_AGENT
  read -e -p "Enter path to DB Agent: " DB_AGENT
}

# Usage information
if [[ $1 == *--help* ]]
then
  echo "Specify agent locations: build.sh -a <Path to App Server Agent> -m <Path to Machine Agent> -d <Path to Database Agent>"
  echo "Prompt for agent locations: build.sh"
  exit
fi

# Prompt for location of App Server, Machine and Database Agents
if  [ $# -eq 0 ]
then   
  promptForAgents

else
  # Allow user to specify locations of App Server, Machine and Database Agents
  while getopts "a:m:d:n:k:" opt; do
    case $opt in
      a)
        APP_SERVER_AGENT=$OPTARG
        if [ ! -e ${APP_SERVER_AGENT} ]
        then
          echo "Not found: ${APP_SERVER_AGENT}"
          exit
        fi
        ;;
      m)
        MACHINE_AGENT=$OPTARG
        if [ ! -e ${MACHINE_AGENT} ]
        then
          echo "Not found: ${MACHINE_AGENT}"
          exit
        fi
        ;;
      d)
        DB_AGENT=$OPTARG
        if [ ! -e ${DB_AGENT} ]
        then
          echo "Not found: ${DB_AGENT}"
          exit
        fi
        ;;
      n)
        ANALYTICS_ACCOUNT_NAME=$OPTARG
        ;;
      k)
        ANALYTICS_ACCOUNT_KEY=$OPTARG
        ;;
      \?)
        echo "Invalid option: -$OPTARG"
        ;;
    esac
  done
fi

# Pull Java base image from appdynamics docker repo
docker pull appdynamics/ecommerce-java:oracle-java7

# Copy Agent zips to build dirs
cp ${APP_SERVER_AGENT} ECommerce-Tomcat/AppServerAgent.zip
cp ${APP_SERVER_AGENT} ECommerce-Synapse/AppServerAgent.zip
cp ${MACHINE_AGENT} ECommerce-Tomcat/MachineAgent.zip

# Enable Analytics 
(cd ECommerce-Tomcat && unzip MachineAgent.zip monitors/analytics-agent/monitor.xml)
if [ `uname` == "Darwin" ]; then
  (cd ECommerce-Tomcat && sed -i .bak "s/false/true/g" monitors/analytics-agent/monitor.xml)
else
  (cd ECommerce-Tomcat && sed -i "s/false/true/g" monitors/analytics-agent/monitor.xml)
fi
(cd ECommerce-Tomcat && zip MachineAgent.zip monitors/analytics-agent/monitor.xml)

# Build Tomcat containers using downloaded AppServer and Machine Agents
(cd ECommerce-Tomcat && git clone https://github.com/Appdynamics/ECommerce-Java.git)
(cd ECommerce-Tomcat && docker build -t appdynamics/ecommerce-tomcat .)

# Build Synapse container using downloaded AppServer and Machine Agents
cp ECommerce-Tomcat/MachineAgent.zip ECommerce-Synapse/MachineAgent.zip
(cd ECommerce-Synapse && docker build -t appdynamics/ecommerce-synapse .)

# Build DBAgent container using downloaded DBAgent
cp ${DB_AGENT} ECommerce-DBAgent/dbagent.zip
(cd ECommerce-DBAgent && docker build -t appdynamics/ecommerce-dbagent .)

# Build LoadGen container
(cd ECommerce-Load && git clone https://github.com/Appdynamics/ECommerce-Load.git)
(cd ECommerce-Load && docker build -t appdynamics/ecommerce-load .)

# Pull ActiveMQ, LBR and LoadGen containers from appdynamics public docker repo
docker pull appdynamics/ecommerce-activemq
docker pull appdynamics/ecommerce-lbr
docker pull appdynamics/ecommerce-oracle

echo "Local docker container images installed: "
echo "    appdynamics/ecommerce-java:oracle-java7"
echo "    appdynamics/ecommerce-tomcat"
echo "    appdynamics/ecommerce-synapse"
echo "    appdynamics/ecommerce-dbagent"
echo "    appdynamics/ecommerce-activemq"
echo "    appdynamics/ecommerce-lbr"
echo "    appdynamics/ecommerce-load"
echo "    appdynamics/ecommerce-oracle"

cleanUp
