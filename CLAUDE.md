# Tang
一个仓颉的轻量级的web框架， 初始版本移植自[uptrace/bunrouter]， 后来context按fiber ctx的api 风格做了修改

# 项目操作

```shell
cjpm clean # 清除构建缓存
cjpm build # 构建
cjpm run   # 运行项目
./target/release/bin/main #手动运行
```

# 关于仓颉语法和API
- 如果不清楚一个语言特性，可以使用mcp工具查找仓颉手册内容
- 如果不清楚一个api是否存在，可以使用mcp工具查找仓颉api内容

# 仓颉语言基础语法参考

> **重要提示**：本文档标注 ⚠️ 的内容为实际使用中容易出错的关键点，AI 编写仓颉代码时请特别关注。

仓颉语言（Cangjie），文件后缀为 `.cj`，简称 `cj`。

---

## 1. 变量声明

### 基本语法

```cj
修饰符 变量名: 变量类型 = 初始值
```

### 修饰符详解

#### 可变性修饰符

- `let` - **不可变变量**（只能赋值一次，即初始化）
- `var` - **可变变量**（可以被多次赋值）

⚠️ **重要**：仓颉的 `let` **不支持**像 Rust 那样的变量遮蔽（shadowing），不能在同一个作用域内重新定义同名变量。

#### 可见性修饰符

- `private` - class 定义内可见
- `public` - 模块内外均可见
- `protected` - 当前模块及当前类的子类可见
- `internal` - 仅当前包及子包内可见（**默认值**）

#### 静态性修饰符

- `static` - 影响成员变量的存储和引用方式

### 示例代码

```cj
main() {
    let a: Int64 = 20      // 不可变变量
    var b: Int64 = 12      // 可变变量
    b = 23                // 可以修改 var 变量
    println("${a}${b}")
}
```

---

## 2. 基础类型

### 数值类型

**有符号整数**：`Int8`、`Int16`、`Int32`、`Int64`、`IntNative`

**无符号整数**：`UInt8`、`UInt16`、`UInt32`、`UInt64`、`UIntNative`

**浮点类型**：`Float16`、`Float32`、`Float64`

**布尔类型**：`true`、`false`

### 字符类型（Rune）

使用 `Rune` 表示，可以表示 Unicode 字符集中的所有字符。

```cj
let a: Rune = r'a'
```

#### Rune 转换

- **Rune → UInt32**：`UInt32(e)` - 获取 Unicode scalar value
- **整数 → Rune**：`Rune(num)` - 值必须在有效 Unicode 范围内
  - 有效范围：`[0x0000, 0xD7FF]` 或 `[0xE000, 0x10FFFF]`
  - 编译时可确定值 → 编译报错
  - 运行时确定值 → 抛异常

#### 转义字符

```cj
let slash: Rune = r'\\'
let newLine: Rune = r'\n'
let tab: Rune = r'\t'
```

#### Unicode 字面量

```cj
let he: Rune = r'\u{4f60}'   // 你
let llo: Rune = r'\u{597d}'   // 好
```

### 字符串类型（String）

#### 基本用法

```cj
let s2 = "Hello Cangjie Lang"
```

#### 插值字符串

⚠️ **注意**：插值字符串中使用 `${}` 表达式

```cj
let fruit = "apples"
let count = 10
let s = "There are ${count * count} ${fruit}"
```

#### 字符串转 Rune 数组

```cj
"apples".toRuneArray()
```

#### 多行原始字符串字面量

⚠️ **重要**：以井号（`#`）和引号开头/结尾，**转义规则不适用**

```cj
let s1: String = #""#                              // 空字符串
let s2 = ##'\n'##                                  // \n 不是换行符，是 \ 和 n 两个字符
let s3 = ###"
    Hello,
    Cangjie
    Lang"###
```

### 元组（Tuple）

- **类型表示**：`(T1, T2, ..., TN)`
- **至少二元**：`(Int64, Float64)`、`(Int64, Float64, String)`
- **索引访问**：`tuple[0]`、`tuple[1]`

```cj
var tuple = (true, false)
println(tuple[0])
```

### 数组类型

```cj
Array<T>  // T 是元素类型，可以是任意类型
```

### 区间类型（Range）

