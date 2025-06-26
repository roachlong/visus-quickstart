#!/usr/bin/env bash
for CRDB_NODE in $(kubectl get pods -o json | jq -r '.items[] | select(.metadata.name | test("^my-release-cockroachdb-[0-9]")) | .metadata.name')
do 
    kubectl exec -it $CRDB_NODE -c visus  -- visus \
        --url "postgres://root@localhost:26257/defaultdb?application_name=visus&sslmode=require&ssrootcert=/cockroach/client/ca.crt&sslcert=/cockroach/client/client.root.crt&sslkey=/cockroach/client/client.root.key" \
        collection put --yaml - < query_count.yaml
    done

