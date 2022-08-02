package tang

public class Config {
    var notFoundHandler:HandlerFunc
    var methodNotAllowedHandler:HandlerFunc
    var group:Group
    init(group:Group) {
        this.group = group
        this.notFoundHandler = defaultNoFoundHandler
        this.methodNotAllowedHandler = defaultMethodNotAllowedHandler
    }
}

type OptionFunc = (Config) -> Unit

public func WithNotFoundHandler(handler:HandlerFunc): OptionFunc {
    return  { c =>  c.notFoundHandler = c.group.wrap(handler)}
}

public func WithMethodNotAllowedHandler(handler:HandlerFunc): OptionFunc {
    return  { c =>  c.methodNotAllowedHandler = c.group.wrap(handler)}
}

type GroupOptionFunc = (Config) -> Unit

public func WithGroup(fn:(Group)->Unit):GroupOptionFunc {
    return {c:Config => fn(c.group)}
}

public func WithMiddleware(fns:Array<MiddlewareFunc>):GroupOptionFunc {
    return {c => 
        for (fn in fns) {
            c.group.stack.append(fn)
        }
    }
}

public func Use(fns:Array<MiddlewareFunc>):GroupOptionFunc {
    return WithMiddleware(fns)
}

public func WithHandler(fn:HandlerFunc):GroupOptionFunc {
   return { c => 
        let md:MiddlewareFunc = {next => 
            return { w, r =>
                fn(w, r)
                return next(w, r)
            }
        }
        c.group.stack.append(md)
   }
}