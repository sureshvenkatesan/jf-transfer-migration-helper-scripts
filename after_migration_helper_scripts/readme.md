After migration is complete for hige mono repos you can setup replication .

For example for the merlin and liquid repos:
Replication configuration:
```
a)
0 15 10 ? * *
https://bose.jfrog.io/artifactory/liquid/
sureshv
_/*

b) 0 15 12 ? * *
https://bose.jfrog.io/artifactory/merlin/
```

---
Then check the replication status in the source JPD . But this requires Mission Control:

https://artifactory.bose.com/ui/admin/mission_control/replications/

If you get error like the following in the artifactorty-service.log , then you will need to restart the source JPD:
```
2023-09-07T00:01:54.965Z [jfrt ] [ERROR] [3446add118180e67] [uteLocalReplicationService:151] [p-nio-8081-exec-7989] - Error scheduling push replication for repo liquid and url https://bose.jfrog.io/artifactory/liquid/: Another manual task org.artifactory.repo.replication.PushReplicationJob is still active!
2023-09-07T00:01:54.965Z [jfrt ] [ERROR] [3446add118180e67] [uteLocalReplicationService:151] [p-nio-8081-exec-7989] - Error scheduling push replication for repo liquid and url https://bose.jfrog.io/artifactory/liquid/: Task org.artifactory.repo.replication.PushReplicationJob cannot stop a mandatory related job org.artifactory.repo.replication.PushReplicationJob while it's running!

```
After fixing that you should see the replication working :
```
2023-09-07T05:15:49.509Z [jfrt ] [INFO ] [34c68cba6f2321cb] [llLocalReplicationsService:115] [p-nio-8081-exec-8070] - Scheduling push replication task for repo liquid and url https://bose.jfrog.io/artifactory/liquid/
2023-09-07T05:15:49.614Z [jfrt ] [INFO ] [34c68cba6f2321cb] [plicationDescriptorHandler:173] [p-nio-8081-exec-8070] - Activating manual local repository replication for 'liquid'
2023-09-07T05:15:49.616Z [jfrt ] [INFO ] [34c68cba6f2321cb] [plicationDescriptorHandler:190] [p-nio-8081-exec-8070] - Replication activated manually for repository 'liquid'#https://bose.jfrog.io/artifactory/liquid/
2023-09-07T05:15:49.638Z [jfrt ] [INFO ] [9c39c6b02444bf8a] [o.a.a.c.BasicStatusHolder:218 ] [art-exec-990852     ] - Starting local folder replication for 'liquid'.
2023-09-07T05:15:49.669Z [jfrt ] [INFO ] [9c39c6b02444bf8a] [eplicationStrategySelector:120] [art-exec-990852     ] - Source liquid Request force Strategy TREE
2023-09-07T05:15:49.670Z [jfrt ] [INFO ] [9c39c6b02444bf8a] [o.a.a.r.g.s.PushReplicator:77 ] [art-exec-990852     ] - FULL Push Replication strategy selected for liquid:
2023-09-07T05:15:49.751Z [jfrt ] [INFO ] [9c39c6b02444bf8a] [o.a.a.c.BasicStatusHolder:218 ] [ent replication 2551] - Replicating properties: https://bose.jfrog.io/artifactory/liquid//:properties
2023-09-07T05:15:49.784Z [jfrt ] [INFO ] [9c39c6b02444bf8a] [.c.BaseReplicationProducer:230] [art-exec-990852     ] - Executing file list request: 'https://bose.jfrog.io/artifactory/api/storage/liquid/?list&deep=1&listFolders=1&mdTimestamps=1&statsTimestamps=1&includeRootPath=1'
2023-09-07T05:15:49.796Z [jfrt ] [INFO ] [9c39c6b02444bf8a] [o.a.a.c.BasicStatusHolder:218 ] [ent replication 2551] - Properties deleted: https://bose.jfrog.io/artifactory/liquid//:properties

```
