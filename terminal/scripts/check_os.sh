#!/usr/bin/env bash

unameOut=$(uname -a)
case "${unameOut}" in
    *Microsoft*)     OS="WSL";; #wls must be first since it will have Linux in the name too
    *microsoft*)     OS="WSL2";; 
    Linux*)     OS="Linux";;
    Darwin*)    OS="Mac";;
    CYGWIN*)    OS="Cygwin";;
    MINGW*)     OS="Windows";; 
    *Msys)     OS="Windows";;
    *)          OS="UNKNOWN:${unameOut}"
esac

if [[ ${OS} == "Mac" ]] && sysctl -n machdep.cpu.brand_string | grep -q 'Apple M1'; then
    #Check if its an M1. This check should work even if the current processes is running under x86 emulation.
    OS="MacM1"
fi

echo ${OS};

