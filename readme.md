# Jamp

> I can't think of a good name so why not jamp?

[JMAP](https://jmap.io/) client that I made. Bit rough at the moment and the API could still change.

### Implemented
- [x] Core
- [ ] Mail
- [ ] Push
- [ ] WebSocket

Specifications that I'm waiting to be finished before implementing

- Calendars
- Sharing
- Contacts
- Tasks 


## Contributing

#### Running tests

Some of the tests require [podman](https://podman.io/) to be configured on your system so a test email server can
be created. The tests also expect podman to be rootless

#### Thanks

Big thanks for fastmail for making an easy [samples repo](https://github.com/fastmail/JMAP-Samples/) that I used 
in making this repo (Also for making their JMAP routes open so I could test out this library)

