# script adopted from
# https://opello.org/blog/2016/02/14/namesilo-api-from-powershell/

# set scheduler according to
# http://www.forkrobotics.com/2014/10/dynamic-dns-with-namesilo-and-powershell/
# note the `-ExecutionPolicy Bypass` argument
# so no need to change ExecutionPolicy for current user/machine

#$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
# In PowerShell v3, us the automatic variable $PSScriptRoot
Import-Module $PSScriptRoot\Write-Log.psm1

# NameSilo API Dynamic DNS
# Variables
$APIkey = "[deleted]"
$domain = "[deleted]"

$date = Get-Date
$logfile = "$PSScriptRoot\{0}.{1}.log" -f $date.Year, $date.Month

Function Write-Log {
    [CmdletBinding()]
   param
   (
      [String]$Message,
      [String]$Level = "INFO"
   )
   Write-Log_ $Message $Level $logfile
}

function NameSilo-API {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$True)]
    [string]
    $uri,

    [Parameter(Mandatory=$False)]
    [hashtable]
    $query = @{}
    )

    try{
        $response = Invoke-RestMethod -Uri $uri -Body $query
    } catch {
        Write-Log $_ "ERROR"
        Write-Log "StatusCode: $($_.Exception.Response.StatusCode.value__)" "ERROR"
        Write-Log "StatusDescription: $($_.Exception.Response.StatusDescription)" "ERROR"
        EXIT
    }
    if ($response.namesilo.reply.code -ne 300) {
        Write-Log "StatusCode: $($response.namesilo.reply.code)" "ERROR"
        Write-Log "Detail: $($response.namesilo.reply.detail)" "ERROR"
        EXIT
    }
    else {
        Write-Log "StatusCode: $($response.namesilo.reply.code)" "INFO"
        return $response
    }
}

function NameSilo-dnsUpdateRecord {
    param ([string]$APIKey, [string]$Domain, [string]$Record, [string]$Type)
    Write-Log "Updating $Type record for $Record.$Domain" "INFO"

    # Retrieve the DNS entries in the domain.
    $query = @{
        version = 1
        type = "xml"
        key = $APIkey
        domain = $domain
    }

    $listdomains = NameSilo-API -uri "https://www.namesilo.com/apibatch/dnsListRecords" -query $query

    $Records = $listdomains.namesilo.reply.resource_record | 
        where { $_.type -eq $Type }

    $UpdateRecord = $null
    $IsNaked = $False
    foreach ($r in $Records ) {
        if ([string]::IsNullOrEmpty($Record) -and $r.host -eq $Domain) {
            $UpdateRecord = $r
            $IsNaked = $True
            Write-Log "Found record $Domain" "INFO"
            break
        } elseif ($r.host -eq "$($Record).$($Domain)") {
            $UpdateRecord = $r
            Write-Log "Found record $Record.$Domain" "INFO"
            break
        }
    }
    if ($UpdateRecord -eq $null) {
        Write-Log "Could not find requested record: $Record.$Domain" "ERROR"
        Exit
    }

    # NameSilo API always return client IP
    # so no need to query https://icanhazip.com
    $CurrentIP = $listdomains.namesilo.request.ip
    # previous IP is here, no need to store in a file
    $RecordIP = $UpdateRecord.value
    $RecordID = $UpdateRecord.record_id
    Write-Log "Record IP: $RecordIP, current IP: $CurrentIP" "INFO"

    # Only update the record if necessary.
    if ($CurrentIP -ne $RecordIP){
        Write-Log "Updating A record for $Record.$Domain to $CurrentIP" "INFO"
        $query = @{
            version = 1
            type = "xml"
            key = $APIkey
            domain = $domain
            rrid = $RecordID
            rrvalue = $CurrentIP
            rrttl = 7207
        }
        if ($IsNaked -eq $False) {
            $query.rrhost = $Record
        }
        Out-String -InputObject $query
        $url = "https://www.namesilo.com/api/dnsUpdateRecord"
        $update = NameSilo-API -uri $url -query $query
    } else {
        Write-Log "IP Address has not changed." "INFO"
    }
}

# Invocations:
NameSilo-dnsUpdateRecord -APIKey $APIkey -Domain $domain -Record "[deleted]" -Type "A"