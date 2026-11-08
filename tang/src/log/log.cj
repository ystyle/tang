package tang.log

import std.io.{BufferedOutputStream, OutputStream}
import std.env.getStdOut
import std.time.DateTime
import std.collection.ArrayList

/// 日志级别（core 自己的门面类型，与 stdx 无关）
public enum LogLevel {
    | OFF
    | FATAL
    | ERROR
    | WARN
    | INFO
    | DEBUG
    | TRACE
}

/// 数值化，便于比较"是否达到阈值"
public func levelValue(lv: LogLevel): Int64 {
    match (lv) {
        case OFF => return 0
        case FATAL => return 1
        case ERROR => return 2
        case WARN => return 3
        case INFO => return 4
        case DEBUG => return 5
        case TRACE => return 6
    }
}

public func isOff(lv: LogLevel): Bool {
    match (lv) {
        case OFF => return true
        case _ => return false
    }
}

public func levelName(lv: LogLevel): String {
    match (lv) {
        case OFF => return "OFF"
        case FATAL => return "FATAL"
        case ERROR => return "ERROR"
        case WARN => return "WARN"
        case INFO => return "INFO"
        case DEBUG => return "DEBUG"
        case TRACE => return "TRACE"
    }
}

/// 结构化日志字段值
///
/// 为什么不全用 String：数值字段（status/latency）要能被结构化输出成数字，
/// 否则 JSON 日志里全是字符串，下游还要再转一次。
public enum LogValue {
    | VString(String)
    | VInt(Int64)
    | VFloat(Float64)
    | VBool(Bool)
}

public func logValueText(v: LogValue): String {
    match (v) {
        case VString(s) => return s
        case VInt(i) => return i.toString()
        case VFloat(f) => return f.toString()
        case VBool(b) => return b.toString()
    }
}

/// 日志门面
///
/// core 只依赖这个接口；具体实现可以是内置的 `DefaultLogger`（零依赖），
/// 也可以是扩展成员（如 `tang_ext_log_stdx`）桥接到 stdx.log。
public interface Logger {
    func enabled(level: LogLevel): Bool
    func log(level: LogLevel, message: String, attrs: ArrayList<(String, LogValue)>): Unit

    // 便捷方法（接口默认实现）
    func info(message: String): Unit {
        log(LogLevel.INFO, message, ArrayList<(String, LogValue)>())
    }

    func warn(message: String): Unit {
        log(LogLevel.WARN, message, ArrayList<(String, LogValue)>())
    }

    func error(message: String): Unit {
        log(LogLevel.ERROR, message, ArrayList<(String, LogValue)>())
    }

    func error(message: String, attr: (String, LogValue)): Unit {
        let attrs = ArrayList<(String, LogValue)>()
        attrs.add(attr)
        log(LogLevel.ERROR, message, attrs)
    }

    func debug(message: String): Unit {
        log(LogLevel.DEBUG, message, ArrayList<(String, LogValue)>())
    }

    func withAttrs(attrs: Array<(String, LogValue)>): Logger {
        let list = ArrayList<(String, LogValue)>()
        for (a in attrs) {
            list.add(a)
        }
        return AttrLogger(this, list)
    }
}

/// 给 Logger 附加固定字段（返回新的包装，不改原对象）
public class AttrLogger <: Logger {
    let inner: Logger
    let attrs: ArrayList<(String, LogValue)>

    public init(inner: Logger, attrs: ArrayList<(String, LogValue)>) {
        this.inner = inner
        this.attrs = attrs
    }

    public func enabled(level: LogLevel): Bool {
        return inner.enabled(level)
    }

    public func log(level: LogLevel, message: String, extra: ArrayList<(String, LogValue)>): Unit {
        let merged = ArrayList<(String, LogValue)>()
        for (a in attrs) {
            merged.add(a)
        }
        for (a in extra) {
            merged.add(a)
        }
        inner.log(level, message, merged)
    }
}

/// 日志输出形态
public enum LogType {
    | Json
    | Text
}

/// 内置默认实现：不依赖任何外部库，直接写 OutputStream
public class DefaultLogger <: Logger {
    var minLevel: LogLevel
    let out: OutputStream
    let logType: LogType

