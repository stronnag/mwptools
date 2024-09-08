#!/usr/bin/env bash

function set_mission() {
  FN=$1
  if [ -n "$FN" -a -e "$FN" ] ; then
    dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	      /org/stronnag/mwp \
	      org.stronnag.mwp.SetMission string:"$(cat $FN)"
    else
      echo >2 "Need a mission file"
  fi
}

function load_mission() {
  FN=$1
  if [ -n "$FN" -a -e "$FN" ] ; then
    dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	      /org/stronnag/mwp \
	      org.stronnag.mwp.LoadMission string:"$FN"
    else
      echo >2 "Need a mission file"
  fi
}

function load_blackbox() {
  FN=$1
  if [ -n "$FN" -a -e "$FN" ] ; then
    dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	      /org/stronnag/mwp \
	      org.stronnag.mwp.LoadBlackbox string:"$FN"
    else
      echo >2 "Need a BBL file"
  fi
}

function load_mwp_log() {
  FN=$1
  if [ -n "$FN" -a -e "$FN" ] ; then
    dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	      /org/stronnag/mwp \
	      org.stronnag.mwp.LoadMwpLog string:"$FN"
    else
      echo >2 "Need a mwp log file"
  fi
}

function clear_mission() {
  dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	    /org/stronnag/mwp \
	    org.stronnag.mwp.ClearMission
}

function get_devices() {
  dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	    /org/stronnag/mwp \
	    org.stronnag.mwp.GetDevices
}

function upload_mission() {
  to_eeprom=${1:-false}
  dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	    /org/stronnag/mwp \
	    org.stronnag.mwp.UploadMission boolean:$to_eeprom
}

function connection_status() {
  dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	    /org/stronnag/mwp \
	    org.stronnag.mwp.ConnectionStatus
}

function connect_device() {
  device=$1
  dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	    /org/stronnag/mwp \
	    org.stronnag.mwp.ConnectDevice string:$device
}

function ping() {
  dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	    /org/stronnag/mwp \
	    org.freedesktop.DBus.Peer.Ping
}

function introspect() {
  dbus-send --session --print-reply=literal --dest=org.stronnag.mwp \
	    /org/stronnag/mwp \
	    org.freedesktop.DBus.Introspectable.Introspect
}

$@
