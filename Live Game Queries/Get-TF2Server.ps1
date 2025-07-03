# PowerShell script to send a UDP Source Engine A2S_INFO query with challenge response handling
# Script only works for Dedicated TF2 servers, TF2 Servers hosted via ingame GUI won't response to UDP Broadcasts
# Parameters (replace with your target server IP and port)
$targetIP = "192.168.1.101"  # Example IP, replace with your server's IP or use broadcast range
$targetPort = 27015          # Default TF2 server port

# Function to send and receive UDP data
function Send-UdpQuery {
    param (
        [string]$IPAddress,
        [int]$Port,
        [byte[]]$Query,
        [int]$Timeout = 3000
    )

    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Client.ReceiveTimeout = $Timeout
        $udpClient.Connect($IPAddress, $Port)

        [void]$udpClient.Send($Query, $Query.Length)

        $remoteEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $response = $udpClient.Receive([ref]$remoteEndPoint)

        $udpClient.Close()
        return $response
    }
    catch {
        Write-Warning "Failed to query $IPAddress`:$Port - $_"
        return $null
    }
}

# Function to parse A2S_INFO response
function Parse-A2SInfo {
    param (
        [byte[]]$Response
    )

    if ($null -eq $Response -or $Response.Length -lt 6) {
        return $null
    }

    if ($Response[0..3] -join ',' -ne '255,255,255,255' -or $Response[4] -ne 0x49) {
        return $null
    }

    $offset = 5
    $serverInfo = @{}

    try {
        $serverInfo.Protocol = $Response[$offset]
        $offset++

        $serverName = ""
        while ($Response[$offset] -ne 0) {
            $serverName += [char]$Response[$offset]
            $offset++
        }
        $serverInfo.ServerName = $serverName
        $offset++

        $map = ""
        while ($Response[$offset] -ne 0) {
            $map += [char]$Response[$offset]
            $offset++
        }
        $serverInfo.Map = $map
        $offset++

        $folder = ""
        while ($Response[$offset] -ne 0) {
            $folder += [char]$Response[$offset]
            $offset++
        }
        $serverInfo.Folder = $folder
        $offset++

        $game = ""
        while ($Response[$offset] -ne 0) {
            $game += [char]$Response[$offset]
            $offset++
        }
        $serverInfo.Game = $game
        $offset++

        $serverInfo.SteamID = [BitConverter]::ToUInt16($Response, $offset)
        $offset += 2

        $serverInfo.Players = $Response[$offset]
        $offset++

        $serverInfo.MaxPlayers = $Response[$offset]
        $offset++

        $serverInfo.Bots = $Response[$offset]
        $offset++

        $serverInfo.ServerType = switch ($Response[$offset]) {
            0x64 { "Dedicated" }
            0x6E { "Non-Dedicated" }
            0x6C { "SourceTV" }
            default { "Unknown" }
        }
        $offset++

        $serverInfo.Environment = switch ($Response[$offset]) {
            0x6C { "Linux" }
            0x77 { "Windows" }
            0x6D { "Mac" }
            default { "Unknown" }
        }
        $offset++

        $serverInfo.Visibility = if ($Response[$offset] -eq 0) { "Public" } else { "Private" }
        $offset++

        $serverInfo.VAC = if ($Response[$offset] -eq 0) { "Unsecured" } else { "Secured" }
        $offset++

        return $serverInfo
    }
    catch {
        Write-Warning "Failed to parse response from $IPAddress`:$Port"
        return $null
    }
}

# Function to handle challenge response
function Get-ChallengeResponse {
    param (
        [string]$IPAddress,
        [int]$Port
    )

    # Initial A2S_INFO query: 0xFF 0xFF 0xFF 0xFF 0x54 "Source Engine Query" 0x00
    $queryPacket = [byte[]](
        0xFF, 0xFF, 0xFF, 0xFF, 0x54,
        0x53, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x20, 0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65, 0x20, 0x51, 0x75, 0x65, 0x72, 0x79,
        0x00
    )

    $response = Send-UdpQuery -IPAddress $IPAddress -Port $Port -Query $queryPacket

    if ($null -eq $response) {
        return $null
    }

    # Check for challenge response: 0xFF 0xFF 0xFF 0xFF 0x41
    if ($response.Length -ge 9 -and $response[0..3] -join ',' -eq '255,255,255,255' -and $response[4] -eq 0x41) {
        # Extract challenge number (4 bytes)
        $challenge = [BitConverter]::ToInt32($response, 5)
        Write-Verbose "Received challenge number: $challenge"

        # Resend query with challenge
        $queryWithChallenge = [byte[]](
            0xFF, 0xFF, 0xFF, 0xFF, 0x54,
            0x53, 0x6F, 0x75, 0x72, 0x63, 0x65, 0x20, 0x45, 0x6E, 0x67, 0x69, 0x6E, 0x65, 0x20, 0x51, 0x75, 0x65, 0x72, 0x79,
            0x00
        ) + [BitConverter]::GetBytes($challenge)

        $response = Send-UdpQuery -IPAddress $IPAddress -Port $Port -Query $queryWithChallenge
    }

    return $response
}

# Main script
Write-Host "Sending Source Engine A2S_INFO query to a Team Fortress 2 server..."



# Send query and handle challenge response
$response = Get-ChallengeResponse -IPAddress $targetIP -Port $targetPort

# Parse response
$serverInfo = Parse-A2SInfo -Response $response

# Output results
if ($null -ne $serverInfo) {
    Write-Host "`nTeam Fortress 2 Server Information:"
    Write-Host "Server Name: $($serverInfo.ServerName)"
    Write-Host "Map: $($serverInfo.Map)"
    Write-Host "Game: $($serverInfo.Game)"
    Write-Host "Players: $($serverInfo.Players)/$($serverInfo.MaxPlayers) (Bots: $($serverInfo.Bots))"
    Write-Host "Server Type: $($serverInfo.ServerType)"
    Write-Host "Environment: $($serverInfo.Environment)"
    Write-Host "Visibility: $($serverInfo.Visibility)"
    Write-Host "VAC: $($serverInfo.VAC)"
}
else {
    Write-Host "`nNo valid Team Fortress 2 server response from $targetIP`:$targetPort."
}

Write-Host "`nQuery complete."