    public init(out: OutputStream, minLevel!: LogLevel = LogLevel.INFO, logType!: LogType = LogType.Text) {
        this.out = out
        this.minLevel = minLevel
        this.logType = logType
    }

    public func enabled(level: LogLevel): Bool {
        if (isOff(level)) {
            return false
        }
        return levelValue(level) <= levelValue(minLevel)
    }

    public func log(level: LogLevel, message: String, attrs: ArrayList<(String, LogValue)>): Unit {
        if (!enabled(level)) {
            return
        }
        let line = match (logType) {
            case Json => renderJson(level, message, attrs)
            case Text => renderText(level, message, attrs)
        }
        try {
            out.write((line + "\n").toArray())
            out.flush()
        } catch (e: Exception) {
            ()
        }
    }

    func renderText(level: LogLevel, message: String, attrs: ArrayList<(String, LogValue)>): String {
        var sb = StringBuilder()
        sb.append(levelName(level))
        sb.append(" ")
        sb.append(message)
        for ((k, v) in attrs) {
            sb.append(" ")
            sb.append(k)
            sb.append("=")
            sb.append(logValueText(v))
        }
        return sb.toString()
    }

    func renderJson(level: LogLevel, message: String, attrs: ArrayList<(String, LogValue)>): String {
        var sb = StringBuilder()
        sb.append("{\"level\":\"")
        sb.append(levelName(level))
        sb.append("\",\"msg\":\"")
        sb.append(escapeJson(message))
        sb.append("\"")
        for ((k, v) in attrs) {
            sb.append(",\"")
            sb.append(escapeJson(k))
            sb.append("\":")
            match (v) {
                case VString(s) =>
                    sb.append("\"")
                    sb.append(escapeJson(s))
                    sb.append("\"")
                case VInt(i) => sb.append(i.toString())
                case VFloat(f) => sb.append(f.toString())
                case VBool(b) => sb.append(b.toString())
            }
        }
        sb.append("}")
        return sb.toString()
    }
}

func escapeJson(s: String): String {
    var sb = StringBuilder()
    for (c in s.toArray()) {
        if (c == 34) {
            sb.append("\\\"")
        } else if (c == 92) {
            sb.append("\\\\")
        } else if (c == 10) {
            sb.append("\\n")
        } else if (c == 13) {
            sb.append("\\r")
        } else {
            sb.append(String.fromUtf8([c]))
        }
    }
    return sb.toString()
}

public class TangLogerConfig {
    var defaultLogType: LogType = LogType.Text
    var defaultLogLevel: LogLevel = LogLevel.INFO
    var output: OutputStream = BufferedOutputStream<OutputStream>(getStdOut())

    public init() {}

    public func setLogType(t: LogType): Unit {
        this.defaultLogType = t
    }

    public func setLogLevel(lv: LogLevel): Unit {
        this.defaultLogLevel = lv
    }

    public func setOuput(output: OutputStream): Unit {
        this.output = output
    }
}

var defaultconfig = TangLogerConfig()
var customLogger: ?Logger = None

public func setLogConfig(config: TangLogerConfig): Unit {
    defaultconfig = config
}

/// 用外部实现替换默认 logger（例如扩展成员提供的 stdx 桥接实现）
public func setLogger(logger: Logger): Unit {
    customLogger = Some(logger)
}

public func getLogger(): Logger {
    return getLogger(ArrayList<(String, LogValue)>())
}

public func getLogger(attrs: Array<(String, LogValue)>): Logger {
    return getLogger(toAttrList(attrs))
}

func toAttrList(attrs: Array<(String, LogValue)>): ArrayList<(String, LogValue)> {
    let list = ArrayList<(String, LogValue)>()
    for (a in attrs) {
        list.add(a)
    }
    return list
}

public func getLogger(attrs: ArrayList<(String, LogValue)>): Logger {
    let base: Logger = match (customLogger) {
        case Some(l) => l
        case None => DefaultLogger(defaultconfig.output, minLevel: defaultconfig.defaultLogLevel,
                                  logType: defaultconfig.defaultLogType)
    }
    let withApp = ArrayList<(String, LogValue)>()
    withApp.add(("Application", LogValue.VString("Tang")))
    for (a in attrs) {
        withApp.add(a)
    }
    return AttrLogger(base, withApp)
}
