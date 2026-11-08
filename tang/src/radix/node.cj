package tang.radix

import std.collection.ArrayList

///
/// RadixNode 表示基数树的节点
///
class RadixNode<V> {
    var prefix: String
    var children: ArrayList<RadixNode<V>>
    var value: ?V = None

    init(prefix: String) {
        this.prefix = prefix
        this.children = ArrayList<RadixNode<V>>()
    }

    /// 插入键值对
    func insert(key: String, value: V): Unit {
        // 查找可以共享前缀的子节点
        for (i in 0..this.children.size) {
            let child = this.children[i]

            // 计算公共前缀长度
            let commonPrefix = longestCommonPrefix(key, child.prefix)

            if (commonPrefix == 0) {
                // 没有公共前缀，继续检查下一个子节点
                continue
            }

            if (commonPrefix < child.prefix.size) {
                // 公共前缀小于子节点前缀，需要分裂子节点
                // 例如：已有 "user/"，插入 "user_file"
                // 分裂成：user -> / 和 _file

                // 1. 创建新节点，包含原节点的剩余部分
                let splitNode = RadixNode<V>(child.prefix[commonPrefix..])
                splitNode.children = child.children
                splitNode.value = child.value

                // 2. 修改原节点为公共前缀部分
                child.prefix = child.prefix[..commonPrefix]
                child.children = ArrayList<RadixNode<V>>()
                child.children.add(splitNode)
                child.value = None

                // 3. 如果公共前缀等于 key，说明当前节点就是目标
                if (commonPrefix == key.size) {
                    child.value = Some(value)
                    return
                }

                // 4. 否则，为新创建的分支节点添加子节点
                let newNode = RadixNode<V>(key[commonPrefix..])
                newNode.value = Some(value)
                child.children.add(newNode)
                return
            }

            // 公共前缀等于子节点前缀
            if (commonPrefix == key.size) {
                // key 是子节点前缀的前缀，直接设置值
                child.value = Some(value)
                return
            }

            // key 比子节点前缀长，继续在子节点中插入剩余部分
            child.insert(key[commonPrefix..], value)
            return
        }

        // 没有找到可共享前缀的子节点，创建新子节点
        let newNode = RadixNode<V>(key)
        newNode.value = Some(value)
        this.children.add(newNode)
    }

    /// 搜索键对应的节点
    func search(key: String): ?RadixNode<V> {
        // 检查是否有子节点匹配
        for (child in this.children) {
            if (key.startsWith(child.prefix)) {
                // 找到匹配的子节点
                let remaining = key[child.prefix.size..]
                if (remaining.isEmpty()) {
                    // 完全匹配
                    return child
                }
                // 继续在子节点中搜索剩余部分
                return child.search(remaining)
            }
        }

        // 没找到匹配
        return None
    }

    /// 查找最长前缀匹配
    func longestPrefix(key: String, currentPath: String): (String, ?V) {
        var bestMatch = (currentPath, this.value)

        for (child in this.children) {
            if (key.startsWith(child.prefix)) {
                let remaining = key[child.prefix.size..]
                let newPath = currentPath + child.prefix

                // 如果子节点有值，更新最佳匹配
                if (let Some(v) <- child.value) {
                    bestMatch = (newPath, Some(v))
                }

                // 继续向下搜索
                if (!remaining.isEmpty()) {
                    let (path, value) = child.longestPrefix(remaining, newPath)
                    if (let Some(v) <- value) {
                        return (path, Some(v))
                    }
                } else {
                    return bestMatch
                }
            }
        }

        return bestMatch
    }
}

/// 计算两个字符串的公共前缀长度
func longestCommonPrefix(a: String, b: String): Int64 {
    let runesA = a.toRuneArray()
    let runesB = b.toRuneArray()
    var i: Int64 = 0

    while (i < runesA.size && i < runesB.size && runesA[Int64(i)] == runesB[Int64(i)]) {
        i++
    }

    return i
}
