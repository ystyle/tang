package tang.radix

import std.collection.ArrayList

/// 节点类型
public enum NodeType {
    | Static    // 静态路径，如 /home
    | Param     // 命名参数，如 /:id
    | Wildcard  // 通配符，如 /*path
}

/// HTTP方法到处理器的映射
public class MethodHandlers {
    var get_: ?RouteHandler = None
    var post: ?RouteHandler = None
    var put: ?RouteHandler = None
    var delete: ?RouteHandler = None
    var patch: ?RouteHandler = None
    var head: ?RouteHandler = None
    var options: ?RouteHandler = None

    func set(method: String, handler: RouteHandler): Unit {
        match (method) {
            case "GET" => this.get_ = Some(handler)
            case "POST" => this.post = Some(handler)
            case "PUT" => this.put = Some(handler)
            case "DELETE" => this.delete = Some(handler)
            case "PATCH" => this.patch = Some(handler)
            case "HEAD" => this.head = Some(handler)
            case "OPTIONS" => this.options = Some(handler)
            case _ => throw Exception("method: ${method} no support")
        }
    }

    func get(method: String): ?RouteHandler {
        match (method) {
            case "GET" => this.get_
            case "POST" => this.post
            case "PUT" => this.put
            case "DELETE" => this.delete
            case "PATCH" => this.patch
            case "HEAD" => this.head
            case "OPTIONS" => this.options
            case _ => None
        }
    }
}

/// 路由树节点，支持HTTP路由特性
public class RouteNode {
    var prefix: String                    // 公共前缀
    var children: ArrayList<RouteNode>    // 子节点
    var paramChild: ?RouteNode = None     // 命名参数子节点
    var wildcardChild: ?RouteNode = None  // 通配符子节点
    var handlers: MethodHandlers = MethodHandlers()  // 按HTTP方法存储的处理器
    var nodeType: NodeType = NodeType.Static
    public var pattern: String = ""       // 存储原始的注册路径（如 /api/user/:id）

    public init(prefix: String, nodeType!: NodeType = NodeType.Static) {
        this.prefix = prefix
        this.children = ArrayList<RouteNode>()
        this.nodeType = nodeType
    }

    /// 插入路由
    public func insertRoute(method: String, pattern: String, handler: RouteHandler): Unit {
        // 去掉前导 '/'
        var search = if (pattern.startsWith("/") && pattern.size > 1) {
            pattern[1..]
        } else if (pattern == "/") {
            pattern
        } else {
            pattern
        }

        // 按 '/' 分割路径
        let segments = search.split('/').toArray()

        var currentNode = this
        var i = 0

        while (i < segments.size) {
            let segment = segments[i]

            // 处理通配符
            if (segment.startsWith("*")) {
                if (let None <- currentNode.wildcardChild) {
                    // 提取参数名（跳过 '*'）
                    let paramName = if (segment.size > 1) { segment[1..] } else { "path" }
                    let wcNode = RouteNode(paramName, nodeType: NodeType.Wildcard)
                    currentNode.wildcardChild = Some(wcNode)
                }
                if (let Some(wcNode) <- currentNode.wildcardChild) {
                    // 最后一个段，设置handler
                    if (i == segments.size - 1) {
                        wcNode.handlers.set(method, handler)
                        wcNode.pattern = pattern
                    } else {
                        currentNode = wcNode
                    }
                }
                i++
                continue
            }

            // 处理命名参数
            if (segment.startsWith(":")) {
                if (let None <- currentNode.paramChild) {
                    // 提取参数名（跳过 ':'）
                    let paramName = if (segment.size > 1) { segment[1..] } else { "param" }
                    let paramNode = RouteNode(paramName, nodeType: NodeType.Param)
                    currentNode.paramChild = Some(paramNode)
                }
                if (let Some(paramChild) <- currentNode.paramChild) {
                    // 最后一个段，设置handler
                    if (i == segments.size - 1) {
                        paramChild.handlers.set(method, handler)
                        paramChild.pattern = pattern
                    } else {
                        currentNode = paramChild
                    }
                }
                i++
                continue
            }

            // 处理静态路径
            // 查找匹配的子节点
            var matchedChild: ?RouteNode = None

            for (child in currentNode.children) {
                match (child.nodeType) {
                    case NodeType.Static =>
                        if (segment == child.prefix) {
                            matchedChild = Some(child)
                            break
                        }
                    case _ => ()
                }
            }

            if (let Some(child) <- matchedChild) {
                // 最后一个段，设置handler
                if (i == segments.size - 1) {
                    child.handlers.set(method, handler)
                    child.pattern = pattern
                } else {
                    currentNode = child
                }
            } else {
                // 创建新的静态节点
                let newNode = RouteNode(segment, nodeType: NodeType.Static)
                // 最后一个段，设置handler
                if (i == segments.size - 1) {
                    newNode.handlers.set(method, handler)
                    newNode.pattern = pattern
                }
                currentNode.children.add(newNode)
                currentNode = newNode

                // 按前缀排序，保证查找顺序
                currentNode.sortChildren()
            }
            i++
        }

        // 处理根路径
        if (segments.size == 0 || pattern == "/") {
            this.handlers.set(method, handler)
            this.pattern = pattern
        }
    }

