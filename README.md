# WFA_Snapshot_Datasource
WFA Datasource template to collect volume snapshot info and store in cache DB.  You can then use filters to query the snapshot info  and plug right into your application or report.  OCUM 6.x and up does not pull snapshot information as DFM 5.2 used to.  This pack connects directly to the CDOT clusters and pulls the information for you.


![alt text](https://github.com/storagedevops/WFA_Snapshot_Datasource/blob/master/images/clones.png "Example of application usage")

# Instructions

Download the dar file and import into your WFA server.

![alt text](https://github.com/storagedevops/WFA_Snapshot_Datasource/blob/master/images/import.png "Example of Importing the pack")

Create Datasource

![alt text](https://github.com/storagedevops/WFA_Snapshot_Datasource/blob/master/images/createDS.png)

Example of a filter call via API

![alt text](https://github.com/storagedevops/WFA_Snapshot_Datasource/blob/master/images/filtercall.png)


