# script adopted from
# https://opello.org/blog/2016/02/14/namesilo-api-from-powershell/

Using module ".\DDNS.psm1"

class NameSilo : DDNS {
    #NameSilo() : base() {}

    static [object] callAPI (
        [string]
        $uri,

        [hashtable]
        $query = @{}
    ){
        $response = $null
        try{
            $response = Invoke-RestMethod -Uri $uri -Body $query
        } catch {
            Write-Log $_ "ERROR"
            Write-Log "StatusCode: $($_.Exception.Response.StatusCode.value__)" "ERROR"
            Write-Log "StatusDescription: $($_.Exception.Response.StatusDescription)" "ERROR"
            throw("API error, see log")
        }
        if ($response.namesilo.reply.code -ne 300) {
            Write-Log "StatusCode: $($response.namesilo.reply.code)" "ERROR"
            Write-Log "Detail: $($response.namesilo.reply.detail)" "ERROR"
            throw("API error, see log")
        }
        else {
            Write-Log "StatusCode: $($response.namesilo.reply.code)" "INFO"
            return $response
        }
    }

    static dnsUpdateRecord (
        [string]$APIKey, 
        [string]$Domain, 
        [string]$Record, 
        [string]$Type
    ){
        Write-Log "Updating $Type record for $Record.$Domain" "INFO"

        # Retrieve the DNS entries in the domain.
        $query = @{
            version = 1
            type = "xml"
            key = $APIkey
            domain = $domain
        }

        $listdomains = [NameSilo]::callAPI("https://www.namesilo.com/apibatch/dnsListRecords", $query)

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
            $update = [NameSilo]::callAPI($url, $query)
        } else {
            Write-Log "IP Address has not changed." "INFO"
        }
    }
}