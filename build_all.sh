#!/bin/bash

set -xe

odin build server -vet
odin build client -vet