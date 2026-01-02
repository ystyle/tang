package tang

import std.collection.HashMap
import std.collection.ArrayList
import cjpminfo.*

///
/// Banner 和路由打印工具
///

// 从 cjpm.toml 自动获取版本号
let TANG_VERSION: String = @ModuleVer("1.0.0")

class BannerPrinter {
    // ANSI 颜色代码（使用字符数组）
    // String.fromUtf8() 不是编译时常量，使用 let 而不是 const
    public static let RESET: String = String.fromUtf8([0x1Bu8, 0x5B, 0x30, 0x6D]) // \u001b[0m
    public static let BRIGHT_CYAN: String = String.fromUtf8([0x1Bu8, 0x5B, 0x39, 0x36, 0x6D]) // \u001b[96m
    public static let BRIGHT_GREEN: String = String.fromUtf8([0x1Bu8, 0x5B, 0x39, 0x32, 0x6D]) // \u001b[92m
    public static let BRIGHT_YELLOW: String = String.fromUtf8([0x1Bu8, 0x5B, 0x39, 0x33, 0x6D]) // \u001b[93m
    public static let BRIGHT_BLUE: String = String.fromUtf8([0x1Bu8, 0x5B, 0x39, 0x34, 0x6D]) // \u001b[94m
    public static let BRIGHT_MAGENTA: String = String.fromUtf8([0x1Bu8, 0x5B, 0x39, 0x35, 0x6D]) // \u001b[95m
    public static let BRIGHT_RED: String = String.fromUtf8([0x1Bu8, 0x5B, 0x39, 0x31, 0x6D]) // \u001b[91m
    public static let BOLD: String = String.fromUtf8([0x1Bu8, 0x5B, 0x31, 0x6D]) // \u001b[1m
    public static let DIM: String = String.fromUtf8([0x1Bu8, 0x5B, 0x32, 0x6D]) // \u001b[2m

    /// 打印 Tang Banner
    public static func printBanner(version!: String = TANG_VERSION, port!: UInt16 = 8080) {
        let supportColor = supportsColor()

        if (!supportColor) {
            printSimpleBanner(version, port)
            return
        }

        // ASCII Art Banner - Bright Theme
        println("")
        println("${BRIGHT_CYAN}${BOLD} _____  _    _   _  ____")
        println("${BRIGHT_CYAN}${BOLD}|_   _|/ \\  | \\ | |/ ___|")
        println("${BRIGHT_CYAN}${BOLD}  | | / _ \\ |  \\| | |  _")
        println("${BRIGHT_CYAN}${BOLD}  | |/ ___ \\| |\\  | |_| |")
        println("${BRIGHT_CYAN}${BOLD}  |_/_/   \\_\\_| \\_|\\____|${RESET}")
        println("")

        // 版本信息 - Bright Theme
        println("${BRIGHT_CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}")
        println("${BOLD}  Tang Web Framework${RESET}      ${BRIGHT_GREEN}${BOLD}v${version}${RESET}")
        println("${DIM}  High-performance Web Framework for Cangjie${RESET}")
        println("${BRIGHT_CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}")
        println("")

        // 服务器信息 - Bright Theme
        println("${BOLD}▶${RESET} ${BRIGHT_BLUE}Server:${RESET}    ${BRIGHT_GREEN}${BOLD}http://localhost:${port}${RESET}")
        println("${BOLD}▶${RESET} ${BRIGHT_BLUE}Mode:${RESET}      ${BRIGHT_GREEN}${BOLD}production${RESET}")
        println("${BOLD}▶${RESET} ${BRIGHT_BLUE}Ready:${RESET}    ${BRIGHT_CYAN}${BOLD}Accepting connections${RESET} ${BRIGHT_GREEN}✓${RESET}")
        println("")
    }

    /// 无颜色的简单 Banner
    public static func printSimpleBanner(version: String, port: UInt16) {
        println("")
        println(" _____  _    _   _  ____")
        println("|_   _|/ \\  | \\ | |/ ___|")
        println("  | | / _ \\ |  \\| | |  _")
        println("  | |/ ___ \\| |\\  | |_| |")
        println("  |_/_/   \\_\\_| \\_|\\____|")
        println("")
        println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        println("  Tang Web Framework    v${version}")
        println("  High-performance Web Framework for Cangjie")
        println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        println("")
        println("▶ Server:    http://localhost:${port}")
        println("▶ Mode:      production")
        println("▶ Ready:    Accepting connections ✓")
        println("")
    }

    /// 检测终端是否支持颜色
    public static func supportsColor(): Bool {
        // TODO: 实现环境变量检测
        return true
    }

