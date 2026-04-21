# Jamp

> I can't think of a good name so why not jamp?

[docs](https://ire4ever1190.github.io/jamp/)

[JMAP](https://jmap.io/) client that I made. Bit rough at the moment and the API could still change.

### Implemented
- [x] [Core](https://jmap.io/spec/rfc8620/)
- [ ] [Mail](https://jmap.io/spec/rfc8621/) (in progress)
- [ ] Push
- [ ] [WebSocket](https://jmap.io/spec/rfc8887/)

Specifications that I'm waiting to be finished before implementing

- [Calendars](https://jmap.io/spec/calendars-draft/)
- [Sharing](https://jmap.io/spec/rfc9670/)
- [Contacts](https://jmap.io/spec/rfc9610/)
- [Tasks](https://www.ietf.org/archive/id/draft-ietf-jmap-tasks-03.html) 


## Contributing

#### Running tests

Some of the tests require docker to be configured on your system so a test email server can
be created. Once that is done you need to build and start the container
before running the tests
```shell
nimble startContainer
```
That only needs to be done once. Tests are then ran through nimble
```shell
nimble test
```


## Thanks

Big thanks for fastmail for making an easy [samples repo](https://github.com/fastmail/JMAP-Samples/) that I used 
in making this repo (Also for making their JMAP routes open so I could test out this library) (Sign up with this [referral link](https://ref.fm/u25971632) if you want to try them out)

Also to Linagora whos [Typescript client](https://github.com/linagora/jmap-client-ts) I looked at for implementing my tests
