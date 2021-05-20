#!/bin/bash


function set_mission()
{
  FN=$1
  if [ -n "$FN" -a -e "$FN" ] ; then
    dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	      /org/mwptools/mwp \
	      org.mwptools.mwp.SetMission string:"$(cat $FN)"
    else
      echo >2 "Need a mission file"
  fi
}

function load_mission()
{
  FN=$1
  if [ -n "$FN" -a -e "$FN" ] ; then
    dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	      /org/mwptools/mwp \
	      org.mwptools.mwp.LoadMission string:"$FN"
    else
      echo >2 "Need a mission file"
  fi
}

function clear_mission()
{
  dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	    /org/mwptools/mwp \
	    org.mwptools.mwp.ClearMission
}

function get_devices()
{
  dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	    /org/mwptools/mwp \
	    org.mwptools.mwp.GetDevices
}

function upload_mission()
{
  to_eeprom=${1:-false}
  dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	    /org/mwptools/mwp \
	    org.mwptools.mwp.UploadMission boolean:$to_eeprom
}

function connection_status()
{
  dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	    /org/mwptools/mwp \
	    org.mwptools.mwp.ConnectionStatus
}

function connect_device()
{
  device=$1
  dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	    /org/mwptools/mwp \
	    org.mwptools.mwp.ConnectDevice string:$device
}


function ping()
{
  dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	    /org/mwptools/mwp \
	    org.freedesktop.DBus.Peer.Ping
}

function introspect()
{
  dbus-send --session --print-reply=literal --dest=org.mwptools.mwp \
	    /org/mwptools/mwp \
	    org.freedesktop.DBus.Introspectable.Introspect
}

$@
