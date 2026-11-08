package tang

import std.collection.ArrayList
import std.convert.*

/// JSON 输出目标（零依赖契约）
///
/// 之所以是"片段 sink"而不是"writer"：各家的 writer 类型（seajson 的 JsonWriter、
/// stdx 的 JsonWriter）属于各自的库，core 不能引用；但它们的输出本质都是文本片段，
/// 所以 core 只定一个最小的 append/finish 契约，适配器负责把自家 writer 桥接过来。
public interface JsonSink {
    func append(piece: String): Unit
    func finish(): Unit
}

/// JSON 编解码器（由扩展成员实现并注册）
public interface JsonCodec {
    /// 把 value 增量写进 sink（不物化整段 JSON）
    func encodeTo(sink: JsonSink, value: Any): Unit
    /// 该 codec 产出的 Content-Type
    func contentType(): String
}

/// 默认 sink：内部攒成 String，finish 时一次成型。
///
/// 相比"每片段都转一次字节"，这种形态对 seajson 那种逐片段 append 的 writer 更友好。
public class BufferJsonSink <: JsonSink {
    let sb: StringBuilder = StringBuilder()

    public init() {}

    public func append(piece: String): Unit {
        sb.append(piece)
    }

    public func finish(): Unit {
        ()
    }

    public func toString(): String {
        return sb.toString()
    }
}

/// 把 codec 的输出收敛成 String（便利方法）
public func jsonToString(codec: JsonCodec, value: Any): String {
    let sink = BufferJsonSink()
    codec.encodeTo(sink, value)
    sink.finish()
    return sink.toString()
}

/// 全局默认 JSON codec。
///
/// 之所以是全局而不是 ctx 字段：codec 是进程级配置，且 TanHttpContext 每请求创建，
/// 挂字段会让每个请求都多一次判空/间接访问。注册在启动时做一次即可。
var defaultJsonCodec: ?JsonCodec = None

/// 注册默认 JSON codec（扩展成员在应用启动时调用）
public func registerJsonCodec(codec: JsonCodec): Unit {
    defaultJsonCodec = Some(codec)
}

/// 取当前 codec（未注册返回 None）
public func getJsonCodec(): ?JsonCodec {
    defaultJsonCodec
}

/// 查询参数绑定契约（零依赖）
///
/// 用户类型实现本接口即可被 `ctx.bindQuery<T>()` 绑定；
/// 不想实现接口的可以改用扩展成员的适配器（seajson / 旧 datamodel）。
public interface QueryBindable {
    func bindQuery(params: QueryParams): Unit
}

/// 查询参数只读视图
public class QueryParams {
    let get: (String) -> ?String

    public init(getter: (String) -> ?String) {
        this.get = getter
    }

    public func value(key: String): ?String {
        return get(key)
    }

    public func int(key: String): ?Int64 {
        match (get(key)) {
            case Some(v) => return Int64.tryParse(v)
            case None => return None
        }
    }

    public func float(key: String): ?Float64 {
        match (get(key)) {
            case Some(v) => return Float64.tryParse(v)
            case None => return None
        }
    }

    public func bool(key: String): ?Bool {
        match (get(key)) {
            case Some(v) => return Bool.tryParse(v)
            case None => return None
        }
    }
}
