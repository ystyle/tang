package tang

from net import http.*

type HandlerFunc = (ResponseWriteStream, Request) -> Unit

type MiddlewareFunc = (HandlerFunc) -> HandlerFunc