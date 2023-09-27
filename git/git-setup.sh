#!/bin/bash
#Username
echo git username?
read username
git config --global user.name $username
echo git username set as: $username
#Email
echo git email?
read email
git config --global user.email $email
echo git email set as: $email
#Done
echo git for $username + $email has been configured!