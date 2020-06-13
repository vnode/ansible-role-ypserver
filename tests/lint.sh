#!/bin/sh

yamllint -c yamllint.yml ../
ansible-lint ../ ./test.yml
