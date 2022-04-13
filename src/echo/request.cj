package echo

from std import net.*

type HandlerFunc = (ResponseWriteStream, Request) -> Result<Unit>

type MiddlewareFunc = (HandlerFunc) -> HandlerFunc