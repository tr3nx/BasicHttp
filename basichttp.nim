import asynchttpserver,
       asyncnet,
       asyncdispatch,
       json

type
  Route = object
    path: string
    name: string
    kind: HttpMethod
    fn: proc (req: Request, headers: Httpheaders): Response {.gcsafe.}
  Routes = array[4, Route]
  Response = (HttpCode, string, HttpHeaders)

var
  routes {.threadvar.}: Routes

proc home(req: Request, headers: Httpheaders): Response =
  var data = `$`(%* {"homepage": true})
  (Http200, data, headers)

proc ip(req: Request, headers: Httpheaders): Response =
  var data = `$`(%* {"ip": asyncnet.getPeerAddr(req.client)[0]})
  (Http200, data, headers)

proc fourohfour(req: Request, headers: Httpheaders): Response =
  var data = `$`(%* {"error": 404})
  (Http404, data, headers)

proc parseRoute(req: Request): Route =
  for r in routes:
    if r.path == req.url.path and r.kind == req.reqMethod:
      return r
  return routes[0]

proc processRequest(req: Request): Response =
  let
    route = parseRoute(req)
    headers = newHttpHeaders([("Content-Type","application/json")])
  route.fn(req, headers)

proc asyncHttpHandler(req: Request) {.async.} =
  let (status, data, headers) = processRequest(req)
  await req.respond(status, data, headers)

when isMainModule:
  routes = [
    Route(path: "/404",    name: "404",    kind: HttpGet, fn: fourohfour),
    Route(path: "/",       name: "root",   kind: HttpGet, fn: home),
    Route(path: "/home",   name: "home",   kind: HttpGet, fn: home),
    Route(path: "/ip",     name: "ip",     kind: HttpGet, fn: ip)
  ]

  var server = newAsyncHttpServer()
  waitFor server.serve(Port(6000), asyncHttpHandler)
