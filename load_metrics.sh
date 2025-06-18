for each visus node 
    kubectl exec -it visus_node -- visus --url "postgresql://root@cockroachdb-0.cockroachdb:26257/defaultdb?sslmode=verify-full&sslrootcert=/cockroach/cockroach-cert/ca.crt&sslcert=/cockroach/cockroach-cert/client.root.crt&sslkey=/cockroach/cockroach-cert/client.root.key" collection put --yaml - < query_count.yaml
done
