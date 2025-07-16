#!/bin/bash

c3vm_directory="$(realpath "$0" | xargs dirname)"

git -C "$c3vm_directory" pull
