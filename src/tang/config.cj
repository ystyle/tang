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

public func withNotFoundHandler(handler:HandlerFunc): OptionFunc {
    return  { c =>  c.notFoundHandler = c.group.wrap(handler)}
}

public func withMethodNotAllowedHandler(handler:HandlerFunc): OptionFunc {
    return  { c =>  c.methodNotAllowedHandler = c.group.wrap(handler)}
}

type GroupOptionFunc = (Config) -> Unit

public func withGroup(fn:(Group)->Unit):GroupOptionFunc {
    return {c:Config => fn(c.group)}
}

public func withMiddleware(fns:Array<MiddlewareFunc>):GroupOptionFunc {
    return {c => 
        for (fn in fns) {
            c.group.stack.append(fn)
        }
    }
}

public func use(fns:Array<MiddlewareFunc>):GroupOptionFunc {
    return withMiddleware(fns)
}

public func withHandler(fn:HandlerFunc):GroupOptionFunc {
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