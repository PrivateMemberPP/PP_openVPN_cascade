#!/bin/bash
#
# This script can be used as an up and down script for OpenVPN.
#
# Usage:
#   Start OpenVPN with the following options:
#
#   openvpn
#       --config <config file>
#       --script-security 2
#       --route remote_host
#       --persist-tun
#       --up updown.sh
#       --down updown.sh
#       --route-noexec
#       --setenv hopid <hop number>
#       --setenv prevgw <gateway>
#
#       config file
#           The *.ovpn config file, ie. "London.ovpn".
#       hop number
#           The number of the hop in the cascading chain, starting with 1.
#           For the first hop, you can omit the hop number (default: 1).
#           It is limited to 5, to limit the amount of total routes.
#       gateway
#          The gateway (internal server IP) of the previous hop as provided
#          in the log of the previous hop.
#          For the first hop ('hop number' = 1), you can omit the gateway.
#          In that case, the gateway of your local network will be used.
#
#   TL;DR: Just start openvpn with all parameters listed above except the last
#   two (--setenv). You will find the command line for the next hop in the log,
#	you will just need to change <config.ovpn> for the configuration file of 
#	the server of your choice.
#
# Example:
#   Hop #1:
#     sudo openvpn --config London.ovpn --script-security 2 --route remote_host
#         --persist-tun --up updown.sh --down updown.sh --route-noexec
#
#   Hop #2 (copy-paste this command line from the log of the hop #1):
#     sudo openvpn --config Rotterdam.ovpn --script-security 2 --route remote_host
#         --persist-tun --up updown.sh --down updown.sh --route-noexec
#         --setenv hopid 2 --setenv prevgw 10.1.13.1
#
#   Hop #3 (copy-paste from hop #2):
#     sudo openvpn --config Reykjavik.ovpn --script-security 2 --route remote_host
#         --persist-tun --up updown.sh --down updown.sh --route-noexec
#         --setenv hopid 3 --setenv prevgw 10.18.12.1
#
# NOTE:
#	We recommend using a dedicated terminal window for each hop. That way the log
#	outputs for each hop can be easily kept apart. It also guarantees that the 
#	routes can be added and removed again in the right order.
#
# Advanced Options:
#   --setenv disable_resolvconf 1
#      By default, this script executes '/etc/openvpn/update-resolv-conf'
#      to update your DNS settings. You can disable this behaviour by
#      setting the environment variable 'disable_resolvconf'.
#   --setenv redirect_output /path/to/file
#      Redirect stdout and stderr to file.
#
# Changelog:
#   1.0
#     * initial version
#   1.1
#     * nice log output and hint for the next connection
#     * you can omit the --setenv parameter for the first hop
#   1.2
#     * backwards compatible to openvpn version 2.2
#       (uses --up and --down instead of --route-up and --route-pre-down)
#     * two environment variables for hopid and prevgw instead of one
#     * use iproute2 (ip route add) instead of net-tools suite (route add)
#   1.3
#     * added /etc/openvpn/update-resolv-conf (can be disabled by
#       --setenv disable_resolvconf 1)
#   1.4
#     * added ability to redirect stdout and stderr to file
#       (--setenv redirect_output /path/to/file)
#   1.5
#     * added support for IPv6

VERSION="1.5"

# remember script name
script_name=$0

# maximum number of hops
# be careful: number of additional routes per hop: 2^hopid + 1
MAX_HOPID=5


# print $1 with prefix to STDOUT
function updown_print {
    echo "updown.sh: $1"
}


# print $1 with prefix to STDERR
function updown_print_error {
    echo "updown.sh: ERROR: $1">&2
}


# check whether $1 is an IPv4 address (exit on error)
# $1: the IP address to check
# $2: the environment variable name for error message
function check_ipv4_regex {
    regex_255="([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])" # 0-255
    regex_ipv4="^($regex_255.){3}$regex_255$"
    if ! [[ $1 =~ $regex_ipv4 ]]
    then
        updown_print_error "$2 ('$1') is not an IPv4 address"
        updown_print "ABORT"
        exit 1
    fi
}

# redirect output if $redirect_output is set
if ! [ "$redirect_output" == "" ]
then
    exec > "$redirect_output"
    exec 2>&1
fi

