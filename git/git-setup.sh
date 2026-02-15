#!/bin/bash
#Username
echo git username?
read -r username
git config --global user.name "$username"
echo "git username set as: $username"
#Email
echo git email?
read -r email
git config --global user.email "$email"
echo "git email set as: $email"
#Done
echo "git for $username + $email has been configured!"
