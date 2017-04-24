<#
This script collects volume snapshot information from the Clustered Data ONTAP.

Snapshot
- Volume
- Name
- Timestamp
- Cluster
- Vserver

Note : Cluster credentials must be configured in the Credentials tab.
Version 1.1 - filtering vservers and leaving snapmirror snaps in
#>

# Ensure that dates are always returned in English
[System.Threading.Thread]::CurrentThread.CurrentCulture="en-US"

Add-Type -TypeDefinition @"
	public enum Syslog_Facility
	{
		kern,
		user,
		mail,
		daemon,
		auth,
		syslog,
		lpr,
		news,
		uucp,
		clock,
		authpriv,
		ftp,
		ntp,
		logaudit,
		logalert,
		cron, 
		local0,
		local1,
		local2,
		local3,
		local4,
		local5,
		local6,
		local7,
	}
"@

Add-Type -TypeDefinition @"
	public enum Syslog_Severity
	{
		Emergency,
		Alert,
		Critical,
		Error,
		Warning,
		Notice,
		Informational,
		Debug
	}
"@

function Send-SyslogMessage
{
<#
.SYNOPSIS
Sends a SYSLOG message to a server running the SYSLOG daemon

.DESCRIPTION
Sends a message to a SYSLOG server as defined in RFC 5424. A SYSLOG message contains not only raw message text,
but also a severity level and application/system within the host that has generated the message.

.PARAMETER Server
Destination SYSLOG server that message is to be sent to

.PARAMETER Message
Our message

.PARAMETER Severity
Severity level as defined in SYSLOG specification, must be of ENUM type Syslog_Severity

.PARAMETER Facility
Facility of message as defined in SYSLOG specification, must be of ENUM type Syslog_Facility

.PARAMETER Hostname
Hostname of machine the mssage is about, if not specified, local hostname will be used

.PARAMETER Timestamp
Timestamp, myst be of format, "yyyy:MM:dd:-HH:mm:ss zzz", if not specified, current date & time will be used

.PARAMETER UDPPort
SYSLOG UDP port to send message to

.INPUTS
Nothing can be piped directly into this function

.OUTPUTS
Nothing is output

.EXAMPLE
Send-SyslogMessage mySyslogserver "The server is down!" Emergency Mail
Sends a syslog message to mysyslogserver, saying "server is down", severity emergency and facility is mail

.NOTES
NAME: Send-SyslogMessage

#>
[CMDLetBinding()]
Param
(
	[Parameter(mandatory=$true)] [String] $Server,
	[Parameter(mandatory=$true)] [String] $Message,
	[Parameter(mandatory=$true)] [Syslog_Severity] $Severity,
	[Parameter(mandatory=$true)] [Syslog_Facility] $Facility,
	[String] $Hostname,
	[String] $Timestamp,
	[int] $UDPPort = 514
)

# Create a UDP Client Object
$UDPCLient = New-Object System.Net.Sockets.UdpClient
$UDPCLient.Connect($Server, $UDPPort)

# Evaluate the facility and severity based on the enum types
$Facility_Number = $Facility.value__
$Severity_Number = $Severity.value__
Write-Verbose "Syslog Facility, $Facility_Number, Severity is $Severity_Number"

# Calculate the priority
$Priority = ($Facility_Number * 8) + $Severity_Number
Write-Verbose "Priority is $Priority"

# If no hostname parameter specified, then set it
if (($Hostname -eq "") -or ($Hostname -eq $null))
{
	$Hostname = Hostname
}

# I the hostname hasn't been specified, then we will use the current date and time
if (($Timestamp -eq "") -or ($Timestamp -eq $null))
{
	$Timestamp = Get-Date -Format "MMM dd hh:mm:ss"
}

# Assemble the full syslog formatted message
$FullSyslogMessage = "<{0}>{1} {2}" -f $Priority, $Timestamp, $Message

# create an ASCII Encoding object
$Encoding = [System.Text.Encoding]::ASCII

# Convert into byte array representation
$ByteSyslogMessage = $Encoding.GetBytes($FullSyslogMessage)

# If the message is too long, shorten it
if ($ByteSyslogMessage.Length -gt 1024)
{
    $ByteSyslogMessage = $ByteSyslogMessage.SubString(0, 1024)
}

# Send the Message
$UDPCLient.Send($ByteSyslogMessage, $ByteSyslogMessage.Length)

}

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

$ClusterName = Get-NcCluster
$ActualClusterName = $ClusterName.ClusterName

Send-SyslogMessage fgprd-oncommand-elasticlog-app001.mhint "[$ActualClusterName-1a:snap.DataSource:info]: Starting snapshot datasource collection!" Informational syslog
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
Send-SyslogMessage fgprd-oncommand-elasticlog-app001.mhint "[$Clustername-1a:snap.DataSource:info]: Stopping snapshot datasource collection!" Informational syslog
          