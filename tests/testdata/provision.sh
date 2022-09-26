function stal() {
	stalwart-cli -c changeme --url http://localhost $@
}

stal domain create example.org

# Make accounts
stal account create alice@example.org aliceSecret Alice

# Import mail
stal import messages -f mbox alice@example.org tests/image/eml/1.eml
stal import messages -f mbox alice@example.org tests/image/eml/2.eml
stal import messages -f mbox alice@example.org tests/image/eml/3.eml
