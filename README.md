
# Solution description
This solution provides an example of how Common Media Client Data (**CMCD**) can be used with CloudFront, Amazon Timestream and Amazon Managed Grafana.
A dashboard with pre-defined set of widgets build out of CloudFront logs enriched with CMCD metrics will be provisioned after installation.
To generate some data for the dashboard, several clients running a media player are provisioned as well.

![Solution diagram](./img/cmcd_arch.png)


The following componets are provisioned:

- One HLS video asset hosted on S3.
- A web page hosting open source [HLS.js](https://github.com/video-dev/hls.js/) media player configured to play the video asset.
- Several [LightSail](https://aws.amazon.com/lightsail) instances in different regions running a python script in infinitive loop that opens the web page and starts the playback.
Instances simulate Mobile, Desktop and Smart TV clients.
Additionally, to generate rebuffering events, one instance in France is throttled to 500 Kbps bandwidth making it difficult for smooth playback.
- CloudFront distribution with Real-time logs that is used by clients to watch the video.
- Kinesis Data Stream to send CloudFront logs to.
- Lambda function to parse the logs and insert into Amazon Timestream.
- Grafana to be used for logs visualisation/dashboarding.

Since we are deploying 5 minutes HLS video asset it takes several minutes to clone the solution and also to install it.

Dashboard is provided, but it needs to be uploaded manually (see below).
There are two dashboards:
- 'QoE' contains visualisation of most common video metrics: rebuffering, number of concurrent plays, average play duration and others.
![QoE dashboard](./img/qoe.png)
- 'Troubleshooting' contains charts that are useful to find the root cause of rebuffering.

Both dashboards have Variables that can be used to filter in/out the data using various dimensions, e.g. Country, Device Type, Distribution, Streaming format etc.

## Prerequisites 
- Terrafrom 1.1.9+
- A user in [AWS Identity and Access Management](https://aws.amazon.com/iam/identity-center/) and the [organizational unit](https://aws.amazon.com/organizations/) to be used for administrating Grafana dashboard 
- AWS CLI with an active profile

## Provisioning
First, set up profile to be used to deploy solution, for example:
`export AWS_PROFILE=CMCD-demo`

```shell
# zip lambda
cd lambda && zip -r cmcd-log-processor.zip cmcd-log-processor.py && cd ..

# init Terraform
terraform init

# apply Terraform with the following parameters: 
# 1. deploy-to-region - where solution will be deployed. Check where Timestream and Grafana available
# 2. grafana_sso_organizational_units - org unit ID to use for Grafana SSO authentication
# 3. grafana_sso_admin_user_id - a user ID to use as Grafana admin
# 4. solution_prefix - a unique prefix will be added to solution resource names
# 
# Following variables are just examples:

terraform apply \
-var "deploy-to-region=eu-west-1" \
-var "solution_prefix=cmcd" \
-var "grafana_sso_organizational_units=r-yejd" \
-var "grafana_sso_admin_user_id=f4c804b8-c011-702f-66d1-f98f8e8b08f5"
```

If you encounter an error when deploying Lightsail instances:
```
Error: InvalidInputException: Sorry, your account can not create an instance using this Lightsail plan size. Please try a smaller plan size or contact Customer Support if you need to use a larger plan.
```
In this case just re-run `terraform apply` again.

As yet, Amazon Grafana provisioning cannot be fully automated. Perform the following steps to complete installation:

* Go to Grafana console, select *cf-grafana*, click *Assign new user or group*, select the user and click *assign users and groups*. Make sure the user has adming rights.
* Open Grafana (*Grafana workspace URL*), select *Configuration* -> *Data sources* and click *Add data source*
* Select *Amazon Timestream* as a data source, specify region used for provisining as *Default Region*
* Select *cmcd-db* as *Database* and *cmcd-table* as *Table* and *MULTI* as *measure*. Click *Save and test*
* Click plus sign in the left menu and select *import*
* Click *Upload JSON file* to upload a dashboard. Select dashboard from [dashboards](./dashboards)

## De-provisioning
```shell
terraform destroy  \
-var "deploy-to-region=eu-west-1" \
-var "solution_prefix=cmcd" \
-var "grafana_sso_organizational_units=r-yejd" \
-var "grafana_sso_admin_user_id=f4c804b8-c011-702f-66d1-f98f8e8b08f5"
```

## Dashboard walk-through.
By default, the dashboard is not refreshed automatically. It helps to minimize numbers of queries to Timestream when it is not needed and hence - its cost.
The dashboard can be refreshed by clicking  **Refresh Dashboard** in the top right hand menu or set to be refreshed automatically in the same menu.
Change Time picker in the same menu from *Last 30 minutes* to another time interval.
### QoE dashboard
1. This dashboard is intended to show QoE and traffic metrics.There are two sections (rows) - **Quality of experience** and **Traffic figures**. They can be minimized to help focus on other data. 
2. **Concurrent Plays** is estimated by counting the number of unique video session id (CMCD *sid* parameter) for the time period specified in Time picker.
Since it is only 5 minutes video constantly played, the same client can start different playbacks even within 5 minutes time interval.
3. **Rebuffering percentage** is calculated as percentage of requests signalling rebuffering (CMCD **bs**) to the total number of requests.
4. Find top contributor to **Rebuffering percentage** by selecting different countries in **Country** variable. How many rebuffering events are in the US and how many in France?
How the data changed in **Average Encoded Bitrate** and  **Average Throughput per Client** for the country producing most of rebuffering events?
5. Check **Average Throughput per Client** for the US and for Ireland (IE) - depending on in what region the solution has been installed, the S3 Origin can be closer to one or another country which affect the throughput for cache Miss case. If Cache Hit rate is close to 100%, feel free to invalidate CloudFront distribution.
6. Check the charts in **Quality of experience** section. Unlike the upper widgets, charts in this section are using percentile aggregation controlled by **Percentiles aggregation** variable.
7. Compare **Total Throughput** and **Measured Throughput** in **Traffic figures** section. **Total Throughput** is calculated from CDN logs, by dividing the sum of bytes sent to the viewers by the time period. 
This way the picks are smoothed over period of time.
**Measured Throughput** is measured from CMCD parameter *measured throughput* estimated by media player. In this case, traffic pick is not smoothed.
8. **Plays by GEO** map shows a number of concurrent sessions originated in a country. **Plays by PoP** shows a number of concurrent sessions terminated by a CloudFront PoP. It can help see accuracy of request routing.
### Troubleshooting dashboard
1. This dashboard is intended to help find a root cause of rebuffering events. **Rebuffering Ratio** is measured differently than in QoE dashboard. 
It quantifies the ratio of video sessions that have more than 1% of rebuffering requests to the total number of requests within selected **Interval**. 
For example, if the video chunks duration is 4 seconds, buffer length is 30 seconds, the player sends approx. 82 requests during 5 minutes. 
Therefore, just 2 requests signalling rebuffering would be more than 1% of all requests making the session being counted as stalled/rebuffered. 
Rebuffering Ratio chart can be used to set up an alert when percentage of rebuffering video plays exceeds a certain threshold and the root cause analysis is required.
2. Using variables try to locate rebuffering to Country, Device type or Edge location. If it is evident that rebufferig is related to one of these dimensions it already suggests what can cause the issue.
For example, if rebuffering happens on one of the CloudFront PoPs and for different viewer countries it signals that the PoP is under performing. 
3. **Rebuffering Events Count** shows the number of requests signalling rebuffering via CMCD parameter BS (Buffer starvation). It is sent by a player when it was in rebuffering state <ins>prior</ins> to this request. Therefore, here we use only dimensions that do not change during the same video playback - Country, Edge Location, Streaming format, Protocol, CloudFront distribution and Device type.
4. To aid on the root cause investigation, the next widget shows excerpt from logs for the request prior to Buffer starvation signal. It includes client IP to determine viewer network ASN and CloudFront request ID required by CloudFront support for performance related tickets. It enables for more accurate issues tracing.
Here we also can filter data by Response Result Type and HTTP status code.
5. To conduct more thorough investigation and understand whether rebuffering is caused by CDN or Origin, we use *Time-to-fist-byte* (TTFB) from CloudFront logs, which is the number of seconds between CloudFront server receives the request and writes the first byte of the response to the underlying kernel TCP stack.
There is no impact of external aspects on this value (such as network or the file size), therefore it is straightforward to use as an indication of a CDN server performance.
However, when request is Cache Miss, the CDN server needs to wait till the response from Origin arrived, therefore in this case TTFB indicates performance of Origin.
By using both TTFB for Cache and Miss case we can determine whether we need to focus investigation on CDN performance or Origin, and if there is no evidence on their performance degradation, the troubleshooting focus can be switched
on network or clients issues.
For this we merge TTFB and Rebuffering ratio on the same chart to see if one is correlated to another. 
For example, if there is simultaneous spike for both metrics it can signal correlation.
Sometimes, TTFB can vary significantly and still remain within acceptable values. 
For example, spike in TTFB from 10 ms to 20 ms is 100% increase but 20 ms is acceptable delay for the application to start delivering the first byte without causing performance issues. 
Therefore, it is important to pay attention to the actual values and not only on TTFB line volatility.
To help we that, we use 3rd line **Moving average TTFB** that measures the trend.
This allows not to be misled by occasional spikes but rather see if there is an uptrend signalling issues. 



## What is CMCD?
CMCD is a specification developed by WAVE (Web Application Video Ecosystem) project hosted by the Consumer Technology Association (CTA). It specifies how media players can convey QoE client-side metrics with each request, as a custom HTTP request header, as an HTTP query argument, or as a JSON object. CMCD specification containing full list of metrics can be found [here](https://cdn.cta.tech/cta/media/media/resources/standards/pdfs/cta-5004-final.pdf)

CMCD metrics enable customers to achieve various tasks, for example:

* **Session ID** (`sid`) identifies the current playback session and allows thousands of individual server log lines to be interpreted as a single user session and build reports on a session level. It can be also used for troubleshooting purposes: if there is a video session suffering from rebuffering, Session ID helps quickly find individual requests belonging to that session and provide them to Support for investigation.
* **Buffer starvation** (`bs`) signals that the player is in rebuffering state and the video or audio playback were stalled right before sending the request. It indicates an issue to be addressed. By checking corresponding server-side metrics we can verify operational health of CDN server and see whether the issue is related to the server, or the root cause resides elsewhere, for example, in specific network segment or Origin.
* **Buffer length** (`bl`), *Measured throughput* (mtp),  *Encoded bitrate* (br) and *Top bitrate* (tb) allow to monitor the quality of experience (QoE) and tell us how happy the viewers are. For example, you can monitor what throughput is available for your viewers in different Geo locations and plan your content encoding profile accordingly. Top bitrate flags the best quality bitrate available for viewers while Encoded bitrate is the actual used bitrate - in ideal scenario they should be the same and if not, the QoE is not at its best. You can even work out a formula for an overall quality of experience score out of these metrics and use it for benchmarking CDNs. 
* **Content ID** (`cid`), *Object duration* (d), *Playback rate* (pr), *Streaming format* (sf) and *Stream type* (st) can be used in content analytics to measure its popularity, engagement time and view it by various dimensions including Geo location, client device type and time of day.

Once CDN served the request, the full query string and all headers containing these metrics are written into a CDN log record from where they become available for data analytics purposes all together with corresponding QoS server-side metrics.

