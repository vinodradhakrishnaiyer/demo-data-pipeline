#!/bin/bash

###################################################################################################################
# This helper script enables the user to operate the data pipeline. The script allows the following operations:
# 1. Start the data pipeline 
# 2. Stop the data pipeline
# 3. Produce the events to the data pipeline
# 4. Monitor the data pipeline
# 5. Get the status of all the components of the data pipeline
###################################################################################################################

# start_data_pipeline function definition
function start_data_pipeline {
    echo "\nSelected option is 'Start the data pipeline'. Continue (y/n)?"
    continue=`read -er | tr '[:upper:]' '[:lower:]'`
    if [[ "$continue" == "y"  ]]; then
        # Check if OpenSearch password is set in env variable
        if [[ -z "${opensearch_pwd}" ]]; then
            echo "\nPlease enter the password to be set for OpenSearch 'admin' user:"
            opensearch_pwd=`read -ers`
            export opensearch_user=admin
            export opensearch_pwd=$opensearch_pwd              
        fi
        # Start all components of the data pipeline except logstash-producer
        echo "\nStarting the data pipeline ..."
        docker-compose up -d zookeeper kafka kafka-init opensearch-node1 opensearch-node2 opensearch-dashboards logstash-consumer
        echo "\nWaiting for 10 seconds for the components to be available ..."
        sleep 10
        get_component_status 
    else
        echo "Exiting helper, goodbye!\n"
    fi
}

# stop_data_pipeline function definition
function stop_data_pipeline {
    echo "\nSelected option is 'Stop the data pipeline'. Continue (y/n)?"
    continue=`read -er | tr '[:upper:]' '[:lower:]'`
    if [[ "$continue" == "y" ]]; then
        echo "\nStopping the data pipeline ..."
        docker-compose down
        echo "\nExiting helper, goodbye!\n"
    else
        echo "Exiting helper, goodbye!\n"
    fi
}

