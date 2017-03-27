<#
This script collects volume snapshot information from the Clustered Data ONTAP.

Snapshot
- Volume
- Name
- Timestamp
- Cluster
- Vserver

Note : Cluster credentials must be configured in the Credentials tab.
#>

# Ensure that dates are always returned in English
[System.Threading.Thread]::CurrentThread.CurrentCulture="en-US"

# Create the output file
$snapshot_csv = "c:\volume_snaps.csv"
New-Item -Path $snapshot_csv -type file -force

#Function Get-ConnectionInfo() {
    #$connectionInfo = @{};

    #Try {
     #   $connectionInfo["host"] = Get-WfaRestParameter "host"
     #   $connectionInfo["port"] = Get-WfaRestParameter "port"
      #  $connectionInfo["credentials"] = Get-WfaCredentials
   # }
   # Catch [System.Exception] {
     #   $error = "Error getting data source credentials: $($_.Exception)"
      #  Get-WFALogger -message $error -Error
      #  Throw "Error getting data source credentials."
    #}

    #return $connectionInfo
#}
#$connectionInfo = Get-ConnectionInfo
$cluster_addr = "trcl1va2cm.mhint"

#Get-WFALogger -message "Retrieving list of Snapshots from Cluster $cluster_addr" -Info
#try 
#{
 # Connect-WfaCluster $cluster_addr -Timeout 300000
#}
#catch [system.exception] 
#{
  #$error = "Error connecting to cluster $cluster_addr : $($_.Exception)" 
 # Get-WFALogger -message $error -Error
  #Throw $error
#}

$vservers = Get-NcVserver
foreach ($vserver in $vservers)
{
    $volumes = Get-NcVol -vserver $vserver.Vserver
    foreach($volume in $volumes)
    {
        $vol_snapshots = Get-NcSnapshot -vserver $vserver.Vserver -volume $volume.name
        if ($vol_snapshots)
        {
            foreach($snapshot in $vol_snapshots)
            {
                if ($snapshot.Name -ne "")
                {
                    $Vserver = $snapshot.Vserver
                    $Cluster = $cluster_addr
                    $Volume = $snapshot.Volume
                    $SnapshotName = $snapshot.Name
                    $Dependency = $snapshot.Dependency
                    $Timestamp = Get-Date ([datetime]'1/1/1970').AddSeconds($snapshot.AccessTime) -f "yyyy-MM-dd HH:mm:ss" 
                    # Add content to file
                    Add-Content $snapshot_csv ([byte[]][char[]] "\N`t$Cluster`t$SnapshotName`t$Timestamp`t$Volume`t$Vserver`t$Dependency`n") -Encoding Byte
                    # This is required to ensure that the output file is UNIX encoded, without which MySQL's LOAD DATA
					# command does not work
                }
            }
      }
    }
}
