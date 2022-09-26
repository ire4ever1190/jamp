# Jamp

> I can't think of a good name so why not jamp?

[JMAP](https://jmap.io/) client that I made. Bit rough at the moment and the API could still change.

### Implemented
- [x] [Core](https://jmap.io/spec-core.html)
- [ ] [Mail](https://jmap.io/spec-mail.html) (in progress)
- [ ] Push
- [ ] [WebSocket](https://www.rfc-editor.org/rfc/rfc8887.html)

Specifications that I'm waiting to be finished before implementing

- [Calendars](https://jmap.io/spec-calendars.html)
- [Sharing](https://jmap.io/spec-sharing.html)
- [Contacts](https://jmap.io/spec-contacts.html)
- [Tasks](https://jmap.io/spec-tasks.html) 


## Contributing

#### Running tests

Some of the tests require docker to be configured on your system so a test email server can
be created. Once that is done you need to build and start the container
before running the tests
```cmd
nimble startContainer
```

## Thanks

Big thanks for fastmail for making an easy [samples repo](https://github.com/fastmail/JMAP-Samples/) that I used 
in making this repo (Also for making their JMAP routes open so I could test out this library) (Sign up with this [referral link](https://ref.fm/u25971632) if you want to try them out)

Also to Linagora whos [Typescript client](https://github.com/linagora/jmap-client-ts) I looked at for implementing my tests
