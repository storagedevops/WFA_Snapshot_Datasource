<#
This script collects volume snapshot information from the Clustered Data ONTAP.

Snapshot
- Volume
- Name
- Timestamp
- Cluster
- Vserver
- Snapshot ID

Note : Cluster credentials must be configured in the Credentials tab.
Version 1.1 - filtering vservers and leaving snapmirror snaps out
#>

# Ensure that dates are always returned in English
[System.Threading.Thread]::CurrentThread.CurrentCulture="en-US"

# Create the output file
$snapshot_csv = "./snapshots.csv"
New-Item -Path $snapshot_csv -type file -force

Function Get-ConnectionInfo() {
    $connectionInfo = @{};

    Try {
        $connectionInfo["host"] = Get-WfaRestParameter "host"
        $connectionInfo["port"] = Get-WfaRestParameter "port"
        $connectionInfo["credentials"] = Get-WfaCredentials
    }
    Catch [System.Exception] {
        $error = "Error getting data source credentials: $($_.Exception)"
        Get-WFALogger -message $error -Error
        Throw "Error getting data source credentials."
    }

    return $connectionInfo
}
$connectionInfo = Get-ConnectionInfo
$cluster_addr = $connectionInfo["host"]

Get-WFALogger -message "Retrieving list of Snapshots from Cluster $cluster_addr" -Info
try
{
  Connect-WfaCluster $cluster_addr -Timeout 300000
}
catch [system.exception]
{
  $error = "Error connecting to cluster $cluster_addr : $($_.Exception)"
  Get-WFALogger -message $error -Error
  Throw $error
}

$ClusterName = (Get-NcCluster).ClusterName
$query = @{
    Vserver = 'vsnfsbbl*';
    Name = '!*snapmirror*';
   }
$attr =  @{
    AccessTime = "";
    Dependency = "";
    SnapshotInstanceUuid = "";
   }

$vol_snapshots = Get-NcSnapshot -Query $query -Attributes $attr

        foreach($snapshot in $vol_snapshots)
          {
                    $Vserver = $snapshot.Vserver
                    $Cluster = $ClusterName.ClusterName
                    $Volume = $snapshot.Volume
                    $SnapshotName = $snapshot.Name
                    $Dependency = $snapshot.Dependency
                    $SnapshotID = $snapshot.SnapshotInstanceUuid
                    $Timestamp = ($snapshot.AccessTimeDT).ToString("yyyy-MM-dd HH:mm:ss")
                    # Add content to file
                    Add-Content $snapshot_csv ([byte[]][char[]] "\N`t$Cluster`t$SnapshotName`t$Timestamp`t$Volume`t$Vserver`t$Dependency`t$SnapshotID`n") -Encoding Byte
                    # This is required to ensure that the output file is UNIX encoded, without which MySQL's LOAD DATA
					# command does not work
 }