    /// 打印路由表格
    public static func printRoutes(handlers: HashMap<String, HandlerFunc>) {
        let supportColor = supportsColor()

        if (handlers.size == 0) {
            return
        }

        println("${BRIGHT_CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}")
        println("${BOLD}  Registered Routes (${handlers.size})${RESET}")
        println("${BRIGHT_CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}")
        println("")

        // 表头
        if (supportColor) {
            println("${BOLD}  Method    Pattern${RESET}")
            println("  ──────    ───────")
        } else {
            println("  Method    Pattern")
            println("  ──────    ───────")
        }

        // 按方法分组收集路由
        var routesByMethod = HashMap<String, ArrayList<String>>()
        for ((key, v) in handlers) {
            let parts = key.split(':').toArray()
            if (parts.size >= 2) {
                let method = parts[0]
                let pattern = parts[1]

                if (routesByMethod.contains(method)) {
                    // 已存在，获取列表并添加
                    match (routesByMethod.get(method)) {
                        case Some(list) => list.add(pattern)
                        case None => ()
                    }
                } else {
                    // 不存在，创建新列表
                    let list = ArrayList<String>()
                    list.add(pattern)
                    routesByMethod[method] = list
                }
            }
        }

        // 按方法排序并打印
        let methodOrder = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS", "*"]
        var sortedMethods = ArrayList<String>()

        // 先添加已知方法
        for (method in methodOrder) {
            if (routesByMethod.contains(method)) {
                sortedMethods.add(method)
            }
        }

        // 再添加其他方法
        for ((method, _) in routesByMethod) {
            if (!methodOrder.contains(method)) {
                sortedMethods.add(method)
            }
        }

        // 打印路由
        for (method in sortedMethods) {
            match (routesByMethod.get(method)) {
                case Some(patterns) =>
                    let sortedPatterns = sortPatterns(patterns)

                    for (pattern in sortedPatterns) {
                        let methodColored = colorizeMethod(method, supportColor)
                        println("  ${methodColored}    ${pattern}")
                    }
                case None => ()
            }
        }

        println("")
        println("${BRIGHT_GREEN}${BOLD}✓ All routes registered successfully${RESET}")
        println("")
    }

    /// 对路径进行排序（静态路径优先，然后是动态路径，最后是通配符）
    public static func sortPatterns(patterns: ArrayList<String>): ArrayList<String> {
        var sortedPatterns = ArrayList<String>()

        // 先添加静态路径
        for (pattern in patterns) {
            if (!pattern.contains(":") && !pattern.contains("*")) {
                sortedPatterns.add(pattern)
            }
        }

        // 再添加动态路径
        for (pattern in patterns) {
            if (pattern.contains(":") && !pattern.contains("*")) {
                sortedPatterns.add(pattern)
            }
        }

        // 最后添加通配符路径
        for (pattern in patterns) {
            if (pattern.contains("*")) {
                sortedPatterns.add(pattern)
            }
        }

        return sortedPatterns
    }

    /// 为 HTTP 方法着色 - Bright Theme 配色
    public static func colorizeMethod(method: String, supportColor: Bool): String {
        if (!supportColor) {
            return formatMethod(method)
        }

        match (method) {
            case "GET" => return "${BRIGHT_BLUE}${BOLD}${formatMethod(method)}${RESET}"        // 亮蓝色
            case "POST" => return "${BRIGHT_GREEN}${BOLD}${formatMethod(method)}${RESET}"      // 亮绿色
            case "PUT" => return "${BRIGHT_YELLOW}${BOLD}${formatMethod(method)}${RESET}"      // 亮黄色
            case "DELETE" => return "${BRIGHT_RED}${BOLD}${formatMethod(method)}${RESET}"      // 亮红色
            case "PATCH" => return "${BRIGHT_MAGENTA}${BOLD}${formatMethod(method)}${RESET}"   // 亮紫色
            case "HEAD" => return "${DIM}${formatMethod(method)}${RESET}"
            case "OPTIONS" => return "${DIM}${formatMethod(method)}${RESET}"
            case "*" => return "${BRIGHT_CYAN}${BOLD}${formatMethod(method)}${RESET}"         // 通配符青色
            case _ => return formatMethod(method)
        }
    }

    /// 格式化方法名（固定宽度）
    public static func formatMethod(method: String): String {
        let width = 8
        if (method.size >= width) {
            return method
        }

        var result = method
        let padding = width - method.size
        for (_ in 0..padding) {
            result += " "
        }
        return result
    }
}
