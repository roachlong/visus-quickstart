# visus-quickstart
[Visus](https://github.com/cockroachlabs/visus) is a tool created by [Cockroach Labs](https://cockroachlabs.com/) Field Engineering team to allow the creation of custom metrics and expose them to a [Prometheus](https://prometheus.io/) instance.  User can turn custom SQL queries that they have created over the CRDB system and internal tables into Prometheus metrics to monitor specific behaviors not available with CRDB’s canned Prometheus metrics.  Further, metrics can be created that are more granular, such as at the database or application level. The purpose of this repository is to get started using Visus quickly

## Prerequisites:
As a first step, it's strongly recommended that you setup your Prometheus instance using the [Monitor CockroachDB with Prometheus](https://www.cockroachlabs.com/docs/stable/monitor-cockroachdb-with-prometheus) guide. It will guide you through the setting up of the basic Prometheus integration with CRDB and provide you with some baseline metrics to get started monitoring CRDB through Prometheus

## Getting Started:

There are two ways to deploy Visus on CRDB clusters:
Self Hosted Traditional
Self Hosted Kubernetes   


## Self Hosted Traditional
The steps to install, configure and start Visus on a non-Kubernetes CRDB deployment are straightforward.
- Deploy a CRDB cluster using your normal/preferred deployment process or tooling.
- [Monitor CockroachDB with Prometheus](https://www.cockroachlabs.com/docs/stable/monitor-cockroachdb-with-prometheus)
- Install the Visus executable on each node in the CRDB cluster to run as a sidecar process.
- Initialize the Visus database on one of the Visus nodes via `visus init`
- Start the Visus process on each node. `visus start`
- Load Visus metric profiles to the cluster. `visus collection put -o yaml < query_count.yaml`
- Configure your Prometheus instance to scrape the Visus endpoint. 

__This link is a roachprod script to deploy a CRDB cluster in GCP, configure a Prometheus VM in the same GCP region and apply the necessary prometheus configuration file to scrape the Visus endpoint.  I have used this script to deploy Visus demos for customers and to show customers the components and steps needed to deploy Visus.__

Once Prometheus is configured and started on the standalone VM point your browser to port 9090 on the public/external address of the VM.  The Prometheus UI will be displayed.  Click on Status and select Targets.  This will show you Visus instances that are reporting metrics.  

__Promethus Image Here__

With healthy Prometheus targets and a by loading the following Visus collection on each node by 
```
name: active_conn
enabled: true
scope: cluster
frequency: 15
maxresults: 50
labels: [application_name]
metrics:
  - name : num_conn
    kind : gauge
    help : number of conns per applications
query:
  SELECT
      application_name::string,
      count(*)::float as num_conn
  FROM
      crdb_internal.cluster_sessions
  WHERE
      active_queries <> ''
  GROUP BY
      1
  ORDER BY
      2 DESC
  LIMIT
      $1;
```

We can view active connections by application name and the output in Prometheus looks like the following
__Promethus Graph Here__





## Self Hosted Kubernetes   
Similarly, in a Kubernetes deployment, an instance of Visus needs to run adjacent to each CRDB pod on each Kubernetes worker node.  This can be accomplished in Kubernetes by running Visus as a DaemonSet.  When the DaemonSet manifest file is applied against the Kubernetes cluster, a Visus pod is created on each Kubernetes worker node.

If you don’t have a deployment of CRDB running on Kubernetes, follow the instructions here.  I created a secure CRDB deployment on GKE using manual statefulset config files.  Edit the statefulset to pull the desired version of CRDB.  I used the container image cockroachdb/cockroach:v23.2.12 to match the version my customers are running.  

Once you have deployed CRDB, verify the CRDB pods are in a ready status.
```
% kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
cockroachdb-0               1/1     Running   0          15d
cockroachdb-1               1/1     Running   0          15d
cockroachdb-2               1/1     Running   0          15d
cockroachdb-client-secure   1/1     Running   0          11d
```

The DaemonSet manifest file I created to run Visus in Kubernetes can be found here.  Note that the Cockroach certificates are mounted similarly as they are in the CRDB statefulset manifest so that Visus can use the certs to access the secure CRDB cluster.  Apply the manifest file with the command. 
```
% kubectl create -f visus-daemonset.yaml
daemonset.apps/visus created

Verify that the Visus pods are created and in a ready status.
% kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
cockroachdb-0               1/1     Running   0          15d
cockroachdb-1               1/1     Running   0          15d
cockroachdb-2               1/1     Running   0          15d
cockroachdb-client-secure   1/1     Running   0          11d
visus-f6bx6                 1/1     Running   0          11d
visus-lxrmr                 1/1     Running   0          11d
visus-vmq9z                 1/1     Running   0          11d
```
With the Visus pods running we can now initialize and load metric configurations.  This presents a bit of a challenge because the Visus docker image is not built on a base image that contains bash or any other command line tooling.  All Visus commands must be executed as kubectl commands instead of using kubectl to exec into the Visus pods and issue “normal” linux commands.

To initialize Visus run the following command.  Note that the certificate paths in the postgresql connection string below map to the secrets mountPath in the visus-daemonset.yaml manifest.
```
% kubectl exec -it visus-f6bx6 -- visus init --url "postgresql://root@cockroachdb-0.cockroachdb:26257/defaultdb?sslmode=verify-full&sslrootcert=/cockroach/cockroach-cert/ca.crt&sslcert=/cockroach/cockroach-cert/client.root.crt&sslkey=/cockroach/cockroach-cert/client.root.key"
```

Start a CRDB command line SQL session to verify the _visus database and tables were created.
```
root@cockroachdb-public:26257/_visus> show tables;                                                                                                    
  schema_name | table_name | type  | owner | estimated_row_count | locality
--------------+------------+-------+-------+---------------------+-----------
  public      | collection | table | root  |                   1 | NULL
  public      | histogram  | table | root  |                   0 | NULL
  public      | metric     | table | root  |                   1 | NULL
  public      | node       | table | root  |                   0 | NULL
  public      | pattern    | table | root  |                   0 | NULL
  public      | scan       | table | root  |                   0 | NULL
(6 rows)
```

To load the metric configuration (collection) contained in the query_count.yaml file with definition found here, use the following command
```
% kubectl exec -it visus-f6bx6 -- visus --url "postgresql://root@cockroachdb-0.cockroachdb:26257/defaultdb?sslmode=verify-full&sslrootcert=/cockroach/cockroach-cert/ca.crt&sslcert=/cockroach/cockroach-cert/client.root.crt&sslkey=/cockroach/cockroach-cert/client.root.key" collection put --yaml - < query_count.yaml
```

To test metric configuration (collection) that you just inserted is valid, use the following command
```
% kubectl exec -it visus-f6bx6 -- visus --url "postgresql://root@cockroachdb-0.cockroachdb:26257/defaultdb?sslmode=verify-full&sslrootcert=/cockroach/cockroach-cert/ca.crt&sslcert=/cockroach/cockroach-cert/client.root.crt&sslkey=/cockroach/cockroach-cert/client.root.key" collection test query_count --count 2
```

Which gives the following output showing that Visus is setup and configured correctly on Kubernetes.
```
---- 10-22-2024 19:50:13 query_count -----
# HELP query_count_exec_count statement count per application and database.
# TYPE query_count_exec_count counter
query_count_exec_count{application="",database="defaultdb"} 3
---- 10-26-2024 19:50:23 query_count -----
# HELP query_count_exec_count statement count per application and database.
# TYPE query_count_exec_count counter
query_count_exec_count{application="",database="defaultdb"} 4
```

All of the configuration files, executable objects and supporting files can be found in this Google Drive location.

Install helm
```
brew install helm

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm search repo prometheus-community
helm install prometheus prometheus-community/prometheus

kubectl port-forward service/prometheus-server 9090:80
<prometheus configured>
```
