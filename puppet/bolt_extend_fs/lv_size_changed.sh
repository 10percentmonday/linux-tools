#!/bin/bash
old_lvsize=$1
new_lvsize=$((old_lvsize + 1))

facter --custom_fact lv_size_changed="{ 'old': '$old_lvsize', 'new': '$new_lvsize' }"