# start_logstash_producer function definition
function start_logstash_producer {
            echo "\nStarting logstash-producer component ...\n"
            docker-compose up -d logstash-producer
            echo "\nWaiting for 5 seconds for logstash-producer component to start up ..."
            sleep 5
            echo "\nChecking the status of logstash-producer component ..."            
            if [[ "`docker container ls | grep logstash-producer | wc -l | tr -d " "`" == "1" ]]; then
                ls_producer_health=`docker ps --format json | grep logstash-producer | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
                ls_producer_status=`curl -XGET "localhost:9801/?pretty" -ks | grep status | tr -d ", " | sed -nr 's/.*status":"(.*)"/\1/p'`
                # Display component status as a table
                seperator=""
                rows="%-22s  %-35s  %-25s\n"
                TableWidth=100

                printf "%-22s  %-35s  %-25s\n" "COMPONENT NAME" "DOCKER CONTAINER HEALTH" "COMPONENT STATUS"
                printf "%.${TableWidth}s" "$seperator"
                printf "$rows" "logstash-producer" $ls_producer_health $ls_producer_status
            else
                echo "logstash-producer: \nNot started"
            fi             
            echo "\nProducing the events to the data pipeline ... \n \nPlease check OpenSearch Dashboards in a few minutes at https://localhost:5601 (nginx index pattern) for viewing the produced events.\n\nShutting down logstash-producer ...\n\nExiting helper, goodbye!\n"  
}

# produce_events function definition
function produce_events {
    echo "\nSelected option is 'Produce the events to the data pipeline'. Continue (y/n)?"
    continue=`read -er | tr '[:upper:]' '[:lower:]'`
    if [[ "$continue" == "y" ]]; then
        echo "\nChecking for existing data in OpenSearch ..."
        nginx_log_count=`curl -XGET "https://localhost:9200/nginx/_count?pretty" -u $opensearch_user:$opensearch_pwd -ks | grep "count" | tr -d "," | cut -c13-`
        # Compare document count in nginx index in OpenSearch to line count in nginx_json_logs file
        if [[ "$nginx_log_count" -ge "`cat dataset/nginx_json_logs | wc -l | tr -d " "`" ]]; then
            echo "\nnginx_json_logs dataset has already been ingested to OpenSearch. Continuing with producing the events to the data pipeline will result in duplicate data to be ingested to OpenSearch.\nDo you want to continue producing the events to the data pipeline anyway (y/n)?"
            continue_anyway=`read -er | tr '[:upper:]' '[:lower:]'`
            if [[ "$continue_anyway" == "y" ]]; then
                start_logstash_producer
            else
                echo "\nExiting helper, goodbye!\n"
            fi
        else
            start_logstash_producer
        fi
    else
        echo "Exiting helper, goodbye!\n"
    fi  
}

# monitor_data_pipeline function definition
function monitor_data_pipeline {
    echo "\nMonitoring the data pipeline ...\n"
    echo "DOCKER STATS:\n"
    echo "Retrieving the Docker Stats for all components ...\n"
    docker stats --no-stream
    echo "\n"
    echo "DATA PIPELINE COMPONENT STATUS:"
    get_component_status
    
    echo "COMPONENT ERROR LOGS COUNT:\n"
    # Retrieve count of error logs for each component
    ls_producer_error_logs=`docker compose logs logstash-producer | grep "error" | wc -l | tr -d " "`
    kafka_error_logs=`docker compose logs kafka | grep "error" | wc -l | tr -d " "`
    zk_error_logs=`docker compose logs zookeeper | grep "error" | wc -l | tr -d " "`
    ls_consumer_error_logs=`docker compose logs logstash-consumer | grep "error" | wc -l | tr -d " "`
    os_node1_error_logs=`docker compose logs opensearch-node1 | grep "error" | wc -l | tr -d " "`
    os_node2_error_logs=`docker compose logs opensearch-node2 | grep "error" | wc -l | tr -d " "`
    osd_error_logs=`docker compose logs opensearch-dashboards | grep "error" | wc -l | tr -d " "`

    echo "Retrieving count of error logs from all components ...\n"

    # Display component error logs count as a table
    seperator=""
    rows="%-22s  %-25s\n"
    TableWidth=100

    printf "%-22s  %-25s\n" "COMPONENT NAME" "COUNT OF ERROR LOGS"
    printf "%.${TableWidth}s" "$seperator"
    printf "$rows" "logstash-producer" $ls_producer_error_logs
    printf "$rows" "zookeeper" $zk_error_logs
    printf "$rows" "kafka" $kafka_error_logs
    printf "$rows" "logstash-consumer" $ls_consumer_error_logs
    printf "$rows" "opensearch-node1" $os_node1_error_logs                    
    printf "$rows" "opensearch-node2" $os_node2_error_logs
    printf "$rows" "opensearch-dashboards" $osd_error_logs
    echo "\nExecute the following command to view the error logs for a component:\ndocker compose logs <component_name> | grep error\n"
    echo "Exiting helper, goodbye!\n"
}

# get_component_status function definition
function get_component_status {
    echo "\nChecking the status of all the components of the data pipeline ...\n"

    # logstash-producer status
    if [[ "`docker container ls | grep logstash-producer | wc -l | tr -d " "`" == "1" ]]; then
        ls_producer_health=`docker ps --format json | grep logstash-producer | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
        ls_producer_status=`curl -XGET "localhost:9801/?pretty" -ks | grep status | tr -d ", " | sed -nr 's/.*status":"(.*)"/\1/p'`
    else
        ls_producer_status="n/a"
        ls_producer_health="not started"
    fi

    # zookeeper status
    zk_health=`docker ps --format json | grep cp-zookeeper | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
    zk_status="n/a"

    # kafka status
    kafka_health=`docker ps --format json | grep cp-kafka | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
    kafka_status="n/a"

    # logstash-consumer status
    ls_consumer_health=`docker ps --format json | grep logstash-consumer | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
    ls_consumer_status=`curl -XGET "localhost:9800/?pretty" -ks | grep status | tr -d ", " | sed -nr 's/.*status":"(.*)"/\1/p'`

    # opensearch status
    os_node1_health=`docker ps --format json | grep opensearch-node1 | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
    os_node2_health=`docker ps --format json | grep opensearch-node2 | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
    opensearch_health=`curl -XGET "https://localhost:9200/_cluster/health?pretty" -ks -u $opensearch_user:$opensearch_pwd | grep status | tr -d ", " | sed -nr 's/.*status":"(.*)"/\1/p'`   

    # opensearch-dashboards status
    osd_health=`docker ps --format json | grep opensearch-dashboards | sed -nr 's/.*Status"(.*)".*/\1/p' | tr -d ":\""`
    osd_status=`curl -XGET "http://localhost:5601/api/status" -ks -u $opensearch_user:$opensearch_pwd | grep status | tr -d "," | sed -nr 's/.*Z"(.*)"title.*/\1/p' | sed -nr 's/.*state":"(.*)"/\1/p'`            

    # Display component status as a table

    seperator=""
    rows="%-22s  %-35s  %-25s\n"
    TableWidth=100

    printf "%-22s  %-35s  %-25s\n" "COMPONENT NAME" "DOCKER CONTAINER HEALTH" "COMPONENT STATUS"
    printf "%.${TableWidth}s" "$seperator"
    printf "$rows" "logstash-producer" $ls_producer_health $ls_producer_status
    printf "$rows" "zookeeper" $zk_health $zk_status
    printf "$rows" "kafka" $kafka_health $kafka_status
    printf "$rows" "logstash-consumer" $ls_consumer_health $ls_consumer_status
    printf "$rows" "opensearch-node1" $os_node1_health n/a                    
    printf "$rows" "opensearch-node2" $os_node2_health n/a
    printf "$rows" "opensearch-cluster" n/a $opensearch_health
    printf "$rows" "opensearch-dashboards" $osd_health $osd_status
    echo "\nExiting helper, goodbye!\n"
}

function cleanup_variables {
    user_selection=""
    cli_argument=""
    continue=""
    ls_consumer_health=""
    ls_consumer_status=""
    ls_consumer_error_logs=""
    ls_producer_health=""
    ls_producer_status=""
    ls_producer_error_logs=""
    zk_health=""
    zk_status=""
    zk_error_logs=""
    kafka_health=""
    kafka_status=""
    kafka_error_logs=""
    os_node1_health=""
    os_node1_status=""
    os_node1_error_logs=""
    os_node2_health=""
    os_node2_status=""
    os_node2_error_logs=""
    osd_health=""
    osd_status=""
    osd_error_logs=""
}

function main_data_pipeline {
    # Check if any argument is passed via Command Line Input(CLI)
    # Provide selection options to the user in case no CLI argument is provided 
    if [ -z "$1" ]; then
        echo "\nPlease select an operation for the data pipeline helper to execute (1/2/3/4/5): \n 1. Start the data pipeline \n 2. Stop the data pipeline \n 3. Produce the events to the data pipeline \n 4. Monitor the data pipeline \n 5. Get the status of all the components of the data pipeline\n"
        user_selection=`read -er`

    # Retrieve CLI argument provided by the user
    else
        cli_argument=$1
    fi

    # 1. Start the data pipeline
    if [[ "$user_selection" == "1" ]] || [[ "$cli_argument" == "start" ]]; then
        start_data_pipeline

    # 2. Stop the data pipeline
    elif [[ "$user_selection" == "2" ]] || [[ "$cli_argument" == "stop" ]]; then
        stop_data_pipeline

    # 3. Produce the events to the data pipeline
    elif [[ "$user_selection" == "3" ]] || [[ "$cli_argument" == "produce-events" ]]; then
        produce_events

    # 4. Monitor the data pipeline
    elif [[ "$user_selection" == "4" ]] || [[ "$cli_argument" == "monitor" ]]; then
        monitor_data_pipeline

    # 5. Get the status of all the components of the data pipeline
    elif [[ "$user_selection" == "5" ]] || [[ "$cli_argument" == "status" ]]; then
        get_component_status        

    # Unsupported arguments passed to helper
    else
        echo "\nUnsupported argument passed to helper.\nExiting helper, goodbye!"
    fi
}

# Execute main_data_pipeline function
main_data_pipeline $1

# Cleanup variables
cleanup_variables