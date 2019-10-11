Using module ".\DDNS.psm1"

class DNSPod : DDNS {
    #DNSPod() : base() {
    #    # https://stackoverflow.com/questions/41618766/powershell-invoke-webrequest-fails-with-ssl-tls-secure-channel
    #    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    #}

    static [object] callAPI (
        [string]
        $uri,

        [hashtable]
        $query = @{}
    ){
        try{
            $response = Invoke-RestMethod -Uri $uri -Method Post -Body $query
        } catch {
            Write-Log $_ "ERROR"
            Write-Log "Code: $($_.Exception.Response.StatusCode.value__)" "ERROR"
            Write-Log "StatusDescription: $($_.Exception.Response.StatusDescription)" "ERROR"
            throw("API error, see log")
        }
        
        # https://www.dnspod.cn/docs/info.html#common-response
        if ($response.status.code -ne 1) {
            Write-Log "Code: $($response.status.code)" "ERROR"
            Write-Log "Detail: $($response.status.message)" "ERROR"
            throw("API error, see log")
        }
        else {
            Write-Log "Code: $($response.status.code)" "INFO"
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

        if ([string]::IsNullOrEmpty($Record)) {
          $IsNaked = $True
        } else {
          $IsNaked = $False
        }
        
        # Retrieve the DNS entries in the domain.
        $query = @{
          login_token = $APIKey
          format = "json"
          lang = "en"
          error_on_empty = "yes"
          ###
          domain = $domain
          record_type = "A"
        }
        if ($IsNaked -eq $False) {
          $query.sub_domain = $Record
        }

        $listdomains = ([DNSPod]::callAPI("https://dnsapi.cn/Record.List", $query)).records

        if ($listdomains.length -eq 0) {
            Write-Log "Could not find requested record: $Record.$Domain" "ERROR"
            throw("Error, see log")
        }
        if ($listdomains.length -gt 1) {
            Write-Log "Found multiple matches for requested record: $Record.$Domain" "ERROR"
            throw("Error, see log")
        }
        $UpdateRecord = $listdomains[0]

        $CurrentIP = (Invoke-WebRequest -uri "http://icanhazip.com").Content.trim()
        # previous IP is here, no need to store in a file
        $RecordIP = $UpdateRecord.value
        $RecordID = $UpdateRecord.record_id
        Write-Log "Record IP: $RecordIP, current IP: $CurrentIP" "INFO"
        
        # Only update the record if necessary.
        if ($CurrentIP -ne $RecordIP){
            Write-Log "Updating A record for $Record.$Domain to $CurrentIP" "INFO"
            $query = @{
              login_token = $APIKey
              format = "json"
              lang = "en"
              error_on_empty = "yes"
              ###
              domain = $domain
              record_id = $UpdateRecord.id
              record_type = $UpdateRecord.type
              record_line = $UpdateRecord.line
              value = $CurrentIP
            }
            if ($IsNaked -eq $False) {
                $query.sub_domain = $Record
            }
            Out-String -InputObject $query
            $url = "https://dnsapi.cn/Record.Modify"
            $update = [DNSPod]::callAPI($url, $query)
        } else {
            Write-Log "IP Address has not changed." "INFO"
        }
    }
}