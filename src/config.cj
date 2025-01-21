package tang

import net.http.{HttpContext, FuncHandler}

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

func withGroup(fn:(Group)->Unit):GroupOptionFunc {
    return {c:Config => fn(c.group)}
}

func withMiddleware(fns:Array<MiddlewareFunc>):GroupOptionFunc {
    return {c => 
        for (fn in fns) {
            c.group.stack.add(fn)
        }
    }
}

public func use(fns:Array<MiddlewareFunc>):GroupOptionFunc {
    return withMiddleware(fns)
}

public func withHandler(fn:HandlerFunc):GroupOptionFunc {
   return { c => 
        let md:MiddlewareFunc = {next => 
            return { ctx =>
                fn(ctx)
                return next(ctx)
            }
        }
        c.group.stack.add(md)
   }
}

public func withStdHandlr(fn:(HttpContext) -> Unit): HandlerFunc {
    return {ctx => 
        fn(ctx.context)
    }
}

public func withStdFunHandlr(handler:FuncHandler): HandlerFunc {
    return {ctx => 
        handler.handle(ctx.context)
    }
}