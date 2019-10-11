# set scheduler according to
# http://www.forkrobotics.com/2014/10/dynamic-dns-with-namesilo-and-powershell/
# note the `-ExecutionPolicy Bypass` argument
# so no need to change ExecutionPolicy for current user/machine

Using module ".\NameSilo.psm1"
Using module ".\DNSPod.psm1"

$domain = "[deleted]"
$record = "[deleted]"

# 名称: DDNS
$ID = "[deleted]"
$Token = "[deleted]"
# 创建时间: 2019-08-30 22:58:06
$DNSPodAPIkey = $ID + "," + $Token
Write-Log "=====Pushing to DNSPod=====" "INFO"
[DNSPod]::dnsUpdateRecord($DNSPodAPIkey, $domain, $record, "A")

$NameSiloAPIkey = "[deleted]"
Write-Log "=====Pushing to NameSilo=====" "INFO"
[NameSilo]::dnsUpdateRecord($NameSiloAPIkey, $domain, $record, "A")
