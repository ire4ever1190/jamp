import std/unittest
import jamp/jsonptr


type
  Job = object
    title: string
    `~head`: string
    directions: seq[string]
    
  Person = object
    name: string
    age: int
    job: Job
    sideGigs: seq[Job]


suite "JSON pointer":
  test "Everything":
    check Person.point() == ""
    
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

  test "Element that doesnt exist":
    check not compiles(Person.point(noExist))

  test "Using array on non array type":
    check not compiles(Person.point(age[0]))