    /// 查找路由
    public func searchRoute(method: String, path: String): (?RouteNode, RouteParams) {
        // 处理根路径
        if (path == "/" || path.isEmpty()) {
            if (let Some(_) <- this.handlers.get(method)) {
                return (Some(this), RouteParams())
            }
            return (None, RouteParams())
        }

        var params = RouteParams()

        // 去掉前导 '/'
        let searchPath = if (path.startsWith("/") && path.size > 1) {
            path[1..]
        } else {
            path
        }

        // 按 '/' 分割路径
        let segments = searchPath.split('/').toArray()

        var currentNode = this
        var i = 0

        while (i < segments.size) {
            let segment = segments[i]

            // 1. 优先尝试静态路由
            var found = false
            for (child in currentNode.children) {
                match (child.nodeType) {
                    case NodeType.Static =>
                        if (segment == child.prefix) {
                            // 最后一个段
                            if (i == segments.size - 1) {
                                if (let Some(_) <- child.handlers.get(method)) {
                                    return (Some(child), params)
                                }
                            } else {
                                currentNode = child
                                found = true
                            }
                            break
                        }
                    case _ => ()
                }
            }
            if (found) {
                i++
                continue
            }

            // 2. 如果是最后一个段，优先尝试参数路由；否则优先尝试通配符
            let isLastSegment = (i == segments.size - 1)

            if (isLastSegment) {
                // 最后一个段：优先尝试参数路由
                if (let Some(paramChild) <- currentNode.paramChild) {
                    let paramName = paramChild.prefix
                    params.add(paramName, segment)

                    if (let Some(_) <- paramChild.handlers.get(method)) {
                        return (Some(paramChild), params)
                    }
                }
            } else {
                // 不是最后一个段：优先尝试通配符路由
                if (let Some(wcChild) <- currentNode.wildcardChild) {
                    let paramName = wcChild.prefix
                    let remainingPath = String.join(segments[i..], delimiter: "/")
                    params.add(paramName, remainingPath)

                    if (let Some(_) <- wcChild.handlers.get(method)) {
                        return (Some(wcChild), params)
                    }
                }
            }

            // 3. 兜底：如果上面的优先匹配失败，尝试另一种方式
            if (isLastSegment) {
                // 最后一个段但参数路由失败，尝试通配符
                if (let Some(wcChild) <- currentNode.wildcardChild) {
                    let paramName = wcChild.prefix
                    params.add(paramName, segment)

                    if (let Some(_) <- wcChild.handlers.get(method)) {
                        return (Some(wcChild), params)
                    }
                }
            } else {
                // 不是最后一个段但通配符失败，尝试参数路由并继续
                if (let Some(paramChild) <- currentNode.paramChild) {
                    let paramName = paramChild.prefix
                    params.add(paramName, segment)

                    currentNode = paramChild
                    i++
                    continue
                }
            }

            // 都没找到
            return (None, params)
        }

        return (None, params)
    }

    /// 排序子节点（静态路由优先，长的路径优先）
    func sortChildren(): Unit {
        if (this.children.size <= 1) {
            return
        }

        // 简单的冒泡排序，按前缀长度降序
        for (i in 0..this.children.size - 1) {
            for (j in 0..this.children.size - 1 - i) {
                if (this.children[j].prefix.size < this.children[j + 1].prefix.size) {
                    let temp = this.children[j]
                    this.children[j] = this.children[j + 1]
                    this.children[j + 1] = temp
                }
            }
        }
    }
}

/// 路由处理器
public type RouteHandler = (RouteParams) -> Unit

/// 路由参数
public class RouteParams {
    var keys: ArrayList<String> = ArrayList<String>()
    var values: ArrayList<String> = ArrayList<String>()

    func add(key: String, value: String): Unit {
        this.keys.add(key)
        this.values.add(value)
    }

    func addAll(other: RouteParams): Unit {
        for (i in 0..other.keys.size) {
            this.keys.add(other.keys[i])
            this.values.add(other.values[i])
        }
    }

    public func get(key: String): ?String {
        for (i in 0..this.keys.size) {
            if (this.keys[i] == key) {
                return Some(this.values[i])
            }
        }
        return None
    }

    public func forEach(action: (String, String) -> Unit): Unit {
        for (i in 0..this.keys.size) {
            action(this.keys[i], this.values[i])
        }
    }
}
