#!/bin/bash

# function james-cli() {
  # java -jar /root/james-cli.jar "$@"
# }



# Wait for the server to start
while true; do
  james-cli ListUsers;
  if [[ "$?" == '0' ]]; then
    break
  fi
  echo "Waiting for startup..."
  sleep 1
  
done

james-cli AddUser alice@localhost aliceSecret
james-cli AddUser bob@localhost bobSecret
james-cli AddUser empty@localhost emptrySecret

declare -a arr=("INBOX" "Important" "Outbox" "Sent" "Drafts" "Trash" "Spam")

for i in "${arr[@]}"
do
   echo "Creating mailbox $i"
   james-cli CreateMailbox \#private alice@localhost $i &
   james-cli CreateMailbox \#private bob@localhost $i &
   wait
done

for i in {1..1}
do
  echo "Importing $j.eml"
  james-cli ImportEml \#private alice@localhost $i /root/eml/$i.eml
done

# 
# for i in "${arr[@]}"
# do
   # for j in {1..41}
   # do
       # echo "Importing $j.eml in $i"
       # james-cli ImportEml \#private alice@localhost $i /root/eml/$j.eml &
       # james-cli ImportEml \#private bob@localhost $i /root/eml/$j.eml &
       # wait
   # done
# done
# 
# james-cli CreateMailbox \#private alice@localhost empty
# james-cli CreateMailbox \#private bob@localhost empty
# 
# james-cli CreateMailbox \#private alice@localhost five
# james-cli ImportEml \#private alice@localhost five 0.eml
# james-cli ImportEml \#private alice@localhost five 1.eml
# james-cli ImportEml \#private alice@localhost five 2.eml
# james-cli ImportEml \#private alice@localhost five 3.eml
# james-cli ImportEml \#private alice@localhost five 4.eml
# james-cli CreateMailbox \#private bob@localhost five
# james-cli ImportEml \#private bob@localhost five 0.eml
# james-cli ImportEml \#private bob@localhost five 1.eml
# james-cli ImportEml \#private bob@localhost five 2.eml
# james-cli ImportEml \#private bob@localhost five 3.eml
# james-cli ImportEml \#private bob@localhost five 4.eml