- **类型表示**：`Range<T>`（泛型）
- **包含三个值**：`start`、`end`、`step`
- **约束**：
  - `start` 和 `end` 类型相同（T）
  - `step` 类型是 `Int64`
  - `step` 值不能等于 0

### Unit 类型

- **唯一值**：`()`
- **支持操作**：仅赋值、判等、判不等
- ⚠️ **不支持**：其他所有操作

---

## 3. 表达式与控制流

### ⚠️ 条件表达式括号（重要）

**条件表达式的括号不能省略**，这是与很多语言的差异：

```cj
if (条件) {        // ✅ 必须有括号
    分支 1
} else {
    分支 2
}
```

### if 表达式

#### 基本形式

```cj
if (条件) {
    分支 1
} else {
    分支 2
}
```

#### 模式匹配（let pattern）

**语法**：`let pattern <- expression`

- `pattern` - 模式，匹配 expression 的类型和内容
- `<-` - 模式匹配操作符
- `expression` - 表达式（优先级不能低于 `..`）

```cj
let a = Some(3)
let d = Some(1)
if (let Some(e) <- a && let Some(f) <- d) {  // 两个模式都匹配
    println("${e} ${f}")  // 输出: 3 1
}
```

### while 表达式

```cj
while (条件) {
    循环体
}

// do-while 形式
do {
    循环体
} while (条件)
```

### for-in 表达式

```cj
for (迭代变量 in 序列) {
    循环体
}
```

#### 元组遍历

```cj
let array = [(1, 2), (3, 4), (5, 6)]
for ((x, y) in array) {
    println("${x}, ${y}")
}
```

#### 区间遍历

```cj
main() {
    var sum = 0
    for (i in 1..=100) {    // 1 到 100（包含）
        sum += i
    }
    println(sum)
}
```

### ⚠️ 跳转控制（重要）

- 支持 `break`、`continue`
- ⚠️ **不支持标签跳转**
- ⚠️ **完全不支持 `goto`**

---

## 4. 函数

### 函数是一等公民

- 可以作为函数的参数或返回值
- 可以赋值给变量
- 函数本身也有类型

### 函数类型

**语法**：`(参数类型) -> 返回类型`

- 参数类型用 `()` 括起，多个参数用 `,` 分隔
- 参数类型和返回类型用 `->` 连接

```cj
func add(a: Int64, b: Int64): Int64 {
    return a + b
}

type FnType = (Int64) -> Unit

func display(a: Int64): Unit {
    println(a)
}

// 命名参数:
func name(name!:string)

// 命名参数还可以设置默认值
func name(name!:String = "小王")
```

### ⚠️ 函数参数（重要）

**函数参数默认是 `let` 定义的不可变变量**

```cj
// a 和 b 都是不可变的
func add(a: Int64, b: Int64): Int64 {
    return a + b
}
```

### 返回值简写

```cj
func add(a: Int64, b: Int64): Int64 {
    a + b  // 最后一个表达式自动作为返回值
}

func returnAdd(): (Int64, Int64) -> Int64 {
    add  // 可以直接返回函数
}
```

### Lambda 表达式

#### 语法

```cj
{ p1: T1, ..., pn: Tn => expressions | declarations }
```

#### 示例

```cj
// 完整类型声明
let f1 = { a: Int64, b: Int64 => a + b }

// 无参 Lambda
var display = { =>
    println("Hello")
    println("World")
}

// 类型推断
var sum1: (Int64, Int64) -> Int64 = { a, b => a + b }
var sum2: (Int64, Int64) -> Int64 = { a: Int64, b => a + b }

// Lambda 作为参数
func f(a1: (Int64) -> Int64): Int64 {
    a1(1)
}

main(): Int64 {
    f({ a2 => a2 + 10 })  // 参数类型推断
}
```

#### ⚠️ Lambda 立即调用

```cj
let r2 = { => 123 }()  // r2 = 123，立即执行
var g = { x: Int64 => println("x = ${x}") }
g(2)  // 调用 Lambda
```

---

## 5. 枚举类型（enum）

### 定义语法

- 以 `enum` 关头
- 构造器之间使用 `|` 分隔
- **至少存在一个有名字的构造器**
- 第一个构造器之前的 `|` 是可选的

