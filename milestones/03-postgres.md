# Milestone 3: PostgreSQL

Deploy PostgreSQL 16 and verify connectivity.

## Goals

- [ ] PostgreSQL 16 StatefulSet with persistent volume
- [ ] Service for internal cluster access
- [ ] Local script to psql into the instance

## Reference

See `~/infrastructure_/terraform/` for previous postgres setup patterns.

## Test Script

Local script that connects via kubectl port-forward or direct connection:

```bash
#!/usr/bin/env bash
# scripts/psql-connect.sh
kubectl port-forward svc/postgres 5432:5432 &
PF_PID=$!
sleep 2
psql -h localhost -U postgres -c "SELECT version();"
kill $PF_PID
```

## Success Criteria

- PostgreSQL pod running with persistent storage
- Can connect and run queries from local machine
- Data persists across pod restarts
