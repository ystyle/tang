package default
import echo.*


func main():Unit {
    println("hello world")
    testAll()
}

func testAll():Unit {
    try {
        TestPathClean()
    } catch (e:Exception) {
        e.printStackTrace()
    }
}

record cleanTest {
    cleanTest(let path:String, let result:String){}
}

var cleanTests = Array<cleanTest>([
    // Already clean
    cleanTest("/", "/"),
    cleanTest("/abc", "/abc"),
    cleanTest("/a/b/c", "/a/b/c"),
    cleanTest("/abc/", "/abc/"),
    cleanTest("/a/b/c/", "/a/b/c/"),
    
    // missing root
    cleanTest("", "/"),
    cleanTest("abc", "/abc"),
    cleanTest("abc/def", "/abc/def"),
    cleanTest("a/b/c", "/a/b/c"),

    // Remove doubled slash
    cleanTest("//", "/"),
    cleanTest("/abc//", "/abc/"),
    cleanTest("/abc/def//", "/abc/def/"),
    cleanTest("/a/b/c//", "/a/b/c/"),
    cleanTest("/abc//def//ghi", "/abc/def/ghi"),
    cleanTest("//abc", "/abc"),
    cleanTest("///abc", "/abc"),
    cleanTest("//abc//", "/abc/"),

    // Remove . elements
    cleanTest(".", "/"),
    cleanTest("./", "/"),
    cleanTest("/abc/./def", "/abc/def"),
    cleanTest("/./abc/def", "/abc/def"),
    cleanTest("/abc/.", "/abc/"),

    // Remove .. elements
    cleanTest("..", "/"),
    cleanTest("../", "/"),
    cleanTest("../../", "/"),
    cleanTest("../..", "/"),
    cleanTest("../../abc", "/abc"),
    cleanTest("/abc/def/ghi/../jkl", "/abc/def/jkl"),
    cleanTest("/abc/def/../ghi/../jkl", "/abc/jkl"),
    cleanTest("/abc/def/..", "/abc"),
    cleanTest("/abc/def/../..", "/"),
    cleanTest("/abc/def/../../..", "/"),
    cleanTest("/abc/def/../../..", "/"),
    cleanTest("/abc/def/../../../ghi/jkl/../../../mno", "/mno"),

    // Combinations
    cleanTest("abc/./../def", "/def"),
    cleanTest("abc//./../def", "/def"),
    cleanTest("abc/../../././../def", "/def")
])


func TestPathClean() {
    for (test in cleanTests) {
        let s1 = CleanPath(test.path)
        if (s1 != test.result) {
            throw Exception("Clean(${test.path}) = ${s1}, want ${test.result}")
        }
        let s2 = CleanPath(test.result)
        if (s2 != test.result) {
            throw Exception("Clean(${test.result}) = ${s2}, want ${test.result}")
        }
    }
}