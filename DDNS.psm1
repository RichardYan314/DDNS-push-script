using module ".\Write-Log.psm1"

$date = (Get-Date)
$logfile = "$PSScriptRoot\{0}.{1}.log" -f $date.Year, $date.Month

Function Write-Log (
    [String]$Message,
    [String]$Level = "INFO"
){
    Write-Log_ $Message $Level $logfile
}

class DDNS {
    #DDNS (){
    #    $type = $this.GetType()
    #
    #    if ($type -eq [Foo])
    #    {
    #        throw("Class $type must be inherited")
    #    }
    #}

    static [object] callAPI (
        [string]
        $uri,

        [hashtable]
        $query = @{}
    ){
        throw("Must Override Method")
    }

    static dnsUpdateRecord (
        [string]$APIKey, 
        [string]$Domain, 
        [string]$Record, 
        [string]$Type
    ){
        throw("Must Override Method")
    }
}