updown_print "STARTED"
updown_print "hop number:              $hopid (default: 1)"
updown_print "gateway of previous hop: $prevgw (default: local gateway)"
updown_print "local gateway:           $route_net_gateway"
updown_print "VPN: int. IP address:    $ifconfig_local"
updown_print "VPN: netmask:            $ifconfig_netmask"
updown_print "VPN: gateway:            $route_vpn_gateway"
updown_print "VPN: public IP address:  $route_network_1"

# if hopid is not set, assume it to be 1
if [[ ${hopid} == "" ]]
then
    updown_print "Notice: You didn't set 'hopid'. Assuming this to be the first hop (hopid=1)."
    hopid=1
fi

# check whether environment variable hopid is a number
regex_number="^[0-9]+$"
if ! [[ ${hopid} =~ $regex_number ]]
then
    updown_print_error "hopid ('$hopid') is not a number!"
    updown_print_error "See updown.sh for the usage of this script."
    updown_print "ABORT"
    exit 1
fi

# check whether hopid <= MAX_HOPID
if [[ ${hopid} -gt ${MAX_HOPID} ]]
then
    updown_print_error "You shouldn't use more than $MAX_HOPID hops. Otherwise it will result in a massive amount of routes."
    updown_print "ABORT"
    exit 1
fi

# check whether all environment variables needed are IPv4 addresses
check_ipv4_regex ${route_vpn_gateway} "route_vpn_gateway"
check_ipv4_regex ${route_network_1} "route_network_1"
vpn_server_ip=${route_network_1}

# make sure we have a valid gateway
# (prevgw is the route_vpn_gateway from the previous hop)
if [[ ${prevgw} == "" ]]
then
    if [[ ${hopid} -eq 1 ]]
    then
        # for the first hop, use the local gateway
        updown_print "Notice: You didn't set the previous gateway. The gateway of your local network ('$route_net_gateway') will be used."
        prevgw=${route_net_gateway}
    else
        updown_print_error "You didn't set the previous gateway."
        updown_print_error "See updown.sh for the usage of this script."
    fi
fi
check_ipv4_regex ${prevgw} "prevgw"

# determine whether to add or del our routes
if [[ "$script_type" == "up" ]]
then
    add_del="add"
elif [[ "$script_type" == "down" ]]
then
    add_del="delete"
else
    updown_print_error "script_type is not 'up' or 'down'!"
    updown_print_error "See updown.sh for the usage of this script."
    updown_print "ABORT"
    exit 1
fi

# add route to (next) vpn server via previous gateway
IP=$(which ip)
route_cmd="$IP route $add_del $vpn_server_ip via $prevgw"
updown_print "executing: '$route_cmd'"
eval ${route_cmd}

# calculate and execute IPv4 routes
for (( i=0; i < $((2 ** $hopid)); i++ ))
do
    net="$(( $i << (8 - $hopid) )).0.0.0/$hopid"
    route_cmd="$IP route $add_del $net via $route_vpn_gateway"
    updown_print "executing: '$route_cmd'"
    eval ${route_cmd}
done

# IPv6
for (( i=0; i < $((2 ** $hopid)); i++ ))
do
    net=$(printf "%X::/$((3 + $hopid))" $(( 0x2000 + ( $i << (13 - $hopid) ) )))
    route_cmd="$IP -6 route $add_del $net dev $dev"
    updown_print "executing: '$route_cmd'"
    eval ${route_cmd}
done

# print hint for the next connection (on up)
if [[ "$script_type" == "up" ]]
then
    if [[ ${hopid} -le ${MAX_HOPID} ]]
    then
        next_hop_number=$((hopid+1))
        next_gateway=${route_vpn_gateway}
        updown_print "HINT: For the next hop, start openvpn with the following options:"
        updown_print "HINT: openvpn --config <config.ovpn> --script-security 2 --route remote_host --persist-tun --up $script_name --down $script_name --route-noexec --setenv hopid $next_hop_number --setenv prevgw $next_gateway"
    else
        updown_print "Notice: Maximum numbers of hops reached. Don't start another connection."
    fi
fi

# update DNS settings
if ! [ "$disable_resolvconf" ]
then
    resolvconf_cmd="/etc/openvpn/update-resolv-conf"
    updown_print "execuding: '$resolvconf_cmd'"
    eval ${resolvconf_cmd}
fi

updown_print "FINISHED"
