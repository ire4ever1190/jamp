#!/bin/bash

function stal() {
	/usr/local/bin/stalwart-cli -c changeme --url http://localhost $@
}

stal domain create example.org

# Make accounts
stal group create everyone@example.org "everyone"

stal account create -a alice@example.org -m "everyone" Alice aliceSecret
stal account create -a bob@example.org -m "everyone" Bob bobSecret

# Import mail
stal import messages -f mbox alice@example.org tests/testdata/eml/1.eml
stal import messages -f mbox alice@example.org tests/testdata/eml/2.eml
stal import messages -f mbox alice@example.org tests/testdata/eml/3.eml

