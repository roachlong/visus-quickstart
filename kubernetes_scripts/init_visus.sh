#!/usr/bin/env bash
kubectl exec -it my-release-cockroachdb-0  -c visus -- visus \
      init \
      --url \
      "postgres://root@localhost:26257/defaultdb?application_name=visus&sslmode=require&sslrootcert=/cockroach/client/ca.crt&sslcert=/cockroach/client/client.root.crt&sslkey=/cockroach/client/client.root.key"
