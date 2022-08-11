### 返回json数据

可以直接使用`JSON`和`JSONWithCode`方法返回json数据， value需要实现Serializable接口, 详情请查看[src/main.cj](/examples/json/src/main.cj)

- `public func JSON<T>(w: ResponseWriteStream, value:T) where T <: Serializable<T>`
- `public func JSON<T>(w: ResponseWriteStream, code:Int64, value:T) where T <: Serializable<T>`

另外也可以使用 `PlainString` 和 `PlainStringWithCode` 返回String数据
- `func PlainString(w: ResponseWriteStream, value:String)`
- `func PlainStringWithCode(w: ResponseWriteStream, code:Int64, value:String)`