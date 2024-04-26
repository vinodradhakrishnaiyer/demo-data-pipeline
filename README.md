# Demo Data Pipeline

Table of Contents
-----------------

-	[Introduction](#introduction)
-	[Architecture Diagram](#architecture)
-	[Installation](#installation)
    -   [Pre-requisites](#pre-requisites)
    -   [Quick Start Guide](#quick-start-guide)
-	[Helper Script](#helper-script)
	-	[Start the data pipeline](#start-the-data-pipeline)
	-	[Stop the data pipeline](#stop-the-data-pipeline)
    -	[Produce the events to the data pipeline](#produce-the-events-to-the-data-pipeline)
    -   [Monitor the data pipeline](#monitor-the-data-pipeline)
    -   [Get the status of all the components of the data pipeline](#get-the-status-of-all-the-components-of-the-data-pipeline)
-	[OpenSearch Dashboards](#opensearch-dashboards)
-	[Design Document](#design-document)


Introduction
-------------
This repository contains a ***Demo Data Pipeline*** that can be used to derive insights from [nginx_json_logs](https://raw.githubusercontent.com/elastic/examples/master/Common%20Data%20Formats/nginx_json_logs/nginx_json_logs) dataset. 

In the Demo Data Pipeline, the dataset is first produced to a message queue (Kafka) by a producer (Logstash). The events from the message queue (Kafka) are then consumed by a consumer (Logstash) which manipulates it to the below format, and indexes the events into an OpenSearch Cluster.

        {
            "time": 1426279439, // epoch time derived from the time field in the event
            "sourcetype": "nginx",
            "index": "nginx",
            "fields": {
                "region": "us-west-1",
                "assetid": "8972349837489237"
            },
            "event": {
                "remote_ip": "93.180.71.3",
                "remote_user": "-",
                "request": "GET /downloads/product_1 HTTP/1.1",
                "response": 304,
                "bytes": 0,
                "referrer": "-",
                "agent": "Debian APT-HTTP/1.3 (0.8.16~exp12ubuntu10.21)"
            } // this should be all of the data from the event itself, minus time
        }

A helper script ***(demo-data-pipeline.sh)*** has been provided to interact with the data pipeline. It can perform the following operations per user input:
-	[Start the data pipeline](#start-the-data-pipeline)
-	[Stop the data pipeline](#stop-the-data-pipeline)
-	[Produce the events to the data pipeline](#produce-the-events-to-the-data-pipeline)
-   [Monitor the data pipeline](#monitor-the-data-pipeline)
-   [Give the status of all the components of the data pipeline](#give-the-status-of-all-the-components-of-the-data-pipeline)

Finally, an [NGINX Log Analysis Dashboard](https://github.com/vinodradhakrishnaiyer/demo-data-pipeline/blob/main/opensearch-dashboards/) provides insight in to the dataset through 10 different visualizations of various types.

Architecture Diagram
---------------------
Below is the Architecture Diagram for the data pipeline.

Installation
-------------

#### Pre-requisites
Install [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git), [Docker](https://www.docker.com/get-docker), and [Docker Compose](https://docs.docker.com/compose/install/#install-compose) in order to run the steps provided in following Quick Start Guide.

#### Quick Start Guide

1. Clone the ***demo-data-pipeline*** repository to local machine:

        git clone https://github.com/vinodradhakrishnaiyer/demo-data-pipeline.git


2. Build the Docker containers for the components of the data pipeline and start the data pipeline:
    
        . ./demo-data-pipeline.sh start


3. For the initial start up of the data pipeline, set a password for OpenSearch ***admin*** user. Password must be a minimum 8 character password and must contain at least one uppercase letter, one lowercase letter, one digit, and one special character that is strong. The user receives the below prompt during the initial start up:

        vinodiyer@MacBook-Pro demo-data-pipeline % . ./demo-data-pipeline.sh start
        Selected option is 'Start the data pipeline'. Continue (y/n)?
        y
        Please enter the password to be set for OpenSearch 'admin' user:


4. Check the status of the data pipeline and confirm that *DOCKER CONTAINER HEALTH* of all components except *logstash-producer* and *opensearch-cluster* are *healthy*.

        . ./demo-data-pipeline.sh status

5. Produce events to the data pipeline:

        . ./demo-data-pipeline.sh produce-events

6. Login to OpenSearch Dashboards by navigating to [this](http://localhost:5601) link. The username for login is ***admin*** and the password is the one set in step 3. Import *NGINX Log Analysis Dashboard* to OpenSearch Dashboards, by navigating to *[this](http://localhost:5601/app/management/opensearch-dashboards/objects)* link (*Menu --> Dashboards Management --> Saved Objects*) and clicking import Select *osd_export.ndjson* file from *demo-data-pipeline/opensearch-dashboards* directory in the repository. Select *Check for existing objects* and *Automatically overwrite conflicts*. Click import, and the dashboard should be imported successfully.

7. View the *NGINX Log Analysis Dashboard* by navigating to *[this](http://localhost:5601/app/dashboards#/view/b39103e0-004a-11ef-b521-258cc7591416)* link.


Helper Script
--------------
A helper script ***(demo-data-pipeline.sh)*** has been provided to interact with the data pipeline. It can perform the following operations per user input. The general syntax for usage of the helper script is given below:

    . ./demo-data-pipeline <operation_name>

The five allowed values for ***operation_name*** are ***start***, ***stop***, ***produce-events***, ***monitor***, and ***status***.

#### Start the data pipeline

The below command can be used to start the data pipeline:

    . ./demo-data-pipeline.sh start


#### Stop the data pipeline

The below command can be used to stop the data pipeline:

    . ./demo-data-pipeline.sh stop

#### Produce the events to the data pipeline

The below command can be used to Produce the events to the data pipeline:

    . ./demo-data-pipeline.sh produce-events

#### Monitor the data pipeline

The below command can be used to monitor the data pipeline:

    . ./demo-data-pipeline.sh monitor

#### Get the status of all the components of the data pipeline

The below command can be used to get the status of all the components of the data pipeline:

    . ./demo-data-pipeline.sh status


***Note:*** Alternatively, the helper script can also be executed without any option to display the list of possible operations:

    vinodiyer@MacBook-Pro demo-data-pipeline % . ./demo-data-pipeline.sh

    Please select an operation for the data pipeline helper to execute (1/2/3/4/5):
    1. Start the data pipeline
    2. Stop the data pipeline
    3. Produce the events to the data pipeline
    4. Monitor the data pipeline
    5. Get the status of all the components of the data pipeline


OpenSearch Dashboards
----------------------
An [NGINX Log Analysis Dashboard](http://localhost:5601/app/dashboards#/view/b39103e0-004a-11ef-b521-258cc7591416) provides insight in to the dataset through 10 different visualizations of various types. These can be seen in the following screenshots. 

[NGINX Log Analysis Dashboard - Page1](https://github.com/vinodradhakrishnaiyer/demo-data-pipeline/blob/main/opensearch-dashboards/)

[NGINX Log Analysis Dashboard - Page2](https://github.com/vinodradhakrishnaiyer/demo-data-pipeline/blob/main/opensearch-dashboards/)

[NGINX Log Analysis Dashboard - Page3](https://github.com/vinodradhakrishnaiyer/demo-data-pipeline/blob/main/opensearch-dashboards/)

More details about each visualization can be found in the [Technical Design Document](https://github.com/vinodradhakrishnaiyer/demo-data-pipeline/blob/main/technical-design-document.pdf)

Once the data pipeline is started using the helper script, OpenSearch Dashboards can be accessed at [this](http://localhost:5601) url. The username for login is ***admin*** and the password is the one set using the helper script while starting the data pipeline.

To import *NGINX Log Analysis Dashboard* to OpenSearch Dashboards, navigate to *[this](http://localhost:5601/app/management/opensearch-dashboards/objects)* link (*Menu --> Dashboards Management --> Saved Objects*) and click import. Select *osd_export.ndjson* file from *opensearch-dashboards* directory in the repository. Select *Check for existing objects* and *Automatically overwrite conflicts*. Click import, and the dashboard should be imported.

The dashboard should be accessible at *[this](http://localhost:5601/app/dashboards#/view/b39103e0-004a-11ef-b521-258cc7591416)* link after successful import.


Design Document
--------------------------
For more details from the details of Demo Data Pipeline design, please read the ***[Technical Design Document](https://github.com/vinodradhakrishnaiyer/demo-data-pipeline/blob/main/technical-design-document.pdf)***