```cj
enum RGBColor {
    | Red(UInt8) | Green(UInt8) | Blue(UInt8)
}
```

### 构造器类型

- **无参构造器**：`C`
- **有参构造器**：`C(p1, p2, ..., pn)`

---

## 6. 模式匹配

### match 表达式

#### 基本语法
⚠️ **case**：不需要{}大括号

```cj
match (待匹配值) {
    case 模式1 => 处理1
    case 模式2 => 处理2
    case _ => 默认处理  // 通配符
}
```

#### 示例

```cj
main() {
    let x = 0
    match (x) {
        case 1 => print("x = 1")
        case 0 => print("x = 0")        // 匹配
        case 2 | 3 | 4 => print("other")  // 多值匹配
        case _ => print("其他")
    }
}
```

### 模式类型详解

#### 1. 常量模式

支持：整数字面量、浮点数字面量、字符字面量、布尔字面量、字符串字面量、Unit 字面量

⚠️ **不支持**：字符串插值

#### 2. 通配符模式

使用 `_` 表示，匹配任意值，通常作为最后一个 case

#### 3. 绑定模式

使用标识符，匹配并绑定值

```cj
main() {
    let x = -10
    let y = match (x) {
        case 0 => "zero"
        case n => "x is not zero and x = ${n}"  // n 绑定匹配的值
    }
    println(y)
}
```

#### 4. Tuple 模式

用于匹配元组值

```cj
main() {
    let tv = ("Alice", 24)
    let s = match (tv) {
        case ("Bob", age) => "Bob is ${age} years old"
        case ("Alice", age) => "Alice is ${age} years old"  // age 是绑定模式
        case (name, 100) => "${name} is 100 years old"
        case (_, _) => "someone"
    }
    println(s)
}
```

#### 5. 类型模式

判断运行时类型是否是某个类型的子类型

```cj
main() {
    var d = Derived()
    var r = match (d) {
        case b: Base => b  // b 是类型模式，匹配 Base 类型
        case _ => 0
    }
    println("r = ${r}")
}
```

#### 6. enum 模式

用于匹配 enum 类型的实例

```cj
enum TimeUnit {
    | Year(UInt64)
    | Month(UInt64)
}

main() {
    let x = Year(2)
    let s = match (x) {
        case Year(n) => "x has ${n * 12} months"      // 匹配
        case TimeUnit.Month(n) => "x has ${n} months"  // TimeUnit.Month 是完整路径
    }
    println(s)
}
```

#### ⚠️ 模式嵌套（重要）

Tuple 模式和 enum 模式可以嵌套任意模式

```cj
enum TimeUnit {
    | Year(UInt64)
    | Month(UInt64)
}

enum Command {
    | SetTimeUnit(TimeUnit)
    | GetTimeUnit
    | Quit
}

main() {
    let command = (SetTimeUnit(Year(2022)), SetTimeUnit(Year(2024)))
    match (command) {
        case (SetTimeUnit(Year(year)), _) => println("Set year ${year}")
        case (_, SetTimeUnit(Month(month))) => println("Set month ${month}")
        case _ => ()
    }
}
```

---

## 7. Option 类型

### 定义

```cj
enum Option<T> {
    | Some(T)   // 有值
    | None      // 无值
}
```

### 使用场景

当需要表示某个类型可能有值，也可能没有值的时候使用。

---

## 8. class 类型

### 定义语法

```cj
class ClassName {
    // 成员变量
    // 成员属性
    // 静态初始化器
    // 构造函数
    // 成员函数
    // 操作符函数
}
```

### 示例

```cj
class Rectangle {
    let width: Int64
    let height: Int64

    public init(width: Int64, height: Int64) {
        this.width = width
        this.height = height
    }

    public func area() {
        width * height
    }
}

let rec = Rectangle(10, 20)
let l = rec.height  // l = 20
```

### ⚠️ 访问修饰符（重要）

对于 class 的成员（变量、属性、构造函数、函数）：

| 修饰符 | 含义 | **默认** |
|--------|------|---------|
| `private` | class 定义内可见 | ❌ |
| `internal` | 当前包及子包（含子包的子包）内可见 | ✅ **默认** |
| `protected` | 当前模块及当前类的子类可见 | ❌ |
| `public` | 模块内外均可见 | ❌ |

