import std/unittest
import jamp/jsonptr


type
  Job = object
    title: string
    `~1`: string
    `/tail`: string
    directions: seq[string]
    boss: Person
    
  Person = ref object
    name: string
    age: int
    job: Job
    sideGigs: seq[Job]


suite "JSON pointer":    
  test "Top level element":
    check:
      Person.point(name) == "/name"
      Person.point(age) == "/age"
      Person.point(job) == "/job"

  test "Child object":
    check Person.point(job.title) == "/job/title"

  test "Pointing to array":
    check Person.point(sideGigs) == "/sideGigs/*"
    
  test "Pointing to element inside array":
    check:
      Person.point(sideGigs[0]) == "/sideGigs/0"
      Person.point(sideGigs[0].title) == "/sideGigs/0/title"

  test "Pointing to element that is inside everything in an array":
    check Person.point(sideGigs.title) == "/sideGigs/*/title"

  test "Element that doesnt exist":
    check not compiles(Person.point(noExist))

  test "Using array on non array type":
    check not compiles(Person.point(age[0]))

  test "Deeper":
    check Person.point(sideGigs[0].boss.job.title) == "/sideGigs/0/boss/job/title"

  test "Array of objects":
    check:
      seq[Person].point([0].name) == "/0/name"
      seq[Person].point(name) == "/*/name"

  test "Value escaping":
    check:
      Person.point(job.`/tail`) == "/job/~1tail"
      Person.point(job.`~1`) == "/job/~01"
