package tang.radix

///
/// RadixTree 是一个基于基数树的数据结构
/// 用于高效地存储和查找字符串键值对
///
public class RadixTree<V> {
    var root: RadixNode<V>

    public init() {
        this.root = RadixNode<V>("")
    }

    /// 插入一个键值对
    public func insert(key: String, value: V): Unit {
        if (key.isEmpty()) {
            this.root.value = Some(value)
            return
        }
        this.root.insert(key, value)
    }

    /// 查找键对应的值
    public func search(key: String): ?V {
        if (key.isEmpty()) {
            return this.root.value
        }
        let node = this.root.search(key)
        if (let Some(n) <- node) {
            return n.value
        }
        return None
    }

    /// 查找最长前缀匹配
    public func longestPrefix(key: String): (String, ?V) {
        if (key.isEmpty()) {
            return ("", this.root.value)
        }
        return this.root.longestPrefix(key, "")
    }
}