⚠️ **重要**：成员的默认访问修饰符是 `internal`，不是 `private` 或 `public`。

---

## 9. 集合
>以下添加元素都用`add`方法添加，修改可以使用`[]`下标方式修改， 移除是`remove`, 列表是`remove(at: 1)`
- Array：不需要增加和删除元素，但需要修改元素
- ArrayList：需要频繁对元素增删查改
- HashSet：希望每个元素都是唯一的
- HashMap：希望存储一系列的映射关系

## 10. 包

### 声明
```cj
// The directory structure is as follows:
src
`-- directory_0
    |-- directory_1
    |    |-- a.cj
    |    `-- b.cj
    `-- c.cj
`-- main.cj


// a.cj
package demo.directory_0.directory_1
// b.cj
package demo.directory_0.directory_1
// c.cj
package demo.directory_0
// main.cj
package demo

package demo      // root 包 demo
package demo.directory_0 // root 包 demo 的子包 directory_0
```

### 导入
```cj
package a
import std.math.*
import package1.foo
import {package1.foo, package2.bar, package1.MyClass}


直接使用导入的方法，类型
func test() {
    let a = pow(1,2) // std.math.pow
    foo() // 方法
    let b = MyClass()
}
```

## 11. 单元测试

### 测试宏

- `@Test` - 应用于顶级函数或类，转换为单元测试类
- `@TestCase` - 标记测试类内的函数为测试用例
- `@Fail` - 标记测试失败

### 断言宏

#### Assert 断言（失败停止用例）

```cj
@Assert(leftExpr, rightExpr)      // 判断相等
@Assert(condition: Bool)          // 判断条件
```

#### Expect 断言（失败继续执行）

```cj
@Expect(leftExpr, rightExpr)      // 判断相等
@Expect(condition: Bool)          // 判断条件
```

### 完整示例

```cj
@Test
class LexerTest {
    @TestCase
    func test() {
        let a = 1

        // 方式一：手动判断
        if (a != 1) {
            @Fail("a is not 1")
        }

        // 方式二：Assert 条件
        @Assert(a != 1)

        // 方式三：Assert 相等
        @Assert(a, 1)
    }
}
```

---

## 10. 常见错误与注意事项

### 变量相关

1. ⚠️ `let` 不支持变量遮蔽，不能在同一作用域重新定义同名变量
2. 函数参数默认是 `let` 不可变的
3. 成员变量默认访问修饰符是 `internal`

### 控制流相关

4. ⚠️ 所有条件表达式（`if`、`while`、`for-in`）的括号不能省略
5. ⚠️ 不支持 `goto`，`break`/`continue` 不支持标签跳转

### 类型转换相关

6. `Rune` 转整数需要确保在有效 Unicode 范围内
7. 原始字符串字面量中转义字符不会被转义

### 模式匹配相关

8. match 表达式的 case 按顺序匹配，不会自动优化
9. 通配符模式 `_` 应放在最后

### 其他

10. `Unit` 类型只支持赋值、判等、判不等操作
11. Lambda 表达式可以立即调用：`{ => 123 }()`
12. 插值字符串使用 `${}` 而非 `{}`
13. `Duration` 和 `sleep` 在 `std.core` 里不需导入

---

## 快速参考

### 代码块

```cj
main() {
    // 条件判断（必须有括号）
    if (条件) {
        // ...
    } else {
        // ...
    }

    // 循环
    while (条件) { }
    do { } while (条件)
    for (变量 in 序列) { }

    // 模式匹配
    match (值) {
        case 模式 => 处理
        case _ => 默认
    }
}
```

### 类型后缀速查

| 类型 | 后缀 |
|------|------|
| 整数 | `Int8`, `Int16`, `Int32`, `Int64`, `IntNative` |
| 无符号整数 | `UInt8`, `UInt16`, `UInt32`, `UInt64`, `UIntNative` |
| 浮点 | `Float16`, `Float32`, `Float64` |
| 字符 | `Rune` |
| 字符串 | `String` |
| 元组 | `(T1, T2, ...)` |
| 数组 | `Array<T>` |
| 区间 | `Range<T>` |
| 函数 | `(T1, T2) -> Rt` |
