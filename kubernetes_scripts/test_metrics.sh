#!/usr/bin/env bash
for CRDB_NODE in $(kubectl get pods -o json | jq -r '.items[] | select(.metadata.name | test("^my-release-cockroachdb-[0-9]")) | .metadata.name')
do 
    echo 📈Testing node $CRDB_NODE metrics📈
    kubectl exec -it $CRDB_NODE -c visus  -- visus \
        --url "postgres://root@localhost:26257/defaultdb?application_name=visus&sslmode=require&sslrootcert=/cockroach/client/ca.crt&sslcert=/cockroach/client/client.root.crt&sslkey=/cockroach/client/client.root.key" \
 	collection test query_count --count 2
    echo 📈Testing Complete📈
done

