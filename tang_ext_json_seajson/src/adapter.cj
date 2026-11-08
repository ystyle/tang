package tang_ext_json_seajson

import seajson.*
import tang.{JsonSink, JsonCodec, registerJsonCodec}
import tang.TangHttpContext

/// 把 tang 的 JsonSink 桥接成 seajson 的 JsonTextSink
class BridgeSink <: JsonTextSink {
    let sink: JsonSink

    init(sink: JsonSink) {
        this.sink = sink
    }

    public func append(text: String): Unit {
        sink.append(text)
    }

    public func finish(): Unit {
        sink.finish()
    }
}

/// 基于 SeaJSON 的 JSON 编解码器（零 stdx）
///
/// 编码分两条路：
///   - 类型实现了 JsonWriterEncodable：走 seajson 的 JsonWriter 逐字段写出（真流式）
///   - 只实现 JsonEncodable：整段 toJsonString() 后写入 sink（退化为一次大 append）
public class SeaJsonCodec <: JsonCodec {
    public init() {}

    public func contentType(): String {
        return "application/json; charset=utf-8"
    }

    public func encodeTo(sink: JsonSink, value: Any): Unit {
        match (value) {
            case e: JsonWriterEncodable =>
                let w = JsonWriter(sink: BridgeSink(sink))
                e.writeJson(w)
                w.finish()
            case e: JsonEncodable =>
                sink.append(e.toJsonString())
            case _ =>
                throw Exception("SeaJsonCodec: value 未实现 JsonEncodable / JsonWriterEncodable")
        }
    }
}

/// 进程内单例 codec（无状态）
let seaJsonCodec: SeaJsonCodec = SeaJsonCodec()

/// 注册为 tang 的默认 JSON codec
public func useSeaJson(): Unit {
    registerJsonCodec(seaJsonCodec)
}

/// 取 codec 实例（需要显式传 codec 的场景）
public func codec(): SeaJsonCodec {
    return seaJsonCodec
}

/// 从请求体反序列化（泛型约束落在适配器，因此只能是自由函数）
public func bindJson<T>(ctx: TangHttpContext): ?T where T <: JsonDecodable<T> {
    let body = ctx.raw.body()
    if (body.isEmpty()) {
        return None
    }
    try {
        return Some(T.fromJsonString(String.fromUtf8(body.toArray())))
    } catch (e: JsonDecodeError) {
        return None
    } catch (e: Exception) {
        return None
    }
}
