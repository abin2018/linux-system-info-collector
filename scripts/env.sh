#!/bin/bash
# Some variables

DISK_INCLUDE_PATTERN='(sd|vd|xvd)[a-z]$'  # Set the disk name for different system
NET_EXCLUDE_PATTERN='lo|docker|veth' # Set the network interface name to be exclude
