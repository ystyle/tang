package tang

import std.unittest.*
import std.unittest.testmacro.*

struct CleanTest {
    CleanTest(let path:String, let result:String){}
}

var cleanTests = Array<CleanTest>([
    // Already clean
    CleanTest("/", "/"),
    CleanTest("/abc", "/abc"),
    CleanTest("/a/b/c", "/a/b/c"),
    CleanTest("/abc/", "/abc/"),
    CleanTest("/a/b/c/", "/a/b/c/"),
    
    // missing root
    CleanTest("", "/"),
    CleanTest("abc", "/abc"),
    CleanTest("abc/def", "/abc/def"),
    CleanTest("a/b/c", "/a/b/c"),

    // Remove doubled slash
    CleanTest("//", "/"),
    CleanTest("/abc//", "/abc/"),
    CleanTest("/abc/def//", "/abc/def/"),
    CleanTest("/a/b/c//", "/a/b/c/"),
    CleanTest("/abc//def//ghi", "/abc/def/ghi"),
    CleanTest("//abc", "/abc"),
    CleanTest("///abc", "/abc"),
    CleanTest("//abc//", "/abc/"),

    // Remove . elements
    CleanTest(".", "/"),
    CleanTest("./", "/"),
    CleanTest("/abc/./def", "/abc/def"),
    CleanTest("/./abc/def", "/abc/def"),
    CleanTest("/abc/.", "/abc/"),

    // Remove .. elements
    CleanTest("..", "/"),
    CleanTest("../", "/"),
    CleanTest("../../", "/"),
    CleanTest("../..", "/"),
    CleanTest("../../abc", "/abc"),
    CleanTest("/abc/def/ghi/../jkl", "/abc/def/jkl"),
    CleanTest("/abc/def/../ghi/../jkl", "/abc/jkl"),
    CleanTest("/abc/def/..", "/abc"),
    CleanTest("/abc/def/../..", "/"),
    CleanTest("/abc/def/../../..", "/"),
    CleanTest("/abc/def/../../..", "/"),
    CleanTest("/abc/def/../../../ghi/jkl/../../../mno", "/mno"),

    // Combinations
    CleanTest("abc/./../def", "/def"),
    CleanTest("abc//./../def", "/def"),
    CleanTest("abc/../../././../def", "/def")
])

@Test
func TestPathClean():Unit {
    for (test in cleanTests) {
        let s1 = cleanPath(test.path)
        if (s1 != test.result) {
            throw Exception("Clean(${test.path}) = ${s1}, want ${test.result}")
        }
        let s2 = cleanPath(test.result)
        if (s2 != test.result) {
            throw Exception("Clean(${test.result}) = ${s2}, want ${test.result}")
        }
    }
}