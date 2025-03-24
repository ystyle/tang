package tang.log

import log.{getGlobalLogger, setGlobalLogger, LogLevel, LogValue, Logger}
import std.io.{BufferedOutputStream, OutputStream}
import logger.{JsonLogger , TextLogger }
import std.env.getStdOut
import std.collection.ArrayList

public enum LogType {
    Json | Text
}

public class TangLogerConfig {
    var defaultLogType = Json
    var defaultLogLevel = LogLevel.INFO
    var output:OutputStream = BufferedOutputStream<OutputStream>(getStdOut())
    var logger:Logger = JsonLogger(output)
    public func setLogType(t:LogType):Unit {
        this.defaultLogType = t
    }
    public func setLogLevel(lv:LogLevel):Unit {
        this.defaultLogLevel = lv
    }
    public func setOuput(output:OutputStream) {
        this.output = output
    }
}

var defaultconfig = TangLogerConfig()

public func setLogConfig(config:TangLogerConfig) {
    defaultconfig = config
}

public func getLogger(attrs: Array<(String, LogValue)>):Logger {
    var logger:Logger
    match (defaultconfig.defaultLogType) {
        case Json =>  logger = JsonLogger(defaultconfig.output)
        case Text => logger = TextLogger(defaultconfig.output)
    }
    logger.level = defaultconfig.defaultLogLevel
    return logger.withAttrs(("Application", "Tang")).withAttrs(attrs)
}