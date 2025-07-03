#Set Progress integer
$pi = 0
# Define the query packet for Quake 3 server discovery
$query = [byte[]](0xFF, 0xFF, 0xFF, 0xFF) + [System.Text.Encoding]::ASCII.GetBytes("getinfo")

# Define the port for Quake 3 servers
$port = 27960
$portb = 27961
# Define the timeout in milliseconds
$timeout = 2000

# Function to generate IP list from CIDR notation

# Generate list of IPs to scan
#$ipList = "192.168.1.101"



function Quake3Server {
    param (
        [string]$ip,
        [int]$port,
        [byte[]]$query,
        [int]$timeout
    )
    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Client.ReceiveTimeout = $timeout
        $udpClient.Send($query, $query.Length, $ip, $port) | Out-Null
        $remoteEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $response = $udpClient.Receive([ref]$remoteEndPoint)
        $responseString = [System.Text.Encoding]::ASCII.GetString($response)
        if ($responseString -like "*infoResponse*") {
            #$responseString | out-file D:\quake_response.txt
            if($responseString.split("\")[14] -eq 3){$type = "TDM"}
            if($responseString.split("\")[14] -eq 4){$type = "CTF"}
            if($responseString.split("\")[14] -eq 0){$type = "FFA"}
            if($responseString.split("\")[14] -eq 1){$type = "Duel"}
            if($type -eq $null){$type = $responseString.split("\")[14]}
            return [PSCustomObject]@{
                IP = $ip
                Port = $port
                Status = "Online"
                ServerName = $responseString.split("\")[4]
                Map = $responseString.split("\")[6]
                Current_Players = $responseString.split("\")[8]
                Gametype = $type

                
            }
        }
    } catch {
        # Ignore errors (e.g., timeout or no response)
    }
    return $null
}
#Test-Quake3Server -ip 192.168.1.255 -port $port -query $query -timeout $timeout
function Get-IpRange {
<#
.SYNOPSIS
    Given a subnet in CIDR format, get all of the valid IP addresses in that range.
.DESCRIPTION
    Given a subnet in CIDR format, get all of the valid IP addresses in that range.
.PARAMETER Subnets
    The subnet written in CIDR format 'a.b.c.d/#' and an example would be '192.168.1.24/27'. Can be a single value, an
    array of values, or values can be taken from the pipeline.
.EXAMPLE
    Get-IpRange -Subnets '192.168.1.24/30'
 
    192.168.1.25
    192.168.1.26
.EXAMPLE
    (Get-IpRange -Subnets '10.100.10.0/24').count
 
    254
.EXAMPLE
    '192.168.1.128/30' | Get-IpRange
 
    192.168.1.129
    192.168.1.130
.NOTES
    Inspired by https://gallery.technet.microsoft.com/PowerShell-Subnet-db45ec74
 
    * Added comment help
#>

    [CmdletBinding(ConfirmImpact = 'None')]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Please enter a subnet in the form a.b.c.d/#', ValueFromPipeline, Position = 0)]
        [string[]] $Subnets
    )

    begin {
        Write-Verbose -Message "Starting [$($MyInvocation.Mycommand)]"
    }

    process {
        foreach ($subnet in $subnets) {
            if ($subnet -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$') {
                #Split IP and subnet
                $IP = ($Subnet -split '\/')[0]
                [int] $SubnetBits = ($Subnet -split '\/')[1]
                if ($SubnetBits -lt 7 -or $SubnetBits -gt 30) {
                    Write-Error -Message 'The number following the / must be between 7 and 30'
                    break
                }
                #Convert IP into binary
                #Split IP into different octects and for each one, figure out the binary with leading zeros and add to the total
                $Octets = $IP -split '\.'
                $IPInBinary = @()
                foreach ($Octet in $Octets) {
                    #convert to binary
                    $OctetInBinary = [convert]::ToString($Octet, 2)
                    #get length of binary string add leading zeros to make octet
                    $OctetInBinary = ('0' * (8 - ($OctetInBinary).Length) + $OctetInBinary)
                    $IPInBinary = $IPInBinary + $OctetInBinary
                }
                $IPInBinary = $IPInBinary -join ''
                #Get network ID by subtracting subnet mask
                $HostBits = 32 - $SubnetBits
                $NetworkIDInBinary = $IPInBinary.Substring(0, $SubnetBits)
                #Get host ID and get the first host ID by converting all 1s into 0s
                $HostIDInBinary = $IPInBinary.Substring($SubnetBits, $HostBits)
                $HostIDInBinary = $HostIDInBinary -replace '1', '0'
                #Work out all the host IDs in that subnet by cycling through $i from 1 up to max $HostIDInBinary (i.e. 1s stringed up to $HostBits)
                #Work out max $HostIDInBinary
                $imax = [convert]::ToInt32(('1' * $HostBits), 2) - 1
                $IPs = @()
                #Next ID is first network ID converted to decimal plus $i then converted to binary
                For ($i = 1 ; $i -le $imax ; $i++) {
                    #Convert to decimal and add $i
                    $NextHostIDInDecimal = ([convert]::ToInt32($HostIDInBinary, 2) + $i)
                    #Convert back to binary
                    $NextHostIDInBinary = [convert]::ToString($NextHostIDInDecimal, 2)
                    #Add leading zeros
                    #Number of zeros to add
                    $NoOfZerosToAdd = $HostIDInBinary.Length - $NextHostIDInBinary.Length
                    $NextHostIDInBinary = ('0' * $NoOfZerosToAdd) + $NextHostIDInBinary
                    #Work out next IP
                    #Add networkID to hostID
                    $NextIPInBinary = $NetworkIDInBinary + $NextHostIDInBinary
                    #Split into octets and separate by . then join
                    $IP = @()
                    For ($x = 1 ; $x -le 4 ; $x++) {
                        #Work out start character position
                        $StartCharNumber = ($x - 1) * 8
                        #Get octet in binary
                        $IPOctetInBinary = $NextIPInBinary.Substring($StartCharNumber, 8)
                        #Convert octet into decimal
                        $IPOctetInDecimal = [convert]::ToInt32($IPOctetInBinary, 2)
                        #Add octet to IP
                        $IP += $IPOctetInDecimal
                    }
                    #Separate by .
                    $IP = $IP -join '.'
                    $IPs += $IP
                }
                Write-Output -InputObject $IPs
            } else {
                Write-Error -Message "Subnet [$subnet] is not in a valid format"
            }
        }
    }

    end {
        Write-Verbose -Message "Ending [$($MyInvocation.Mycommand)]"
    }
}
$subnets = @("10.20.30.0/24","10.20.37.0/24","10.20.40.0/24","10.20.50.0/24","10.20.31.0/24")

$iplist = $subnets | %{Get-IpRange -Subnets $_}

$export_functions = [scriptblock]::Create(@"
  Function Quake3Server { $function:Quake3Server }
"@)
# Scan IPs in parallel using jobs
$jobs = @()
foreach ($ip in $ipList) {
    $pi++
    write-progress -Activity "Scanning $IP" -percentcomplete ($PI/$iplist.count*100)
    $jobs += Start-Job -ScriptBlock {
        param ($ip, $port, $query, $timeout)
        Quake3Server -ip $ip -port $port -query $query -timeout $timeout
    } -ArgumentList $ip, $port, $query, $timeout -InitializationScript $export_functions
    $jobs += Start-Job -ScriptBlock {
        param ($ip, $portb, $query, $timeout)
        Quake3Server -ip $ip -port $portb -query $query -timeout $timeout
    } -ArgumentList $ip, $portb, $query, $timeout -InitializationScript $export_functions
    # Limit concurrent jobs to avoid overwhelming the system
    while ((Get-Job -State Running).Count -ge 100) {
        Write-host "Waiting for earlier jobs to finish" -f cyan
        Start-Sleep -Milliseconds 100
    }cls
}

# Wait for all jobs to complete and collect results
$results = $jobs | ForEach-Object { Receive-Job -Job $_ -Wait } | Where-Object { $_ -ne $null }

# Clean up jobs
Get-Job | Remove-Job

# Output discovered servers
if ($results) {
    Write-Output "Discovered Quake 3 servers:"
    $results | Format-Table -Property IP,port,Status,servername,map,current_players,gametype -AutoSize
} else {
    Write-Output "No Quake 3 servers found in the specified subnets."
}
