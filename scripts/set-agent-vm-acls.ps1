#Requires -Version 7.4
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Limit the agent VM's network adapter to DHCP, the internet and ssh from the host with extended port ACLs.

.DESCRIPTION
  Denies, in both directions, every private, link-local, CGNAT, benchmarking, multicast and reserved range, IPv6, and
  each public address the host's ziti tunnels intercept, if it runs any. The VM sits on the Default Switch, where the
  host routes its traffic, so an intercepted public address would reach the host's ziti services. Rerun after starting
  a ziti tunnel or adding a ziti service that intercepts a public address. The rules also deny the switch's DNS proxy
  on the host, so the guest must use public DNS servers.
#>
param(
    [Parameter(Mandatory)] [string] $VmName
)
$ErrorActionPreference = 'Stop'
# perusal mirrors the agent's uncommitted edits into ~\dev, and this runs elevated.
if ($PSScriptRoot.StartsWith("$HOME\dev\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Run set-agent-vm-acls.ps1 from the runtime checkout ~\.windows-dev, not $PSScriptRoot"
}

$blockedRanges = '0.0.0.0/8', '10.0.0.0/8', '100.64.0.0/10', '169.254.0.0/16', '172.16.0.0/12', '192.168.0.0/16',
    '198.18.0.0/15', '224.0.0.0/4', '240.0.0.0/4'

# ziti-edge-tunnel, alone or under Ziti Desktop Edge, runs as the service ziti (SVCNAME in ziti-tunnel-sdk-c
# windows-service.h). A stopped one would leave its intercepts out of the rules, and the VM would reach them once it
# starts.
$zitiService = Get-Service | Where-Object Name -eq 'ziti'
if ($zitiService -and $zitiService.Status -ne 'Running') {
    throw "The ziti tunnel service is $($zitiService.Status). Start it, so its intercepts get denied"
}
# A tunnel run outside the service routes its intercepts the same way. Each one numbers its adapter from ziti-tun0
# (ZITI_TUN_NAME_BASE in ziti-tunnel-sdk-c tun.c).
$interceptedPrefixes = @(Get-NetRoute -AddressFamily IPv4 | Where-Object InterfaceAlias -like 'ziti-tun*' |
    ForEach-Object DestinationPrefix | Sort-Object -Unique |
    Where-Object {
        $routeNetwork = [Net.IPNetwork]::Parse($_)
        $coveringRanges = @($blockedRanges | Where-Object {
            $blockedNetwork = [Net.IPNetwork]::Parse($_)
            $routeNetwork.PrefixLength -ge $blockedNetwork.PrefixLength -and $blockedNetwork.Contains($routeNetwork.BaseAddress)
        })
        -not $coveringRanges
    })
Write-Host "ziti intercepts denied besides the blocked ranges: $($interceptedPrefixes -join ', ')"

# The new rules take the weight bank the old ones do not use and the old ones go after, so the VM is never without
# its denies. Higher weight applies first.
$oldRules = @(Get-VMNetworkAdapterExtendedAcl -VMName $VmName)
if ($oldRules | Where-Object Weight -ge 500) {
    $bankBase = 0
} else {
    $bankBase = 500
}

# Above the denies, so DHCP reaches 255.255.255.255 (inside 240.0.0.0/4) and the host's private address.
Add-VMNetworkAdapterExtendedAcl -VMName $VmName -Action Allow -Direction Outbound -Protocol UDP -LocalPort 68 -RemotePort 67 -Weight ($bankBase + 400)
Add-VMNetworkAdapterExtendedAcl -VMName $VmName -Action Allow -Direction Inbound -Protocol UDP -LocalPort 68 -RemotePort 67 -Weight ($bankBase + 399)
# Stateful, so the VM's packets to the host pass only as replies on an ssh connection the host opened.
Add-VMNetworkAdapterExtendedAcl -VMName $VmName -Action Allow -Direction Inbound -Protocol TCP -LocalPort 22 -Stateful $true -Weight ($bankBase + 450)

$deniedPrefixes = @($blockedRanges) + $interceptedPrefixes + '::/0'
for ($prefixIndex = 0; $prefixIndex -lt $deniedPrefixes.Count; $prefixIndex++) {
    $outboundWeight = $bankBase + 300 - 2 * $prefixIndex
    Add-VMNetworkAdapterExtendedAcl -VMName $VmName -Action Deny -Direction Outbound -RemoteIPAddress $deniedPrefixes[$prefixIndex] -Weight $outboundWeight
    Add-VMNetworkAdapterExtendedAcl -VMName $VmName -Action Deny -Direction Inbound -RemoteIPAddress $deniedPrefixes[$prefixIndex] -Weight ($outboundWeight - 1)
}

if ($oldRules) {
    $oldRules | Remove-VMNetworkAdapterExtendedAcl
}

Get-VMNetworkAdapterExtendedAcl -VMName $VmName | Sort-Object Weight -Descending |
    Format-Table Weight, Direction, Action, RemoteIPAddress, Protocol, LocalPort, RemotePort
