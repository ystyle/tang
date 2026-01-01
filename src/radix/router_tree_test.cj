package tang.radix

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TestRouteNode {
    @TestCase
    func testInsertStaticRoute(): Unit {
        let root = RouteNode("")
        root.insertRoute("GET", "/", { _ => () })
        root.insertRoute("GET", "/home", { _ => () })
        root.insertRoute("GET", "/about", { _ => () })

        let (node1, _) = root.searchRoute("GET", "/")
        if (let None <- node1) {
            @Fail("node1 should be Some")
        }

        let (node2, _) = root.searchRoute("GET", "/home")
        if (let None <- node2) {
            @Fail("node2 should be Some")
        }

        let (node3, _) = root.searchRoute("GET", "/about")
        if (let None <- node3) {
            @Fail("node3 should be Some")
        }
    }

    @TestCase
    func testInsertParamRoute(): Unit {
        let root = RouteNode("")
        root.insertRoute("GET", "/user/:id", { params =>
            let id = params.get("id")
            if (let Some(v) <- id) {
                @Assert("123", v)
            }
        })

        let (node, params) = root.searchRoute("GET", "/user/123")
        if (let None <- node) {
            @Fail("node should be Some")
        }
        let id = params.get("id")
        if (let Some(v) <- id) {
            @Assert("123", v)
        } else {
            @Fail("id should be Some")
        }
    }

    @TestCase
    func testInsertWildcardRoute(): Unit {
        let root = RouteNode("")
        root.insertRoute("GET", "/files/*path", { params =>
            let path = params.get("path")
            if (let Some(v) <- path) {
                @Assert("docs/file.txt", v)
            }
        })

        let (node, params) = root.searchRoute("GET", "/files/docs/file.txt")
        if (let None <- node) {
            @Fail("node should be Some")
        }
        let path = params.get("path")
        if (let Some(v) <- path) {
            @Assert("docs/file.txt", v)
        } else {
            @Fail("path should be Some")
        }
    }

    @TestCase
    func testStaticRoutePriority(): Unit {
        let root = RouteNode("")
        root.insertRoute("GET", "/user/current", { _ => () })
        root.insertRoute("GET", "/user/:id", { _ => () })

        // 静态路由应该优先于参数路由
        let (node1, _) = root.searchRoute("GET", "/user/current")
        if (let None <- node1) {
            @Fail("node1 should be Some")
        }

        let (node2, params2) = root.searchRoute("GET", "/user/123")
        if (let None <- node2) {
            @Fail("node2 should be Some")
        }
        let id = params2.get("id")
        if (let Some(v) <- id) {
            @Assert("123", v)
        } else {
            @Fail("id should be Some")
        }
    }

    @TestCase
    func testMultipleMethods(): Unit {
        let root = RouteNode("")
        root.insertRoute("GET", "/api/users", { _ => () })
        root.insertRoute("POST", "/api/users", { _ => () })

        let (node1, _) = root.searchRoute("GET", "/api/users")
        if (let None <- node1) {
            @Fail("node1 should be Some")
        }

        let (node2, _) = root.searchRoute("POST", "/api/users")
        if (let None <- node2) {
            @Fail("node2 should be Some")
        }

        let (node3, _) = root.searchRoute("DELETE", "/api/users")
        if (let Some(_) <- node3) {
            @Fail("node3 should be None")
        }
    }

    @TestCase
    func testNestedParams(): Unit {
        let root = RouteNode("")
        root.insertRoute("GET", "/user/:id/post/:postId", { params =>
            let id = params.get("id")
            let postId = params.get("postId")
            if (let Some(v1) <- id && let Some(v2) <- postId) {
                @Assert("123", v1)
                @Assert("456", v2)
            }
        })

        let (node, params) = root.searchRoute("GET", "/user/123/post/456")
        if (let None <- node) {
            @Fail("node should be Some")
        }
        let id = params.get("id")
        let postId = params.get("postId")
        if (let Some(v1) <- id && let Some(v2) <- postId) {
            @Assert("123", v1)
            @Assert("456", v2)
        } else {
            @Fail("params should be Some")
        }
    }

    @TestCase
    func testNotFound(): Unit {
        let root = RouteNode("")
        root.insertRoute("GET", "/home", { _ => () })

        let (node1, _) = root.searchRoute("GET", "/about")
        if (let Some(_) <- node1) {
            @Fail("node1 should be None")
        }

        let (node2, _) = root.searchRoute("POST", "/home")
        if (let Some(_) <- node2) {
            @Fail("node2 should be None")
        }
    }

    @TestCase
    func testComplexRoute(): Unit {
        let root = RouteNode("")

        // 测试 examples/basic 中的路由
        root.insertRoute("GET", "/hello", { _ => () })
        root.insertRoute("GET", "/api/user/current", { _ => () })
        root.insertRoute("GET", "/api/user/:id", { _ => () })
        root.insertRoute("GET", "/api/user_file/*path", { _ => () })

        // 测试静态路由 /hello
        let (node1, _) = root.searchRoute("GET", "/hello")
        if (let None <- node1) {
            @Fail("node1 should be Some")
        }

        // 测试静态路由 /api/user/current（应该优先于参数路由）
        let (node2, _) = root.searchRoute("GET", "/api/user/current")
        if (let None <- node2) {
            @Fail("node2 should be Some")
        }

        // 测试参数路由 /api/user/123
        let (node3, params3) = root.searchRoute("GET", "/api/user/123")
        if (let None <- node3) {
            @Fail("node3 should be Some")
        }
        let id = params3.get("id")
        if (let Some(v) <- id) {
            @Assert("123", v)
        } else {
            @Fail("id should be Some")
        }

        // 测试通配符路由 /api/user_file/docs/file.txt
        let (node4, params4) = root.searchRoute("GET", "/api/user_file/docs/file.txt")
        if (let None <- node4) {
            @Fail("node4 should be Some")
        }
        let path = params4.get("path")
        if (let Some(v) <- path) {
            @Assert("docs/file.txt", v)
        } else {
            @Fail("path should be Some")
        }
    }

    @TestCase
    func testParamAndWildcardCoexistence(): Unit {
        let root = RouteNode("")

        // 测试 path_params 示例中的路由：参数路由和通配符路由在同一节点
        root.insertRoute("GET", "/api/user/:id", { _ => () })
        root.insertRoute("GET", "/api/user/*path", { _ => () })

        // 单段路径应该匹配参数路由
        let (node1, params1) = root.searchRoute("GET", "/api/user/123")
        if (let None <- node1) {
            @Fail("node1 should be Some")
        }
        let id = params1.get("id")
        if (let Some(v) <- id) {
            @Assert("123", v)
        } else {
            @Fail("id should be Some for single segment path")
        }

        // 多段路径应该匹配通配符路由
        let (node2, params2) = root.searchRoute("GET", "/api/user/files/docs")
        if (let None <- node2) {
            @Fail("node2 should be Some")
        }
        let path = params2.get("path")
        if (let Some(v) <- path) {
            @Assert("files/docs", v)
        } else {
            @Fail("path should be Some for multi-segment path")
        }

        // 另一个多段路径测试
        let (node3, params3) = root.searchRoute("GET", "/api/user/test/path")
        if (let None <- node3) {
            @Fail("node3 should be Some")
        }
        let path3 = params3.get("path")
        if (let Some(v) <- path3) {
            @Assert("test/path", v)
        } else {
            @Fail("path3 should be Some")
        }
    }

    @TestCase
    func testAllMethodRoute(): Unit {
        let root = RouteNode("")

        // 注册一个匹配所有方法的路由
        root.insertRoute("*", "/health", { _ => () })

        // 应该匹配所有 HTTP 方法
        let methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]

        for (method in methods) {
            let (node, _) = root.searchRoute(method, "/health")
            if (let None <- node) {
                @Fail("node should be Some for method ${method}")
            }
        }

        // 测试优先级：具体方法应该优先于 all
        root.insertRoute("GET", "/status", { _ => () })
        root.insertRoute("*", "/status", { _ => () })

        let (node1, _) = root.searchRoute("GET", "/status")
        if (let None <- node1) {
            @Fail("node1 should be Some for GET /status")
        }

        let (node2, _) = root.searchRoute("POST", "/status")
        if (let None <- node2) {
            @Fail("node2 should be Some for POST /status")
        }
    }
}
