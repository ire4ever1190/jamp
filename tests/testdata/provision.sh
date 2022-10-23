#!/bin/bash
function stal() {
	stalwart-cli -c changeme --url http://localhost $@
}

stal domain create example.org

# Make accounts
stal account create alice@example.org aliceSecret Alice
stal account create bob@example.org bobSecret Bob

#stal group create everyone@example.org "everyone"
#stal group add-members everyone@example.org alice@example.org bob@example.org


# Import mail
stal import messages -f mbox alice@example.org tests/testdata/eml/1.eml
stal import messages -f mbox alice@example.org tests/testdata/eml/2.eml
stal import messages -f mbox alice@example.org tests/testdata/eml/3.eml

